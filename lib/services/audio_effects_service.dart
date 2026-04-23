import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço de efeitos de áudio nativos via Platform Channel.
///
/// Controla Equalizer, BassBoost e Virtualizer do Android
/// usando android.media.audiofx via MethodChannel.
class AudioEffectsService {
  static const _channel = MethodChannel('com.constanza.audio_effects');

  static bool _initialized = false;

  /// Inicializa os efeitos com o audioSessionId do player.
  /// Retorna info das bandas do EQ nativo.
  static Future<Map<String, dynamic>?> init(int sessionId) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'init',
        {'sessionId': sessionId},
      );
      _initialized = true;
      if (result == null) return null;
      return result.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('[AudioEffects] init error: $e');
      return null;
    }
  }

  /// Habilita/desabilita todos os efeitos.
  static Future<void> setEnabled(bool enabled) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[AudioEffects] setEnabled error: $e');
    }
  }

  /// Define todas as bandas do EQ de uma vez.
  /// [levels] é uma lista de valores em mB (miliBels, ex: -1200 a 1200).
  static Future<void> setAllBands(List<int> levels) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('setAllBands', {'levels': levels});
    } catch (e) {
      debugPrint('[AudioEffects] setAllBands error: $e');
    }
  }

  /// Define nível de uma banda específica.
  static Future<void> setBandLevel(int band, int level) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': band,
        'level': level,
      });
    } catch (e) {
      debugPrint('[AudioEffects] setBandLevel error: $e');
    }
  }

  /// Define força do Bass Boost (0-1000).
  static Future<void> setBassBoost(int strength) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': strength});
    } catch (e) {
      debugPrint('[AudioEffects] setBassBoost error: $e');
    }
  }

  /// Define força do Virtualizer (0-1000).
  static Future<void> setVirtualizer(int strength) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('setVirtualizer', {'strength': strength});
    } catch (e) {
      debugPrint('[AudioEffects] setVirtualizer error: $e');
    }
  }

  /// Libera recursos nativos.
  static Future<void> release() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('release');
      _initialized = false;
    } catch (e) {
      debugPrint('[AudioEffects] release error: $e');
    }
  }
}
