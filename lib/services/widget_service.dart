import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Updates the Android home screen widget with current playback info,
/// and dispatches actions originated from the widget back to the app.
class WidgetService {
  static const _channel = MethodChannel(
    'com.constanza.constanza_player/widget',
  );

  static VoidCallback? _onToggleFavorite;
  static VoidCallback? _onCycleRepeatMode;
  static void Function(String route)? _onNavigate;
  static bool _handlerRegistered = false;

  static void _ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toggleFavorite':
          _onToggleFavorite?.call();
          return null;
        case 'cycleRepeatMode':
          _onCycleRepeatMode?.call();
          return null;
        case 'navigate':
          final route = call.arguments as String?;
          if (route != null) _onNavigate?.call(route);
          return null;
      }
      return null;
    });
  }

  /// Registra callbacks invocados quando o utilizador clica nos botões
  /// favorito/repeat dos widgets do ecrã inicial.
  static void registerActionHandlers({
    required VoidCallback onToggleFavorite,
    required VoidCallback onCycleRepeatMode,
  }) {
    _onToggleFavorite = onToggleFavorite;
    _onCycleRepeatMode = onCycleRepeatMode;
    _ensureHandlerRegistered();
  }

  /// Regista o handler de navegação por deeplink e drena qualquer rota
  /// pendente que o widget tenha pedido antes do app estar pronto.
  static void registerNavigationHandler(void Function(String route) onNavigate) {
    _onNavigate = onNavigate;
    _ensureHandlerRegistered();
    _channel.invokeMethod<String>('consumePendingRoute').then((route) {
      if (route != null) onNavigate(route);
    }).catchError((Object e) {
      debugPrint('[WidgetService] consumePendingRoute error: $e');
    });
  }

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
    required bool isFavorite,
    required int repeatMode,
    String? artworkPath,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'isFavorite': isFavorite,
        'repeatMode': repeatMode,
        if (artworkPath != null) 'artworkPath': artworkPath,
      });
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }
}
