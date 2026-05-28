import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';

import 'on_audio_query_backend.dart';
import 'windows_file_backend.dart';

export 'package:on_audio_query/on_audio_query.dart' show ArtworkType;

/// Backend abstrato de biblioteca de mídia.
///
/// Android/iOS → [OnAudioQueryBackend] (usa MediaStore).
/// Windows/Linux/macOS → [WindowsFileBackend] (varre filesystem + lê tags).
abstract class MediaLibraryBackend {
  Future<List<Song>> scanSongs();
  Future<List<Album>> scanAlbums();
  Future<List<Artist>> scanArtists();

  /// Retorna bytes da artwork. [size] é uma sugestão (backend pode ignorar).
  Future<Uint8List?> queryArtwork(
    int id,
    ArtworkType type, {
    int size = 300,
    int quality = 80,
  });

  /// Lista de pastas escaneadas (Windows-only — Android usa MediaStore).
  /// Pode retornar lista vazia em backends que não suportam.
  List<String> get scanFolders => const [];

  /// Atualiza pastas e força rescan. No-op em backends que não suportam.
  Future<void> setScanFolders(List<String> folders) async {}

  /// Escaneia uma única pasta (recursivo) sem alterar o cache/pastas globais.
  /// Usado pela FoldersPage para mostrar a contagem de músicas imediatamente
  /// ao adicionar uma pasta no desktop, antes de "Aplicar".
  /// Retorna lista vazia em backends que não suportam (Android usa MediaStore).
  Future<List<Song>> scanFolder(String folder) async => const [];

  /// Reindexa os mapas internos (id → path) a partir de músicas já conhecidas.
  /// Chamado pela [LibraryProvider] após carregar do cache em disco — sem isto,
  /// no Windows queries de artwork retornam null porque os mapas só são
  /// populados durante um scan completo do filesystem.
  /// No Android é no-op (MediaStore mantém os IDs próprios).
  void indexFromSongs(List<Song> songs) {}
}

/// Singleton acessado por toda a app. Inicializado em main.dart via [init].
class MediaLibrary {
  MediaLibrary._();

  static MediaLibraryBackend? _backend;

  static MediaLibraryBackend get instance {
    final b = _backend;
    if (b == null) {
      throw StateError(
        'MediaLibrary não inicializada. Chame MediaLibrary.init() em main().',
      );
    }
    return b;
  }

  /// Seleciona o backend correto para a plataforma atual.
  static Future<void> init({List<String> windowsScanFolders = const []}) async {
    if (_backend != null) return;
    if (Platform.isAndroid || Platform.isIOS) {
      _backend = OnAudioQueryBackend();
    } else {
      // Windows / Linux / macOS — filesystem-based
      final b = WindowsFileBackend();
      await b.setScanFolders(windowsScanFolders);
      _backend = b;
    }
  }

  /// Útil em testes.
  static void overrideForTesting(MediaLibraryBackend backend) {
    _backend = backend;
  }
}
