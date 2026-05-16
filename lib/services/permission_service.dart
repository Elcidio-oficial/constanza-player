import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

/// Serviço de permissões do Constanza.
///
/// Android 13+ (API 33): READ_MEDIA_AUDIO; Android 12-: READ_EXTERNAL_STORAGE.
/// Em desktop (Windows/Linux/macOS) todas as chamadas retornam `true` —
/// o acesso ao filesystem é controlado pelo OS via prompts no file_picker.
class PermissionService {
  /// Verifica se já tem permissão de áudio.
  static Future<bool> hasAudioPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final status = await Permission.audio.status;
    if (status.isGranted) return true;

    // Fallback para storage em versões antigas
    final storageStatus = await Permission.storage.status;
    return storageStatus.isGranted;
  }

  /// Solicita permissão de áudio.
  /// Retorna true se concedida.
  static Future<bool> requestAudioPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // Tenta READ_MEDIA_AUDIO primeiro (Android 13+)
    var status = await Permission.audio.request();
    if (status.isGranted) return true;

    // Fallback para READ_EXTERNAL_STORAGE (Android 12-)
    status = await Permission.storage.request();
    if (status.isGranted) return true;

    return false;
  }

  /// Verifica se a permissão foi negada permanentemente.
  static Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    final audioStatus = await Permission.audio.status;
    final storageStatus = await Permission.storage.status;
    return audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied;
  }

  /// Abre as configurações do app (quando negado permanentemente).
  static Future<bool> openSettings() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return await openAppSettings();
  }

  /// Solicita permissão de notificação (Android 13+ / API 33).
  /// Sem isto, o foreground service do audio_service não mostra notificação,
  /// e o OS mata o service em poucos segundos em background.
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Indica se o app está isento de battery optimization (Doze mode).
  /// Sem isenção, sessões longas em background podem ser interrompidas
  /// (volume baixo, pausa abrupta) por agressividade do OEM.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Pede ao usuário a isenção de battery optimization. Abre diálogo do sistema.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }
}
