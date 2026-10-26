import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'bpmConfidence': bpmConfidence,
    'key': key,
    'scale': scale,
    'keyConfidence': keyConfidence,
  };

  factory NativeAnalysisResult.fromJson(Map<String, dynamic> json) =>
      NativeAnalysisResult(
        bpm: json['bpm'] as int?,
        bpmConfidence: (json['bpmConfidence'] as num?)?.toDouble() ?? 0.0,
        key: json['key'] as String?,
        scale: json['scale'] as String?,
        keyConfidence: (json['keyConfidence'] as num?)?.toDouble() ?? 0.0,
      );
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

  /// Cache em disco por URI: cada música é analisada uma vez só.
  /// Subir a versão quando o algoritmo do plugin mudar, para reanalisar.
  static const _prefsKey = 'native_analysis_cache_v2';
  static const _legacyPrefsKeys = ['native_analysis_cache_v1'];

  static final Map<String, NativeAnalysisResult> _cache = {};
  static const _maxCache = 2000;
  static bool _diskLoaded = false;
  static Future<void>? _loading;

  static Future<void> _ensureLoaded() {
    if (_diskLoaded) return Future.value();
    return _loading ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final k in _legacyPrefsKeys) {
          await prefs.remove(k);
        }
        final raw = prefs.getString(_prefsKey);
        if (raw != null) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          for (final e in map.entries) {
            try {
              _cache[e.key] = NativeAnalysisResult.fromJson(
                e.value as Map<String, dynamic>,
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[NativeAnalysis] Cache load error: $e');
      }
      _diskLoaded = true;
    }();
  }

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {for (final e in _cache.entries) e.key: e.value.toJson()};
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[NativeAnalysis] Cache save error: $e');
    }
  }

  /// Resultado já salvo, sem analisar.
  static Future<NativeAnalysisResult?> getCached(String uri) async {
    await _ensureLoaded();
    return _cache[uri];
  }

  /// Analisa uma música. Retorna null em caso de erro.
  /// Resultado salvo em disco por URI — a análise roda uma vez por música.
  static Future<NativeAnalysisResult?> analyze(String uri) async {
    if (uri.isEmpty) return null;

    await _ensureLoaded();
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
        _saveCache();
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

  static void clearCache() {
    _cache.clear();
    _saveCache();
  }

  static void removeCached(String uri) {
    _cache.remove(uri);
    _saveCache();
  }

  static int get cachedCount => _cache.length;
}
