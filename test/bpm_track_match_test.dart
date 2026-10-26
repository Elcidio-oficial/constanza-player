import 'package:constanza_player/services/bpm_key_fetch_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BpmKeyFetchService.isSameTrack', () {
    test('aceita a mesma música com acentos e feat diferentes', () {
      expect(
        BpmKeyFetchService.isSameTrack(
          'Coração (feat. Ana)',
          'Matias Damásio',
          'Coracao',
          ['Matias Damasio', 'Ana'],
        ),
        isTrue,
      );
    });

    test('rejeita outra música do mesmo artista', () {
      expect(
        BpmKeyFetchService.isSameTrack(
          'Loucos',
          'Matias Damásio',
          'Porquê',
          ['Matias Damásio'],
        ),
        isFalse,
      );
    });

    test('rejeita o mesmo título de outro artista', () {
      expect(
        BpmKeyFetchService.isSameTrack(
          'Hello',
          'Artista Local',
          'Hello',
          ['Adele'],
        ),
        isFalse,
      );
    });
  });
}
