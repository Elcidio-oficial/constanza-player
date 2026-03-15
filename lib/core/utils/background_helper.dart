import 'package:flutter/material.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';

/// Helper para aplicar transparência quando o fundo está ativo.
abstract final class BackgroundHelper {
  /// Cor do Scaffold — transparente se há fundo, senão cor padrão.
  static Color scaffoldColor(ColorScheme colors, ThemeState themeState) {
    return themeState.hasBackground ? Colors.transparent : colors.surface;
  }

  /// Cor do AppBar — sempre transparente quando há fundo.
  static Color appBarColor(ColorScheme colors, ThemeState themeState) {
    return themeState.hasBackground ? Colors.transparent : colors.surface;
  }

  /// Cor de cards/containers — semi-transparente quando há fundo.
  static Color cardColor(ColorScheme colors, ThemeState themeState) {
    return themeState.hasBackground
        ? colors.surfaceContainer.withValues(alpha: 0.8)
        : colors.surfaceContainer;
  }

  /// Cor do bottom nav — semi-transparente quando há fundo.
  static Color navColor(ColorScheme colors, ThemeState themeState) {
    return themeState.hasBackground
        ? colors.surface.withValues(alpha: 0.88)
        : colors.surface;
  }

  /// Cor do mini player — semi-transparente quando há fundo.
  static Color miniPlayerColor(ColorScheme colors, ThemeState themeState) {
    return themeState.hasBackground
        ? colors.surfaceContainer.withValues(alpha: 0.9)
        : colors.surfaceContainer;
  }
}
