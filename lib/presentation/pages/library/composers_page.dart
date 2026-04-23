import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/pages/library/song_list_page.dart';

/// Página de Compositores
class ComposersPage extends ConsumerWidget {
  const ComposersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final composers = ref.watch(libraryProvider.select((s) => s.composers));

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Compositores',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: composers.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 64,
                      color: colors.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nenhum compositor encontrado',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Informação disponível nos metadados ID3',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: composers.length,
                itemBuilder: (context, index) {
                  final composer = composers[index];
                  final libState = ref.read(libraryProvider);
                  final songs = libState.songsByComposer(composer);
                  final initial = composer.isNotEmpty
                      ? composer[0].toUpperCase()
                      : '?';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primary.withValues(alpha: 0.1),
                      child: Text(
                        initial,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      composer,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${songs.length} música${songs.length != 1 ? 's' : ''}',
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
                      Navigator.push(
                        context,
                        AppPageRoute(
                          page: SongListPage(title: composer, songs: songs),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
