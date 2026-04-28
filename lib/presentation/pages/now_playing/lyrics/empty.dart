// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({
    required this.onAdd,
    required this.onImportLrc,
    required this.onPasteText,
    required this.onSearchOnline,
    required this.isSearching,
    required this.colors,
    required this.theme,
  });
  final VoidCallback onAdd;
  final VoidCallback onImportLrc;
  final VoidCallback onPasteText;
  final VoidCallback onSearchOnline;
  final bool isSearching;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 420;
        final padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: isTight ? AppSpacing.sm : AppSpacing.xl,
        );
        final col = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: isTight ? 40 : 56,
              color: colors.onSurface.withValues(alpha: 0.08),
            ),
            SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
            Text(
              'Sem letras',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Busque online, importe LRC\nou adicione manualmente',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.18),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTight ? AppSpacing.md : AppSpacing.xxl),
            FilledButton.icon(
              onPressed: isSearching ? null : onSearchOnline,
              icon: isSearching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(isSearching ? 'Buscando...' : 'Buscar online'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar manualmente'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onImportLrc,
                  icon: Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                  label: Text(
                    'LRC',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: onPasteText,
                  icon: Icon(
                    Icons.content_paste_rounded,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                  label: Text(
                    'Colar texto',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        // Em landscape (tight), permite scroll. Em portrait, centraliza.
        return isTight
            ? SingleChildScrollView(padding: padding, child: col)
            : Center(
                child: Padding(padding: padding, child: col),
              );
      },
    );
  }
}

// ============================================================
// ESTILO 5: VINYL — disco giratório animado
// ============================================================
