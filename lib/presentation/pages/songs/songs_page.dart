import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/presentation/widgets/song_tile/song_tile.dart';
import 'package:constanza_player/presentation/widgets/song_tile/playlist_selector_bottom_sheet.dart';
import 'package:constanza_player/services/share_service.dart';

class SongsPage extends ConsumerStatefulWidget {
  const SongsPage({super.key});

  @override
  ConsumerState<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends ConsumerState<SongsPage> {
  final Set<String> _selectedIds = {};
  bool _selectMode = false;

  void _enterSelectMode(Song song) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectMode = true;
      _selectedIds.add(song.id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSong(Song song) {
    setState(() {
      if (_selectedIds.contains(song.id)) {
        _selectedIds.remove(song.id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(song.id);
      }
    });
  }

  void _selectAll(List<Song> songs) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIds.addAll(songs.map((s) => s.id));
    });
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
  }

  List<Song> _getSelectedSongs(List<Song> songs) =>
      songs.where((s) => _selectedIds.contains(s.id)).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final libraryState = ref.watch(libraryProvider);
    final songs = libraryState.sortedSongs;
    final accentColor = ref.watch(artworkPaletteProvider)?.dominant;
    final l10n = AppLocalizations.of(context);

    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
    final hours = totalDur.inHours;
    final mins = totalDur.inMinutes.remainder(60);
    final durationLabel = hours > 0
        ? l10n.libraryHoursMinutes(hours, mins)
        : l10n.libraryMinutes(mins);

    final allSelected = _selectedIds.length == songs.length && songs.isNotEmpty;

    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: _selectMode ? 0 : 100,
              floating: true,
              snap: true,
              backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
              elevation: 0,
              leading: _selectMode
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.onSurface),
                      onPressed: _exitSelectMode,
                    )
                  : null,
              title: _selectMode
                  ? Text(
                      l10n.librarySelected(_selectedIds.length),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              actions: _selectMode
                  ? [
                      TextButton(
                        onPressed: allSelected
                            ? _deselectAll
                            : () => _selectAll(songs),
                        child: Text(
                          allSelected
                              ? l10n.commonDeselectAll
                              : l10n.commonSelectAll,
                          style: TextStyle(
                            color: accentColor ?? colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ]
                  : [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: colors.onSurface.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        onPressed: songs.isEmpty
                            ? null
                            : () => ref
                                  .read(playerProvider.notifier)
                                  .playSong(
                                    songs.first,
                                    queue: songs,
                                    shuffle: true,
                                  ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          color: colors.onSurface.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        onPressed: () => _showViewOptionsSheet(context, ref),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
              flexibleSpace: _selectMode
                  ? null
                  : FlexibleSpaceBar(
                      expandedTitleScale: 1.0,
                      titlePadding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: 14,
                      ),
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.librarySectionLibrary,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.35),
                              letterSpacing: 1.2,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.librarySectionMusic,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w200,
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    l10n.libraryNoSongs,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.librarySongsAndDuration(
                          songs.length,
                          durationLabel,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      if (!_selectMode)
                        GestureDetector(
                          onTap: () => ref
                              .read(playerProvider.notifier)
                              .playSong(songs.first, queue: songs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: colors.primary.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.libraryPlayAll,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Divider(
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: colors.outline.withValues(alpha: 0.12),
                ),
              ),
              SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final isSelected = _selectedIds.contains(song.id);

                  if (_selectMode) {
                    return _SelectableSongTile(
                      song: song,
                      isSelected: isSelected,
                      accentColor: accentColor ?? colors.primary,
                      onTap: () => _toggleSong(song),
                    );
                  }

                  return _LongPressSongTile(
                    song: song,
                    songs: songs,
                    onLongPress: () => _enterSelectMode(song),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
        // ── Barra de ações no modo seleção ──
        bottomSheet: _selectMode && _selectedIds.isNotEmpty
            ? _SelectionActionBar(
                selectedSongs: _getSelectedSongs(songs),
                accentColor: accentColor ?? colors.primary,
                onDone: _exitSelectMode,
              )
            : null,
      ),
    );
  }

  void _showViewOptionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ViewOptionsSheet(),
    );
  }
}

// ── Tile normal com suporte a long-press para entrar em modo seleção ─────────

class _LongPressSongTile extends ConsumerWidget {
  const _LongPressSongTile({
    required this.song,
    required this.songs,
    required this.onLongPress,
  });

  final Song song;
  final List<Song> songs;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: SongTile(
        song: song,
        onTap: () =>
            ref.read(playerProvider.notifier).playSong(song, queue: songs),
      ),
    );
  }
}

// ── Tile com checkbox para modo seleção ───────────────────────────────────────

class _SelectableSongTile extends StatelessWidget {
  const _SelectableSongTile({
    required this.song,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final Song song;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : colors.outline.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            ArtworkImage.song(
              songId: song.numericId,
              size: 48,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isSelected ? accentColor : colors.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.artist} · ${song.album}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              song.durationFormatted,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barra de ações de seleção em baixo ────────────────────────────────────────

class _SelectionActionBar extends ConsumerWidget {
  const _SelectionActionBar({
    required this.selectedSongs,
    required this.accentColor,
    required this.onDone,
  });

  final List<Song> selectedSongs;
  final Color accentColor;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.outline.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionBtn(
                icon: Icons.play_arrow_rounded,
                label: l10n.songsActionPlay,
                color: accentColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(playerProvider.notifier)
                      .playSong(selectedSongs.first, queue: selectedSongs);
                  onDone();
                },
              ),
              _ActionBtn(
                icon: Icons.playlist_add_rounded,
                label: l10n.navPlaylists,
                color: accentColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _addToPlaylist(context, ref);
                },
              ),
              _ActionBtn(
                icon: Icons.share_outlined,
                label: l10n.songsActionShare,
                color: accentColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _shareSelected(context, ref);
                },
              ),
              _ActionBtn(
                icon: Icons.playlist_play_rounded,
                label: l10n.songsActionPlayNext,
                color: accentColor,
                onTap: () {
                  HapticFeedback.lightImpact();
                  for (final s in selectedSongs.reversed) {
                    ref.read(playerProvider.notifier).addNextInQueue(s);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${selectedSongs.length} música${selectedSongs.length != 1 ? 's' : ''} adicionada${selectedSongs.length != 1 ? 's' : ''} à fila',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  onDone();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addToPlaylist(BuildContext context, WidgetRef ref) {
    if (selectedSongs.isEmpty) return;
    if (selectedSongs.length == 1) {
      PlaylistSelectorBottomSheet.show(context, ref, selectedSongs.first);
      return;
    }
    // Para múltiplas músicas, adiciona à playlist selecionada via sheet customizado
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _MultiAddToPlaylistSheet(songs: selectedSongs, onDone: onDone),
    );
  }

  Future<void> _shareSelected(BuildContext context, WidgetRef ref) async {
    if (selectedSongs.isEmpty) return;
    final palette = ref.read(artworkPaletteProvider);
    await ShareService.shareSongs(
      context: context,
      songs: selectedSongs,
      palette: palette,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.65),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet para adicionar múltiplas músicas a uma playlist ─────────────────────

class _MultiAddToPlaylistSheet extends ConsumerWidget {
  const _MultiAddToPlaylistSheet({required this.songs, required this.onDone});

  final List<Song> songs;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final playlists = ref.watch(playlistProvider);
    final userPlaylists = playlists
        .where((p) => p.id != 'fav' && p.id != 'recent' && p.id != 'most')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Adicionar ${songs.length} músicas a…',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Divider(color: colors.outline.withValues(alpha: 0.12)),
          if (userPlaylists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Sem playlists criadas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            )
          else
            ...userPlaylists.map(
              (pl) => ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(pl.name),
                subtitle: Text('${pl.songs.length} músicas'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  for (final s in songs) {
                    ref
                        .read(playlistProvider.notifier)
                        .addSongToPlaylist(pl.id, s);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${songs.length} músicas adicionadas a ${pl.name}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  onDone();
                },
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── View Options Sheet ────────────────────────────────────────────────────────

class _ViewOptionsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ViewOptionsSheet> createState() => _ViewOptionsSheetState();
}

class _ViewOptionsSheetState extends ConsumerState<_ViewOptionsSheet> {
  bool _filterExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final libraryState = ref.watch(libraryProvider);
    final accentColor = ref.watch(artworkPaletteProvider)?.dominant;
    final current = libraryState.sortOrder;
    final minDur = libraryState.minTrackDurationSec;
    final filterEnabled = minDur > 0;
    final activeColor = accentColor ?? colors.primary;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionLabel('DENSIDADE', theme, colors),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  for (final d in ListDensity.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _DensityChip(
                          density: d,
                          selected: themeState.listDensity == d,
                          colors: colors,
                          theme: theme,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setListDensity(d),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.outline.withValues(alpha: 0.12)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Capa do álbum', style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  'Mostrar thumbnail nas músicas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                secondary: Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
                value: themeState.showAlbumArtInList,
                onChanged: (_) =>
                    ref.read(themeProvider.notifier).toggleAlbumArtInList(),
                activeThumbColor: accentColor ?? colors.primary,
                activeTrackColor: accentColor?.withValues(alpha: 0.3),
                trackOutlineColor: WidgetStatePropertyAll(
                  colors.onSurface.withValues(alpha: 0.15),
                ),
              ),
              Divider(color: colors.outline.withValues(alpha: 0.12)),
              // ── Filtro de músicas curtas (painel expansível) ──
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _filterExpanded || filterEnabled,
                  onExpansionChanged: (v) =>
                      setState(() => _filterExpanded = v),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  leading: Icon(
                    Icons.filter_list_rounded,
                    size: 22,
                    color: filterEnabled
                        ? activeColor
                        : colors.onSurface.withValues(alpha: 0.5),
                  ),
                  title: Text(
                    'Filtrar músicas curtas',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    filterEnabled
                        ? 'Ocultar faixas menores que ${minDur}s'
                        : 'Desativado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            filterEnabled ? '${minDur}s' : 'Off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: filterEnabled
                                  ? activeColor
                                  : colors.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: activeColor,
                              thumbColor: activeColor,
                              overlayColor: activeColor.withValues(alpha: 0.15),
                            ),
                            child: Slider(
                              value: minDur.toDouble().clamp(0, 120),
                              min: 0,
                              max: 120,
                              divisions: 24,
                              label: minDur == 0 ? 'Desativado' : '${minDur}s',
                              onChanged: (v) => ref
                                  .read(libraryProvider.notifier)
                                  .setMinTrackDuration(v.round()),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '120s',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: colors.outline.withValues(alpha: 0.12)),
              _SectionLabel('ORDENAÇÃO', theme, colors),
              const SizedBox(height: AppSpacing.xs),
              for (final order in SortOrder.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _iconFor(order),
                    size: 22,
                    color: order == current
                        ? (accentColor ?? colors.primary)
                        : colors.onSurface.withValues(alpha: 0.5),
                  ),
                  title: Text(
                    _labelFor(order),
                    style: TextStyle(
                      color: order == current
                          ? (accentColor ?? colors.primary)
                          : colors.onSurface,
                      fontWeight: order == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: order == current
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: accentColor ?? colors.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(libraryProvider.notifier).setSortOrder(order);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SortOrder o) => switch (o) {
    SortOrder.title => Icons.sort_by_alpha_rounded,
    SortOrder.artist => Icons.person_rounded,
    SortOrder.album => Icons.album_rounded,
    SortOrder.dateAdded => Icons.schedule_rounded,
    SortOrder.duration => Icons.timer_outlined,
  };

  String _labelFor(SortOrder o) => switch (o) {
    SortOrder.title => 'Título',
    SortOrder.artist => 'Artista',
    SortOrder.album => 'Álbum',
    SortOrder.dateAdded => 'Data adicionada',
    SortOrder.duration => 'Duração',
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.theme, this.colors);
  final String text;
  final ThemeData theme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.35),
      letterSpacing: 1.5,
    ),
  );
}

class _DensityChip extends StatelessWidget {
  const _DensityChip({
    required this.density,
    required this.selected,
    required this.colors,
    required this.theme,
    required this.onTap,
  });
  final ListDensity density;
  final bool selected;
  final ColorScheme colors;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (density) {
      ListDensity.compact => 'Compacto',
      ListDensity.normal => 'Normal',
      ListDensity.comfortable => 'Confortável',
    };
    final icon = switch (density) {
      ListDensity.compact => Icons.density_small_rounded,
      ListDensity.normal => Icons.density_medium_rounded,
      ListDensity.comfortable => Icons.density_large_rounded,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.onSurface.withValues(alpha: 0.08)
              : colors.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected
                ? colors.onSurface.withValues(alpha: 0.4)
                : colors.outline.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.4),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
