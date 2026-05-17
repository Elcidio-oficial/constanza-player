import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';

import 'media_library_backend.dart';

/// Implementação Android/iOS — consulta o MediaStore via on_audio_query.
///
/// Mantém o comportamento original 1:1 do antigo [AudioScannerService].
class OnAudioQueryBackend implements MediaLibraryBackend {
  OnAudioQueryBackend() : _audioQuery = OnAudioQuery();

  final OnAudioQuery _audioQuery;

  @override
  Future<List<Song>> scanSongs() async {
    try {
      final songModels = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return songModels
          .where((s) => s.duration != null && s.duration! > 10000)
          .map(
            (s) => Song(
              id: s.id.toString(),
              title: s.title,
              artist: s.artist ?? 'Desconhecido',
              album: s.album ?? 'Desconhecido',
              duration: Duration(milliseconds: s.duration ?? 0),
              uri: s.uri ?? '',
              filePath: s.data,
              trackNumber: s.track,
              albumId: s.albumId?.toString(),
              artistId: s.artistId?.toString(),
              dateAdded: s.dateAdded != null
                  ? DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000)
                  : null,
              genre: s.genre,
              composer: s.composer,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[OnAudioQueryBackend] scanSongs error: $e');
      return [];
    }
  }

  @override
  Future<List<Album>> scanAlbums() async {
    try {
      final albumModels = await _audioQuery.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      return albumModels
          .map(
            (a) => Album(
              id: a.id.toString(),
              name: a.album,
              artist: a.artist ?? 'Desconhecido',
              songCount: a.numOfSongs,
              year: null,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[OnAudioQueryBackend] scanAlbums error: $e');
      return [];
    }
  }

  @override
  Future<List<Artist>> scanArtists() async {
    try {
      final artistModels = await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
      );

      return artistModels
          .map(
            (a) => Artist(
              id: a.id.toString(),
              name: a.artist,
              songCount: a.numberOfTracks ?? 0,
              albumCount: a.numberOfAlbums ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[OnAudioQueryBackend] scanArtists error: $e');
      return [];
    }
  }

  @override
  Future<Uint8List?> queryArtwork(
    int id,
    ArtworkType type, {
    int size = 300,
    int quality = 80,
  }) async {
    if (id == 0) return null;
    try {
      return await _audioQuery.queryArtwork(
        id,
        type,
        size: size,
        quality: quality,
      );
    } catch (e) {
      debugPrint('[OnAudioQueryBackend] queryArtwork error: $e');
      return null;
    }
  }

  @override
  List<String> get scanFolders => const [];

  @override
  Future<void> setScanFolders(List<String> folders) async {
    // No-op no Android — MediaStore varre o device inteiro.
  }

  @override
  Future<List<Song>> scanFolder(String folder) async {
    // No-op no Android — seleção de pastas usa o discover do MediaStore.
    return const [];
  }

  @override
  void indexFromSongs(List<Song> songs) {
    // No-op no Android — IDs do MediaStore são estáveis entre execuções,
    // queryArtwork não depende de mapa local.
  }
}
