import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Auto-cura de crashes FFI durante o scan de tags no Windows.
///
/// Algumas tags ID3/FLAC/MP4 malformadas fazem a libtag-rust do `audiotags`
/// segfaultar dentro do FFI — não vira `Exception` Dart, mata o processo
/// silenciosamente. Tentar capturar com try/catch é inútil contra crash
/// nativo, e Isolate não isola (Dart isolates compartilham processo OS).
///
/// Estratégia:
/// 1. Antes de cada [AudioTags.read], grava-se **sincronamente** o path no
///    arquivo `scan_inprogress.txt` (overwrite, não append).
/// 2. Após sucesso, sobrescreve com vazio.
/// 3. No próximo boot, [checkCrashOnBoot] lê o arquivo. Se não-vazio, aquele
///    path crashou no run anterior → é adicionado à blacklist persistida em
///    `scan_blocklist.json` e ignorado em scans futuros.
///
/// O usuário pode resetar a blacklist via [clearBlocklist] (botão em settings).
class ScanCrashGuard {
  ScanCrashGuard._();

  static File? _inProgressFile;
  static File? _blocklistFile;
  static final Set<String> _blocked = {};
  static bool _initialized = false;

  /// Inicializa os arquivos e processa crash detectado no boot anterior.
  /// Retorna o path que crashou (se houver) para logging/UX.
  static Future<String?> init() async {
    if (_initialized) return null;
    String? culprit;
    try {
      final dir = await getApplicationSupportDirectory();
      _inProgressFile = File('${dir.path}/scan_inprogress.txt');
      _blocklistFile = File('${dir.path}/scan_blocklist.json');

      // Carrega blacklist persistida
      if (await _blocklistFile!.exists()) {
        try {
          final raw = await _blocklistFile!.readAsString();
          final list = (jsonDecode(raw) as List?)?.cast<String>() ?? const [];
          _blocked.addAll(list);
        } catch (e) {
          debugPrint('[ScanCrashGuard] blocklist parse failed: $e');
        }
      }

      // Detecta crash do scan anterior
      if (await _inProgressFile!.exists()) {
        final last = (await _inProgressFile!.readAsString()).trim();
        if (last.isNotEmpty) {
          culprit = last;
          _blocked.add(last);
          await _persistBlocklist();
          await _inProgressFile!.writeAsString('', flush: true);
          debugPrint(
            '[ScanCrashGuard] previous scan crashed on: $last — blacklisted',
          );
        }
      } else {
        await _inProgressFile!.create(recursive: true);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[ScanCrashGuard] init failed: $e');
    }
    return culprit;
  }

  /// Marca início da leitura de tag de [path]. Sincronizo — precisa ser
  /// flushed para disco ANTES do FFI rodar, senão o crash leva o buffer
  /// junto.
  static void markBegin(String path) {
    final f = _inProgressFile;
    if (f == null) return;
    try {
      f.writeAsStringSync(path, flush: true);
    } catch (_) {}
  }

  /// Marca leitura concluída com sucesso. Limpa o arquivo.
  static void markEnd() {
    final f = _inProgressFile;
    if (f == null) return;
    try {
      f.writeAsStringSync('', flush: true);
    } catch (_) {}
  }

  /// Path está na blacklist (crashou em scan anterior)?
  static bool isBlocked(String path) => _blocked.contains(path);

  /// Conjunto atual de paths bloqueados (cópia somente-leitura).
  static Set<String> get blocklist => Set.unmodifiable(_blocked);

  /// Limpa a blacklist — usuário pode acionar via settings depois que tiver
  /// removido/reparado os arquivos problemáticos.
  static Future<void> clearBlocklist() async {
    _blocked.clear();
    await _persistBlocklist();
  }

  static Future<void> _persistBlocklist() async {
    final f = _blocklistFile;
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(_blocked.toList()), flush: true);
    } catch (e) {
      debugPrint('[ScanCrashGuard] blocklist persist failed: $e');
    }
  }
}
