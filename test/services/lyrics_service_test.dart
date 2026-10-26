import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/services/lyrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LyricsService.parseLrc', () {
    test('lê timestamps com centésimos, décimos e milésimos', () {
      final lines = LyricsService.parseLrc(
        '[00:01.50]um\n[00:02.5]dois\n[00:03.250]três\n[01:04]quatro',
      );
      expect(lines.map((l) => l.timestamp!.inMilliseconds), [
        1500,
        2500,
        3250,
        64000,
      ]);
      expect(lines.map((l) => l.text), ['um', 'dois', 'três', 'quatro']);
    });

    test('ignora metadados, linhas vazias e timestamps sem texto', () {
      final lines = LyricsService.parseLrc(
        '[ar:Artista]\n[ti:Título]\n[offset:0]\n\n[00:01.00]\n[00:02.00]linha',
      );
      expect(lines, [
        const LyricLine(timestamp: Duration(seconds: 2), text: 'linha'),
      ]);
    });

    test('ordena por timestamp e põe não sincronizadas no fim', () {
      final lines = LyricsService.parseLrc('solta\n[00:05.00]b\n[00:01.00]a');
      expect(lines.map((l) => l.text), ['a', 'b', 'solta']);
      expect(lines.last.isSynced, isFalse);
    });

    test('aceita CRLF do Windows', () {
      final lines = LyricsService.parseLrc('[00:01.00]a\r\n[00:02.00]b\r\n');
      expect(lines.map((l) => l.text), ['a', 'b']);
    });
  });

  group('LyricsService.exportLrc', () {
    test('ida e volta preserva timestamps e texto', () {
      const original = [
        LyricLine(timestamp: Duration(milliseconds: 1500), text: 'um'),
        LyricLine(timestamp: Duration(minutes: 1, seconds: 4), text: 'dois'),
      ];
      final lrc = LyricsService.exportLrc(original);
      expect(lrc, '[00:01.50]um\n[01:04.00]dois');
      expect(LyricsService.parseLrc(lrc), original);
    });

    test('linhas não sincronizadas saem sem timestamp', () {
      expect(
        LyricsService.exportLrc(const [LyricLine(text: 'livre')]),
        'livre',
      );
    });
  });

  group('LyricLine', () {
    test('toJson/fromJson ida e volta', () {
      const line = LyricLine(timestamp: Duration(milliseconds: 820), text: 'x');
      expect(LyricLine.fromJson(line.toJson()), line);
      const plain = LyricLine(text: 'y');
      expect(LyricLine.fromJson(plain.toJson()), plain);
    });

    test('formattedTimestamp', () {
      expect(
        const LyricLine(
          timestamp: Duration(minutes: 2, seconds: 3, milliseconds: 450),
          text: '',
        ).formattedTimestamp,
        '2:03.45',
      );
      expect(const LyricLine(text: '').formattedTimestamp, '--:--');
    });
  });
}
