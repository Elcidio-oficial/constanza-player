import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:go_router/go_router.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final history = ref.watch(playHistoryProvider);
    final songs = ref.watch(libraryProvider.select((s) => s.songs));

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Historico',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            if (history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Limpar historico',
                onPressed: () => _showClearDialog(context, ref),
              ),
          ],
        ),
        body: history.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: colors.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nenhuma reproducao registrada',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final entry = history[index];
                  final songId = entry['songId'] as String;
                  final title = entry['title'] as String? ?? 'Desconhecido';
                  final artist = entry['artist'] as String? ?? '';
                  final timestamp = entry['timestamp'] as int? ?? 0;
                  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
                  final numericId = int.tryParse(songId) ?? 0;

                  // Find song in library for playback
                  final song = songs.where((s) => s.id == songId).firstOrNull;
                  final timeLabel = _formatTime(time);

                  // Show date header
                  final showDateHeader =
                      index == 0 ||
                      _dateKey(time) !=
                          _dateKey(
                            DateTime.fromMillisecondsSinceEpoch(
                              (history[index - 1]['timestamp'] as int?) ?? 0,
                            ),
                          );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDateHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            _formatDate(time),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.35),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 2,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          child: ArtworkImage.song(
                            songId: numericId,
                            size: 48,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            placeholderIconSize: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                        trailing: Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        onTap: song != null
                            ? () => ref
                                  .read(playerProvider.notifier)
                                  .playSong(song)
                            : null,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'HOJE';
    if (date == today.subtract(const Duration(days: 1))) return 'ONTEM';
    final months = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar Historico'),
        content: const Text('Deseja apagar todo o historico de reproducao?'),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(playlistProvider.notifier).clearHistory();
              ctx.pop();
            },
            child: Text('Limpar', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }
}
