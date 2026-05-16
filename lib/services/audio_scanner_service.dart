import 'package:flutter/foundation.dart';

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/services/media_library/media_library_backend.dart';

/// Serviço de scan de músicas.
///
/// Camada fina sobre [MediaLibrary] — preservada para compatibilidade com
/// os providers existentes ([LibraryNotifier], etc.). Toda lógica real está
/// no backend selecionado por plataforma:
/// - Android/iOS → [OnAudioQueryBackend] (MediaStore)
/// - Windows/Linux/macOS → [WindowsFileBackend] (filesystem + audiotags)
class AudioScannerService {
  AudioScannerService();

  MediaLibraryBackend get _backend => MediaLibrary.instance;

  Future<List<Song>> scanSongs() async {
    try {
      return await _backend.scanSongs();
    } catch (e) {
      debugPrint('[AudioScanner] scanSongs error: $e');
      return [];
    }
  }

  Future<List<Album>> scanAlbums() async {
    try {
      return await _backend.scanAlbums();
    } catch (e) {
      debugPrint('[AudioScanner] scanAlbums error: $e');
      return [];
    }
  }

  Future<List<Artist>> scanArtists() async {
    try {
      return await _backend.scanArtists();
    } catch (e) {
      debugPrint('[AudioScanner] scanArtists error: $e');
      return [];
    }
  }

  Future<Uint8List?> getArtwork(int songId, {int size = 300}) async {
    return _backend.queryArtwork(songId, ArtworkType.AUDIO, size: size);
  }

  Future<Uint8List?> getAlbumArtwork(int albumId, {int size = 300}) async {
    return _backend.queryArtwork(albumId, ArtworkType.ALBUM, size: size);
  }
}
