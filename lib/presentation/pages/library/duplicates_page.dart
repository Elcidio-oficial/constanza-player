import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:go_router/go_router.dart';

/// Página para detectar e remover músicas duplicadas.
class DuplicatesPage extends ConsumerStatefulWidget {
  const DuplicatesPage({super.key});

  @override
  ConsumerState<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends ConsumerState<DuplicatesPage> {
  // Para cada grupo (índice), qual songId manter (null = manter o primeiro/padrão)
  final Map<int, String> _keepMap = {};
  List<List<Song>> _groups = [];
  bool _isLoading = false;
  bool _isScanning = true;
  // IDs selecionados pelo usuário para deleção (overrides automático)
  final Set<String> _manualDeleteIds = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() {
    setState(() => _isScanning = true);
    // Roda no próximo frame para não bloquear a animação de entrada
    Future.microtask(() {
      final groups = ref.read(libraryProvider.notifier).findDuplicates();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isScanning = false;
        _keepMap.clear();
        _manualDeleteIds.clear();
      });
    });
  }

  /// Retorna o songId que será mantido para um grupo.
  /// Default: primeiro da lista (maior duração).
  String _keepIdFor(int groupIdx) {
    return _keepMap[groupIdx] ?? _groups[groupIdx].first.id;
  }

  /// Total de músicas que serão removidas.
  int get _totalToDelete {
    int count = 0;
    for (int i = 0; i < _groups.length; i++) {
      count += _groups[i].where((s) => s.id != _keepIdFor(i)).length;
    }
    return count;
  }

  /// Constrói a lista de Songs a serem deletadas.
  List<Song> _buildDeleteList() {
    final toDelete = <Song>[];
    for (int i = 0; i < _groups.length; i++) {
      final keepId = _keepIdFor(i);
      toDelete.addAll(_groups[i].where((s) => s.id != keepId));
    }
    return toDelete;
  }

  Future<void> _removeSelected() async {
    final toDelete = _buildDeleteList();
    if (toDelete.isEmpty) return;

    final confirmed = await _showConfirmDialog(toDelete.length);
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    final results = await ref
        .read(libraryProvider.notifier)
        .removeSongs(toDelete);

    if (!mounted) return;
    setState(() => _isLoading = false);

    final successCount = results.values.where((v) => v).length;
    final failCount = results.values.where((v) => !v).length;

    if (mounted) {
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? '$successCount música${successCount != 1 ? 's' : ''} removida${successCount != 1 ? 's' : ''}'
                : '$successCount removida${successCount != 1 ? 's' : ''}, $failCount falhou (permissão negada)',
          ),
          backgroundColor: failCount == 0 ? colors.primary : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      );
      // Re-escaneia após remoção
      _scan();
    }
  }

  Future<bool> _showConfirmDialog(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final colors = Theme.of(ctx).colorScheme;
            return AlertDialog(
              title: const Text('Remover duplicadas'),
              content: Text(
                'Isso irá excluir $count música${count != 1 ? 's' : ''} do dispositivo permanentemente.\n\nAs músicas selecionadas para manter serão preservadas.',
              ),
              actions: [
                TextButton(
                  onPressed: () => ctx.pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => ctx.pop(true),
                  style: FilledButton.styleFrom(backgroundColor: colors.error),
                  child: const Text('Remover'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Músicas Duplicadas'),
        actions: [
          if (!_isScanning && _groups.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Re-escanear',
              onPressed: _scan,
            ),
        ],
      ),
      body: _isScanning
          ? _buildScanning(colors, theme)
          : _groups.isEmpty
          ? _buildEmpty(colors, theme)
          : _buildContent(colors, theme),
      bottomNavigationBar: (!_isScanning && _groups.isNotEmpty)
          ? _buildBottomBar(colors, theme)
          : null,
    );
  }

  Widget _buildScanning(ColorScheme colors, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Analisando biblioteca...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colors, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma duplicata encontrada',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sua biblioteca está organizada.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, ThemeData theme) {
    final totalDuplicateSongs = _groups.fold<int>(
      0,
      (sum, g) => sum + g.length,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildSummaryBanner(colors, theme, totalDuplicateSongs),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildGroup(ctx, i, colors, theme),
            childCount: _groups.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSummaryBanner(
    ColorScheme colors,
    ThemeData theme,
    int totalDuplicateSongs,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.copy_all_rounded,
            color: colors.onErrorContainer,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_groups.length} grupo${_groups.length != 1 ? 's' : ''} de duplicatas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$totalDuplicateSongs músicas — $_totalToDelete podem ser removidas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onErrorContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    BuildContext ctx,
    int groupIdx,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final group = _groups[groupIdx];
    final keepId = _keepIdFor(groupIdx);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${group.length} cópias',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    group.first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Songs in group
          ...group.asMap().entries.map((entry) {
            final idx = entry.key;
            final song = entry.value;
            final isKeep = song.id == keepId;
            final isLast = idx == group.length - 1;

            return _buildSongRow(
              song: song,
              isKeep: isKeep,
              isLast: isLast,
              groupIdx: groupIdx,
              colors: colors,
              theme: theme,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSongRow({
    required Song song,
    required bool isKeep,
    required bool isLast,
    required int groupIdx,
    required ColorScheme colors,
    required ThemeData theme,
  }) {
    final ext = song.filePath.isNotEmpty
        ? song.filePath.split('.').last.toUpperCase()
        : '?';
    final folderName = song.folderPath.isNotEmpty
        ? song.folderPath.split('/').last
        : 'Desconhecido';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: ArtworkImage.song(
                  songId: song.numericId,
                  size: 48,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Row(
                      children: [
                        _chip(
                          ext,
                          colors,
                          theme,
                          color: colors.primary.withValues(alpha: 0.12),
                          textColor: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        _chip(song.durationFormatted, colors, theme),
                        const SizedBox(width: 4),
                        Flexible(
                          child: _chip(
                            folderName,
                            colors,
                            theme,
                            maxWidth: 110,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Keep/delete indicator
              GestureDetector(
                onTap: () {
                  setState(() => _keepMap[groupIdx] = song.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isKeep
                        ? Colors.green.withValues(alpha: 0.15)
                        : colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: isKeep
                          ? Colors.green.withValues(alpha: 0.4)
                          : colors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isKeep
                            ? Icons.check_circle_rounded
                            : Icons.delete_outline_rounded,
                        size: 14,
                        color: isKeep
                            ? Colors.green.shade400
                            : colors.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isKeep ? 'Manter' : 'Remover',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isKeep
                              ? Colors.green.shade400
                              : colors.error.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: colors.outline.withValues(alpha: 0.06),
          ),
      ],
    );
  }

  Widget _chip(
    String label,
    ColorScheme colors,
    ThemeData theme, {
    Color? color,
    Color? textColor,
    double? maxWidth,
  }) {
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
      decoration: BoxDecoration(
        color: color ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: textColor ?? colors.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
    return chip;
  }

  Widget _buildBottomBar(ColorScheme colors, ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton.icon(
          onPressed: (_isLoading || _totalToDelete == 0)
              ? null
              : _removeSelected,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_sweep_rounded),
          label: Text(
            _isLoading
                ? 'Removendo...'
                : 'Remover $_totalToDelete duplicada${_totalToDelete != 1 ? 's' : ''}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _totalToDelete > 0 ? colors.error : null,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ),
    );
  }
}
