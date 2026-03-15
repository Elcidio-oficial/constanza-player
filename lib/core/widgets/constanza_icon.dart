import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';

/// Tamanhos padrão de ícone do Constanza.
enum ConstanzaIconSize {
  sm(AppSpacing.iconSm),
  md(AppSpacing.iconMd),
  lg(AppSpacing.iconLg),
  xl(AppSpacing.iconXl),
  hero(AppSpacing.iconHero);

  const ConstanzaIconSize(this.value);
  final double value;
}

/// Ícone padronizado do Constanza Músicas.
///
/// Exemplo:
/// ```dart
/// ConstanzaIcon(
///   icon: Icons.play_arrow_rounded,
///   size: ConstanzaIconSize.xl,
/// )
/// ```
class ConstanzaIcon extends StatelessWidget {
  const ConstanzaIcon({
    super.key,
    required this.icon,
    this.size = ConstanzaIconSize.md,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final ConstanzaIconSize size;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: size.value,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

    if (onTap == null) return iconWidget;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: iconWidget,
      ),
    );
  }
}
