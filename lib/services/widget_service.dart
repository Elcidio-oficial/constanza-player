import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Updates the Android home screen widget with current playback info.
class WidgetService {
  static const _channel = MethodChannel(
    'com.constanza.constanza_player/widget',
  );

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
    String? artworkPath,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        if (artworkPath != null) 'artworkPath': artworkPath,
      });
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }
}
