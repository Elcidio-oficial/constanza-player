import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/artist_links_text.dart';
import 'package:go_router/go_router.dart';

class ArtistSelectorBottomSheet extends StatelessWidget {
  const ArtistSelectorBottomSheet({super.key, required this.artistsList});

  final List<dynamic> artistsList;

  static void showOrNavigate(BuildContext context, WidgetRef ref, Song song) {
    HapticFeedback.selectionClick();
    final allArtists = ref.read(libraryProvider).artists;
    final names = ArtistLinksText.splitArtists(song.artist);
    final found = names
        .map(
          (n) => allArtists
              .where((a) => a.name.toLowerCase() == n.toLowerCase())
              .firstOrNull,
        )
        .nonNulls
        .toList();

    if (found.length == 1) {
      Navigator.of(
        context,
      ).push(AppPageRoute(page: ArtistDetailPage(artist: found.first)));
    } else if (found.length > 1) {
      final colors = Theme.of(context).colorScheme;

      showModalBottomSheet(
        context: context,
        backgroundColor: colors.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        builder: (_) => ArtistSelectorBottomSheet(artistsList: found),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Escolher Artista',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Divider(color: colors.outline.withValues(alpha: 0.15)),
          for (final a in artistsList)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(a.name),
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
                Navigator.of(
                  context,
                ).push(AppPageRoute(page: ArtistDetailPage(artist: a)));
              },
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
