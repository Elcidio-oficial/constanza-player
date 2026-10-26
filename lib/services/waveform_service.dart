import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Energia de uma música ao longo do tempo, preenchida aos poucos enquanto
/// o Android decodifica o arquivo. As barras de progresso leem [pulseAt] a
/// cada quadro: sobem nas batidas e ficam baixas nas partes calmas.
class SongWaveform {
  SongWaveform(this.frameMs, {int capacity = 6000})
    : _energy = Uint8List(capacity),
      _known = Uint8List(capacity),
      _pulse = Float32List(capacity);

  factory SongWaveform.fromEnvelope(Uint8List envelope, int frameMs) {
    final w = SongWaveform(frameMs, capacity: math.max(1, envelope.length));
    w.addChunk(0, envelope);
    w._complete = true;
    w._frames = envelope.length;
    return w;
  }

  final int frameMs;

  Uint8List _energy;
  Uint8List _known;
  Float32List _pulse;
  var _knownCount = 0;
  var _frames = 0;
  var _complete = false;

  /// Algum quadro já chegou (antes disso as barras ficam baixas e planas).
  bool get hasData => _knownCount > 0;
  bool get isComplete => _complete;

  // Média de ~1 s antes do quadro: a "batida" é o quanto a energia a supera.
  static const _avgFrames = 20;
  // Queda por quadro de 50 ms após um pico (ataque é instantâneo).
  static const _release = 0.82;

  void addChunk(int start, Uint8List bytes) {
    if (start < 0 || bytes.isEmpty) return;
    final end = start + bytes.length;
    _ensureCapacity(end);
    for (var i = 0; i < bytes.length; i++) {
      final f = start + i;
      if (_known[f] == 0) _knownCount++;
      _known[f] = 1;
      _energy[f] = bytes[i];
    }
    _frames = math.max(_frames, end);
    // Quadros seguintes dependem da média e do release: recalcula até o fim
    // do bloco contíguo já conhecido após o pedaço.
    var stop = end;
    while (stop < _frames && _known[stop] == 1) {
      stop++;
    }
    for (var f = start; f < stop; f++) {
      _pulse[f] = _computePulse(f);
    }
  }

  double _computePulse(int f) {
    final e = _energy[f] / 255;
    var sum = 0.0;
    var n = 0;
    for (var j = math.max(0, f - _avgFrames); j < f; j++) {
      if (_known[j] == 1) {
        sum += _energy[j] / 255;
        n++;
      }
    }
    final avg = n == 0 ? e : sum / n;
    final onset = math.max(0.0, e - avg);
    // Volume dá a base (partes baixas ficam baixas); o excesso sobre a média
    // recente é a batida e domina a altura.
    var raw = (0.5 * e + 2.4 * onset).clamp(0.0, 1.0);
    raw = math.pow(raw, 1.25).toDouble();
    if (f > 0 && _known[f - 1] == 1) {
      raw = math.max(raw, _pulse[f - 1] * _release);
    }
    return raw;
  }

  void _ensureCapacity(int frames) {
    if (frames <= _energy.length) return;
    final cap = math.max(frames, _energy.length * 2);
    _energy = Uint8List(cap)..setRange(0, _energy.length, _energy);
    _known = Uint8List(cap)..setRange(0, _known.length, _known);
    _pulse = Float32List(cap)..setRange(0, _pulse.length, _pulse);
  }

  /// Pulso (0..1) na posição [position], interpolado entre quadros. Quadros
  /// ainda não lidos valem 0.
  double pulseAt(Duration position) {
    if (_frames == 0) return 0;
    final f = position.inMicroseconds / (frameMs * 1000);
    if (f <= 0) return _at(0);
    final i = f.floor();
    if (i >= _frames - 1) return _at(_frames - 1);
    final t = f - i;
    return _at(i) * (1 - t) + _at(i + 1) * t;
  }

  double _at(int f) => _known[f] == 1 ? _pulse[f] : 0;

  /// Envelope completo para o cache em disco.
  Uint8List toEnvelope() => Uint8List.sublistView(_energy, 0, _frames);

  void _markComplete(int frames) {
    _frames = math.max(_frames, frames);
    _complete = _knownCount >= _frames;
  }
}

/// Calcula (Android, AudioAnalysisPlugin) e guarda o envelope de energia das
/// músicas — sem microfone nem permissão RECORD_AUDIO. O nativo envia pedaços
/// assim que decodifica (o primeiro em ~100 ms), começando pela posição atual.
/// Cache em memória e em disco (~20 bytes por segundo de música).
class WaveformService {
  static const _channel = MethodChannel('com.constanza.audio_analysis');

  static final Map<String, SongWaveform> _memory = {};
  static const _maxMemory = 40;
  static final Map<int, SongWaveform> _pending = {};
  static final Set<String> _loading = {};
  static var _nextId = 0;
  static var _handlerInstalled = false;
  static Directory? _dir;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Devolve na hora o envelope de [uri] (vazio no começo) e o preenche em
  /// segundo plano. [startMs] = posição atual, lida primeiro.
  static SongWaveform? open(String uri, {int startMs = 0}) {
    if (!isSupported || uri.isEmpty) return null;
    final key = _key(uri);
    var waveform = _memory[key];
    if (waveform == null) {
      waveform = SongWaveform(50);
      if (_memory.length >= _maxMemory) _memory.remove(_memory.keys.first);
      _memory[key] = waveform;
    }
    if (!waveform.isComplete && !_loading.contains(key)) {
      unawaited(_load(key, uri, startMs, waveform));
    }
    return waveform;
  }

  static Future<void> _load(
    String key,
    String uri,
    int startMs,
    SongWaveform waveform,
  ) async {
    _loading.add(key);
    try {
      final file = await _file(key);
      if (await _readCache(file, waveform)) return;

      _installHandler();
      final id = ++_nextId;
      _pending[id] = waveform;
      try {
        final raw = await _channel
            .invokeMapMethod<String, Object?>('envelope', {
              'uri': uri,
              'id': id,
              'startMs': startMs,
            })
            .timeout(const Duration(seconds: 90));
        final frames = raw?['frames'];
        if (frames is int && frames > 0) {
          waveform._markComplete(frames);
          if (waveform.isComplete) unawaited(_write(file, waveform));
        }
      } finally {
        _pending.remove(id);
      }
    } on PlatformException catch (e) {
      debugPrint('[Waveform] PlatformException: ${e.message}');
    } on TimeoutException {
      debugPrint('[Waveform] timeout for $uri');
    } catch (e) {
      debugPrint('[Waveform] error: $e');
    } finally {
      _loading.remove(key);
    }
  }

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'envelopeChunk') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final id = args['id'], start = args['start'], data = args['data'];
      if (id is int && start is int && data is Uint8List) {
        _pending[id]?.addChunk(start, data);
      }
      return null;
    });
  }

  // Formato: [frameMs][envelope...]
  static Future<bool> _readCache(File file, SongWaveform waveform) async {
    try {
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      if (bytes.length < 2 || bytes[0] != waveform.frameMs) return false;
      final envelope = Uint8List.sublistView(bytes, 1);
      waveform.addChunk(0, envelope);
      waveform._markComplete(envelope.length);
      return true;
    } catch (e) {
      debugPrint('[Waveform] cache read failed: $e');
      return false;
    }
  }

  static Future<void> _write(File file, SongWaveform waveform) async {
    try {
      final data = waveform.toEnvelope();
      await file.parent.create(recursive: true);
      final out = Uint8List(data.length + 1)
        ..[0] = waveform.frameMs
        ..setRange(1, data.length + 1, data);
      await file.writeAsBytes(out, flush: true);
    } catch (e) {
      debugPrint('[Waveform] cache write failed: $e');
    }
  }

  static Future<File> _file(String key) async {
    // v2: escala fixa (v1 normalizava pelo pico da música).
    _dir ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'envelopes_v2'),
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
