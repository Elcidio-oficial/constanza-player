import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/app_page_route.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/artist_image.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/pages/library/album_detail_page.dart';
import 'package:constanza_player/presentation/pages/library/artist_detail_page.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

/// Página de Busca — pesquisa em tempo real na biblioteca local.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

enum _SearchFilter { all, songs, albums, artists }

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  _SearchFilter _filter = _SearchFilter.all;
  List<String> _recentSearches = [];

  // Memoized search results — invalidados quando _query muda
  String _lastRankedQuery = '';
  List<Song> _cachedSongResults = [];
  List<Album> _cachedAlbumResults = [];
  List<Artist> _cachedArtistResults = [];

  /// Limite de resultados por seção no modo "Todos"
  static const _previewLimit = 5;

  @override
  void initState() {
    super.initState();
    _recentSearches = SettingsStorageService.loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final newQuery = value.trim().toLowerCase();
        if (newQuery != _query) {
          _lastRankedQuery = ''; // invalidar cache
          setState(() => _query = newQuery);
        }
      }
    });
  }

  void _addToRecent(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _recentSearches.remove(q);
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 10) _recentSearches.removeLast();
    });
    SettingsStorageService.saveRecentSearches(_recentSearches);
  }

  void _clearRecent() {
    setState(() => _recentSearches.clear());
    SettingsStorageService.saveRecentSearches([]);
  }

  void _removeRecent(String query) {
    setState(() => _recentSearches.remove(query));
    SettingsStorageService.saveRecentSearches(_recentSearches);
  }

  void _useRecent(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
    _focusNode.requestFocus();
  }

  /// Insere texto de pesquisa recente no campo sem executar busca imediata.
  void _insertRecent(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
      appBar: AppBar(
        backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
        title: Text(
          'Busca',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      body: Column(
        children: [
          // === Search Bar ===
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxs,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              onSubmitted: _addToRecent,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar músicas, artistas, álbuns...',
                hintStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          // === Filter chips + contagem ===
          if (_query.isNotEmpty) _buildFilterChips(theme, colors),
          Expanded(
            child: _query.isEmpty
                ? _buildEmptyState(theme, colors)
                : _buildResults(theme, colors, ref),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CHIPS com contagem de resultados
  // ============================================================

  /// Atualiza o cache de resultados se a query mudou.
  void _ensureRankedResults(LibraryState libState) {
    if (_lastRankedQuery == _query) return;
    _lastRankedQuery = _query;
    _cachedSongResults = _rankSongs(libState.sortedSongs);
    _cachedAlbumResults = _rankAlbums(libState.albums);
    _cachedArtistResults = _rankArtists(libState.artists);
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme colors) {
    final libState = ref.watch(libraryProvider);
    _ensureRankedResults(libState);

    final songCount = _cachedSongResults.length;
    final albumCount = _cachedAlbumResults.length;
    final artistCount = _cachedArtistResults.length;
    final totalCount = songCount + albumCount + artistCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            children: [
              _FilterChip(
                label: 'Todos',
                count: totalCount,
                active: _filter == _SearchFilter.all,
                onTap: () => setState(() => _filter = _SearchFilter.all),
                colors: colors,
                theme: theme,
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterChip(
                label: 'Músicas',
                count: songCount,
                active: _filter == _SearchFilter.songs,
                onTap: () => setState(() => _filter = _SearchFilter.songs),
                colors: colors,
                theme: theme,
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterChip(
                label: 'Álbuns',
                count: albumCount,
                active: _filter == _SearchFilter.albums,
                onTap: () => setState(() => _filter = _SearchFilter.albums),
                colors: colors,
                theme: theme,
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterChip(
                label: 'Artistas',
                count: artistCount,
                active: _filter == _SearchFilter.artists,
                onTap: () => setState(() => _filter = _SearchFilter.artists),
                colors: colors,
                theme: theme,
              ),
            ],
          ),
        ),
        // Barra de contagem total
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            totalCount == 0
                ? 'Nenhum resultado'
                : '$totalCount resultado${totalCount != 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE — stats da biblioteca + buscas recentes
  // ============================================================

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    final libState = ref.watch(libraryProvider);

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.search_rounded,
          size: 48,
          color: colors.onSurface.withValues(alpha: 0.1),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Explore sua biblioteca',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.35),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxs),
        // Stats da biblioteca
        Text(
          [
            '${libState.songs.length} música${libState.songs.length != 1 ? 's' : ''}',
            '${libState.albums.length} álbun${libState.albums.length != 1 ? 's' : ''}',
            '${libState.artists.length} artista${libState.artists.length != 1 ? 's' : ''}',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          textAlign: TextAlign.center,
        ),
        // === Buscas recentes ===
        if (_recentSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUSCAS RECENTES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: _clearRecent,
                  child: Text(
                    'Limpar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          ..._recentSearches.map(
            (query) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              dense: true,
              leading: Icon(
                Icons.history_rounded,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              title: Text(
                query,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botão de inserir no campo (seta NE)
                  GestureDetector(
                    onTap: () => _insertRecent(query),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Botão de remover
                  GestureDetector(
                    onTap: () => _removeRecent(query),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => _useRecent(query),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // RESULTADOS — ranking por relevância + seções "Ver todos"
  // ============================================================

  Widget _buildResults(ThemeData theme, ColorScheme colors, WidgetRef ref) {
    final libState = ref.watch(libraryProvider);
    _ensureRankedResults(libState);

    final showSongs =
        _filter == _SearchFilter.all || _filter == _SearchFilter.songs;
    final showAlbums =
        _filter == _SearchFilter.all || _filter == _SearchFilter.albums;
    final showArtists =
        _filter == _SearchFilter.all || _filter == _SearchFilter.artists;

    // Usar resultados cacheados
    final songResults = showSongs ? _cachedSongResults : <Song>[];
    final albumResults = showAlbums ? _cachedAlbumResults : <Album>[];
    final artistResults = showArtists ? _cachedArtistResults : <Artist>[];

    if (songResults.isEmpty && albumResults.isEmpty && artistResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: colors.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhum resultado para "$_query"',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Verifique a ortografia ou tente outro termo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      );
    }

    final isAllMode = _filter == _SearchFilter.all;
    final songPreview = isAllMode && songResults.length > _previewLimit;
    final albumPreview = isAllMode && albumResults.length > _previewLimit;
    final artistPreview = isAllMode && artistResults.length > _previewLimit;

    final displaySongs = songPreview
        ? songResults.take(_previewLimit).toList()
        : songResults;
    final displayAlbums = albumPreview
        ? albumResults.take(_previewLimit).toList()
        : albumResults;
    final displayArtists = artistPreview
        ? artistResults.take(_previewLimit).toList()
        : artistResults;

    return ListView(
      children: [
        // ── ARTISTAS ──
        if (displayArtists.isNotEmpty) ...[
          _sectionHeader(
            'Artistas',
            artistResults.length,
            theme,
            colors,
            showViewAll: artistPreview,
            onViewAll: () => setState(() => _filter = _SearchFilter.artists),
          ),
          ...displayArtists.map(
            (artist) => _buildArtistTile(artist, theme, colors, ref),
          ),
          if (displaySongs.isNotEmpty || displayAlbums.isNotEmpty)
            Divider(
              color: colors.outline.withValues(alpha: 0.08),
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
              height: AppSpacing.md,
            ),
        ],

        // ── ÁLBUNS ──
        if (displayAlbums.isNotEmpty) ...[
          _sectionHeader(
            'Álbuns',
            albumResults.length,
            theme,
            colors,
            showViewAll: albumPreview,
            onViewAll: () => setState(() => _filter = _SearchFilter.albums),
          ),
          ...displayAlbums.map(
            (album) => _buildAlbumTile(album, theme, colors, ref),
          ),
          if (displaySongs.isNotEmpty)
            Divider(
              color: colors.outline.withValues(alpha: 0.08),
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
              height: AppSpacing.md,
            ),
        ],

        // ── MÚSICAS ──
        if (displaySongs.isNotEmpty) ...[
          _sectionHeader(
            'Músicas',
            songResults.length,
            theme,
            colors,
            showViewAll: songPreview,
            onViewAll: () => setState(() => _filter = _SearchFilter.songs),
          ),
          ...displaySongs.map(
            (song) => SongTile(
              song: song,
              useArtistLinks: true,
              onTap: () {
                _addToRecent(_searchController.text.trim());
                ref
                    .read(playerProvider.notifier)
                    .playSong(song, queue: songResults);
              },
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  // ============================================================
  // RANKING — exact > starts with > contains
  // ============================================================

  List<Song> _rankSongs(List<Song> all) {
    final exact = <Song>[];
    final startsWith = <Song>[];
    final contains = <Song>[];

    for (final s in all) {
      final title = s.title.toLowerCase();
      final artist = s.artist.toLowerCase();
      final album = s.album.toLowerCase();

      if (title == _query || artist == _query || album == _query) {
        exact.add(s);
      } else if (title.startsWith(_query) ||
          artist.startsWith(_query) ||
          album.startsWith(_query)) {
        startsWith.add(s);
      } else if (title.contains(_query) ||
          artist.contains(_query) ||
          album.contains(_query)) {
        contains.add(s);
      }
    }
    return [...exact, ...startsWith, ...contains];
  }

  List<Album> _rankAlbums(List<Album> all) {
    final exact = <Album>[];
    final startsWith = <Album>[];
    final contains = <Album>[];

    for (final a in all) {
      final name = a.name.toLowerCase();
      final artist = a.artist.toLowerCase();

      if (name == _query || artist == _query) {
        exact.add(a);
      } else if (name.startsWith(_query) || artist.startsWith(_query)) {
        startsWith.add(a);
      } else if (name.contains(_query) || artist.contains(_query)) {
        contains.add(a);
      }
    }
    return [...exact, ...startsWith, ...contains];
  }

  List<Artist> _rankArtists(List<Artist> all) {
    final exact = <Artist>[];
    final startsWith = <Artist>[];
    final contains = <Artist>[];

    for (final a in all) {
      final name = a.name.toLowerCase();

      if (name == _query) {
        exact.add(a);
      } else if (name.startsWith(_query)) {
        startsWith.add(a);
      } else if (name.contains(_query)) {
        contains.add(a);
      }
    }
    return [...exact, ...startsWith, ...contains];
  }

  // ============================================================
  // TILES DE RESULTADO
  // ============================================================

  Widget _buildAlbumTile(
    Album album,
    ThemeData theme,
    ColorScheme colors,
    WidgetRef ref,
  ) {
    final libState = ref.watch(libraryProvider);
    final albumSongs = libState.sortedSongs
        .where((s) => s.album.toLowerCase() == album.name.toLowerCase())
        .toList();

    // Subtitle: artista · ano · X músicas
    final parts = <String>[
      album.artist,
      if (album.year != null) '${album.year}',
      '${albumSongs.length} faixa${albumSongs.length != 1 ? 's' : ''}',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: ArtworkImage.album(
        albumId: album.numericId,
        size: 48,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        placeholderIcon: Icons.album_rounded,
      ),
      title: Text(
        album.name,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.45),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colors.onSurface.withValues(alpha: 0.15),
      ),
      onTap: () {
        _addToRecent(_searchController.text.trim());
        Navigator.of(
          context,
        ).push(AppPageRoute(page: AlbumDetailPage(album: album)));
      },
    );
  }

  Widget _buildArtistTile(
    Artist artist,
    ThemeData theme,
    ColorScheme colors,
    WidgetRef ref,
  ) {
    // Subtitle: X músicas · Y álbuns
    final parts = <String>[
      '${artist.songCount} música${artist.songCount != 1 ? 's' : ''}',
      '${artist.albumCount} álbun${artist.albumCount != 1 ? 's' : ''}',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: ArtistImage(artistName: artist.name, size: 48),
      title: Text(
        artist.name,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.45),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colors.onSurface.withValues(alpha: 0.15),
      ),
      onTap: () {
        _addToRecent(_searchController.text.trim());
        Navigator.of(
          context,
        ).push(AppPageRoute(page: ArtistDetailPage(artist: artist)));
      },
    );
  }

  // ============================================================
  // SECTION HEADER com "Ver todos"
  // ============================================================

  Widget _sectionHeader(
    String title,
    int count,
    ThemeData theme,
    ColorScheme colors, {
    bool showViewAll = false,
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ),
          const Spacer(),
          if (showViewAll)
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todos',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTER CHIP com badge de contagem
// ============================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.colors,
    required this.theme,
  });
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.12)
              : colors.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: active
                ? colors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.5),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? colors.primary.withValues(alpha: 0.15)
                      : colors.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
