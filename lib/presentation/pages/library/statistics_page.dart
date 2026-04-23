import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final libState = ref.watch(libraryProvider);
    final songs = libState.songs;
    final albums = libState.albums;
    final artists = libState.artists;
    final genres = libState.genres;
    final playCounts = ref.watch(playCountsProvider);

    // Calculate stats
    final totalSongs = songs.length;
    final totalAlbums = albums.length;
    final totalArtists = artists.length;
    final totalGenres = genres.length;
    final favCount = songs.where((s) => s.isFavorite).length;
    final totalDuration = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final hours = totalDuration.inHours;
    final mins = totalDuration.inMinutes.remainder(60);

    // Total plays
    final totalPlays = playCounts.values.fold<int>(0, (sum, c) => sum + c);

    // Top 5 most played
    final topSongs = playCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topSongs.take(5).toList();

    // Top genres by song count
    final genreStats = <String, int>{};
    for (final s in songs) {
      if (s.genre != null && s.genre!.isNotEmpty) {
        genreStats[s.genre!] = (genreStats[s.genre!] ?? 0) + 1;
      }
    }
    final topGenres = genreStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Estatisticas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // -- Library Overview --
            Text(
              'BIBLIOTECA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatCard(
                  label: 'Musicas',
                  value: '$totalSongs',
                  icon: Icons.music_note_rounded,
                  color: colors.primary,
                  colors: colors,
                  theme: theme,
                ),
                _StatCard(
                  label: 'Albuns',
                  value: '$totalAlbums',
                  icon: Icons.album_rounded,
                  color: const Color(0xFF64B5F6),
                  colors: colors,
                  theme: theme,
                ),
                _StatCard(
                  label: 'Artistas',
                  value: '$totalArtists',
                  icon: Icons.person_rounded,
                  color: const Color(0xFFBA68C8),
                  colors: colors,
                  theme: theme,
                ),
                _StatCard(
                  label: 'Generos',
                  value: '$totalGenres',
                  icon: Icons.category_rounded,
                  color: const Color(0xFFFFB74D),
                  colors: colors,
                  theme: theme,
                ),
                _StatCard(
                  label: 'Favoritas',
                  value: '$favCount',
                  icon: Icons.favorite_rounded,
                  color: colors.error,
                  colors: colors,
                  theme: theme,
                ),
                _StatCard(
                  label: 'Duracao Total',
                  value: '${hours}h ${mins}m',
                  icon: Icons.timer_rounded,
                  color: const Color(0xFF4DD0E1),
                  colors: colors,
                  theme: theme,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // -- Playback Stats --
            Text(
              'REPRODUCAO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_rounded,
                    size: 40,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalPlays',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'reproducoes totais',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (top5.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'MAIS TOCADAS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...top5.asMap().entries.map((entry) {
                final idx = entry.key;
                final songId = entry.value.key;
                final count = entry.value.value;
                final song = songs.where((s) => s.id == songId).firstOrNull;
                if (song == null) return const SizedBox.shrink();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${idx + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  trailing: Text(
                    '${count}x',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ],

            if (topGenres.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'GENEROS MAIS OUVIDOS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...topGenres.take(5).map((e) {
                final pct = totalSongs > 0 ? e.value / totalSongs : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            '${e.value} musicas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: colors.onSurface.withValues(
                            alpha: 0.06,
                          ),
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 80), // bottom padding for mini player
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colors,
    required this.theme,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final w =
        (MediaQuery.sizeOf(context).width - AppSpacing.md * 2 - AppSpacing.sm) /
        2;
    return Container(
      width: w,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
