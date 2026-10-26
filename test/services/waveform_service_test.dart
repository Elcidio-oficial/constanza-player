import 'dart:typed_data';

import 'package:constanza_player/services/waveform_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envelope sintético: fundo constante com "batidas" a cada [beatEvery]
/// quadros.
Uint8List _beats({int frames = 200, int beatEvery = 10, int base = 60}) =>
    Uint8List.fromList([
      for (var i = 0; i < frames; i++) i % beatEvery == 0 ? 255 : base,
    ]);

Duration _frame(int i) => Duration(milliseconds: i * 50);

void main() {
  group('SongWaveform', () {
    test('pulso é bem maior na batida do que entre batidas', () {
      final w = SongWaveform.fromEnvelope(_beats(), 50);
      final onBeat = w.pulseAt(_frame(100));
      final between = w.pulseAt(_frame(105));
      expect(onBeat, greaterThan(between * 2));
    });

    test('parte calma fica baixa e parte alta com batidas fica alta', () {
      final env = Uint8List.fromList([
        // 10 s calmos (volume baixo constante) …
        for (var i = 0; i < 200; i++) 25,
        // … depois 10 s altos com batidas.
        for (var i = 0; i < 200; i++) i % 10 == 0 ? 255 : 150,
      ]);
      final w = SongWaveform.fromEnvelope(env, 50);
      final quiet = w.pulseAt(_frame(150));
      final beat = w.pulseAt(_frame(300));
      expect(quiet, lessThan(0.1));
      expect(beat, greaterThan(0.8));
    });

    test('silêncio gera pulso 0 e volume constante é estável', () {
      final silent = SongWaveform.fromEnvelope(Uint8List(100), 50);
      expect(silent.pulseAt(const Duration(seconds: 2)), 0);

      final flat = SongWaveform.fromEnvelope(
        Uint8List.fromList(List.filled(100, 128)),
        50,
      );
      expect(flat.pulseAt(_frame(40)), closeTo(flat.pulseAt(_frame(80)), 1e-6));
    });

    test(
      'pedaços fora de ordem (posição atual primeiro) dão o mesmo resultado',
      () {
        final env = _beats(frames: 120);
        final once = SongWaveform.fromEnvelope(env, 50);

        final chunked = SongWaveform(50, capacity: 16);
        // Como o nativo: do meio até o fim, depois do início até o meio.
        chunked.addChunk(60, Uint8List.sublistView(env, 60, 70));
        chunked.addChunk(70, Uint8List.sublistView(env, 70));
        chunked.addChunk(0, Uint8List.sublistView(env, 0, 60));

        for (final f in [5, 30, 59, 60, 75, 110]) {
          expect(
            chunked.pulseAt(_frame(f)),
            closeTo(once.pulseAt(_frame(f)), 1e-6),
          );
        }
      },
    );

    test('quadros ainda não lidos valem 0 e o primeiro pedaço já pulsa', () {
      final w = SongWaveform(50);
      expect(w.hasData, isFalse);
      expect(w.pulseAt(_frame(3)), 0);

      w.addChunk(0, Uint8List.fromList([255, 40, 40, 40, 40]));
      expect(w.hasData, isTrue);
      expect(w.pulseAt(_frame(0)), greaterThan(0));
    });

    test('interpola entre quadros e limita às pontas', () {
      final w = SongWaveform.fromEnvelope(
        Uint8List.fromList(List.filled(40, 100)),
        50,
      );
      expect(
        w.pulseAt(const Duration(milliseconds: 525)),
        inInclusiveRange(0.0, 1.0),
      );
      expect(w.pulseAt(const Duration(hours: 1)), w.pulseAt(_frame(39)));
      expect(w.pulseAt(-const Duration(seconds: 1)), w.pulseAt(Duration.zero));
    });
  });
}
