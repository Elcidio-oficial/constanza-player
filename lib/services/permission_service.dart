import 'package:permission_handler/permission_handler.dart';

/// Serviço de permissões do Constanza.
///
/// Gerencia permissões de forma inteligente:
/// - Android 13+ (API 33): READ_MEDIA_AUDIO
/// - Android 12 e abaixo: READ_EXTERNAL_STORAGE
class PermissionService {
  /// Verifica se já tem permissão de áudio.
  static Future<bool> hasAudioPermission() async {
    final status = await Permission.audio.status;
    if (status.isGranted) return true;

    // Fallback para storage em versões antigas
    final storageStatus = await Permission.storage.status;
    return storageStatus.isGranted;
  }

  /// Solicita permissão de áudio.
  /// Retorna true se concedida.
  static Future<bool> requestAudioPermission() async {
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
    final audioStatus = await Permission.audio.status;
    final storageStatus = await Permission.storage.status;
    return audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied;
  }

  /// Abre as configurações do app (quando negado permanentemente).
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Solicita permissão de notificação (Android 13+ / API 33).
  /// Sem isto, o foreground service do audio_service não mostra notificação,
  /// e o OS mata o service em poucos segundos em background.
  static Future<bool> requestNotificationPermission() async {
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
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Pede ao usuário a isenção de battery optimization. Abre diálogo do sistema.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }
}
