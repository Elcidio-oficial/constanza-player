import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/pages/library/song_list_page.dart';

/// Página de Gêneros Musicais
class GenresPage extends ConsumerWidget {
  const GenresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final genres = ref.watch(libraryProvider.select((s) => s.genres));

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).genresTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: genres.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category_rounded,
                      size: 64,
                      color: colors.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nenhum gênero encontrado',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: genres.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: AppSpacing.md + 52 + AppSpacing.md,
                  color: colors.outline.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final libState = ref.read(libraryProvider);
                  final songCount = libState.songsByGenre(genre).length;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _genreColor(
                          index,
                          colors,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Icon(
                        _genreIcon(genre),
                        size: 24,
                        color: _genreColor(index, colors),
                      ),
                    ),
                    title: Text(
                      genre,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '$songCount música${songCount != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: colors.onSurface.withValues(alpha: 0.2),
                    ),
                    onTap: () {
                      final songs = ref
                          .read(libraryProvider)
                          .songsByGenre(genre);
                      Navigator.push(
                        context,
                        AppPageRoute(
                          page: SongListPage(title: genre, songs: songs),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  static Color _genreColor(int index, ColorScheme colors) {
    const palette = [
      Color(0xFFE57373),
      Color(0xFF81C784),
      Color(0xFF64B5F6),
      Color(0xFFFFB74D),
      Color(0xFFBA68C8),
      Color(0xFF4DD0E1),
      Color(0xFFF06292),
      Color(0xFFAED581),
      Color(0xFF7986CB),
      Color(0xFFFF8A65),
      Color(0xFFA1887F),
      Color(0xFF90A4AE),
    ];
    return palette[index % palette.length];
  }

  static IconData _genreIcon(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('rock')) return Icons.electric_bolt_rounded;
    if (g.contains('pop')) return Icons.star_rounded;
    if (g.contains('hip') || g.contains('rap')) return Icons.mic_rounded;
    if (g.contains('jazz')) return Icons.piano_rounded;
    if (g.contains('class')) return Icons.music_note_rounded;
    if (g.contains('electr') || g.contains('edm')) {
      return Icons.equalizer_rounded;
    }
    if (g.contains('r&b') || g.contains('soul')) return Icons.favorite_rounded;
    if (g.contains('country')) return Icons.landscape_rounded;
    if (g.contains('metal')) return Icons.whatshot_rounded;
    if (g.contains('reggae')) return Icons.wb_sunny_rounded;
    if (g.contains('blues')) return Icons.nightlight_rounded;
    if (g.contains('latin') || g.contains('salsa') || g.contains('samba')) {
      return Icons.celebration_rounded;
    }
    if (g.contains('folk')) return Icons.forest_rounded;
    if (g.contains('punk')) return Icons.flash_on_rounded;
    if (g.contains('gospel') ||
        g.contains('christian') ||
        g.contains('worship')) {
      return Icons.church_rounded;
    }
    if (g.contains('kizomba') || g.contains('zouk') || g.contains('semba')) {
      return Icons.nightlife_rounded;
    }
    return Icons.album_rounded;
  }
}
