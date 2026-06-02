import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/services/lyrics_service.dart';

/// Um resultado candidato vindo do LRCLIB.
///
/// Usado tanto pela busca automática (`fetch`) quanto pelo seletor manual
/// (`search`), que mostra vários candidatos ao utilizador.
class LyricsHit {
  const LyricsHit({
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.duration,
    this.syncedLyrics,
    this.plainLyrics,
  });

  final String trackName;
  final String artistName;
  final String? albumName;
  final Duration? duration;
  final String? syncedLyrics;
  final String? plainLyrics;

  bool get hasSynced => (syncedLyrics?.trim().isNotEmpty ?? false);
  bool get hasPlain => (plainLyrics?.trim().isNotEmpty ?? false);
  bool get hasAnyLyrics => hasSynced || hasPlain;

  /// Converte o melhor conteúdo disponível em linhas (sincronizadas > texto).
  List<LyricLine>? toLines() {
    if (hasSynced) {
      final lines = LyricsService.parseLrc(syncedLyrics!);
      if (lines.isNotEmpty) return lines;
    }
    if (hasPlain) {
      return plainLyrics!
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => LyricLine(text: l.trim()))
          .toList();
    }
    return null;
  }

  static LyricsHit fromJson(Map<String, dynamic> m) {
    final dur = m['duration'];
    return LyricsHit(
      trackName: (m['trackName'] as String?)?.trim() ?? '',
      artistName: (m['artistName'] as String?)?.trim() ?? '',
      albumName: (m['albumName'] as String?)?.trim(),
      duration: dur is num ? Duration(seconds: dur.round()) : null,
      syncedLyrics: m['syncedLyrics'] as String?,
      plainLyrics: m['plainLyrics'] as String?,
    );
  }
}

/// Busca letras online via LRCLIB (lrclib.net).
///
/// - [fetch]: melhor correspondência automática (uma chamada, sem interação).
/// - [search]: lista de candidatos para escolha manual do utilizador.
///
/// Prioriza letras sincronizadas (LRC); cai para texto simples quando não há.
class LyricsFetchService {
  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 10);

  // ── Normalização de query ─────────────────────────────────────

  /// Limpa ruído típico de tags ID3 que derruba a busca:
  /// `(feat. X)`, `[Official Video]`, `- Remaster 2011`, `- Live`, etc.
  static String _clean(String input) {
    var t = input;
    // Conteúdo entre parênteses/colchetes/chaves.
    t = t.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
    // "feat./ft./featuring/with ..." até ao fim.
    t = t.replaceAll(
      RegExp(r'\b(feat\.?|ft\.?|featuring|with)\b.*$', caseSensitive: false),
      ' ',
    );
    // Sufixo " - Remaster / - Live / - Radio Edit / - 2011 Mix ...".
    t = t.replaceAll(RegExp(r'\s[-–—]\s.*$'), ' ');
    // Aspas e separadores residuais.
    t = t.replaceAll(RegExp(r'["“”]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? input.trim() : t;
  }

  // ── API pública ───────────────────────────────────────────────

  /// Busca a melhor correspondência automaticamente.
  /// Retorna as linhas ou `null` se nada for encontrado.
  static Future<List<LyricLine>?> fetch({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    debugPrint(
      '[LyricsFetch] query title="$title" artist="$artist" '
      'album="$album" duration=${duration?.inSeconds}s',
    );
    try {
      // 1. /get exato (título/artista/álbum/duração crus).
      final exact = await _fetchExact(title, artist, album, duration);
      if (exact != null) {
        debugPrint('[LyricsFetch] /get HIT');
        return exact;
      }

      // 2. /get exato com título/artista limpos.
      final cTitle = _clean(title);
      final cArtist = _clean(artist);
      if (cTitle != title || cArtist != artist) {
        final cleaned = await _fetchExact(cTitle, cArtist, null, duration);
        if (cleaned != null) {
          debugPrint('[LyricsFetch] /get(cleaned) HIT');
          return cleaned;
        }
      }

      // 3. /search — escolhe o melhor candidato. Como o /search é fuzzy (e a
      // estratégia "só título" pode trazer faixas de outros artistas), só
      // aceitamos candidatos cujo título E artista batem com a música tocando.
      // Sem este filtro, músicas com título comum recebiam letras de outra
      // faixa qualquer ("letras que não são das respetivas músicas").
      final hits = await search(title: title, artist: artist);
      final matching = hits
          .where((h) => _matches(h, title, artist))
          .toList();
      final best = _pickBest(matching, duration);
      if (best != null) {
        debugPrint(
          '[LyricsFetch] /search HIT '
          '(${matching.length}/${hits.length} matching candidates)',
        );
        return best.toLines();
      }

      debugPrint('[LyricsFetch] MISS');
      return null;
    } on TimeoutException {
      debugPrint('[LyricsFetch] Request timed out');
      return null;
    } catch (e) {
      debugPrint('[LyricsFetch] Error: $e');
      return null;
    }
  }

  /// Lista de candidatos para o seletor manual, já deduplicada e ordenada
  /// (sincronizadas primeiro). Vazia se nada for encontrado.
  static Future<List<LyricsHit>> search({
    required String title,
    required String artist,
  }) async {
    final hits = <LyricsHit>[];
    final seen = <String>{};

    Future<void> run(Map<String, String> params) async {
      try {
        final uri = Uri.parse(
          '$_baseUrl/search',
        ).replace(queryParameters: params);
        final r = await http.get(uri, headers: _headers).timeout(_timeout);
        if (r.statusCode != 200) return;
        final list = jsonDecode(r.body) as List<dynamic>;
        for (final item in list) {
          final hit = LyricsHit.fromJson(item as Map<String, dynamic>);
          if (!hit.hasAnyLyrics) continue;
          final key =
              '${hit.trackName.toLowerCase()}|'
              '${hit.artistName.toLowerCase()}|'
              '${hit.duration?.inSeconds ?? 0}';
          if (seen.add(key)) hits.add(hit);
        }
      } catch (_) {
        // Ignora falha de uma estratégia; as outras ainda podem acertar.
      }
    }

    // Estratégia 1: estruturada (track_name + artist_name).
    await run({'track_name': title, 'artist_name': artist});
    // Estratégia 2: termo livre limpo "titulo artista".
    if (hits.length < 5) {
      final q = '${_clean(title)} ${_clean(artist)}'.trim();
      if (q.isNotEmpty) await run({'q': q});
    }
    // Estratégia 3: só o título limpo (artista mal preenchido no ID3).
    if (hits.length < 3) {
      final q = _clean(title);
      if (q.isNotEmpty) await run({'q': q});
    }

    hits.sort((a, b) {
      if (a.hasSynced != b.hasSynced) return a.hasSynced ? -1 : 1;
      return 0;
    });
    return hits.take(25).toList();
  }

  // ── Internos ──────────────────────────────────────────────────

  /// Remove diacríticos (ç, ã, é, ñ…) para comparar títulos/artistas de forma
  /// robusta — o ID3 local e o LRCLIB nem sempre normalizam acentos igual.
  static String _stripDiacritics(String s) {
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }

  /// Normaliza para um conjunto de tokens alfanuméricos minúsculos, já sem
  /// acentos, ruído entre parênteses/colchetes e sufixos "feat./- Remaster".
  static Set<String> _tokens(String input) {
    var t = _stripDiacritics(_clean(input).toLowerCase());
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
  }

  /// Artistas tidos como "não informado" — quando o ID3 não traz artista
  /// confiável, não dá para validar por artista (deixamos passar).
  static const _unknownArtists = {
    '',
    'unknown',
    'unknown artist',
    'desconhecido',
    'artista desconhecido',
    '<unknown>',
  };

  /// `true` se [a] e [b] partilham token suficiente (substring ou ≥1 token
  /// significativo em comum). [minOverlap] = fração mínima de tokens em comum.
  static bool _tokensOverlap(
    Set<String> a,
    Set<String> b, {
    double minOverlap = 0.5,
  }) {
    if (a.isEmpty || b.isEmpty) return false;
    final common = a.intersection(b);
    if (common.isEmpty) return false;
    final ratio = common.length / (a.length < b.length ? a.length : b.length);
    return ratio >= minOverlap;
  }

  /// Valida que o candidato do /search corresponde à música pedida.
  /// Exige correspondência de título E (quando o artista é conhecido) de
  /// artista — evita importar letras de uma faixa homónima de outro artista.
  static bool _matches(LyricsHit hit, String title, String artist) {
    final titleOk = _tokensOverlap(_tokens(title), _tokens(hit.trackName));
    if (!titleOk) return false;

    final reqArtist = _stripDiacritics(artist.trim().toLowerCase());
    if (_unknownArtists.contains(reqArtist)) return true; // não dá p/ validar

    // Artista costuma ter token único significativo em comum — exigimos só 1.
    return _tokensOverlap(
      _tokens(artist),
      _tokens(hit.artistName),
      minOverlap: 0.34,
    );
  }

  static LyricsHit? _pickBest(List<LyricsHit> hits, Duration? duration) {
    if (hits.isEmpty) return null;
    if (duration != null) {
      // Preferir synced com duração dentro de ±3s.
      for (final h in hits) {
        if (h.hasSynced &&
            h.duration != null &&
            (h.duration!.inSeconds - duration.inSeconds).abs() <= 3) {
          return h;
        }
      }
    }
    // Senão, o primeiro synced; senão, o primeiro com qualquer letra.
    for (final h in hits) {
      if (h.hasSynced) return h;
    }
    return hits.first;
  }

  static Future<List<LyricLine>?> _fetchExact(
    String title,
    String artist,
    String? album,
    Duration? duration,
  ) async {
    final params = {
      'track_name': title,
      'artist_name': artist,
      if (album != null && album.isNotEmpty) 'album_name': album,
      if (duration != null) 'duration': duration.inSeconds.toString(),
    };

    final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LyricsHit.fromJson(json).toLines();
  }

  static Map<String, String> get _headers => {
    'User-Agent': 'ConstanzaPlayer/1.0 (https://github.com/constanza)',
  };
}
