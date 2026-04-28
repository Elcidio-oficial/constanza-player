import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/presentation/widgets/artwork_image.dart';
import 'package:constanza_player/services/media_tag_service.dart';
import 'package:constanza_player/services/metadata_service.dart';
import 'package:go_router/go_router.dart';

enum _SearchState { idle, searching, found, notFound, error, applied }

class SongEditPage extends ConsumerStatefulWidget {
  const SongEditPage({super.key, required this.song});
  final Song song;

  @override
  ConsumerState<SongEditPage> createState() => _SongEditPageState();
}

class _SongEditPageState extends ConsumerState<SongEditPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _composerCtrl;
  late TextEditingController _trackCtrl;

  _SearchState _searchState = _SearchState.idle;
  List<MetadataResult> _searchResults = [];
  MetadataResult? _selectedResult;
  bool _hasChanges = false;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _artistCtrl = TextEditingController(text: widget.song.artist);
    _albumCtrl = TextEditingController(text: widget.song.album);
    _genreCtrl = TextEditingController(text: widget.song.genre ?? '');
    _composerCtrl = TextEditingController(text: widget.song.composer ?? '');
    _trackCtrl = TextEditingController(
      text: widget.song.trackNumber?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    _composerCtrl.dispose();
    _trackCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMetadata() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() {
        _searchState = _SearchState.error;
        _errorMessage = 'Digite o título da música para buscar';
      });
      return;
    }

    setState(() => _searchState = _SearchState.searching);
    try {
      var results = await MetadataService.searchAll(
        title,
        _artistCtrl.text.trim(),
      );
      if (results.isEmpty) {
        results = await MetadataService.searchByTitleAll(title);
      }
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchState = results.isEmpty
            ? _SearchState.notFound
            : _SearchState.found;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchState = _SearchState.error;
        _errorMessage = 'Sem conexão à internet';
      });
    }
  }

  void _applyResult(MetadataResult result) {
    setState(() {
      _selectedResult = result;
      _titleCtrl.text = result.title;
      _artistCtrl.text = result.artist;
      _albumCtrl.text = result.album ?? '';
      _genreCtrl.text = result.genre ?? '';
      _trackCtrl.text = result.trackNumber?.toString() ?? '';
      _hasChanges = true;
      _searchState = _SearchState.applied;
      _searchResults = [];
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    final album = _albumCtrl.text.trim();
    final genre = _genreCtrl.text.trim();
    final composer = _composerCtrl.text.trim();
    final trackNumber = int.tryParse(_trackCtrl.text.trim());

    // Download cover art bytes if available from search result
    Uint8List? coverBytes;
    if (_selectedResult?.coverUrl != null) {
      try {
        final response = await http
            .get(Uri.parse(_selectedResult!.coverUrl!))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          coverBytes = response.bodyBytes;
        }
      } catch (_) {
        // Cover download failed — continue without it
      }
    }

    // Atualiza estado in-app e cache PRIMEIRO — independente do resultado da escrita no arquivo
    final updatedSong = widget.song.copyWith(
      title: title,
      artist: artist,
      album: album,
      genre: genre.isEmpty ? null : genre,
      composer: composer.isEmpty ? null : composer,
      trackNumber: trackNumber,
    );

    await ref.read(libraryProvider.notifier).updateSong(updatedSong);

    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong?.id == widget.song.id) {
      ref.read(playerProvider.notifier).updateCurrentSongMetadata(updatedSong);
    }

    // Tenta gravar tags no arquivo real do dispositivo
    bool tagWritten = false;
    if (widget.song.filePath.isNotEmpty) {
      tagWritten = await MediaTagService.writeTags(
        filePath: widget.song.filePath,
        title: title,
        artist: artist,
        album: album.isEmpty ? null : album,
        genre: genre.isEmpty ? null : genre,
        composer: composer.isEmpty ? null : composer,
        trackNumber: trackNumber,
        coverBytes: coverBytes,
      );
    }

    // Se a capa foi escrita com sucesso, invalida o cache de artwork para forçar re-fetch
    if (tagWritten && coverBytes != null) {
      ref
          .read(artworkProvider.notifier)
          .invalidateArtwork(widget.song.numericId);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (widget.song.filePath.isNotEmpty && !tagWritten) {
      // Estado in-app salvo mas arquivo físico não foi modificado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Salvo no app — arquivo físico não pôde ser modificado',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Metadados gravados no arquivo'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    context.pop();
  }

  Future<void> _deleteSong() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir música'),
        content: Text(
          'Deseja excluir "${widget.song.title}" do dispositivo?\n\nEssa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final deleted = await MediaTagService.deleteSong(
      filePath: widget.song.filePath,
      songId: widget.song.numericId,
    );

    if (!mounted) return;
    if (deleted) {
      ref.read(libraryProvider.notifier).removeSong(widget.song.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Música excluída do dispositivo'),
          backgroundColor: Colors.red,
        ),
      );
      context.pop(true); // true = deleted
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível excluir a música'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Editar Música'),
        actions: [
          if (_hasChanges)
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Artwork ──
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: _selectedResult?.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _selectedResult!.coverUrl!,
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artworkPlaceholder(colors),
                          errorWidget: (_, __, ___) => _localArtwork(),
                        )
                      : _localArtwork(),
                ),
                if (_searchState == _SearchState.applied)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Search Button ──
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _searchState == _SearchState.searching
                  ? null
                  : _searchMetadata,
              icon: _searchState == _SearchState.searching
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(switch (_searchState) {
                _SearchState.idle => 'Buscar na Internet',
                _SearchState.searching => 'Buscando...',
                _SearchState.found => 'Buscar novamente',
                _SearchState.notFound => 'Tentar novamente',
                _SearchState.error => 'Tentar novamente',
                _SearchState.applied => 'Buscar novamente',
              }),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Search feedback ──
          _buildSearchFeedback(colors, theme),

          const SizedBox(height: AppSpacing.sm),

          // ── Search results ──
          if (_searchResults.isNotEmpty) ...[
            _buildResultsSection(colors, theme),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Edit fields ──
          _buildField(
            'Título',
            _titleCtrl,
            Icons.music_note_rounded,
            colors,
            theme,
          ),
          _buildField(
            'Artista',
            _artistCtrl,
            Icons.person_rounded,
            colors,
            theme,
          ),
          _buildField('Álbum', _albumCtrl, Icons.album_rounded, colors, theme),
          _buildField(
            'Gênero',
            _genreCtrl,
            Icons.category_rounded,
            colors,
            theme,
          ),
          _buildField(
            'Compositor',
            _composerCtrl,
            Icons.edit_rounded,
            colors,
            theme,
          ),
          _buildField(
            'Faixa',
            _trackCtrl,
            Icons.tag_rounded,
            colors,
            theme,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── File info ──
          _buildFileInfo(colors, theme),

          const SizedBox(height: AppSpacing.lg),

          // ── Delete button ──
          if (widget.song.filePath.isNotEmpty)
            Center(
              child: TextButton.icon(
                onPressed: _deleteSong,
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Excluir música do dispositivo'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _localArtwork() => ArtworkImage.song(
    songId: widget.song.numericId,
    size: 180,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
  );

  Widget _artworkPlaceholder(ColorScheme colors) => Container(
    width: 180,
    height: 180,
    color: colors.surfaceContainerHighest,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  // ── Search state feedback banner ──
  Widget _buildSearchFeedback(ColorScheme colors, ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_searchState) {
        _SearchState.idle => const SizedBox.shrink(),
        _SearchState.searching => _feedbackBanner(
          key: const ValueKey('searching'),
          icon: Icons.hourglass_top_rounded,
          color: colors.primary.withValues(alpha: 0.1),
          iconColor: colors.primary,
          text: 'Pesquisando em MusicBrainz e iTunes...',
          theme: theme,
          colors: colors,
        ),
        _SearchState.found => _feedbackBanner(
          key: const ValueKey('found'),
          icon: Icons.check_circle_rounded,
          color: Colors.green.withValues(alpha: 0.1),
          iconColor: Colors.green.shade400,
          text:
              '${_searchResults.length} resultado${_searchResults.length != 1 ? 's' : ''} encontrado${_searchResults.length != 1 ? 's' : ''}',
          subtitle: _buildSourcesSummary(),
          theme: theme,
          colors: colors,
        ),
        _SearchState.notFound => _feedbackBanner(
          key: const ValueKey('notFound'),
          icon: Icons.search_off_rounded,
          color: Colors.orange.withValues(alpha: 0.1),
          iconColor: Colors.orange.shade400,
          text: 'Nenhum resultado encontrado',
          subtitle: 'Tente editar o título ou artista e buscar novamente',
          theme: theme,
          colors: colors,
        ),
        _SearchState.error => _feedbackBanner(
          key: const ValueKey('error'),
          icon: Icons.wifi_off_rounded,
          color: colors.error.withValues(alpha: 0.1),
          iconColor: colors.error,
          text: _errorMessage,
          theme: theme,
          colors: colors,
        ),
        _SearchState.applied => _feedbackBanner(
          key: const ValueKey('applied'),
          icon: Icons.auto_fix_high_rounded,
          color: Colors.green.withValues(alpha: 0.1),
          iconColor: Colors.green.shade400,
          text: 'Metadados aplicados com sucesso',
          subtitle: _selectedResult?.album != null
              ? '${_selectedResult!.artist} — ${_selectedResult!.album}'
              : _selectedResult?.artist ?? '',
          theme: theme,
          colors: colors,
        ),
      },
    );
  }

  Widget _feedbackBanner({
    required Key key,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required String text,
    String? subtitle,
    required ThemeData theme,
    required ColorScheme colors,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
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

  String _buildSourcesSummary() {
    final mbCount = _searchResults
        .where((r) => r.source == MetadataSource.musicBrainz)
        .length;
    final itCount = _searchResults
        .where((r) => r.source == MetadataSource.iTunes)
        .length;
    final parts = <String>[];
    if (mbCount > 0) parts.add('$mbCount MusicBrainz');
    if (itCount > 0) parts.add('$itCount iTunes');
    return '${parts.join(' · ')} — toque para aplicar';
  }

  // ── Results list ──
  Widget _buildResultsSection(ColorScheme colors, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colors.outline.withValues(alpha: 0.08)),
        itemBuilder: (ctx, i) {
          final r = _searchResults[i];
          return ListTile(
            dense: true,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              child: r.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: r.coverUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 44,
                        height: 44,
                        color: colors.outline.withValues(alpha: 0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _resultFallbackIcon(colors),
                    )
                  : _resultFallbackIcon(colors),
            ),
            title: Text(
              r.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: r.source == MetadataSource.iTunes
                        ? Colors.pink.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    r.sourceLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: r.source == MetadataSource.iTunes
                          ? Colors.pink.shade300
                          : Colors.blue.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    [
                      r.artist,
                      if (r.album != null) r.album!,
                      if (r.releaseDate != null && r.releaseDate!.length >= 4)
                        r.releaseDate!.substring(0, 4),
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'Aplicar',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: () => _applyResult(r),
          );
        },
      ),
    );
  }

  Widget _resultFallbackIcon(ColorScheme colors) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: colors.outline.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
    ),
    child: Icon(
      Icons.album_rounded,
      size: 22,
      color: colors.onSurface.withValues(alpha: 0.3),
    ),
  );

  // ── Edit fields ──
  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon,
    ColorScheme colors,
    ThemeData theme, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        onChanged: (_) {
          if (!_hasChanges) setState(() => _hasChanges = true);
          // Reset applied state if user edits after applying
          if (_searchState == _SearchState.applied) {
            setState(() => _searchState = _SearchState.idle);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(
              color: colors.outline.withValues(alpha: 0.15),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(
              color: colors.outline.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }

  // ── File info ──
  Widget _buildFileInfo(ColorScheme colors, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações do Arquivo',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: [
              _infoRow('Duração', widget.song.durationFormatted, colors, theme),
              if (widget.song.filePath.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                _infoRow(
                  'Formato',
                  widget.song.filePath.split('.').last.toUpperCase(),
                  colors,
                  theme,
                ),
                const SizedBox(height: AppSpacing.xs),
                _infoRow('Caminho', widget.song.filePath, colors, theme),
              ],
              if (widget.song.dateAdded != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _infoRow(
                  'Adicionado',
                  _formatDate(widget.song.dateAdded!),
                  colors,
                  theme,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value,
    ColorScheme colors,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
