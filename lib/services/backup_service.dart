import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:constanza_player/services/settings_storage_service.dart';

/// Backup/restore de dados do usuário (playlists, favoritos, exclusões, histórico,
/// settings de tema/áudio/biblioteca). Funciona em paralelo com Auto Backup do
/// Android — esse arquivo é portátil entre dispositivos e independente da conta.
///
/// Formato: JSON v1 com chave 'meta' e 'data'.
class BackupService {
  BackupService._();

  static const _formatVersion = 1;

  /// Chaves do SharedPreferences que entram no backup. Cache da biblioteca e
  /// crashes não entram (transitórios; o cache é regenerado pelo scan).
  static const _exportedKeys = [
    'constanza_theme_settings',
    'constanza_audio_settings',
    'constanza_library_settings',
    'constanza_favorite_ids',
    'constanza_recent_searches',
    'constanza_music_folders',
    'constanza_user_playlists',
    'constanza_excluded_songs',
    'constanza_play_history',
    'constanza_play_counts',
    'constanza_profile_name',
    'constanza_profile_photo',
  ];

  /// Constrói payload JSON com todas as chaves exportáveis presentes no momento.
  static Map<String, dynamic> _buildPayload() {
    final prefs = SettingsStorageService.safePrefs;
    final data = <String, dynamic>{};
    for (final key in _exportedKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      data[key] = value;
    }
    return {
      'meta': {
        'format': _formatVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'app': 'Constanza Músicas',
      },
      'data': data,
    };
  }

  /// Exporta para arquivo temporário e abre o sheet de partilha do sistema.
  /// Retorna `true` se o arquivo foi gerado (independente de o usuário concluir
  /// a partilha).
  static Future<bool> exportAndShare() async {
    try {
      final payload = _buildPayload();
      final json = const JsonEncoder.withIndent('  ').convert(payload);

      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${tmp.path}/constanza-backup-$stamp.json');
      await file.writeAsString(json, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: 'Backup Constanza Músicas — $stamp',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[BackupService] export failed: $e');
      return false;
    }
  }

  /// Tenta importar a partir de um arquivo no caminho informado. Retorna a
  /// contagem de chaves restauradas, `null` se o formato é inválido, ou `-1`
  /// se o arquivo não foi encontrado/legível.
  static Future<int?> importFromPath(String path) async {
    try {
      final trimmed = path.trim().replaceAll('"', '');
      if (trimmed.isEmpty) return -1;
      final file = File(trimmed);
      if (!await file.exists()) return -1;
      final content = await file.readAsString();
      return importFromString(content);
    } catch (e) {
      debugPrint('[BackupService] importFromPath failed: $e');
      return -1;
    }
  }

  /// Tenta importar a partir de uma string JSON (ex.: vinda do clipboard ou
  /// arquivo). Retorna a contagem de chaves restauradas ou `null` em caso de
  /// formato inválido.
  ///
  /// Não substitui valores que não estejam presentes no payload — restauração
  /// é aditiva por chave; valores existentes da chave são sobrescritos.
  static Future<int?> importFromString(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;
      final meta = decoded['meta'];
      final data = decoded['data'];
      if (meta is! Map || data is! Map) return null;
      final format = meta['format'];
      if (format is! int || format > _formatVersion) return null;

      final prefs = SettingsStorageService.safePrefs;
      var restored = 0;
      for (final entry in data.entries) {
        final key = entry.key;
        if (!_exportedKeys.contains(key)) continue;
        final value = entry.value;
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          await prefs.setStringList(
            key,
            value.map((e) => e.toString()).toList(),
          );
        } else {
          continue;
        }
        restored++;
      }
      return restored;
    } catch (e) {
      debugPrint('[BackupService] import failed: $e');
      return null;
    }
  }
}
