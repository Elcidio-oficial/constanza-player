import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';

/// Variantes do botão Constanza.
enum ConstanzaButtonVariant { primary, secondary, ghost }

/// Botão padronizado do Constanza Músicas.
///
/// Exemplo:
/// ```dart
/// ConstanzaButton(
///   label: 'Criar Playlist',
///   onPressed: () {},
///   variant: ConstanzaButtonVariant.primary,
/// )
/// ```
class ConstanzaButton extends StatelessWidget {
  const ConstanzaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ConstanzaButtonVariant.primary,
    this.icon,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ConstanzaButtonVariant variant;
  final IconData? icon;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;

    return switch (variant) {
      ConstanzaButtonVariant.primary => _buildPrimary(colors, textStyle),
      ConstanzaButtonVariant.secondary => _buildSecondary(colors, textStyle),
      ConstanzaButtonVariant.ghost => _buildGhost(colors, textStyle),
    };
  }

  Widget _buildPrimary(ColorScheme colors, TextStyle? textStyle) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : null,
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: colors.onSurface,
        foregroundColor: colors.surface,
        textStyle: textStyle,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildSecondary(ColorScheme colors, TextStyle? textStyle) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : null,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        textStyle: textStyle,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildGhost(ColorScheme colors, TextStyle? textStyle) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : null,
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        textStyle: textStyle,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
      ),
    );

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
