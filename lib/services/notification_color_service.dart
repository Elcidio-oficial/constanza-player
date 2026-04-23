import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço que envia artwork e cores para o plugin nativo de notificação.
///
/// Abordagem dupla para cobrir todos os dispositivos:
/// - Material You (stock Android 13+): cores extraídas automaticamente do
///   bitmap no MediaMetadata (via ArtworkFileService).
/// - Sem Material You (HiOS, MIUI, ColorOS, etc.): o plugin nativo
///   força setColorized(true) + setColor() na notificação.
class NotificationColorService {
  static const _channel = MethodChannel('com.constanza.media_notification');

  /// Envia os bytes do artwork para extração de cor nativa via Palette API.
  static Future<void> updateFromArtwork(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      await _channel.invokeMethod('updateFromArtwork', {'bytes': bytes});
    } catch (e) {
      debugPrint('[NotificationColor] updateFromArtwork error: $e');
    }
  }

  /// Envia uma cor específica (já extraída no Flutter) para aplicar
  /// na notificação.
  static Future<void> updateColor(int colorValue) async {
    try {
      await _channel.invokeMethod('updateColor', {'color': colorValue});
    } catch (e) {
      debugPrint('[NotificationColor] updateColor error: $e');
    }
  }

  /// Re-aplica a última cor após eventos que reconstroem a notificação.
  static Future<void> reapplyColor() async {
    try {
      await _channel.invokeMethod('reapplyColor');
    } catch (e) {
      debugPrint('[NotificationColor] reapplyColor error: $e');
    }
  }
}
