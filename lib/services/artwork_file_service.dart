import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// Serviço que escreve artwork de alta qualidade em ficheiro temp.
///
/// O Android 13+ (Material You / Monet) extrai cores dinâmicas
/// automaticamente do Bitmap no MediaMetadata. Para que funcione,
/// o audio_service precisa de uma imagem válida e acessível.
///
/// IMPORTANTE: Cada música gera um ficheiro com nome único baseado
/// no songId. Isso força o Android/MediaSession a recarregar o bitmap
/// quando a música muda, em vez de usar cache do URI anterior.
class ArtworkFileService {
  static final _audioQuery = OnAudioQuery();
  static String? _cacheDir;
  static int _lastSongId = -1;
  static Uri? _lastUri;

  /// Consulta artwork do songId em alta qualidade (600px),
  /// escreve num ficheiro temp e retorna o file:// URI.
  ///
  /// Retorna null se o artwork não estiver disponível.
  static Future<Uri?> getArtworkFileUri(int songId) async {
    // Cache: se já escrevemos para este songId, retorna o URI
    if (songId == _lastSongId && _lastUri != null) return _lastUri;

    try {
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 600,
        quality: 90,
      );

      if (bytes == null || bytes.isEmpty) {
        _lastSongId = songId;
        _lastUri = null;
        return null;
      }

      _cacheDir ??= (await getTemporaryDirectory()).path;

      // Nome único por songId — força Android a recarregar o bitmap
      final file = File('$_cacheDir/notif_art_$songId.jpg');
      await file.writeAsBytes(bytes, flush: true);

      // Limpar artwork anterior para não acumular ficheiros
      final prevSongId = _lastSongId;
      _lastSongId = songId;
      _lastUri = Uri.file(file.path);

      if (prevSongId > 0 && prevSongId != songId) {
        try {
          final old = File('$_cacheDir/notif_art_$prevSongId.jpg');
          if (await old.exists()) await old.delete();
        } catch (_) {}
      }
      return _lastUri;
    } catch (e) {
      debugPrint('[ArtworkFileService] Error: $e');
      return null;
    }
  }
}
