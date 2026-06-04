import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resultado da análise on-device via DSP nativo (AudioAnalysisPlugin).
class NativeAnalysisResult {
  const NativeAnalysisResult({
    this.bpm,
    this.bpmConfidence = 0.0,
    this.key,
    this.scale,
    this.keyConfidence = 0.0,
  });

  final int? bpm;
  final double bpmConfidence;
  final String? key;
  final String? scale;
  final double keyConfidence;

  bool get hasBpm => bpm != null && bpm! > 0;
  bool get hasKey => key != null && key!.isNotEmpty && scale != null;
  bool get hasData => hasBpm || hasKey;

  /// Ex: "C Menor"
  String get keyLabel {
    if (!hasKey) return '';
    final scaleLabel = scale == 'Major' ? 'Maior' : 'Menor';
    return '$key $scaleLabel';
  }

  /// Ex: "128 BPM"
  String get bpmLabel => hasBpm ? '$bpm BPM' : '';

  /// Confiança do BPM como percentual
  String get bpmConfidencePercent =>
      '${(bpmConfidence * 100).clamp(0, 100).round()}%';

  /// Confiança da tonalidade como percentual
  String get keyConfidencePercent =>
      '${(keyConfidence * 100).clamp(0, 100).round()}%';
}

/// Serviço de análise DSP on-device via método channel nativo.
///
/// Usa o AudioAnalysisPlugin (Kotlin) que implementa:
/// - BPM: Multi-band Spectral Flux + Autocorrelação harmônica
/// - Tonalidade: HPCP Chromagram + perfis Krumhansl-Kessler + Temperley
///
/// 100% offline, sem necessidade de credenciais.
class NativeAudioAnalysisService {
  static const _channel = MethodChannel('com.constanza.audio_analysis');

  static final Map<String, NativeAnalysisResult> _cache = {};
  static const _maxCache = 300;

  /// Analisa uma música. Retorna null em caso de erro.
  /// Cache em memória por URI.
  static Future<NativeAnalysisResult?> analyze(String uri) async {
    if (uri.isEmpty) return null;

    final cached = _cache[uri];
    if (cached != null) return cached;

    try {
      // Timeout de segurança: se o decode/DSP nativo travar (mídia malformada,
      // codec lento), o badge de BPM não pode girar para sempre. 45s é folgado
      // para a análise legítima de 60s de áudio mesmo em devices modestos.
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('analyze', {'uri': uri})
          .timeout(const Duration(seconds: 45));

      if (result == null) return null;

      final bpmRaw = result['bpm'];
      final bpmConfidence =
          (result['bpmConfidence'] as num?)?.toDouble() ?? 0.0;
      final key = result['key'] as String?;
      final scale = result['scale'] as String?;
      final keyConfidence =
          (result['keyConfidence'] as num?)?.toDouble() ?? 0.0;

      int? bpm;
      if (bpmRaw != null) {
        bpm = (bpmRaw as num).round();
        if (bpm < 40 || bpm > 250) bpm = null;
      }

      final analysis = NativeAnalysisResult(
        bpm: bpm,
        bpmConfidence: bpmConfidence,
        key: (key?.isNotEmpty == true) ? key : null,
        scale: (scale?.isNotEmpty == true) ? scale : null,
        keyConfidence: keyConfidence,
      );

      if (analysis.hasData) {
        if (_cache.length >= _maxCache) {
          final toRemove = _cache.keys.take(50).toList();
          for (final k in toRemove) {
            _cache.remove(k);
          }
        }
        _cache[uri] = analysis;
      }

      return analysis;
    } on PlatformException catch (e) {
      debugPrint('[NativeAnalysis] PlatformException: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[NativeAnalysis] Error: $e');
      return null;
    }
  }

  static void clearCache() => _cache.clear();
  static void removeCached(String uri) => _cache.remove(uri);
  static int get cachedCount => _cache.length;
}
