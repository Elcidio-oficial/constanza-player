import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Energia real de uma música ao longo do tempo, usada pelas barras de
/// progresso visualizadoras para pulsar no ritmo.
class SongWaveform {
  SongWaveform._(this.frameMs, this.overview, this._pulse);

  /// Duração de cada quadro do envelope.
  final int frameMs;

  /// Contorno da música inteira em [WaveformService.bins] níveis (0..1).
  final List<double> overview;

  /// Pulso por quadro (0..1): energia + quanto ela supera a média do último
  /// segundo — destaca batidas/ataques em vez de só o volume.
  final Float32List _pulse;

  factory SongWaveform.fromEnvelope(Uint8List envelope, int frameMs) {
    final n = envelope.length;
    final energy = Float32List(n);
    for (var i = 0; i < n; i++) {
      energy[i] = envelope[i] / 255;
    }

    // Média móvel de ~1 s (janela centrada) via soma prefixada: O(n).
    final half = math.max(1, 500 ~/ frameMs);
    final prefix = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + energy[i];
    }
    final pulse = Float32List(n);
    for (var i = 0; i < n; i++) {
      final a = math.max(0, i - half), b = math.min(n, i + half + 1);
      final avg = (prefix[b] - prefix[a]) / (b - a);
      final onset = math.max(0.0, energy[i] - avg);
      pulse[i] = (energy[i] * 0.55 + onset * 2.2).clamp(0.0, 1.0);
    }

    const bins = WaveformService.bins;
    final overview = List<double>.generate(bins, (b) {
      if (n == 0) return 0.5;
      final start = b * n ~/ bins;
      final end = math.max(start + 1, math.min(n, (b + 1) * n ~/ bins));
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        peak = math.max(peak, energy[j]);
      }
      return 0.12 + 0.88 * peak;
    }, growable: false);

    return SongWaveform._(frameMs, List.unmodifiable(overview), pulse);
  }

  /// Pulso na posição [position], interpolado entre quadros vizinhos.
  double pulseAt(Duration position) {
    if (_pulse.isEmpty) return 0;
    final f = position.inMicroseconds / (frameMs * 1000);
    if (f <= 0) return _pulse.first;
    final i = f.floor();
    if (i >= _pulse.length - 1) return _pulse.last;
    final t = f - i;
    return _pulse[i] * (1 - t) + _pulse[i + 1] * t;
  }
}

/// Calcula (Android, AudioAnalysisPlugin) e guarda o envelope de energia das
/// músicas — sem microfone nem permissão RECORD_AUDIO. Cache em memória e em
/// disco (~20 bytes por segundo de música), então cada arquivo só é
/// decodificado uma vez.
class WaveformService {
  static const _channel = MethodChannel('com.constanza.audio_analysis');
  static const bins = 96;

  static final Map<String, SongWaveform> _memory = {};
  static const _maxMemory = 60;
  static Directory? _dir;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<SongWaveform?> load(String uri) async {
    if (!isSupported || uri.isEmpty) return null;
    final key = _key(uri);

    final cached = _memory[key];
    if (cached != null) return cached;

    final file = await _file(key);
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Formato: [frameMs][envelope...]
        if (bytes.length > 1 && bytes[0] > 0) {
          return _remember(
            key,
            SongWaveform.fromEnvelope(
              Uint8List.sublistView(bytes, 1),
              bytes[0],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Waveform] cache read failed: $e');
    }

    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>('envelope', {'uri': uri})
          .timeout(const Duration(seconds: 60));
      final data = raw?['data'];
      final frameMs = raw?['frameMs'];
      if (data is! Uint8List || frameMs is! int || data.isEmpty) return null;
      if (frameMs <= 0 || frameMs > 255) return null;
      unawaited(_write(file, frameMs, data));
      return _remember(key, SongWaveform.fromEnvelope(data, frameMs));
    } on PlatformException catch (e) {
      debugPrint('[Waveform] PlatformException: ${e.message}');
    } on TimeoutException {
      debugPrint('[Waveform] timeout for $uri');
    } catch (e) {
      debugPrint('[Waveform] error: $e');
    }
    return null;
  }

  static SongWaveform _remember(String key, SongWaveform waveform) {
    if (_memory.length >= _maxMemory) _memory.remove(_memory.keys.first);
    return _memory[key] = waveform;
  }

  static Future<void> _write(File file, int frameMs, Uint8List data) async {
    try {
      await file.parent.create(recursive: true);
      final out = Uint8List(data.length + 1)
        ..[0] = frameMs
        ..setRange(1, data.length + 1, data);
      await file.writeAsBytes(out, flush: true);
    } catch (e) {
      debugPrint('[Waveform] cache write failed: $e');
    }
  }

  static Future<File> _file(String key) async {
    _dir ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'envelopes'),
    );
    return File(p.join(_dir!.path, '$key.bin'));
  }

  // FNV-1a 64 bits: nome de arquivo estável e sem caracteres do caminho
  // original (evita path traversal com URIs arbitrárias).
  static String _key(String uri) {
    // Offset basis 0xcbf29ce484222325 como int64 com sinal; o int nativo do
    // Dart já faz wrap em 64 bits na multiplicação.
    var hash = -3750763034362895579;
    for (final unit in uri.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }
}
