import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';

/// Serviço de scan de músicas do dispositivo.
///
/// Usa on_audio_query para ler metadata (ID3 tags)
/// dos arquivos de áudio locais.
class AudioScannerService {
  AudioScannerService() : _audioQuery = OnAudioQuery();

  final OnAudioQuery _audioQuery;

  /// Escaneia todas as músicas do dispositivo.
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
      return [];
    }
  }

  /// Escaneia álbuns.
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
      return [];
    }
  }

  /// Escaneia artistas.
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
      return [];
    }
  }

  /// Busca artwork (capa do álbum) por ID da música.
  Future<Uint8List?> getArtwork(int songId, {int size = 300}) async {
    try {
      return await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: size,
        quality: 80,
      );
    } catch (e) {
      return null;
    }
  }

  /// Busca artwork por ID do álbum.
  Future<Uint8List?> getAlbumArtwork(int albumId, {int size = 300}) async {
    try {
      return await _audioQuery.queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        size: size,
        quality: 80,
      );
    } catch (e) {
      return null;
    }
  }
}
