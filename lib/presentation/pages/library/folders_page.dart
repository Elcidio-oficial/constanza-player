import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/core/utils/background_helper.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';

/// Página de gestão de Pastas de Música da Biblioteca.
///
/// Nível 1 — lista de pastas com checkbox: seleciona quais pastas
///            são incluídas no scan da biblioteca.
/// Nível 2 — ao entrar numa pasta, lista as músicas com checkbox
///            individual: permite excluir músicas específicas do scan.
class FoldersPage extends ConsumerStatefulWidget {
  const FoldersPage({super.key});

  @override
  ConsumerState<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends ConsumerState<FoldersPage> {
  // Cópias locais dos conjuntos (editáveis antes de confirmar)
  late Set<String> _selectedFolders;
  late Set<String> _excludedSongIds;

  // Músicas brutas agrupadas por pasta (de allScannedSongs)
  Map<String, List<Song>> _folderSongs = {};
  bool _loading = false;

  bool _dirty = false; // tem alterações não salvas?

  @override
  void initState() {
    super.initState();
    final lib = ref.read(libraryProvider);
    _selectedFolders = Set<String>.from(lib.selectedFolders);
    _excludedSongIds = Set<String>.from(lib.excludedSongIds);
    _buildFolderMap();
    // Se _allScannedSongs estiver vazio (carregou do cache), descobre as pastas
    if (ref.read(libraryProvider.notifier).allScannedSongs.isEmpty) {
      _discoverFolders();
    }
  }

  void _buildFolderMap() {
    final all = ref.read(libraryProvider.notifier).allScannedSongs;
    final map = <String, List<Song>>{};
    for (final s in all) {
      final folder = s.folderPath.isEmpty ? 'Pasta desconhecida' : s.folderPath;
      map.putIfAbsent(folder, () => []).add(s);
    }
    _folderSongs = map;
  }

  Future<void> _discoverFolders() async {
    setState(() => _loading = true);
    await ref.read(libraryProvider.notifier).discoverFolders();
    _buildFolderMap();
    setState(() => _loading = false);
  }

  /// Número de músicas incluídas em [folder] (não excluídas).
  int _includedCount(String folder) {
    final songs = _folderSongs[folder] ?? [];
    return songs.where((s) => !_excludedSongIds.contains(s.id)).length;
  }

  /// Estado do checkbox da pasta:
  /// - true  = pasta selecionada e pelo menos 1 música incluída
  /// - false = pasta não selecionada
  /// - null  = pasta selecionada mas todas as músicas excluídas individualmente
  bool? _folderCheckState(String folder) {
    if (!_selectedFolders.contains(folder)) return false;
    final total = (_folderSongs[folder] ?? []).length;
    final included = _includedCount(folder);
    if (included == 0) return null; // tristate: pasta on mas sem músicas
    if (included < total) return null; // tristate: parcialmente incluída
    return true;
  }

  void _toggleFolder(String folder) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedFolders.contains(folder)) {
        _selectedFolders.remove(folder);
      } else {
        _selectedFolders.add(folder);
      }
      _dirty = true;
    });
  }

  Future<void> _applyChanges() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);

    // 1. Salvar exclusões individuais
    await ref.read(libraryProvider.notifier).setExcludedSongs(_excludedSongIds);
    // 2. Salvar pastas selecionadas e re-escanear
    await ref
        .read(libraryProvider.notifier)
        .setSelectedFolders(_selectedFolders.toList());

    if (mounted) {
      setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Biblioteca atualizada'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final allFolders = ref.watch(libraryProvider.select((s) => s.allFolders));

    // Se ainda não descobriu as pastas, usa as que já conhece
    final folders =
        allFolders.isNotEmpty ? allFolders : _folderSongs.keys.toList()
          ..sort();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showDiscardDialog();
      },
      child: Scaffold(
        backgroundColor: BackgroundHelper.scaffoldColor(colors, themeState),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              floating: false,
              pinned: true,
              backgroundColor: BackgroundHelper.appBarColor(colors, themeState),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_dirty) {
                    _showDiscardDialog();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              actions: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _applyChanges,
                    child: Text(
                      'Aplicar',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
              ],
              flexibleSpace: FlexibleSpaceBar(
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
                      'BIBLIOTECA',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.35),
                        letterSpacing: 1.2,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pastas de Músicas',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w200,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Banner informativo ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Selecione as pastas e, opcionalmente, entre em cada pasta para escolher músicas específicas. Toque em "Aplicar" para atualizar a biblioteca.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_loading && folders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'A descobrir pastas…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (folders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        size: 48,
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Nenhuma pasta encontrada',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: _discoverFolders,
                        child: const Text('Procurar pastas'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    '${folders.length} pasta${folders.length != 1 ? 's' : ''} · ${_selectedFolders.length} selecionada${_selectedFolders.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
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
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final checkState = _folderCheckState(folder);
                  final songs = _folderSongs[folder] ?? [];
                  final included = _includedCount(folder);
                  final total = songs.length;

                  return _FolderTile(
                    folderPath: folder,
                    songs: songs,
                    checkState: checkState,
                    includedCount: included,
                    totalCount: total,
                    onToggle: () => _toggleFolder(folder),
                    onEnter: () => _openFolderSongs(folder, songs),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),

        // ── Botão flutuante de confirmação ──
        floatingActionButton: _dirty
            ? FloatingActionButton.extended(
                onPressed: _applyChanges,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aplicar alterações'),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              )
            : null,
      ),
    );
  }

  void _openFolderSongs(String folder, List<Song> songs) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FolderSongsSelectionPage(
          folderPath: folder,
          songs: songs,
          excludedSongIds: Set<String>.from(_excludedSongIds),
          isFolderSelected: _selectedFolders.contains(folder),
          onChanged: (excluded, folderSelected) {
            setState(() {
              // Sincroniza exclusões retornadas
              // Remove exclusões antigas desta pasta e adiciona as novas
              final folderIds = songs.map((s) => s.id).toSet();
              _excludedSongIds.removeAll(folderIds);
              _excludedSongIds.addAll(excluded);
              // Sincroniza seleção da pasta
              if (folderSelected) {
                _selectedFolders.add(folder);
              } else {
                _selectedFolders.remove(folder);
              }
              _dirty = true;
            });
          },
        ),
      ),
    );
  }

  Future<void> _showDiscardDialog() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('Tens alterações não guardadas. Sair sem aplicar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ── Tile de pasta (nível 1) ───────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folderPath,
    required this.songs,
    required this.checkState,
    required this.includedCount,
    required this.totalCount,
    required this.onToggle,
    required this.onEnter,
  });

  final String folderPath;
  final List<Song> songs;
  final bool? checkState; // null = parcial
  final int includedCount;
  final int totalCount;
  final VoidCallback onToggle;
  final VoidCallback onEnter;

  String get _folderName {
    if (folderPath == 'Pasta desconhecida') return folderPath;
    final parts = folderPath.split('/');
    return parts.last.isEmpty && parts.length > 1
        ? parts[parts.length - 2]
        : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSelected = checkState != false;
    final isPartial = checkState == null;

    return InkWell(
      onTap: onEnter,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Checkbox da pasta
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isSelected ? colors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : colors.outline.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          isPartial
                              ? Icons.remove_rounded
                              : Icons.check_rounded,
                          size: 14,
                          color: colors.onPrimary,
                        )
                      : null,
                ),
              ),
            ),

            // Mosaico das capas
            _FolderMosaic(songs: songs),
            const SizedBox(width: AppSpacing.sm),

            // Info da pasta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _folderName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    folderPath == 'Pasta desconhecida' ? '' : folderPath,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Contador incluídas / total
                  Row(
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 11,
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.7)
                            : colors.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        includedCount == totalCount
                            ? '$totalCount música${totalCount != 1 ? 's' : ''}'
                            : '$includedCount / $totalCount música${totalCount != 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colors.primary.withValues(alpha: 0.7)
                              : colors.onSurface.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Seta para entrar na pasta
            GestureDetector(
              onTap: onEnter,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mosaico 2×2 das capas da pasta ───────────────────────────────────────────

class _FolderMosaic extends StatelessWidget {
  const _FolderMosaic({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const size = 52.0;
    const half = size / 2 - 0.75;

    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(
          Icons.folder_rounded,
          color: colors.onSurface.withValues(alpha: 0.3),
          size: 26,
        ),
      );
    }

    if (songs.length == 1) {
      return ArtworkImage.song(
        songId: songs[0].numericId,
        size: size,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      );
    }

    final picks = songs.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(
              children: [
                ArtworkImage.song(
                  songId: picks[0].numericId,
                  size: half,
                  borderRadius: BorderRadius.zero,
                ),
                const SizedBox(width: 1.5),
                ArtworkImage.song(
                  songId: picks.length > 1
                      ? picks[1].numericId
                      : picks[0].numericId,
                  size: half,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
            const SizedBox(height: 1.5),
            Row(
              children: [
                ArtworkImage.song(
                  songId: picks.length > 2
                      ? picks[2].numericId
                      : picks[0].numericId,
                  size: half,
                  borderRadius: BorderRadius.zero,
                ),
                const SizedBox(width: 1.5),
                ArtworkImage.song(
                  songId: picks.length > 3
                      ? picks[3].numericId
                      : picks[0].numericId,
                  size: half,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Página de músicas de uma pasta (nível 2) ──────────────────────────────────

class _FolderSongsSelectionPage extends StatefulWidget {
  const _FolderSongsSelectionPage({
    required this.folderPath,
    required this.songs,
    required this.excludedSongIds,
    required this.isFolderSelected,
    required this.onChanged,
  });

  final String folderPath;
  final List<Song> songs;
  final Set<String> excludedSongIds; // cópia local
  final bool isFolderSelected;
  final void Function(Set<String> excluded, bool folderSelected) onChanged;

  @override
  State<_FolderSongsSelectionPage> createState() =>
      _FolderSongsSelectionPageState();
}

class _FolderSongsSelectionPageState extends State<_FolderSongsSelectionPage> {
  late Set<String> _excluded;
  late bool _folderSelected;

  @override
  void initState() {
    super.initState();
    _excluded = Set<String>.from(widget.excludedSongIds);
    _folderSelected = widget.isFolderSelected;
  }

  bool _isIncluded(Song song) => !_excluded.contains(song.id);

  void _toggleSong(Song song) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_excluded.contains(song.id)) {
        _excluded.remove(song.id);
      } else {
        _excluded.add(song.id);
      }
    });
    widget.onChanged(_excluded, _folderSelected);
  }

  void _selectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      final ids = widget.songs.map((s) => s.id).toSet();
      _excluded.removeAll(ids);
    });
    widget.onChanged(_excluded, _folderSelected);
  }

  void _deselectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final s in widget.songs) {
        _excluded.add(s.id);
      }
    });
    widget.onChanged(_excluded, _folderSelected);
  }

  void _toggleFolder() {
    HapticFeedback.mediumImpact();
    setState(() => _folderSelected = !_folderSelected);
    widget.onChanged(_excluded, _folderSelected);
  }

  String get _folderName {
    if (widget.folderPath == 'Pasta desconhecida') return widget.folderPath;
    final parts = widget.folderPath.split('/');
    return parts.last.isEmpty && parts.length > 1
        ? parts[parts.length - 2]
        : parts.last;
  }

  int get _includedCount =>
      widget.songs.where((s) => !_excluded.contains(s.id)).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allIncluded = _includedCount == widget.songs.length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _folderName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$_includedCount / ${widget.songs.length} incluída${widget.songs.length != 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: allIncluded ? _deselectAll : _selectAll,
            child: Text(
              allIncluded ? 'Desmarcar tudo' : 'Selecionar tudo',
              style: TextStyle(color: colors.primary, fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Tile da pasta (toggle para incluir/excluir a pasta inteira) ──
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            decoration: BoxDecoration(
              color: _folderSelected
                  ? colors.primary.withValues(alpha: 0.08)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _folderSelected
                    ? colors.primary.withValues(alpha: 0.25)
                    : colors.outline.withValues(alpha: 0.15),
              ),
            ),
            child: ListTile(
              onTap: _toggleFolder,
              leading: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _folderSelected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: _folderSelected
                        ? colors.primary
                        : colors.outline.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: _folderSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: colors.onPrimary,
                      )
                    : null,
              ),
              title: Text(
                'Incluir pasta no scan',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _folderSelected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              subtitle: Text(
                widget.folderPath,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // ── Separador ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Divider(color: colors.outline.withValues(alpha: 0.15)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    'MÚSICAS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.3),
                      letterSpacing: 1.2,
                      fontSize: 9,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: colors.outline.withValues(alpha: 0.15)),
                ),
              ],
            ),
          ),

          // ── Lista de músicas com checkbox ──
          Expanded(
            child: widget.songs.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma música nesta pasta',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.songs.length,
                    itemBuilder: (ctx, i) {
                      final song = widget.songs[i];
                      final included = _isIncluded(song);
                      return _SongCheckTile(
                        song: song,
                        included: included,
                        folderActive: _folderSelected,
                        onToggle: () => _toggleSong(song),
                      );
                    },
                  ),
          ),

          // ── Aviso quando pasta desativada ──
          if (!_folderSelected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: colors.errorContainer.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'A pasta está desativada — as músicas não serão incluídas mesmo que estejam marcadas.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
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

// ── Tile de música com checkbox (nível 2) ─────────────────────────────────────

class _SongCheckTile extends StatelessWidget {
  const _SongCheckTile({
    required this.song,
    required this.included,
    required this.folderActive,
    required this.onToggle,
  });

  final Song song;
  final bool included;
  final bool folderActive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final effectivelyIncluded = included && folderActive;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            // Checkbox circular
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectivelyIncluded
                    ? colors.primary
                    : Colors.transparent,
                border: Border.all(
                  color: effectivelyIncluded
                      ? colors.primary
                      : colors.outline.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: effectivelyIncluded
                  ? Icon(Icons.check_rounded, size: 13, color: colors.onPrimary)
                  : null,
            ),

            // Artwork
            ArtworkImage.song(
              songId: song.numericId,
              size: 46,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: effectivelyIncluded
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.artist} · ${song.album}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
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
