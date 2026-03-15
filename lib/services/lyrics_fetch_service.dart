import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/services/lyrics_service.dart';

/// Busca letras online via LRCLIB (api.lrclib.net).
///
/// Prioriza letras sincronizadas (LRC) quando disponíveis.
/// Fallback para letras não sincronizadas (plain text).
class LyricsFetchService {
  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 10);

  /// Busca letras para uma música.
  /// Retorna lista de [LyricLine] ou null se não encontrar.
  static Future<List<LyricLine>?> fetch({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      // 1. Tentar busca exata via GET /get
      final result = await _fetchExact(title, artist, album, duration);
      if (result != null) return result;

      // 2. Fallback: busca por termo via GET /search
      return _fetchSearch(title, artist);
    } catch (e) {
      debugPrint('[LyricsFetch] Error: $e');
      return null;
    }
  }

  static Future<List<LyricLine>?> _fetchExact(
    String title, String artist, String? album, Duration? duration,
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
    return _parseResponse(json);
  }

  static Future<List<LyricLine>?> _fetchSearch(
    String title, String artist,
  ) async {
    final query = '$title $artist';
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode != 200) return null;

    final list = jsonDecode(response.body) as List<dynamic>;
    if (list.isEmpty) return null;

    // Pick the first result that has synced lyrics, or first with any lyrics
    Map<String, dynamic>? best;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      if (m['syncedLyrics'] != null && (m['syncedLyrics'] as String).isNotEmpty) {
        best = m;
        break;
      }
      best ??= m;
    }

    if (best == null) return null;
    return _parseResponse(best);
  }

  static List<LyricLine>? _parseResponse(Map<String, dynamic> json) {
    // Prefer synced (LRC) over plain
    final synced = json['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) {
      final lines = LyricsService.parseLrc(synced);
      if (lines.isNotEmpty) return lines;
    }

    final plain = json['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) {
      return plain
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => LyricLine(text: l.trim()))
          .toList();
    }

    return null;
  }

  static Map<String, String> get _headers => {
    'User-Agent': 'ConstanzaPlayer/1.0',
  };
}
