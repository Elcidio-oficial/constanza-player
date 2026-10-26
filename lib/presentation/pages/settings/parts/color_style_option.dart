part of '../settings_page.dart';

// ============================================================
// COLOR STYLE OPTION — visual card for degradê/gradient picker
// ============================================================

class _ColorStyleOption extends StatelessWidget {
  const _ColorStyleOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.theme,
    required this.previewColors,
    required this.isLinear,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ColorScheme colors;
  final ThemeData theme;
  final List<Color> previewColors;
  final bool isLinear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? colors.onSurface.withValues(alpha: 0.6)
                : colors.outline.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          color: isSelected
              ? colors.onSurface.withValues(alpha: 0.06)
              : colors.onSurface.withValues(alpha: 0.02),
        ),
        child: Row(
          children: [
            // Mini preview
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                gradient: isLinear
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: previewColors,
                      )
                    : null,
              ),
              child: isLinear
                  ? null
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: const Color(0xFF121212)),
                          // 3 radial blobs
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.7, -0.6),
                                radius: 1.2,
                                colors: [
                                  previewColors[0].withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.7, -0.3),
                                radius: 1.0,
                                colors: [
                                  previewColors[1].withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.4, 0.8),
                                radius: 1.0,
                                colors: [
                                  previewColors[2].withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? colors.onSurface
                            : colors.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Check indicator
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.onSurface,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colors.surface,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
