import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/widgets/artist_image.dart';
import 'package:constanza_player/presentation/widgets/columns_picker.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';

enum ArtistCardShape { circle, square, rounded }

enum ArtistFilter { all, popularity, favorites }

class ArtistsPage extends ConsumerStatefulWidget {
  const ArtistsPage({super.key});

  @override
  ConsumerState<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends ConsumerState<ArtistsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ArtistCardShape _shape = ArtistCardShape.circle;
  ArtistFilter _filter = ArtistFilter.all;
  String? _genre;
  int? _columns;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final lib = ref.watch(libraryProvider);
    final artists = _applyFilters(lib.artists, lib);
    final genres = lib.genres;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Artistas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: 'Colunas',
              icon: Icon(columnsIconFor(_columns)),
              onPressed: () async {
                final picked = await showColumnsPicker(
                  context: context,
                  current: _columns,
                );
                if (!mounted) return;
                setState(() => _columns = picked);
              },
            ),
            IconButton(
              tooltip: _shapeTooltip(_shape),
              icon: Icon(_shapeIcon(_shape)),
              onPressed: () => setState(() {
                _shape = ArtistCardShape
                    .values[(_shape.index + 1) % ArtistCardShape.values.length];
              }),
            ),
          ],
        ),
        body: Column(
          children: [
            _SearchBar(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            _FilterRow(
              selected: _filter,
              onSelect: (f) => setState(() => _filter = f),
            ),
            if (genres.isNotEmpty)
              _GenreChips(
                genres: genres,
                selected: _genre,
                onSelect: (g) => setState(() => _genre = g),
              ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: artists.isEmpty
                  ? _EmptyState(colors: colors)
                  : _ArtistsGrid(
                      artists: artists,
                      shape: _shape,
                      columns: _columns,
                      onTap: (a) {
                        Navigator.push(
                          context,
                          AppPageRoute(page: ArtistDetailPage(artist: a)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Artist> _applyFilters(List<Artist> input, LibraryState lib) {
    var list = List<Artist>.of(input);

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((a) => a.name.toLowerCase().contains(q)).toList();
    }

    if (_genre != null) {
      final genreSongs = lib.songsByGenre(_genre!);
      final names = genreSongs.map((s) => s.artist).toSet();
      list = list.where((a) => names.contains(a.name)).toList();
    }

    switch (_filter) {
      case ArtistFilter.all:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ArtistFilter.popularity:
        list.sort((a, b) => b.songCount.compareTo(a.songCount));
      case ArtistFilter.favorites:
        final favByArtist = <String, int>{};
        for (final s in lib.songs) {
          if (s.isFavorite) {
            favByArtist[s.artist] = (favByArtist[s.artist] ?? 0) + 1;
          }
        }
        list = list.where((a) => (favByArtist[a.name] ?? 0) > 0).toList();
        list.sort(
          (a, b) =>
              (favByArtist[b.name] ?? 0).compareTo(favByArtist[a.name] ?? 0),
        );
    }
    return list;
  }

  IconData _shapeIcon(ArtistCardShape s) => switch (s) {
    ArtistCardShape.circle => Icons.circle_outlined,
    ArtistCardShape.square => Icons.crop_square_rounded,
    ArtistCardShape.rounded => Icons.rounded_corner_rounded,
  };

  String _shapeTooltip(ArtistCardShape s) => switch (s) {
    ArtistCardShape.circle => 'Circular',
    ArtistCardShape.square => 'Quadrado',
    ArtistCardShape.rounded => 'Arredondado',
  };
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar artista',
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          filled: true,
          fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelect});
  final ArtistFilter selected;
  final ValueChanged<ArtistFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    const entries = [
      (ArtistFilter.all, 'Todos', Icons.apps_rounded),
      (ArtistFilter.popularity, 'Populares', Icons.trending_up_rounded),
      (ArtistFilter.favorites, 'Favoritos', Icons.favorite_rounded),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final (val, label, icon) = entries[i];
          final isSel = val == selected;
          return FilterChip(
            selected: isSel,
            showCheckmark: false,
            avatar: Icon(icon, size: 16),
            label: Text(label),
            onSelected: (_) => onSelect(val),
          );
        },
      ),
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({
    required this.genres,
    required this.selected,
    required this.onSelect,
  });
  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: genres.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          if (i == 0) {
            return ChoiceChip(
              label: const Text('Todos gêneros'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            );
          }
          final g = genres[i - 1];
          return ChoiceChip(
            label: Text(g),
            selected: selected == g,
            onSelected: (_) => onSelect(g),
          );
        },
      ),
    );
  }
}

class _ArtistsGrid extends StatelessWidget {
  const _ArtistsGrid({
    required this.artists,
    required this.shape,
    required this.columns,
    required this.onTap,
  });
  final List<Artist> artists;
  final ArtistCardShape shape;
  final int? columns;
  final ValueChanged<Artist> onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cross =
        columns ??
        (width < 380
            ? 2
            : width < 600
            ? 3
            : width < 900
            ? 4
            : 5);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.8,
      ),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final a = artists[i];
        return _ArtistCard(artist: a, shape: shape, onTap: () => onTap(a));
      },
    );
  }
}

class _ArtistCard extends StatefulWidget {
  const _ArtistCard({
    required this.artist,
    required this.shape,
    required this.onTap,
  });
  final Artist artist;
  final ArtistCardShape shape;
  final VoidCallback onTap;

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final BorderRadius radius = switch (widget.shape) {
      ArtistCardShape.circle => BorderRadius.circular(AppSpacing.radiusFull),
      ArtistCardShape.square => BorderRadius.circular(AppSpacing.radiusXs),
      ArtistCardShape.rounded => BorderRadius.circular(AppSpacing.radiusLg),
    };
    final isCircle = widget.shape == ArtistCardShape.circle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1,
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ArtistImage(
                      artistName: widget.artist.name,
                      size: 200,
                      isCircle: isCircle,
                      borderRadius: isCircle ? null : radius,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _subtitle(widget.artist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Artist a) {
    final songs = '${a.songCount} música${a.songCount == 1 ? '' : 's'}';
    if (a.albumCount > 0) {
      return '${a.albumCount} álbum${a.albumCount == 1 ? '' : 'ns'} · $songs';
    }
    return songs;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhum artista encontrado',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
