import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia do Constanza Músicas.
///
/// Fonte: Inter — limpa, legível, moderna.
/// Hierarquia radical: cada estilo tem um propósito claro.
abstract final class AppTypography {
  static String get _fontFamily => GoogleFonts.inter().fontFamily!;

  static TextTheme textTheme() {
    return TextTheme(
      // Display Large — Título em Now Playing
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
        height: 1.2,
      ),

      // Display Medium — Não usado (reservado)
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        height: 1.2,
      ),

      // Headline Medium — Títulos de seção
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.3,
      ),

      // Headline Small
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.3,
      ),

      // Title Large — Títulos de página
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.3,
      ),

      // Title Medium — Nome da música na lista
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.4,
      ),

      // Title Small
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),

      // Body Large
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
      ),

      // Body Medium — Artista, info secundária
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
      ),

      // Body Small — Duração, metadata
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
      ),

      // Label Large
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),

      // Label Medium
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.3,
      ),

      // Label Small — Badges, tags, tempo
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.3,
      ),
    );
  }
}
