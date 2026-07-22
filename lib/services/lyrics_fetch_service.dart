import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/services/lyrics_service.dart';

/// Lançada quando a rede falhou de forma transitória (timeout, sem conexão,
/// rate-limit ou erro 5xx) DEPOIS de esgotar as tentativas.
///
/// É o sinal que permite ao chamador distinguir "a internet/servidor falhou"
/// de "o servidor respondeu que esta música não tem letra". Sem isto, uma
/// falha de rede era tratada como ausência de letra e persistida — obrigando
/// o utilizador a buscar 2-3 vezes até acertar uma janela com rede boa.
class LyricsNetworkException implements Exception {
  const LyricsNetworkException(this.message);
  final String message;
  @override
  String toString() => 'LyricsNetworkException: $message';
}

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

/// Resultado agregado de um conjunto de buscas `/search` disparadas juntas.
///
/// [anyResponse] = ao menos uma query obteve resposta do servidor (200 ou
/// outro status definitivo). [networkFailed] = ao menos uma query falhou por
/// rede. Juntos permitem distinguir "não há letra" de "a rede caiu".
class _SearchOutcome {
  const _SearchOutcome(this.hits, this.anyResponse, this.networkFailed);
  final List<LyricsHit> hits;
  final bool anyResponse;
  final bool networkFailed;
}

/// Resultado de um `/get` exato. [networkFailed] indica falha de rede (o 404
/// do /get é INCONCLUSIVO — quem decide a existência da letra é o /search).
class _ExactOutcome {
  const _ExactOutcome(this.lines, this.networkFailed);
  final List<LyricLine>? lines;
  final bool networkFailed;
  bool get hasLines => lines != null && lines!.isNotEmpty;
}

/// Busca letras online via LRCLIB (lrclib.net).
///
/// - [fetch]: melhor correspondência automática (uma chamada, sem interação).
/// - [search]: lista de candidatos para escolha manual do utilizador.
///
/// Prioriza letras sincronizadas (LRC); cai para texto simples quando não há.
///
/// **Latência:** [fetch] dispara os pedidos independentes em paralelo (duas
/// "ondas") em vez de em cascata sequencial — a maioria das músicas resolve
/// num único round-trip, mesmo quando o `/get` exato falha (caso comum, porque
/// a duração do ID3 raramente bate certo com o LRCLIB).
class LyricsFetchService {
  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 12);

  /// Tentativas por pedido HTTP. Cobre o caso comum: a 1ª chamada bate no
  /// rate-limit do LRCLIB ou num pico de latência da rede móvel.
  static const _maxAttempts = 3;

  /// Backoff exponencial leve: 350ms, 1400ms entre tentativas.
  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 350 * attempt * attempt);

  /// GET com retry+backoff. Repete em timeout, erro de socket/conexão, 429 e
  /// 5xx. Devolve a resposta para QUALQUER status final (incl. 404 — que para
  /// o LRCLIB significa "não existe letra", um resultado definitivo). Só lança
  /// [LyricsNetworkException] quando esgota as tentativas por falha de REDE.
  static Future<http.Response> _get(Uri uri) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final r = await http.get(uri, headers: _headers).timeout(_timeout);
        if ((r.statusCode == 429 || r.statusCode >= 500) &&
            attempt < _maxAttempts) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        return r;
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
      if (attempt < _maxAttempts) {
        await Future<void>.delayed(_backoff(attempt));
      }
    }
    throw LyricsNetworkException(
      'falha de rede após $_maxAttempts tentativas: $lastError',
    );
  }

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
  ///
  /// - Retorna as linhas quando encontra.
  /// - Retorna `null` quando o servidor respondeu mas NÃO há letra para esta
  ///   música (resultado definitivo — pode marcar como "sem letra").
  /// - **Lança [LyricsNetworkException]** quando a rede falhou. O chamador NÃO
  ///   deve marcar a música como "sem letra" neste caso — foi falha de rede,
  ///   não ausência de letra.
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

    // ── Onda 1 (caso comum) ──────────────────────────────────────
    // Dispara em paralelo o caminho preciso (/get exato) e o fuzzy (/search
    // estruturado). Como o /get exige duração exata e quase sempre dá 404,
    // antes a busca só começava DEPOIS de 1-2 /get falharem em série. Agora os
    // dois correm juntos: na maioria das músicas a letra vem num único hop.
    final exactFut = _fetchExactSafe(title, artist, album, duration);
    final structFut = _runSearches([
      {'track_name': title, 'artist_name': artist},
    ]);

    final exact = await exactFut;
    if (exact.hasLines) {
      debugPrint('[LyricsFetch] /get HIT');
      return exact.lines;
    }

    // /search é fuzzy (e a estratégia "só título" pode trazer faixas de outros
    // artistas), por isso só aceitamos candidatos cujo título E artista batem
    // com a música tocando — senão títulos comuns recebiam letra de outra faixa.
    final struct = await structFut;
    final best1 = _pickBest(
      struct.hits.where((h) => _matches(h, title, artist)).toList(),
      duration,
    );
    if (best1 != null) {
      debugPrint('[LyricsFetch] /search HIT (onda 1)');
      return best1.toLines();
    }

    // ── Onda 2 (casos difíceis) ──────────────────────────────────
    // Variantes "limpas" (sem feat./- Remaster/(Live)…) — também em paralelo.
    final cTitle = _clean(title);
    final cArtist = _clean(artist);
    final cleanedFut = (cTitle != title || cArtist != artist)
        ? _fetchExactSafe(cTitle, cArtist, null, duration)
        : Future<_ExactOutcome>.value(const _ExactOutcome(null, false));

    final queries = <Map<String, String>>[];
    final qFull = '$cTitle $cArtist'.trim();
    if (qFull.isNotEmpty) queries.add({'q': qFull});
    if (cTitle.isNotEmpty && cTitle != qFull) queries.add({'q': cTitle});
    final moreFut = _runSearches(queries);

    final cleaned = await cleanedFut;
    if (cleaned.hasLines) {
      debugPrint('[LyricsFetch] /get(cleaned) HIT');
      return cleaned.lines;
    }

    final more = await moreFut;
    final allHits = <LyricsHit>[...struct.hits, ...more.hits];
    final best2 = _pickBest(
      allHits.where((h) => _matches(h, title, artist)).toList(),
      duration,
    );
    if (best2 != null) {
      debugPrint('[LyricsFetch] /search HIT (onda 2)');
      return best2.toLines();
    }

    // Distinguir "rede caiu" de "não há letra": o /search é a autoridade sobre
    // existência. Só lançamos falha de rede se NENHUMA busca obteve resposta E
    // houve falha de rede — o 404 do /get é inconclusivo e não conta aqui.
    final searchResponded = struct.anyResponse || more.anyResponse;
    final anyNetworkFail =
        exact.networkFailed ||
        struct.networkFailed ||
        cleaned.networkFailed ||
        more.networkFailed;
    if (!searchResponded && anyNetworkFail) {
      throw const LyricsNetworkException('busca falhou (sem resposta da rede)');
    }

    debugPrint('[LyricsFetch] MISS (definitivo — servidor respondeu)');
    return null;
  }

  /// Lista de candidatos para o seletor manual, já deduplicada e ordenada
  /// (sincronizadas primeiro). Vazia se nada for encontrado.
  static Future<List<LyricsHit>> search({
    required String title,
    required String artist,
  }) async {
    // As 3 estratégias são independentes → correm em paralelo (antes eram
    // sequenciais, somando latência). Sem o gating "if hits.length < N": com
    // execução concorrente não há ganho em encadear, e mais candidatos ajudam
    // o seletor manual.
    final queries = <Map<String, String>>[
      // Estratégia 1: estruturada (track_name + artist_name).
      {'track_name': title, 'artist_name': artist},
    ];
    // Estratégia 2: termo livre limpo "titulo artista".
    final qFull = '${_clean(title)} ${_clean(artist)}'.trim();
    if (qFull.isNotEmpty) queries.add({'q': qFull});
    // Estratégia 3: só o título limpo (artista mal preenchido no ID3).
    final qTitle = _clean(title);
    if (qTitle.isNotEmpty && qTitle != qFull) queries.add({'q': qTitle});

    final outcome = await _runSearches(queries);

    // Nenhuma resposta E houve falha de rede → propaga como falha de rede para
    // o chamador não confundir com "não há letra".
    if (outcome.hits.isEmpty && outcome.networkFailed && !outcome.anyResponse) {
      throw const LyricsNetworkException('busca falhou (sem resposta da rede)');
    }

    final hits = outcome.hits;
    hits.sort((a, b) {
      if (a.hasSynced != b.hasSynced) return a.hasSynced ? -1 : 1;
      return 0;
    });
    return hits.take(25).toList();
  }

  // ── Internos ──────────────────────────────────────────────────

  /// Dispara N buscas `/search` em paralelo e agrega os candidatos
  /// (deduplicados). Cada query falha de forma isolada: uma falha de rede ou
  /// de parse numa não derruba as outras. Devolve também os flags
  /// resposta/rede para a decisão "não há letra" vs "rede caiu".
  static Future<_SearchOutcome> _runSearches(
    List<Map<String, String>> queries,
  ) async {
    if (queries.isEmpty) return const _SearchOutcome([], false, false);

    var anyResponse = false;
    var networkFailed = false;

    final responses = await Future.wait(
      queries.map((params) async {
        try {
          final uri = Uri.parse(
            '$_baseUrl/search',
          ).replace(queryParameters: params);
          final r = await _get(uri);
          anyResponse = true;
          return r;
        } on LyricsNetworkException {
          networkFailed = true; // as outras ainda podem ter resposta
          return null;
        } catch (_) {
          return null; // erro de parse/inesperado; ignora esta estratégia
        }
      }),
    );

    final hits = <LyricsHit>[];
    final seen = <String>{};
    for (final r in responses) {
      if (r == null || r.statusCode != 200) continue;
      try {
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
        // Corpo malformado numa estratégia; as outras ainda valem.
      }
    }
    return _SearchOutcome(hits, anyResponse, networkFailed);
  }

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

  /// `/get` exato, seguro para correr em paralelo: captura a falha de rede num
  /// flag em vez de a lançar, para não derrubar a busca concorrente. Quem
  /// decide "não há letra" é o `/search` — o 404 do `/get` é inconclusivo.
  static Future<_ExactOutcome> _fetchExactSafe(
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
    try {
      final response = await _get(uri);
      // 404 = LRCLIB não tem ESTA faixa exata; demais não-200 → sem dados.
      if (response.statusCode != 200) return const _ExactOutcome(null, false);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _ExactOutcome(LyricsHit.fromJson(json).toLines(), false);
    } on LyricsNetworkException {
      return const _ExactOutcome(null, true);
    } catch (_) {
      return const _ExactOutcome(null, false);
    }
  }

  static Map<String, String> get _headers => {
    'User-Agent': 'ConstanzaPlayer/1.0 (https://github.com/constanza)',
  };
}
