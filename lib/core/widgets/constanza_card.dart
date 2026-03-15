import 'package:flutter/material.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';

/// Nível de elevação do card.
enum ConstanzaElevation {
  flat(0, 0, 0),
  level1(1, 3, 0.08),
  level2(3, 6, 0.12),
  level3(6, 12, 0.16),
  level4(12, 24, 0.20);

  const ConstanzaElevation(this.offset, this.blur, this.opacity);
  final double offset;
  final double blur;
  final double opacity;
}

/// Card padronizado do Constanza Músicas.
///
/// Exemplo:
/// ```dart
/// ConstanzaCard(
///   elevation: ConstanzaElevation.level1,
///   child: ListTile(...),
/// )
/// ```
class ConstanzaCard extends StatelessWidget {
  const ConstanzaCard({
    super.key,
    required this.child,
    this.elevation = ConstanzaElevation.flat,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
  });

  final Widget child;
  final ConstanzaElevation elevation;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? AppSpacing.radiusMd;

    final container = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevation == ConstanzaElevation.flat
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: elevation.opacity),
                  offset: Offset(0, elevation.offset),
                  blurRadius: elevation.blur,
                ),
              ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (onTap == null) return container;

    return GestureDetector(onTap: onTap, child: container);
  }
}
