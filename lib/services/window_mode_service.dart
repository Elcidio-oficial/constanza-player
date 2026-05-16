import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

/// Controla a transição entre o modo cheio do app e o mini-leitor estilo
/// Windows Media Player: janela pequena, sempre-no-topo, com capa + controles.
///
/// Mantém em memória o tamanho da janela antes de entrar no modo mini para
/// restaurar exatamente o estado anterior ao sair.
class WindowModeService {
  WindowModeService._();

  static const Size _miniSize = Size(360, 380);
  static const Size _defaultFullSize = Size(1100, 720);
  static const Size _miniMinimum = Size(300, 320);
  static const Size _fullMinimum = Size(900, 600);

  static Size? _fullSizeBeforeMini;

  /// Notifica listeners (ex.: MaterialApp.builder) sempre que entra/sai do
  /// modo mini. Usado para esconder o [WindowsTitleBar] no modo mini sem
  /// precisar acoplar a UI ao GoRouter.
  static final ValueNotifier<bool> isMiniNotifier = ValueNotifier<bool>(false);

  static bool get isMini => isMiniNotifier.value;

  static bool get isSupported => Platform.isWindows || Platform.isLinux;

  /// Entra no modo mini: salva tamanho atual, encolhe janela, fixa no topo.
  static Future<void> enterMini() async {
    if (!isSupported || isMini) return;
    try {
      final bounds = await windowManager.getBounds();
      _fullSizeBeforeMini = bounds.size;
      await windowManager.setMinimumSize(_miniMinimum);
      await windowManager.setSize(_miniSize, animate: true);
      await windowManager.setAlwaysOnTop(true);
      isMiniNotifier.value = true;
    } catch (e) {
      debugPrint('[WindowMode] enterMini failed: $e');
    }
  }

  /// Volta ao modo cheio: restaura tamanho anterior e libera always-on-top.
  static Future<void> exitMini() async {
    if (!isSupported || !isMini) return;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(_fullMinimum);
      final restore = _fullSizeBeforeMini ?? _defaultFullSize;
      await windowManager.setSize(restore, animate: true);
      await windowManager.center();
      isMiniNotifier.value = false;
    } catch (e) {
      debugPrint('[WindowMode] exitMini failed: $e');
    }
  }

  static Future<void> toggle() async {
    if (isMini) {
      await exitMini();
    } else {
      await enterMini();
    }
  }
}
