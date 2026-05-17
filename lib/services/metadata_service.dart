import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fonte de onde veio o resultado.
enum MetadataSource { musicBrainz, iTunes }

/// Resultado de busca de metadados de música.
class MetadataResult {
  const MetadataResult({
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    this.trackNumber,
    this.releaseDate,
    this.coverUrl,
    this.mbid,
    this.source = MetadataSource.musicBrainz,
  });

  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final int? trackNumber;
  final String? releaseDate;
  final String? coverUrl;
  final String? mbid;
  final MetadataSource source;

  String get sourceLabel => switch (source) {
    MetadataSource.musicBrainz => 'MusicBrainz',
    MetadataSource.iTunes => 'iTunes',
  };
}

/// Serviço para buscar metadados de músicas via múltiplas fontes.
class MetadataService {
  // ── MusicBrainz ──
  static const _mbBase = 'https://musicbrainz.org/ws/2';
  static const _userAgent = 'ConstanzaPlayer/1.0 (constanza@app.com)';
  static const _coverArtBase = 'https://coverartarchive.org';

  // ── iTunes ──
  static const _itunesBase = 'https://itunes.apple.com/search';

  /// Busca em todas as fontes simultaneamente.
  static Future<List<MetadataResult>> searchAll(
    String title,
    String artist,
  ) async {
    final futures = await Future.wait([
      _searchMusicBrainz(title, artist).catchError((_) => <MetadataResult>[]),
      _searchItunes(title, artist).catchError((_) => <MetadataResult>[]),
    ]);

    final combined = <MetadataResult>[...futures[0], ...futures[1]];

    // Deduplicate by title+artist (case insensitive)
    final seen = <String>{};
    final deduped = <MetadataResult>[];
    for (final r in combined) {
      final key = '${r.title.toLowerCase()}|${r.artist.toLowerCase()}';
      if (seen.add(key)) deduped.add(r);
    }

    return deduped;
  }

  /// Busca apenas por título em todas as fontes.
  static Future<List<MetadataResult>> searchByTitleAll(String title) async {
    final futures = await Future.wait([
      _searchMusicBrainzByTitle(title).catchError((_) => <MetadataResult>[]),
      _searchItunes(title, '').catchError((_) => <MetadataResult>[]),
    ]);

    final combined = [...futures[0], ...futures[1]];
    final seen = <String>{};
    final deduped = <MetadataResult>[];
    for (final r in combined) {
      final key = '${r.title.toLowerCase()}|${r.artist.toLowerCase()}';
      if (seen.add(key)) deduped.add(r);
    }
    return deduped;
  }

  // ════════════════════════════════════════════════════════════
  // MUSICBRAINZ
  // ════════════════════════════════════════════════════════════

  static Future<List<MetadataResult>> _searchMusicBrainz(
    String title,
    String artist,
  ) async {
    final query = artist.isNotEmpty
        ? Uri.encodeComponent('recording:"$title" AND artist:"$artist"')
        : Uri.encodeComponent('recording:"$title"');
    final url = '$_mbBase/recording?query=$query&limit=6&fmt=json';

    final response = await http
        .get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    try {
      return _parseMbRecordings(json.decode(response.body));
    } on FormatException catch (e) {
      debugPrint('[MetadataService] JSON parse error: $e');
      return [];
    }
  }

  static Future<List<MetadataResult>> _searchMusicBrainzByTitle(
    String title,
  ) async {
    final query = Uri.encodeComponent('recording:"$title"');
    final url = '$_mbBase/recording?query=$query&limit=6&fmt=json';

    final response = await http
        .get(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    try {
      return _parseMbRecordings(json.decode(response.body));
    } on FormatException catch (e) {
      debugPrint('[MetadataService] JSON parse error: $e');
      return [];
    }
  }

  static List<MetadataResult> _parseMbRecordings(Map<String, dynamic> data) {
    final recordings = data['recordings'] as List? ?? [];
    final results = <MetadataResult>[];

    for (final rec in recordings) {
      final recTitle = rec['title'] as String? ?? '';
      final artists = rec['artist-credit'] as List? ?? [];
      final artistName = artists.isNotEmpty
          ? (artists.first['name'] as String? ?? '')
          : '';

      final releases = rec['releases'] as List? ?? [];
      String? albumName;
      String? releaseDate;
      int? trackNumber;
      String? releaseMbid;
      String? genre;

      if (releases.isNotEmpty) {
        final release = releases.first;
        albumName = release['title'] as String?;
        releaseDate = release['date'] as String?;
        releaseMbid = release['id'] as String?;

        final media = release['media'] as List?;
        if (media != null && media.isNotEmpty) {
          final tracks = media.first['track'] as List?;
          if (tracks != null && tracks.isNotEmpty) {
            trackNumber = int.tryParse(
              tracks.first['number']?.toString() ?? '',
            );
          }
        }
      }

      final tags = rec['tags'] as List?;
      if (tags != null && tags.isNotEmpty) {
        genre = tags.first['name'] as String?;
      }

      String? coverUrl;
      if (releaseMbid != null) {
        // Cover Art Archive serve front-250 / front-500 / front-1200 e o
        // original sem sufixo. front-250 (padrão antigo) fica borrado em
        // telas grandes/desktop — front-1200 entrega ótima resolução com
        // tamanho ainda razoável.
        coverUrl = '$_coverArtBase/release/$releaseMbid/front-1200';
      }

      results.add(
        MetadataResult(
          title: recTitle,
          artist: artistName,
          album: albumName,
          genre: genre,
          trackNumber: trackNumber,
          releaseDate: releaseDate,
          coverUrl: coverUrl,
          mbid: releaseMbid,
          source: MetadataSource.musicBrainz,
        ),
      );
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════
  // ITUNES SEARCH API
  // ════════════════════════════════════════════════════════════

  static String? _safeDateSubstring(String? date) {
    if (date == null || date.length < 10) return date;
    return date.substring(0, 10);
  }

  static Future<List<MetadataResult>> _searchItunes(
    String title,
    String artist,
  ) async {
    final searchTerm = artist.isNotEmpty ? '$title $artist' : title;
    final url = Uri.parse(_itunesBase).replace(
      queryParameters: {
        'term': searchTerm,
        'media': 'music',
        'entity': 'song',
        'limit': '6',
      },
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final Map<String, dynamic> data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      debugPrint('[MetadataService] iTunes JSON parse error: $e');
      return [];
    }
    final tracks = data['results'] as List? ?? [];

    final results = <MetadataResult>[];
    for (final track in tracks) {
      final coverSmall = track['artworkUrl100'] as String?;
      // O iTunes devolve sempre 100x100; o tamanho real é trocável na URL.
      // 600x600 ficava sem nitidez em capas grandes — 1200x1200 dá ótima
      // resolução e o iTunes serve esse tamanho de forma confiável.
      final coverUrl = coverSmall?.replaceAll('100x100bb', '1200x1200bb');

      results.add(
        MetadataResult(
          title: track['trackName'] as String? ?? '',
          artist: track['artistName'] as String? ?? '',
          album: track['collectionName'] as String?,
          genre: track['primaryGenreName'] as String?,
          trackNumber: track['trackNumber'] as int?,
          releaseDate: _safeDateSubstring(track['releaseDate'] as String?),
          coverUrl: coverUrl,
          source: MetadataSource.iTunes,
        ),
      );
    }
    return results;
  }
}
