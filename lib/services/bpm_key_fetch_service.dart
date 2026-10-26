import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado do fetch de BPM e features da música.
///
/// ReccoBeats NÃO fornece `key`/`scale` — esses campos ficam por conta
/// da análise DSP nativa (AudioAnalysisPlugin.kt) e são preenchidos em
/// camadas superiores (AudioAnalysisState).
class BpmKeyResult {
  const BpmKeyResult({
    this.bpm,
    this.key,
    this.scale,
    this.source,
    this.camelotCode,
    this.energy,
    this.danceability,
    this.happiness,
    this.acousticness,
    this.instrumentalness,
    this.liveness,
    this.loudness,
    this.speechiness,
  });

  final int? bpm;
  final String? key;
  final String? scale;
  final String? source;
  final String? camelotCode;
  final double? energy;
  final double? danceability;
  final double? happiness; // = valence
  final double? acousticness;
  final double? instrumentalness;
  final double? liveness;
  final double? loudness; // dB
  final double? speechiness;

  bool get hasBpm => bpm != null && bpm! > 0;
  bool get hasKey => key != null && key!.isNotEmpty && scale != null;
  bool get hasData => hasBpm || hasKey || energy != null;

  BpmKeyResult mergeWith(BpmKeyResult other) => BpmKeyResult(
    bpm: other.bpm ?? bpm,
    key: other.key ?? key,
    scale: other.scale ?? scale,
    source: other.source ?? source,
    camelotCode: other.camelotCode ?? camelotCode,
    energy: other.energy ?? energy,
    danceability: other.danceability ?? danceability,
    happiness: other.happiness ?? happiness,
    acousticness: other.acousticness ?? acousticness,
    instrumentalness: other.instrumentalness ?? instrumentalness,
    liveness: other.liveness ?? liveness,
    loudness: other.loudness ?? loudness,
    speechiness: other.speechiness ?? speechiness,
  );

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'key': key,
    'scale': scale,
    'source': source,
    'camelotCode': camelotCode,
    'energy': energy,
    'danceability': danceability,
    'happiness': happiness,
    'acousticness': acousticness,
    'instrumentalness': instrumentalness,
    'liveness': liveness,
    'loudness': loudness,
    'speechiness': speechiness,
  };

  factory BpmKeyResult.fromJson(Map<String, dynamic> json) => BpmKeyResult(
    bpm: json['bpm'] as int?,
    key: json['key'] as String?,
    scale: json['scale'] as String?,
    source: json['source'] as String?,
    camelotCode: json['camelotCode'] as String?,
    energy: (json['energy'] as num?)?.toDouble(),
    danceability: (json['danceability'] as num?)?.toDouble(),
    happiness: (json['happiness'] as num?)?.toDouble(),
    acousticness: (json['acousticness'] as num?)?.toDouble(),
    instrumentalness: (json['instrumentalness'] as num?)?.toDouble(),
    liveness: (json['liveness'] as num?)?.toDouble(),
    loudness: (json['loudness'] as num?)?.toDouble(),
    speechiness: (json['speechiness'] as num?)?.toDouble(),
  );
}

/// Serviço que busca BPM e audio-features via **ReccoBeats API**.
///
/// Fluxo:
///   1. Spotify Search (client-credentials) → encontra track ID oficial
///   2. ReccoBeats `/v1/audio-features?ids={spotifyId}` → tempo, energy,
///      danceability, valence, acousticness, loudness, etc.
///
/// Credenciais necessárias:
///   - Spotify: client_id + client_secret (developer.spotify.com) — obrigatório
///   - ReccoBeats: sem API key (público, grátis, com rate-limit brando)
///
/// Observação: ReccoBeats NÃO fornece tonalidade/modo — o key detection
/// continua a ser feito por DSP nativo (AudioAnalysisPlugin.kt).
///
/// Nunca lança exceção — retorna null se nada for encontrado.
class BpmKeyFetchService {
  // ─── Storage keys ─────────────────────────────────────────
  // v5: caches anteriores têm resultados de faixas erradas (busca sem
  // verificação) — descartados.
  static const _cacheKey = 'bpm_key_cache_v5';
  static const _spotifyCredsKey = 'spotify_credentials';
  static const _spotifyTokenKey = 'spotify_access_token';
  static const _spotifyTokenExpiryKey = 'spotify_token_expiry';

  static const _maxMemCache = 500;
  static const _timeout = Duration(seconds: 12);

  // ReccoBeats
  static const _reccoBase = 'https://api.reccobeats.com/v1';

  // ─── In-memory state ──────────────────────────────────────
  static final Map<String, BpmKeyResult> _memCache = {};
  static bool _diskLoaded = false;

  // Spotify auth
  static String? _spotifyClientId;
  static String? _spotifyClientSecret;
  static String? _spotifyToken;
  static DateTime? _spotifyTokenExpiry;

  // Concurrency guard — evita dupla auth simultânea
  static Future<String?>? _inflightTokenFetch;

  // ─── Accessors ────────────────────────────────────────────

  static bool get hasSpotifyCredentials =>
      _spotifyClientId != null &&
      _spotifyClientId!.isNotEmpty &&
      _spotifyClientSecret != null &&
      _spotifyClientSecret!.isNotEmpty;

  /// Spotify é obrigatório para obter track IDs que o ReccoBeats consome.
  static bool get hasCredentials => hasSpotifyCredentials;

  static String? get spotifyClientId => _spotifyClientId;
  static String? get spotifyClientSecret => _spotifyClientSecret;

  // ─── Init ─────────────────────────────────────────────────

  static Future<void> loadCache() async {
    if (_diskLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Spotify credentials
      final spotifyJson = prefs.getString(_spotifyCredsKey);
      if (spotifyJson != null) {
        final m = jsonDecode(spotifyJson) as Map<String, dynamic>;
        _spotifyClientId = m['clientId'] as String?;
        _spotifyClientSecret = m['clientSecret'] as String?;
      }
      _spotifyToken = prefs.getString(_spotifyTokenKey);
      final expiryMs = prefs.getInt(_spotifyTokenExpiryKey);
      if (expiryMs != null) {
        _spotifyTokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      }

      // Migração: limpar chaves legadas do GetSongBPM
      await prefs.remove('getsongbpm_api_key');
      await prefs.remove('bpm_key_cache_v3');
      await prefs.remove('bpm_key_cache_v4');

      // Results cache
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          try {
            _memCache[e.key] = BpmKeyResult.fromJson(
              e.value as Map<String, dynamic>,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[BpmKey] loadCache error: $e');
    }
    _diskLoaded = true;
  }

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {for (final e in _memCache.entries) e.key: e.value.toJson()};
      await prefs.setString(_cacheKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[BpmKey] saveCache error: $e');
    }
  }

  // ─── Credential management ────────────────────────────────

  static Future<void> saveSpotifyCredentials(
    String clientId,
    String clientSecret,
  ) async {
    _spotifyClientId = clientId.trim();
    _spotifyClientSecret = clientSecret.trim();
    _spotifyToken = null;
    _spotifyTokenExpiry = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _spotifyCredsKey,
        jsonEncode({
          'clientId': _spotifyClientId,
          'clientSecret': _spotifyClientSecret,
        }),
      );
      await prefs.remove(_spotifyTokenKey);
      await prefs.remove(_spotifyTokenExpiryKey);
    } catch (e) {
      debugPrint('[BpmKey] saveSpotifyCredentials error: $e');
    }
  }

  static Future<void> clearSpotifyCredentials() async {
    _spotifyClientId = null;
    _spotifyClientSecret = null;
    _spotifyToken = null;
    _spotifyTokenExpiry = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_spotifyCredsKey);
      await prefs.remove(_spotifyTokenKey);
      await prefs.remove(_spotifyTokenExpiryKey);
    } catch (e) {
      debugPrint('[BpmKey] clearSpotifyCredentials error: $e');
    }
  }

  // ─── Cache helpers ────────────────────────────────────────

  static String _cacheId(String title, String artist) =>
      '${_normalize(title)}|${_normalize(artist)}';

  static BpmKeyResult? getCached(String title, String artist) =>
      _memCache[_cacheId(title, artist)];

  static void _putCache(String title, String artist, BpmKeyResult r) {
    final id = _cacheId(title, artist);
    if (_memCache.length >= _maxMemCache) {
      for (final k in _memCache.keys.take(50).toList()) {
        _memCache.remove(k);
      }
    }
    _memCache[id] = r;
    _saveCache();
  }

  // ─── Main fetch ───────────────────────────────────────────

  /// Busca BPM e audio-features para uma música. NUNCA lança exceção.
  static Future<BpmKeyResult?> fetch({
    required String title,
    required String artist,
  }) async {
    if (title.isEmpty || artist.isEmpty) return null;
    if (!hasSpotifyCredentials) return null;

    final cached = getCached(title, artist);
    if (cached != null) return cached;

    try {
      // 1. Spotify Search → obtém Spotify track ID
      final token = await _getSpotifyToken();
      if (token == null) return null;

      final spotifyHit = await _spotifySearch(token, title, artist);
      if (spotifyHit == null) {
        debugPrint(
          '[BpmKey] Spotify: track não encontrada para "$title" — "$artist"',
        );
        return null;
      }

      // 2. ReccoBeats audio-features
      final result = await _fetchReccoBeats(spotifyHit.trackId);
      if (result != null && result.hasData) {
        _putCache(title, artist, result);
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('[BpmKey] fetch error: $e');
      return null;
    }
  }

  // ─── Spotify Search ───────────────────────────────────────

  static Future<String?> _getSpotifyToken() async {
    if (_spotifyToken != null &&
        _spotifyTokenExpiry != null &&
        DateTime.now().isBefore(
          _spotifyTokenExpiry!.subtract(const Duration(seconds: 60)),
        )) {
      return _spotifyToken;
    }
    if (!hasSpotifyCredentials) return null;

    // Evita múltiplas auths concorrentes
    final inflight = _inflightTokenFetch;
    if (inflight != null) return inflight;

    final future = _doSpotifyTokenFetch();
    _inflightTokenFetch = future;
    try {
      return await future;
    } finally {
      _inflightTokenFetch = null;
    }
  }

  static Future<String?> _doSpotifyTokenFetch() async {
    try {
      final creds = base64Encode(
        utf8.encode('$_spotifyClientId:$_spotifyClientSecret'),
      );
      final res = await http
          .post(
            Uri.parse('https://accounts.spotify.com/api/token'),
            headers: {
              'Authorization': 'Basic $creds',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=client_credentials',
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('[Spotify] Auth failed: ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) return null;
      final expiresIn = data['expires_in'] as int? ?? 3600;
      _spotifyToken = token;
      _spotifyTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spotifyTokenKey, token);
      await prefs.setInt(
        _spotifyTokenExpiryKey,
        _spotifyTokenExpiry!.millisecondsSinceEpoch,
      );

      debugPrint('[Spotify] Auth OK, expires in ${expiresIn}s');
      return token;
    } catch (e) {
      debugPrint('[Spotify] Auth error: $e');
      return null;
    }
  }

  static Future<_SpotifyHit?> _spotifySearch(
    String token,
    String title,
    String artist,
  ) async {
    final cleanTitle = _cleanTitle(title);
    // Tenta filtros precisos, depois busca geral
    for (final q in [
      'track:$cleanTitle artist:$artist',
      '$cleanTitle $artist',
    ]) {
      try {
        final url = Uri.parse(
          'https://api.spotify.com/v1/search?q=${Uri.encodeQueryComponent(q)}&type=track&limit=5',
        );
        final res = await http
            .get(url, headers: {'Authorization': 'Bearer $token'})
            .timeout(_timeout);

        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items =
            (data['tracks'] as Map<String, dynamic>?)?['items']
                as List<dynamic>?;
        if (items == null || items.isEmpty) continue;

        // Só aceita um resultado que seja de fato a mesma música: o Spotify
        // sempre devolve *algo*, e aceitar o primeiro dava o BPM de outra
        // faixa para músicas que ele não conhece.
        for (final item in items) {
          final track = item as Map<String, dynamic>;
          final id = track['id'] as String?;
          final name = track['name'] as String? ?? '';
          final artistNames = [
            for (final a in (track['artists'] as List<dynamic>? ?? const []))
              (a as Map<String, dynamic>)['name'] as String? ?? '',
          ];
          if (id == null || id.isEmpty || name.isEmpty) continue;
          if (isSameTrack(cleanTitle, artist, name, artistNames)) {
            return _SpotifyHit(id, name, artistNames.firstOrNull ?? '');
          }
        }
      } catch (e) {
        debugPrint('[BpmKey] Spotify search parse error: $e');
      }
    }
    return null;
  }

  // ─── ReccoBeats ───────────────────────────────────────────

  static Future<BpmKeyResult?> _fetchReccoBeats(String spotifyTrackId) async {
    try {
      final url = Uri.parse('$_reccoBase/audio-features?ids=$spotifyTrackId');
      final res = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('[ReccoBeats] HTTP ${res.statusCode}: ${res.body}');
        return null;
      }

      final body = jsonDecode(res.body);
      // A API pode devolver {content:[...]} ou uma lista direta
      Map<String, dynamic>? track;
      if (body is Map<String, dynamic>) {
        final content = body['content'];
        if (content is List && content.isNotEmpty) {
          track = content.first as Map<String, dynamic>?;
        } else if (body.containsKey('tempo')) {
          // resposta já é o objeto
          track = body;
        }
      } else if (body is List && body.isNotEmpty) {
        track = body.first as Map<String, dynamic>?;
      }

      if (track == null) {
        debugPrint('[ReccoBeats] Empty content for $spotifyTrackId');
        return null;
      }

      final tempo = (track['tempo'] as num?)?.toDouble();
      int? bpm;
      if (tempo != null && tempo.isFinite) {
        final rounded = tempo.round();
        if (rounded >= 40 && rounded <= 250) bpm = rounded;
      }

      double? clamp01(Object? v) {
        if (v is num) {
          final d = v.toDouble();
          if (!d.isFinite) return null;
          return d.clamp(0.0, 1.0);
        }
        return null;
      }

      final result = BpmKeyResult(
        bpm: bpm,
        source: 'reccobeats',
        energy: clamp01(track['energy']),
        danceability: clamp01(track['danceability']),
        happiness: clamp01(track['valence']),
        acousticness: clamp01(track['acousticness']),
        instrumentalness: clamp01(track['instrumentalness']),
        liveness: clamp01(track['liveness']),
        loudness: (track['loudness'] as num?)?.toDouble(),
        speechiness: clamp01(track['speechiness']),
      );

      debugPrint(
        '[ReccoBeats] $spotifyTrackId → bpm=$bpm '
        'energy=${result.energy} dance=${result.danceability}',
      );
      return result;
    } catch (e) {
      debugPrint('[ReccoBeats] error: $e');
      return null;
    }
  }

  // ─── Credential test ──────────────────────────────────────

  /// Testa as credenciais Spotify fazendo uma autenticação.
  static Future<bool> testSpotifyCredentials(
    String clientId,
    String clientSecret,
  ) async {
    if (clientId.trim().isEmpty || clientSecret.trim().isEmpty) return false;
    try {
      final creds = base64Encode(
        utf8.encode('${clientId.trim()}:${clientSecret.trim()}'),
      );
      final res = await http
          .post(
            Uri.parse('https://accounts.spotify.com/api/token'),
            headers: {
              'Authorization': 'Basic $creds',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=client_credentials',
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Cache management ─────────────────────────────────────

  static Future<void> clearCache() async {
    _memCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  static int get cachedCount => _memCache.length;

  // ─── Helpers ─────────────────────────────────────────────

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

  /// Palavras normalizadas, sem acentos (Spotify e tags locais divergem).
  static Set<String> _words(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
  }

  /// Fração das palavras de [a] presentes em [b].
  static double _coverage(Set<String> a, Set<String> b) =>
      a.isEmpty ? 0 : a.where(b.contains).length / a.length;

  /// O resultado do Spotify é a mesma música? Exige título quase igual e
  /// pelo menos um artista em comum.
  @visibleForTesting
  static bool isSameTrack(
    String title,
    String artist,
    String hitTitle,
    List<String> hitArtists,
  ) {
    final t = _words(_cleanTitle(title));
    final ht = _words(_cleanTitle(hitTitle));
    if (_coverage(t, ht) < 0.8 || _coverage(ht, t) < 0.6) return false;

    final a = _words(artist);
    if (a.isEmpty) return false;
    for (final name in hitArtists) {
      final ha = _words(name);
      if (_coverage(ha, a) >= 0.8 || _coverage(a, ha) >= 0.8) return true;
    }
    return false;
  }

  static String _cleanTitle(String title) => title
      .replaceAll(
        RegExp(
          r'\s*[\(\[](feat\.?|ft\.?|with|remix|remaster|live|acoustic|version|edit|radio)[^\)\]]*[\)\]]',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\s*-\s*(feat\.?|ft\.?|remix|remaster|live|acoustic).*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

class _SpotifyHit {
  const _SpotifyHit(this.trackId, this.title, this.artist);
  final String trackId;
  final String title;
  final String artist;
}
