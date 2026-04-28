// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../home_page.dart';

class _LibraryStatsBar extends StatelessWidget {
  const _LibraryStatsBar({
    required this.songCount,
    required this.albumCount,
    required this.artistCount,
    required this.durationLabel,
    required this.colors,
    required this.theme,
  });
  final int songCount;
  final int albumCount;
  final int artistCount;
  final String durationLabel;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              value: '$songCount',
              label: 'Músicas',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$albumCount',
              label: 'Álbuns',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: '$artistCount',
              label: 'Artistas',
              colors: colors,
              theme: theme,
            ),
            Container(
              width: 1,
              height: 24,
              color: colors.outline.withValues(alpha: 0.1),
            ),
            _StatItem(
              value: durationLabel,
              label: 'Duração',
              colors: colors,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.colors,
    required this.theme,
  });
  final String value;
  final String label;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.35),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PULSING DOT — animated indicator
// ============================================================

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _ctrl,
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.5 + 0.5 * value),
          ),
        );
      },
    );
  }
}

// ============================================================
// STANDARD SONG CARD (unchanged from original)
// ============================================================
