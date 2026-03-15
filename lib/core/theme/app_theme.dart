import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_colors.dart';
import 'package:constanza_player/core/theme/app_typography.dart';

/// Temas do Constanza Músicas.
abstract final class AppTheme {
  /// Tema claro. [accentColor] opcional para personalização.
  static ThemeData light({Color? accentColor}) {
    final ColorScheme colorScheme;

    if (accentColor != null) {
      // Gera esquema base e ajusta as superfícies para não ficarem
      // excessivamente saturadas com cores de destaque muito vívidas.
      final base = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
      );
      colorScheme = base.copyWith(
        // Neutraliza APENAS as superfícies (background), nunca o onSurface.
        // onSurface = cor do texto — se neutralizado erroneamente, o texto
        // fica branco sobre branco (light) ou preto sobre preto (dark).
        surface: _neutralize(base.surface, Brightness.light),
        surfaceContainer: _neutralize(base.surfaceContainer, Brightness.light),
        surfaceContainerLow: _neutralize(
          base.surfaceContainerLow,
          Brightness.light,
        ),
        surfaceContainerHigh: _neutralize(
          base.surfaceContainerHigh,
          Brightness.light,
        ),
      );
    } else {
      colorScheme = AppColors.lightScheme();
    }

    return _buildTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
  }

  /// Tema escuro. [accentColor] opcional para personalização.
  static ThemeData dark({Color? accentColor}) {
    final ColorScheme colorScheme;

    if (accentColor != null) {
      final base = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
      );
      colorScheme = base.copyWith(
        // No dark mode, as superfícies ficam muito escuras/saturadas com fromSeed.
        // Neutralizamos APENAS as superfícies para um cinza escuro confortável.
        // onSurface (texto) jamais deve ser neutralizado.
        surface: _neutralize(base.surface, Brightness.dark),
        surfaceContainer: _neutralize(
          base.surfaceContainer,
          Brightness.dark,
        ),
        surfaceContainerLow: _neutralize(
          base.surfaceContainerLow,
          Brightness.dark,
        ),
        surfaceContainerHigh: _neutralize(
          base.surfaceContainerHigh,
          Brightness.dark,
        ),
      );
    } else {
      colorScheme = AppColors.darkScheme();
    }

    return _buildTheme(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  /// Reduz a saturação da cor para que superfícies não fiquem muito coloridas.
  /// Mantém luminosidade adequada para cada modo.
  static Color _neutralize(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);

    // Reduz saturação a no máximo 8% nas superfícies
    final neutralSat = hsl.saturation.clamp(0.0, 0.08);

    // Garante luminosidade adequada:
    // Light: superfícies devem ser claras (0.94 – 1.0)
    // Dark:  superfícies devem ser escuras mas não pretas (0.08 – 0.18)
    double lum = hsl.lightness;
    if (brightness == Brightness.light) {
      lum = lum.clamp(0.93, 1.0);
    } else {
      lum = lum.clamp(0.08, 0.20);
    }

    return hsl
        .withSaturation(neutralSat)
        .withLightness(lum)
        .toColor();
  }

  /// Constrói o ThemeData completo a partir do colorScheme.
  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final textTheme = AppTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.primary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w300,
        ),
      ),

      // ── NavigationBar ───────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          );
        }),
      ),

      // ── FilledButton ────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
          shape: const StadiumBorder(),
        ),
      ),

      // ── TextButton ──────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),

      // ── IconButton ──────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),

      // ── Switch ──────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainer;
        }),
      ),

      // ── Slider ──────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        inactiveTrackColor: colorScheme.outline.withValues(alpha: 0.2),
      ),

      // ── CheckBox ────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),

      // ── ProgressIndicator ───────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),

      // ── BottomSheet ─────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Dialog ──────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // ── Input ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),

      // ── Divider ─────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.3),
        thickness: 0.5,
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }
}
