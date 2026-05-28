// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({
    required this.onAdd,
    required this.onImportLrc,
    required this.onPasteText,
    required this.onSearchOnline,
    required this.onManualSearch,
    required this.isSearching,
    required this.attempted,
    required this.colors,
    required this.theme,
  });
  final VoidCallback onAdd;
  final VoidCallback onImportLrc;
  final VoidCallback onPasteText;
  final VoidCallback onSearchOnline;
  final VoidCallback onManualSearch;
  final bool isSearching;

  /// Já se fez uma busca online que não encontrou nada (estado definitivo,
  /// não ambíguo — acaba com o "clicar duas vezes para confirmar").
  final bool attempted;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 420;
        final padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: isTight ? AppSpacing.sm : AppSpacing.xl,
        );

        // ── Estado: a procurar online ───────────────────────────
        if (isSearching) {
          final searching = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.lyricsSearchingOnline,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
          return Center(
            child: Padding(padding: padding, child: searching),
          );
        }

        // ── Cabeçalho (ícone + título + subtítulo) ───────────────
        final Widget header = attempted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: isTight ? 40 : 56,
                    color: colors.onSurface.withValues(alpha: 0.12),
                  ),
                  SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
                  Text(
                    l10n.lyricsNotFoundTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.lyricsNotFoundSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.22),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lyrics_outlined,
                    size: isTight ? 40 : 56,
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                  SizedBox(height: isTight ? AppSpacing.sm : AppSpacing.md),
                  Text(
                    l10n.lyricsEmpty,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.lyricsEmptySubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.18),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );

        // Ação primária: 1ª vez = "Buscar online"; depois = "Tentar novamente".
        final primary = FilledButton.icon(
          onPressed: onSearchOnline,
          icon: Icon(
            attempted ? Icons.refresh_rounded : Icons.travel_explore_rounded,
            size: 18,
          ),
          label: Text(attempted ? l10n.lyricsRetry : l10n.lyricsSearchOnline),
        );

        final col = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            SizedBox(height: isTight ? AppSpacing.md : AppSpacing.xxl),
            primary,
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onManualSearch,
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: Text(l10n.lyricsManualSearch),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.lyricsAddManually),
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
                    l10n.lyricsLrc,
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
                    l10n.lyricsPaste,
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
