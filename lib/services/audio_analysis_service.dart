import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:constanza_player/services/bpm_key_fetch_service.dart';

/// Resultado da análise de uma música (dados do Spotify).
class AudioAnalysisResult {
  const AudioAnalysisResult({
    this.bpm,
    this.key,
    this.scale,
    this.source,
    this.camelotCode,
    this.energy,
    this.danceability,
    this.happiness,
  });

  final int? bpm;
  final String? key;
  final String? scale;
  final String? source; // "spotify"
  final String? camelotCode; // e.g. "8B", "5A"
  final double? energy; // 0.0–1.0
  final double? danceability; // 0.0–1.0
  final double? happiness; // 0.0–1.0

  bool get hasBpm => bpm != null && bpm! > 0;
  bool get hasKey => key != null && key!.isNotEmpty && scale != null;
  bool get hasCamelot => camelotCode != null && camelotCode!.isNotEmpty;
  bool get hasEnergyData => energy != null;
  bool get hasAnyData => hasBpm || hasKey;

  /// Ex: "C Menor"
  String get keyLabel {
    if (!hasKey) return '';
    final scaleLabel = scale == 'Major' ? 'Maior' : 'Menor';
    return '$key $scaleLabel';
  }

  /// Ex: "C Menor (8B)" — com Camelot se disponível
  String get keyLabelFull {
    if (!hasKey) return '';
    final base = keyLabel;
    if (hasCamelot) return '$base ($camelotCode)';
    return base;
  }

  /// Ex: "120 BPM"
  String get bpmLabel => hasBpm ? '$bpm BPM' : '';

  /// Ex: "120 BPM · C Menor"
  String get fullLabel {
    final parts = <String>[];
    if (hasBpm) parts.add(bpmLabel);
    if (hasKey) parts.add(keyLabelFull);
    return parts.join(' · ');
  }

  /// Categoria de energia baseada no BPM.
  String get energyCategory {
    if (bpm == null) return '';
    if (bpm! < 80) return 'Relaxante';
    if (bpm! < 110) return 'Moderado';
    if (bpm! < 140) return 'Energético';
    return 'Intenso';
  }

  /// Label da fonte dos dados.
  String get sourceLabel => switch (source) {
    'reccobeats' => 'ReccoBeats',
    'spotify' => 'Spotify',
    _ => source ?? '',
  };

  /// Porcentagem de energia formatada.
  String get energyPercent =>
      energy != null ? '${(energy! * 100).round()}%' : '';

  /// Porcentagem de dançabilidade formatada.
  String get danceabilityPercent =>
      danceability != null ? '${(danceability! * 100).round()}%' : '';

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'key': key,
    'scale': scale,
    'source': source,
    'camelotCode': camelotCode,
    'energy': energy,
    'danceability': danceability,
    'happiness': happiness,
  };

  factory AudioAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AudioAnalysisResult(
      bpm: json['bpm'] as int?,
      key: json['key'] as String?,
      scale: json['scale'] as String?,
      source: json['source'] as String?,
      camelotCode: json['camelotCode'] as String?,
      energy: (json['energy'] as num?)?.toDouble(),
      danceability: (json['danceability'] as num?)?.toDouble(),
      happiness: (json['happiness'] as num?)?.toDouble(),
    );
  }

  /// Cria AudioAnalysisResult a partir de BpmKeyResult (ReccoBeats / Spotify).
  factory AudioAnalysisResult.fromSpotify(BpmKeyResult r) {
    return AudioAnalysisResult(
      bpm: r.bpm,
      key: r.key,
      scale: r.scale,
      source: r.source,
      camelotCode: r.camelotCode,
      energy: r.energy,
      danceability: r.danceability,
      happiness: r.happiness,
    );
  }
}

/// Serviço de cache de análise musical.
///
/// Dados online vêm via Spotify Search (identificação) + ReccoBeats (features).
/// Tonalidade vem exclusivamente do DSP nativo (AudioAnalysisPlugin.kt).
class AudioAnalysisService {
  static const _cacheKey = 'audio_analysis_cache_v3';

  static final Map<String, AudioAnalysisResult> _memCache = {};
  static const _maxCacheSize = 500;
  static bool _diskCacheLoaded = false;

  static Future<void> loadCache() async {
    if (_diskCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          try {
            _memCache[entry.key] = AudioAnalysisResult.fromJson(
              entry.value as Map<String, dynamic>,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AudioAnalysis] Cache load error: $e');
    }
    _diskCacheLoaded = true;
  }

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      for (final entry in _memCache.entries) {
        map[entry.key] = entry.value.toJson();
      }
      await prefs.setString(_cacheKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[AudioAnalysis] Cache save error: $e');
    }
  }

  static AudioAnalysisResult? getCached(String songId) => _memCache[songId];

  static void updateCache(String songId, AudioAnalysisResult result) {
    _addToCache(songId, result);
  }

  /// Busca análise via Spotify. Retorna resultado cacheado se disponível.
  static Future<AudioAnalysisResult?> analyze({
    required String songId,
    required String title,
    required String artist,
  }) async {
    final cached = _memCache[songId];
    if (cached != null) return cached;

    final spotifyResult = await BpmKeyFetchService.fetch(
      title: title,
      artist: artist,
    );

    if (spotifyResult == null || !spotifyResult.hasData) return null;

    final result = AudioAnalysisResult.fromSpotify(spotifyResult);
    _addToCache(songId, result);
    return result;
  }

  static void _addToCache(String songId, AudioAnalysisResult analysis) {
    if (_memCache.length >= _maxCacheSize) {
      final keysToRemove = _memCache.keys
          .take(_memCache.length - _maxCacheSize + 1)
          .toList();
      for (final k in keysToRemove) {
        _memCache.remove(k);
      }
    }
    _memCache[songId] = analysis;
    _saveCache();
  }

  static void clearSongCache(String songId) {
    _memCache.remove(songId);
    _saveCache();
  }

  static Future<void> clearCache() async {
    _memCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  static int get analyzedCount => _memCache.length;
}
