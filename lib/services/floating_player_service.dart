import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ponte com o leitor flutuante nativo (system overlay sobre o explorador).
///
/// Ao tocar um áudio pelo gerenciador de arquivos, em vez de abrir o Now
/// Playing inteiro, mostramos um card flutuante por cima do explorador. Requer
/// a permissão "sobrepor a outras apps" (SYSTEM_ALERT_WINDOW).
///
/// Em plataformas não-Android todas as chamadas são no-ops seguros.
class FloatingPlayerService {
  FloatingPlayerService._();

  static const MethodChannel _channel = MethodChannel(
    'com.constanza.constanza_player/floating',
  );

  static VoidCallback? _onClosed;
  static void Function(int positionMs)? _onSeek;
  static bool _handlerRegistered = false;

  static void _ensureHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFloatingClosed':
          _onClosed?.call();
        case 'onFloatingSeek':
          final ms = (call.arguments as num?)?.toInt();
          if (ms != null) _onSeek?.call(ms);
      }
      return null;
    });
  }

  /// Regista o callback chamado quando o usuário fecha o overlay (botão X).
  static void registerOnClosed(VoidCallback handler) {
    _onClosed = handler;
    _ensureHandler();
  }

  /// Regista o callback chamado quando o usuário arrasta a linha do tempo do
  /// overlay (faz seek). Recebe a posição-alvo em milissegundos.
  static void registerOnSeek(void Function(int positionMs) handler) {
    _onSeek = handler;
    _ensureHandler();
  }

  /// `true` se o app pode desenhar por cima de outras apps.
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      debugPrint('[FloatingPlayerService] hasPermission error: $e');
      return false;
    }
  }

  /// Abre as Configurações para o usuário conceder a permissão de overlay.
  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('[FloatingPlayerService] requestPermission error: $e');
    }
  }

  /// Mostra o overlay e envia o app para trás (volta ao explorador).
  /// Devolve `true` se foi exibido (permissão concedida).
  static Future<bool> show() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('showFloatingPlayer') ?? false;
    } catch (e) {
      debugPrint('[FloatingPlayerService] show error: $e');
      return false;
    }
  }

  /// Esconde o overlay.
  static Future<void> hide() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('hideFloatingPlayer');
    } catch (e) {
      debugPrint('[FloatingPlayerService] hide error: $e');
    }
  }

  /// Atualiza a barra de progresso/tempos do overlay.
  static Future<void> updateProgress({
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateFloatingProgress', {
        'positionMs': positionMs,
        'durationMs': durationMs,
        'isPlaying': isPlaying,
      });
    } catch (_) {
      // Silencioso — chamado em loop; um erro pontual não deve poluir logs.
    }
  }
}
