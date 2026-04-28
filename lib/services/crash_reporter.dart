import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Reporter local de crashes. Grava erros em `<AppDir>/crashes.jsonl` para
/// que crashes em release builds não sejam engolidos silenciosamente.
///
/// Uso:
///   1. Chame [init] logo no início de main() (antes de runApp).
///   2. Registre hooks via [installGlobalHandlers] dentro da zona guardada.
///   3. Leia os logs para exibir ao usuário em Configurações via [readLogs].
///
/// Não depende de Sentry/Crashlytics — zero setup externo. Se quiser integrar
/// um serviço remoto depois, basta adicionar a chamada em [_record].
class CrashReporter {
  CrashReporter._();

  static File? _logFile;
  static bool _initialized = false;

  /// Máximo de entradas no log. Ao exceder, o arquivo é rotacionado.
  static const int _maxEntries = 200;

  /// Inicializa o arquivo de log. Idempotente.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}/crashes.jsonl');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[CrashReporter] init failed: $e');
    }
  }

  /// Instala handlers globais de erro: Flutter framework, PlatformDispatcher
  /// e isolates. Deve ser chamado dentro de runZonedGuarded em main().
  static void installGlobalHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _record(
        source: 'FlutterError',
        error: details.exceptionAsString(),
        stack: details.stack?.toString(),
        context: details.context?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _record(
        source: 'PlatformDispatcher',
        error: error.toString(),
        stack: stack.toString(),
      );
      return true;
    };
  }

  /// Captura um erro da zona raiz (runZonedGuarded).
  static void recordZoneError(Object error, StackTrace stack) {
    _record(
      source: 'ZoneError',
      error: error.toString(),
      stack: stack.toString(),
    );
  }

  /// Permite que qualquer parte do app registre erros não-fatais.
  static void recordNonFatal(
    Object error, {
    StackTrace? stack,
    String? context,
  }) {
    _record(
      source: 'NonFatal',
      error: error.toString(),
      stack: stack?.toString(),
      context: context,
    );
  }

  static Future<void> _record({
    required String source,
    required String error,
    String? stack,
    String? context,
  }) async {
    debugPrint('[CrashReporter/$source] $error');
    if (stack != null) debugPrint('[CrashReporter/$source] $stack');

    if (!_initialized || _logFile == null) {
      // Tenta inicializar tardiamente — se falhar, perde só este erro.
      await init();
      if (_logFile == null) return;
    }

    try {
      final entry = {
        'ts': DateTime.now().toIso8601String(),
        'source': source,
        'error': error,
        if (stack != null) 'stack': stack,
        if (context != null) 'context': context,
      };
      await _logFile!.writeAsString(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _rotateIfNeeded();
    } catch (e) {
      debugPrint('[CrashReporter] write failed: $e');
    }
  }

  static Future<void> _rotateIfNeeded() async {
    if (_logFile == null) return;
    try {
      final lines = await _logFile!.readAsLines();
      if (lines.length <= _maxEntries) return;
      final keep = lines.sublist(lines.length - _maxEntries);
      await _logFile!.writeAsString('${keep.join('\n')}\n', flush: true);
    } catch (_) {
      // Se falhar, ignora — não vale derrubar o app por isso.
    }
  }

  /// Lê todas as entradas persistidas (mais recentes no fim).
  static Future<List<Map<String, dynamic>>> readLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return const [];
    try {
      final lines = await _logFile!.readAsLines();
      return lines.where((l) => l.isNotEmpty).map((l) {
        try {
          return jsonDecode(l) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{'error': l, 'source': 'malformed'};
        }
      }).toList();
    } catch (e) {
      debugPrint('[CrashReporter] read failed: $e');
      return const [];
    }
  }

  /// Limpa o arquivo de log. Útil para o usuário via Configurações.
  static Future<void> clear() async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString('', flush: true);
    } catch (e) {
      debugPrint('[CrashReporter] clear failed: $e');
    }
  }

  /// Caminho do arquivo de log (para usar em compartilhamento).
  static String? get logFilePath => _logFile?.path;

  /// Conta entradas no log sem precisar deserializar tudo.
  static Future<int> countLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return 0;
    try {
      final lines = await _logFile!.readAsLines();
      return lines.where((l) => l.isNotEmpty).length;
    } catch (_) {
      return 0;
    }
  }
}
