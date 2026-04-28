// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../playlists_page.dart';

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma playlist criada',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Crie sua primeira playlist',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '+ Nova Playlist',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PLAYLIST DETAIL PAGE — Premium (nível de Album/Artist Detail)
// ============================================================

