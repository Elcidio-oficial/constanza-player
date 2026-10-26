import 'package:constanza_player/core/constants/release_notes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('compara numericamente, não como texto', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.7.0', '1.7.0'), 0);
      expect(compareVersions('1.6.5', '1.7.0'), lessThan(0));
      expect(compareVersions('2.0', '1.9.9'), greaterThan(0));
    });
  });

  group('shouldShowWhatsNew', () {
    test('instalação nova: não mostra (já há o onboarding)', () {
      expect(
        shouldShowWhatsNew(
          current: '1.7.0',
          lastSeen: null,
          hadDataAtLaunch: false,
        ),
        isFalse,
      );
    });

    test('atualização vinda de versão sem registo (≤1.6): mostra', () {
      expect(
        shouldShowWhatsNew(
          current: '1.7.0',
          lastSeen: null,
          hadDataAtLaunch: true,
        ),
        isTrue,
      );
    });

    test('mesma versão já vista: não mostra outra vez', () {
      expect(
        shouldShowWhatsNew(
          current: '1.7.0',
          lastSeen: '1.7.0',
          hadDataAtLaunch: true,
        ),
        isFalse,
      );
    });

    test('versão nova depois de uma já vista: mostra', () {
      expect(
        shouldShowWhatsNew(
          current: '1.8.0',
          lastSeen: '1.7.0',
          hadDataAtLaunch: true,
        ),
        isTrue,
      );
    });
  });

  test('notas atuais têm conteúdo nas duas línguas', () {
    final n = currentReleaseNotes;
    expect(n.highlights, isNotEmpty);
    for (final item in n.highlights) {
      expect(item.titlePt, isNotEmpty);
      expect(item.titleEn, isNotEmpty);
    }
    expect(n.fixesPt.length, n.fixesEn.length);
  });
}
