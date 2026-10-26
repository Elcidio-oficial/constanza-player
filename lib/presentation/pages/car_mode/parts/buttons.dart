part of '../car_mode_page.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Reusable button components
// ──────────────────────────────────────────────────────────────────────────────

class _CarBtn extends StatelessWidget {
  const _CarBtn({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    this.bgColor,
    this.shadow = false,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color? bgColor;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              bgColor ??
              Theme.of(context).colorScheme.onSurface.withValues(
                alpha: onTap != null ? 0.1 : 0.04,
              ),
          boxShadow: shadow && onTap != null
              ? [
                  BoxShadow(
                    color: (bgColor ?? Theme.of(context).colorScheme.onSurface)
                        .withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    this.active = false,
    this.activeColor,
    this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool active;
  final Color? activeColor;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? Theme.of(context).colorScheme.onSurface)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? (activeColor ?? Theme.of(context).colorScheme.onSurface)
                        .withValues(alpha: 0.18)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
              border: Border.all(
                color: active
                    ? (activeColor ?? Theme.of(context).colorScheme.onSurface)
                          .withValues(alpha: 0.35)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
