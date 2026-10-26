import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Forma de onda real (níveis de volume ao longo da música) para as barras
/// de progresso visualizadoras.
///
/// Calculada on-device pelo AudioAnalysisPlugin (Android) decodificando o
/// arquivo — sem microfone nem permissão RECORD_AUDIO. Cache em memória e em
/// disco (96 bytes por música), então cada arquivo só é decodificado uma vez.
class WaveformService {
  static const _channel = MethodChannel('com.constanza.audio_analysis');
  static const bins = 96;

  static final Map<String, List<double>> _memory = {};
  static const _maxMemory = 200;
  static Directory? _dir;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Níveis em 0..1 com [bins] posições, ou null se indisponível.
  static Future<List<double>?> load(String uri) async {
    if (!isSupported || uri.isEmpty) return null;
    final key = _key(uri);

    final cached = _memory[key];
    if (cached != null) return cached;

    final file = await _file(key);
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.length == bins) return _remember(key, _decode(bytes));
      }
    } catch (e) {
      debugPrint('[Waveform] cache read failed: $e');
    }

    try {
      final raw = await _channel
          .invokeListMethod<double>('waveform', {'uri': uri, 'bins': bins})
          .timeout(const Duration(seconds: 60));
      if (raw == null || raw.length != bins) return null;
      final levels = List<double>.unmodifiable(
        raw.map((v) => v.clamp(0.0, 1.0)),
      );
      unawaited(_write(file, levels));
      return _remember(key, levels);
    } on PlatformException catch (e) {
      debugPrint('[Waveform] PlatformException: ${e.message}');
    } on TimeoutException {
      debugPrint('[Waveform] timeout for $uri');
    } catch (e) {
      debugPrint('[Waveform] error: $e');
    }
    return null;
  }

  static List<double> _remember(String key, List<double> levels) {
    if (_memory.length >= _maxMemory) _memory.remove(_memory.keys.first);
    return _memory[key] = levels;
  }

  static List<double> _decode(Uint8List bytes) =>
      List<double>.unmodifiable(bytes.map((b) => b / 255));

  static Future<void> _write(File file, List<double> levels) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        Uint8List.fromList([for (final v in levels) (v * 255).round()]),
        flush: true,
      );
    } catch (e) {
      debugPrint('[Waveform] cache write failed: $e');
    }
  }

  static Future<File> _file(String key) async {
    _dir ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'waveforms'),
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
