import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/background_wrapper.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/columns_picker.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

enum AlbumCardShape { square, rounded, circle }

enum AlbumFilter { all, popularity, favorites }

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  AlbumCardShape _shape = AlbumCardShape.rounded;
  AlbumFilter _filter = AlbumFilter.all;
  String? _genre;
  int? _columns;

  @override
  void initState() {
    super.initState();
    final savedShape = SettingsStorageService.loadAlbumShape();
    if (savedShape != null &&
        savedShape >= 0 &&
        savedShape < AlbumCardShape.values.length) {
      _shape = AlbumCardShape.values[savedShape];
    }
    _columns = SettingsStorageService.loadAlbumColumns();
  }

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
    final albums = _applyFilters(lib.albums, lib);
    final genres = lib.genres;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).albumsTitle,
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
                SettingsStorageService.saveAlbumColumns(picked);
              },
            ),
            IconButton(
              tooltip: _shapeTooltip(_shape, context),
              icon: Icon(_shapeIcon(_shape)),
              onPressed: () {
                setState(() {
                  _shape =
                      AlbumCardShape.values[(_shape.index + 1) %
                          AlbumCardShape.values.length];
                });
                SettingsStorageService.saveAlbumShape(_shape.index);
              },
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
              child: albums.isEmpty
                  ? _EmptyState(colors: colors)
                  : _AlbumsGrid(
                      albums: albums,
                      shape: _shape,
                      columns: _columns,
                      onTap: (a) {
                        Navigator.push(
                          context,
                          AppPageRoute(page: AlbumDetailPage(album: a)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Album> _applyFilters(List<Album> input, LibraryState lib) {
    var list = List<Album>.of(input);

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.artist.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_genre != null) {
      final albumNames = lib.songsByGenre(_genre!).map((s) => s.album).toSet();
      list = list.where((a) => albumNames.contains(a.name)).toList();
    }

    switch (_filter) {
      case AlbumFilter.all:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case AlbumFilter.popularity:
        list.sort((a, b) => b.songCount.compareTo(a.songCount));
      case AlbumFilter.favorites:
        final favByAlbum = <String, int>{};
        for (final s in lib.songs) {
          if (s.isFavorite) {
            favByAlbum[s.album] = (favByAlbum[s.album] ?? 0) + 1;
          }
        }
        list = list.where((a) => (favByAlbum[a.name] ?? 0) > 0).toList();
        list.sort(
          (a, b) =>
              (favByAlbum[b.name] ?? 0).compareTo(favByAlbum[a.name] ?? 0),
        );
    }
    return list;
  }

  IconData _shapeIcon(AlbumCardShape s) => switch (s) {
    AlbumCardShape.square => Icons.crop_square_rounded,
    AlbumCardShape.rounded => Icons.rounded_corner_rounded,
    AlbumCardShape.circle => Icons.album_rounded,
  };

  String _shapeTooltip(AlbumCardShape s, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (s) {
      AlbumCardShape.square => l10n.albumsShapeSquare,
      AlbumCardShape.rounded => l10n.albumsShapeRounded,
      AlbumCardShape.circle => l10n.albumsShapeVinyl,
    };
  }
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
          hintText: AppLocalizations.of(context).albumsSearchHint,
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
  final AlbumFilter selected;
  final ValueChanged<AlbumFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (AlbumFilter.all, l10n.albumsFilterAll, Icons.apps_rounded),
      (
        AlbumFilter.popularity,
        l10n.albumsFilterPopular,
        Icons.trending_up_rounded,
      ),
      (
        AlbumFilter.favorites,
        l10n.albumsFilterFavorites,
        Icons.favorite_rounded,
      ),
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
              label: Text(AppLocalizations.of(context).albumsAllGenres),
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

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid({
    required this.albums,
    required this.shape,
    required this.columns,
    required this.onTap,
  });
  final List<Album> albums;
  final AlbumCardShape shape;
  final int? columns;
  final ValueChanged<Album> onTap;

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
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return _AlbumCard(album: a, shape: shape, onTap: () => onTap(a));
      },
    );
  }
}

class _AlbumCard extends StatefulWidget {
  const _AlbumCard({
    required this.album,
    required this.shape,
    required this.onTap,
  });
  final Album album;
  final AlbumCardShape shape;
  final VoidCallback onTap;

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final BorderRadius radius = switch (widget.shape) {
      AlbumCardShape.square => BorderRadius.circular(AppSpacing.radiusXs),
      AlbumCardShape.rounded => BorderRadius.circular(AppSpacing.radiusLg),
      AlbumCardShape.circle => BorderRadius.circular(AppSpacing.radiusFull),
    };
    final isCircle = widget.shape == AlbumCardShape.circle;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ArtworkImage.album(
                      albumId: widget.album.numericId,
                      size: 220,
                      isCircle: isCircle,
                      borderRadius: isCircle ? null : radius,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.album.artist,
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
            Icons.album_outlined,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.of(context).albumsNoneFound,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
