import 'dart:convert';
import 'dart:io';

import 'package:constanza_player/services/backup_service.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _backup(Map<String, dynamic> data, {Object format = 1}) => jsonEncode({
  'meta': {'format': format},
  'data': data,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStorageService.init();
    await SettingsStorageService.safePrefs.clear();
  });

  group('BackupService.importFromString', () {
    test('restaura cada tipo suportado e conta as chaves', () async {
      final count = await BackupService.importFromString(
        _backup({
          'constanza_theme_settings': '{"mode":"dark"}',
          'constanza_favorite_ids': ['1', '2'],
          'constanza_profile_name': 'Ana',
        }),
      );
      final prefs = SettingsStorageService.safePrefs;
      expect(count, 3);
      expect(prefs.getString('constanza_theme_settings'), '{"mode":"dark"}');
      expect(prefs.getStringList('constanza_favorite_ids'), ['1', '2']);
      expect(prefs.getString('constanza_profile_name'), 'Ana');
    });

    test('ignora chaves fora da lista exportável', () async {
      final count = await BackupService.importFromString(
        _backup({'chave_estranha': 'x', 'constanza_profile_name': 'Ana'}),
      );
      expect(count, 1);
      expect(
        SettingsStorageService.safePrefs.containsKey('chave_estranha'),
        isFalse,
      );
    });

    test('é aditivo: não apaga chaves ausentes do backup', () async {
      await SettingsStorageService.safePrefs.setString(
        'constanza_audio_settings',
        'existente',
      );
      await BackupService.importFromString(
        _backup({'constanza_profile_name': 'Ana'}),
      );
      expect(
        SettingsStorageService.safePrefs.getString('constanza_audio_settings'),
        'existente',
      );
    });

    test('rejeita JSON inválido, formato futuro ou estrutura errada', () async {
      expect(await BackupService.importFromString('não é json'), isNull);
      expect(await BackupService.importFromString('[]'), isNull);
      expect(
        await BackupService.importFromString(_backup({}, format: 2)),
        isNull,
      );
      expect(
        await BackupService.importFromString(_backup({}, format: '1')),
        isNull,
      );
      expect(
        await BackupService.importFromString(jsonEncode({'data': {}})),
        isNull,
      );
    });
  });

  group('BackupService.importFromPath', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('constanza_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('lê o arquivo, aceitando caminho com aspas e espaços', () async {
      final file = File('${tmp.path}/backup.json')
        ..writeAsStringSync(_backup({'constanza_profile_name': 'Ana'}));
      expect(await BackupService.importFromPath('  "${file.path}" '), 1);
    });

    test('-1 para caminho vazio ou inexistente', () async {
      expect(await BackupService.importFromPath('   '), -1);
      expect(await BackupService.importFromPath('${tmp.path}/nada.json'), -1);
    });

    test('null quando o arquivo existe mas o formato é inválido', () async {
      final file = File('${tmp.path}/ruim.json')..writeAsStringSync('{}');
      expect(await BackupService.importFromPath(file.path), isNull);
    });
  });
}
