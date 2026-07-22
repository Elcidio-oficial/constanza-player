import 'package:flutter/services.dart';

/// Bridge to native Android MediaTagPlugin for writing ID3 tags and deleting songs.
class MediaTagService {
  static const _channel = MethodChannel('com.constanza.media_tag');

  /// Write metadata tags to the audio file at [filePath].
  /// [coverBytes] optional artwork image bytes to embed in the file.
  static Future<bool> writeTags({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    String? genre,
    String? composer,
    int? trackNumber,
    Uint8List? coverBytes,
  }) async {
    final tags = <String, dynamic>{
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (genre != null) 'genre': genre,
      if (composer != null) 'composer': composer,
      if (trackNumber != null) 'trackNumber': trackNumber,
    };
    if (tags.isEmpty && coverBytes == null) return false;

    try {
      final result = await _channel.invokeMethod<bool>('writeTags', {
        'filePath': filePath,
        'tags': tags,
        if (coverBytes != null) 'coverBytes': coverBytes,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Delete a song from the device.
  static Future<bool> deleteSong({
    required String filePath,
    int? songId,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteSong', {
        'filePath': filePath,
        'songId': songId,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lê a capa embebida de um áudio externo ([uri] = `content://`, `file://`
  /// ou caminho). Usado para mostrar a capa de faixas abertas pelo explorador
  /// que não estão na biblioteca (sem MediaStore id). `null` se não houver capa.
  static Future<Uint8List?> extractArtwork(String uri) async {
    try {
      return await _channel.invokeMethod<Uint8List>('extractArtwork', {
        'uri': uri,
      });
    } catch (_) {
      return null;
    }
  }
}
