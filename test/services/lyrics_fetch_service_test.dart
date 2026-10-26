import 'package:constanza_player/services/lyrics_fetch_service.dart';
import 'package:flutter_test/flutter_test.dart';

LyricsHit _hit(String track, String artist) =>
    LyricsHit(trackName: track, artistName: artist);

void main() {
  group('LyricsFetchService._clean', () {
    test('remove feat., parênteses, colchetes e sufixos " - "', () {
      expect(LyricsFetchService.cleanForTest('Song (feat. X)'), 'Song');
      expect(LyricsFetchService.cleanForTest('Song [Official Video]'), 'Song');
      expect(LyricsFetchService.cleanForTest('Song - Remaster 2011'), 'Song');
      expect(LyricsFetchService.cleanForTest('Song ft. Fulano'), 'Song');
    });

    test('devolve o original quando a limpeza esvazia', () {
      expect(LyricsFetchService.cleanForTest('(Intro)'), '(Intro)');
    });
  });

  group('LyricsFetchService._matches', () {
    test('aceita mesma faixa com ruído e acentos diferentes', () {
      expect(
        LyricsFetchService.matchesForTest(
          _hit('Coração Selvagem', 'Belchior'),
          'Coracao Selvagem (Ao Vivo)',
          'Belchior',
        ),
        isTrue,
      );
    });

    test('rejeita faixa homónima de outro artista', () {
      expect(
        LyricsFetchService.matchesForTest(
          _hit('Hello', 'Lionel Richie'),
          'Hello',
          'Adele',
        ),
        isFalse,
      );
    });

    test('rejeita título diferente do mesmo artista', () {
      expect(
        LyricsFetchService.matchesForTest(
          _hit('Rolling in the Deep', 'Adele'),
          'Hello',
          'Adele',
        ),
        isFalse,
      );
    });

    test('artista desconhecido valida só pelo título', () {
      for (final unknown in ['', '<unknown>', 'Artista Desconhecido']) {
        expect(
          LyricsFetchService.matchesForTest(
            _hit('Hello', 'Adele'),
            'Hello',
            unknown,
          ),
          isTrue,
          reason: 'artista "$unknown"',
        );
      }
    });

    test('aceita parceria quando um dos artistas bate', () {
      expect(
        LyricsFetchService.matchesForTest(
          _hit('Shallow', 'Lady Gaga & Bradley Cooper'),
          'Shallow',
          'Lady Gaga',
        ),
        isTrue,
      );
    });
  });

  group('LyricsHit.toLines', () {
    test('prefere letra sincronizada', () {
      const hit = LyricsHit(
        trackName: 't',
        artistName: 'a',
        syncedLyrics: '[00:01.00]sync',
        plainLyrics: 'plain',
      );
      expect(hit.toLines()!.single.text, 'sync');
    });

    test('cai para texto simples e descarta linhas vazias', () {
      const hit = LyricsHit(
        trackName: 't',
        artistName: 'a',
        plainLyrics: 'a\n\n  b  \n',
      );
      expect(hit.toLines()!.map((l) => l.text), ['a', 'b']);
    });

    test('null quando não há letra', () {
      expect(_hit('t', 'a').toLines(), isNull);
    });

    test('fromJson arredonda duração e faz trim', () {
      final hit = LyricsHit.fromJson({
        'trackName': ' T ',
        'artistName': ' A ',
        'duration': 212.6,
      });
      expect(hit.trackName, 'T');
      expect(hit.artistName, 'A');
      expect(hit.duration, const Duration(seconds: 213));
    });
  });
}
