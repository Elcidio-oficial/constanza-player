import 'dart:typed_data';

import 'package:constanza_player/services/waveform_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envelope sintético: fundo baixo constante com "batidas" a cada [beatEvery]
/// quadros.
Uint8List _beats({int frames = 200, int beatEvery = 10, int base = 60}) =>
    Uint8List.fromList([
      for (var i = 0; i < frames; i++) i % beatEvery == 0 ? 255 : base,
    ]);

void main() {
  group('SongWaveform', () {
    test('pulso é maior na batida do que entre batidas', () {
      final w = SongWaveform.fromEnvelope(_beats(), 50);
      // Quadro 100 é batida; 105 fica no meio do intervalo.
      final onBeat = w.pulseAt(const Duration(milliseconds: 100 * 50));
      final between = w.pulseAt(const Duration(milliseconds: 105 * 50));
      expect(onBeat, greaterThan(between * 2));
    });

    test('silêncio gera pulso ~0 e volume constante não gera batidas', () {
      final silent = SongWaveform.fromEnvelope(Uint8List(100), 50);
      expect(silent.pulseAt(const Duration(seconds: 2)), 0);

      final flat = SongWaveform.fromEnvelope(
        Uint8List.fromList(List.filled(100, 128)),
        50,
      );
      final a = flat.pulseAt(const Duration(seconds: 1));
      final b = flat.pulseAt(const Duration(seconds: 3));
      expect(a, closeTo(b, 1e-6));
    });

    test('interpola entre quadros e limita às pontas', () {
      final w = SongWaveform.fromEnvelope(
        Uint8List.fromList(List.filled(40, 100)),
        50,
      );
      final mid = w.pulseAt(const Duration(milliseconds: 525));
      expect(mid, inInclusiveRange(0.0, 1.0));
      expect(
        w.pulseAt(const Duration(hours: 1)),
        w.pulseAt(const Duration(milliseconds: 39 * 50)),
      );
      expect(w.pulseAt(-const Duration(seconds: 1)), w.pulseAt(Duration.zero));
    });

    test('overview tem 96 níveis em 0.12..1 e segue o volume', () {
      // Primeira metade baixa, segunda alta.
      final env = Uint8List.fromList([
        for (var i = 0; i < 960; i++) i < 480 ? 40 : 240,
      ]);
      final w = SongWaveform.fromEnvelope(env, 50);
      expect(w.overview, hasLength(WaveformService.bins));
      expect(w.overview.every((v) => v >= 0.12 && v <= 1.0), isTrue);
      expect(w.overview.last, greaterThan(w.overview.first));
    });
  });
}
