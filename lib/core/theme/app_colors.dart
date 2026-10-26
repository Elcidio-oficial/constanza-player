import 'package:flutter/material.dart';

/// Paleta de cores do Constanza Músicas.
///
/// Filosofia: "O luxo sussurra."
/// - Light: Papel Japonês (tons de neve e tinta)
/// - Dark: Obsidiana (tons de void e moonlight)
abstract final class AppColors {
  // ============================================================
  // LIGHT THEME — Papel Japonês
  // ============================================================

  // Superfícies
  static const Color lightBackground = Color(0xFFFAFAFA); // Snow
  static const Color lightBackgroundSecondary = Color(0xFFF5F5F5); // Smoke
  static const Color lightCard = Color(0xFFFFFFFF); // Pure
  static const Color lightDivider = Color(0xFFE0E0E0); // Mist

  // Textos
  static const Color lightTextPrimary = Color(0xFF1A1A1A); // Ink
  static const Color lightTextSecondary = Color(0xFF666666); // Graphite
  static const Color lightTextTertiary = Color(0xFF9E9E9E); // Fog
  static const Color lightTextCaption = Color(0xFFBDBDBD); // Whisper

  // Acentos
  static const Color lightAccent = Color(0xFF1A1A1A); // Noir
  static const Color lightAccentInteractive = Color(0xFF2D2D2D); // Charcoal
  static const Color lightAccentSubtle = Color(0xFF424242); // Slate

  // ============================================================
  // DARK THEME — Obsidiana
  // ============================================================

  // Superfícies
  static const Color darkBackground = Color(0xFF0A0A0A); // Void
  static const Color darkBackgroundSecondary = Color(0xFF121212); // Abyss
  static const Color darkCard = Color(0xFF1E1E1E); // Obsidian
  static const Color darkDivider = Color(0xFF2C2C2C); // Shadow

  // Textos
  static const Color darkTextPrimary = Color(0xFFFAFAFA); // Moonlight
  static const Color darkTextSecondary = Color(0xFFB0B0B0); // Silver
  static const Color darkTextTertiary = Color(0xFF707070); // Pewter
  static const Color darkTextCaption = Color(0xFF505050); // Dusk

  // Acentos
  static const Color darkAccent = Color(0xFFFFFFFF); // Pure
  static const Color darkAccentInteractive = Color(0xFFE0E0E0); // Pearl
  static const Color darkAccentSubtle = Color(0xFF9E9E9E); // Platinum

  // ============================================================
  // UNIVERSAIS
  // ============================================================

  static const Color playingIndicatorLight = Color(0xFF4CAF50); // Zen Green
  static const Color playingIndicatorDark = Color(0xFF69F0AE); // Aurora
  static const Color error = Color(0xFFCF6679);
  static const Color transparent = Colors.transparent;

  // ============================================================
  // COLOR SCHEMES
  // ============================================================

  /// Esquema claro completo (todos os papéis do Material 3).
  ///
  /// Neutros levemente quentes ("papel") em vez de cinza puro, que no claro
  /// parece sujo. Hierarquia: fundo um tom abaixo do branco, cartões e folhas
  /// em branco/quase-branco, contentores descendo em degraus de ~2,5% L.
  /// Contraste de texto: onSurface 16:1, onSurfaceVariant 6,4:1 (AA).
  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1B1B1D),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE6E5E3),
      onPrimaryContainer: Color(0xFF1B1B1D),
      secondary: Color(0xFF5C5B60),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE9E8E5),
      onSecondaryContainer: Color(0xFF1F1F22),
      tertiary: Color(0xFF2E7D4F),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFD3EEDC),
      onTertiaryContainer: Color(0xFF0B2E18),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF7F6F3),
      onSurface: Color(0xFF1B1B1D),
      onSurfaceVariant: Color(0xFF55545A),
      surfaceDim: Color(0xFFDDDCD8),
      surfaceBright: Color(0xFFFCFBF9),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFCFBF9),
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFEFEEEA),
      surfaceContainerHighest: Color(0xFFE8E7E3),
      outline: Color(0xFF8C8B90),
      outlineVariant: Color(0xFFD3D2CE),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2F2F31),
      onInverseSurface: Color(0xFFF3F2EF),
      inversePrimary: Color(0xFFC9C8CC),
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: darkAccent,
      onPrimary: darkBackground,
      secondary: darkAccentSubtle,
      onSecondary: darkTextPrimary,
      tertiary: playingIndicatorDark,
      onTertiary: darkBackground,
      error: error,
      onError: darkBackground,
      surface: darkBackground,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkBackgroundSecondary,
      outline: darkDivider,
      outlineVariant: darkTextCaption,
      inverseSurface: lightBackground,
      onInverseSurface: lightTextPrimary,
      surfaceContainer: darkCard,
    );
  }
}
