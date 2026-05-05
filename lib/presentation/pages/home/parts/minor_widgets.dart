// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../home_page.dart';

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    required this.theme,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.10),
              colors.onSurface.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER — with icon and staggered animation
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    required this.theme,
    this.onSeeAll,
    this.sectionIndex = 0,
    this.icon,
  });
  final String title;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback? onSeeAll;
  final int sectionIndex;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    AppLocalizations.of(context).homeSeeAllAction,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 60 * sectionIndex))
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
