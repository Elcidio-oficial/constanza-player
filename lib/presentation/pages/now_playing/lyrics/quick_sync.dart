// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _QuickSyncPage extends ConsumerStatefulWidget {
  const _QuickSyncPage({required this.song});
  final Song song;

  @override
  ConsumerState<_QuickSyncPage> createState() => _QuickSyncPageState();
}

class _QuickSyncPageState extends ConsumerState<_QuickSyncPage> {
  int _syncIdx = 0;

  @override
  void initState() {
    super.initState();
    // Começar na primeira linha sem sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lines = ref.read(lyricsProvider).lines;
      for (int i = 0; i < lines.length; i++) {
        if (!lines[i].isSynced) {
          setState(() => _syncIdx = i);
          break;
        }
      }
    });
  }

  void _syncCurrentLine() {
    final lyrics = ref.read(lyricsProvider);
    if (_syncIdx >= lyrics.lines.length) {
      _finish();
      return;
    }
    final pos = ref.read(playerProvider).position;
    ref.read(lyricsProvider.notifier).updateLine(_syncIdx, timestamp: pos);
    setState(() => _syncIdx++);
    if (_syncIdx >= lyrics.lines.length) _finish();
  }

  void _finish() {
    ref.read(lyricsProvider.notifier).save();
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sincronização concluída!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseColors = baseTheme.colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(
            primary: baseColors.primary,
            onPrimary: baseColors.onPrimary,
            secondary: baseColors.secondary,
            tertiary: baseColors.tertiary,
            error: baseColors.error,
          );
    final theme = baseTheme.copyWith(colorScheme: colors);
    final lyrics = ref.watch(lyricsProvider);
    final lineCount = lyrics.lines.length;

    return Theme(
      data: theme,
      child: BackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                ref.read(lyricsProvider.notifier).save();
                context.pop();
              },
            ),
            title: Column(
              children: [
                Text(
                  'Sync Rápido',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'Toque no momento certo · $_syncIdx/$lineCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Concluir',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: _syncCurrentLine,
            behavior: HitTestBehavior.opaque,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: 40,
                horizontal: AppSpacing.lg,
              ),
              itemCount: lineCount,
              itemBuilder: (_, i) {
                final line = lyrics.lines[i];
                final isCurrent = i == _syncIdx;
                final isDone = i < _syncIdx;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : isCurrent
                              ? Icons.arrow_forward_rounded
                              : Icons.circle_outlined,
                          size: isDone
                              ? 16
                              : isCurrent
                              ? 18
                              : 14,
                          color: isDone
                              ? colors.primary
                              : isCurrent
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isDone && line.isSynced)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            line.formattedTimestamp,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          line.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isCurrent
                                ? colors.onSurface
                                : isDone
                                ? colors.onSurface.withValues(alpha: 0.5)
                                : colors.onSurface.withValues(alpha: 0.2),
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: isCurrent ? 18 : 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: lineCount > 0 ? _syncIdx / lineCount : 0,
                      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Toque em qualquer lugar para sincronizar a próxima linha',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.25),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EDIT MODE — editor de linhas com timestamp + reorder
// ============================================================

