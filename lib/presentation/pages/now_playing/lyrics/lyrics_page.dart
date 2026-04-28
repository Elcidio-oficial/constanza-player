// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter
part of '../now_playing_page.dart';

class _LyricsPage extends ConsumerStatefulWidget {
  const _LyricsPage({required this.song});
  final Song song;

  @override
  ConsumerState<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<_LyricsPage> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastScrolledIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  static const _scrollCooldown = Duration(seconds: 5);

  bool _isSearching = false;

  /// Tamanho da fonte (3 níveis)
  double _baseFontSize = 22.0;
  static const _fontSizes = [18.0, 22.0, 28.0];
  static const _fontLabels = ['Pequena', 'Média', 'Grande'];
  int _fontIdx = 1;

  GlobalKey _keyFor(int idx) => _lineKeys.putIfAbsent(idx, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lyricsProvider.notifier).loadForSong(widget.song.id);
    });
  }

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ── Scroll inteligente ──────────────────────────────────────

  void _onUserScrollStart() {
    _userScrollTimer?.cancel();
    if (!_userIsScrolling) setState(() => _userIsScrolling = true);
  }

  void _onUserScrollEnd() {
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(_scrollCooldown, () {
      if (mounted) {
        setState(() => _userIsScrolling = false);
        _lastScrolledIndex = -1;
      }
    });
  }

  void _resumeAutoScroll() {
    _userScrollTimer?.cancel();
    setState(() {
      _userIsScrolling = false;
      _lastScrolledIndex = -1;
    });
  }

  void _scrollToLine(int idx) {
    if (idx < 0 || _userIsScrolling) return;
    if (idx == _lastScrolledIndex) return;
    _lastScrolledIndex = idx;

    final ctx = _lineKeys[idx]?.currentContext;
    if (ctx == null || !mounted) return;

    // alignment: 0.5 → centraliza o widget no viewport, independente da
    // altura variável da linha (fontes maiores ou texto que quebra).
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _cycleFontSize() {
    setState(() {
      _fontIdx = (_fontIdx + 1) % _fontSizes.length;
      _baseFontSize = _fontSizes[_fontIdx];
      _lastScrolledIndex = -1;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tamanho: ${_fontLabels[_fontIdx]}'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _seekToLine(Duration? ts) {
    if (ts == null) return;
    ref.read(playerProvider.notifier).seek(ts);
    _resumeAutoScroll();
  }

  void _copyLyrics(ColorScheme c) {
    final text = ref.read(lyricsProvider).lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Letras copiadas!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Busca online ────────────────────────────────────────────

  Future<void> _searchOnline() async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    try {
      // Sempre usar a música atual do player — não a que abriu a tela.
      final song = ref.read(playerProvider).currentSong ?? widget.song;
      // Garante que o lyricsProvider está vinculado a esta música
      // antes de importar (evita salvar letras na chave errada).
      await ref.read(lyricsProvider.notifier).loadForSong(song.id);
      final lines = await LyricsFetchService.fetch(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;
      if (lines != null && lines.isNotEmpty) {
        final notifier = ref.read(lyricsProvider.notifier);
        // Import synced lines and persist
        final lrcText = lines
            .where((l) => l.isSynced)
            .map((l) {
              final ts = l.timestamp!;
              final m = ts.inMinutes.remainder(60).toString().padLeft(2, '0');
              final s = ts.inSeconds.remainder(60).toString().padLeft(2, '0');
              final ms = (ts.inMilliseconds.remainder(1000) ~/ 10)
                  .toString()
                  .padLeft(2, '0');
              return '[$m:$s.$ms]${l.text}';
            })
            .join('\n');
        if (lrcText.isNotEmpty) {
          await notifier.importLrc(lrcText);
        } else {
          // Plain text lines — import as unsynchronized text
          final plainText = lines.map((l) => l.text).join('\n');
          await notifier.importPlainText(plainText);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lines.length} linhas encontradas!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nenhuma letra encontrada online'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro na busca: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseColors = baseTheme.colorScheme;
    final colors = baseColors.brightness == Brightness.dark
        ? baseColors
        : ColorScheme.dark(
            primary: baseColors.primary,
            onPrimary: baseColors.onPrimary,
            secondary: baseColors.secondary,
            tertiary: baseColors.tertiary,
            error: baseColors.error,
          );
    final theme = baseTheme.copyWith(colorScheme: colors);
    final lyrics = ref.watch(lyricsProvider);
    final position = ref.watch(playerProvider.select((s) => s.position));
    final curIdx = lyrics.currentLineIndex(position);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Song atual do player — se mudar (skip no mini player), recarrega letras.
    final currentSong =
        ref.watch(playerProvider.select((s) => s.currentSong)) ?? widget.song;
    final songId = currentSong.numericId;

    ref.listen<String?>(
      playerProvider.select((s) => s.currentSong?.id),
      (prev, next) {
        if (next != null && next != prev) {
          _lineKeys.clear();
          _lastScrolledIndex = -1;
          _userScrollTimer?.cancel();
          _userIsScrolling = false;
          ref.read(lyricsProvider.notifier).loadForSong(next);
        }
      },
    );

    // Auto-scroll no view mode
    if (!lyrics.isEditing && curIdx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToLine(curIdx),
      );
    }

    final Widget bodyContent = !lyrics.isLoaded
        ? const Center(child: CircularProgressIndicator())
        : lyrics.isEmpty && !lyrics.isEditing
        ? _EmptyLyrics(
            onAdd: () => ref.read(lyricsProvider.notifier).toggleEdit(),
            onImportLrc: () => _showImportDialog(context),
            onPasteText: () => _showPasteTextDialog(context),
            onSearchOnline: _searchOnline,
            isSearching: _isSearching,
            colors: colors,
            theme: theme,
          )
        : lyrics.isEditing
        ? _EditView(song: widget.song)
        : _LyricsViewMode(
            lines: lyrics.lines,
            currentIndex: curIdx,
            scroll: _scroll,
            baseFontSize: _baseFontSize,
            colors: colors,
            onSeek: _seekToLine,
            onUserScrollStart: _onUserScrollStart,
            onUserScrollEnd: _onUserScrollEnd,
            keyFor: _keyFor,
            horizontalPadding: isLandscape
                ? AppSpacing.xl
                : AppSpacing.lg,
            textAlign: isLandscape ? TextAlign.left : TextAlign.left,
          );

    // Em landscape, quebra body em Row: lado esquerdo (arte+info+mini controles),
    // lado direito (letras centradas). Não usa bottomNavigationBar.
    final Widget scaffoldBody = isLandscape && !lyrics.isEditing
        ? _LyricsLandscapeBody(
            song: currentSong,
            colors: colors,
            theme: theme,
            lyricsContent: bodyContent,
          )
        : bodyContent;

    return Theme(
      data: theme,
      child: BackgroundWrapper(
        child: Stack(
          children: [
            _BlurredArtworkBg(songId: songId, opacity: 0.35),
            Container(color: Colors.black.withValues(alpha: 0.5)),
            Scaffold(
              backgroundColor: Colors.transparent,
              // Mini-player só em portrait — landscape já mostra controles no pane
              bottomNavigationBar: (!isLandscape && !lyrics.isEditing)
                  ? const _LyricsMiniPlayer()
                  : null,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  onPressed: () => context.pop(),
                ),
                title: Column(
                  children: [
                    Text(
                      currentSong.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentSong.artist,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                actions: _buildActions(lyrics, colors),
              ),
              floatingActionButton: lyrics.isEditing
                  ? FloatingActionButton(
                      mini: true,
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      onPressed: () => _showAddLineDialog(context),
                      child: const Icon(Icons.add_rounded),
                    )
                  : _userIsScrolling && !lyrics.isEmpty && lyrics.hasSyncedLines
                  ? FloatingActionButton.small(
                      backgroundColor: colors.surface.withValues(alpha: 0.85),
                      foregroundColor: colors.primary,
                      onPressed: _resumeAutoScroll,
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    )
                  : null,
              body: scaffoldBody,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(LyricsState lyrics, ColorScheme colors) {
    if (lyrics.isEditing) {
      return [
        if (lyrics.lines.any((l) => !l.isSynced))
          IconButton(
            icon: Icon(Icons.timer_rounded, size: 20, color: colors.primary),
            tooltip: 'Sync rápido',
            onPressed: () {
              ref.read(lyricsProvider.notifier).save();
              Navigator.of(
                context,
              ).push(AppPageRoute(page: _QuickSyncPage(song: widget.song)));
            },
          ),
        if (!lyrics.isEmpty)
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
            onPressed: () => _confirmDelete(context),
          ),
        TextButton(
          onPressed: () => ref.read(lyricsProvider.notifier).save(),
          child: Text('Salvar', style: TextStyle(color: colors.primary)),
        ),
      ];
    }
    if (!lyrics.isLoaded || lyrics.isEmpty) return [];
    return [
      IconButton(
        icon: const Icon(Icons.text_fields_rounded, size: 20),
        onPressed: _cycleFontSize,
      ),
      IconButton(
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onPressed: () => _showMenu(context, colors, lyrics),
      ),
    ];
  }

  // ── Menu ⋮ ──

  void _showMenu(BuildContext context, ColorScheme colors, LyricsState lyrics) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
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
            ListTile(
              leading: const Icon(Icons.travel_explore_rounded),
              title: const Text('Buscar online'),
              subtitle: Text(
                'Substituir pelas letras da internet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              onTap: () {
                ctx.pop();
                _searchOnline();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar letras'),
              onTap: () {
                ctx.pop();
                _copyLyrics(colors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Editar letras'),
              onTap: () {
                ctx.pop();
                ref.read(lyricsProvider.notifier).toggleEdit();
              },
            ),
            if (lyrics.lines.any((l) => !l.isSynced))
              ListTile(
                leading: Icon(Icons.timer_rounded, color: colors.primary),
                title: const Text('Sync rápido'),
                subtitle: Text(
                  'Sincronize linha por linha em tempo real',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ref.read(lyricsProvider.notifier).save();
                  Navigator.of(
                    context,
                  ).push(AppPageRoute(page: _QuickSyncPage(song: widget.song)));
                },
              ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Importar LRC'),
              onTap: () {
                ctx.pop();
                _showImportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Colar texto simples'),
              onTap: () {
                ctx.pop();
                _showPasteTextDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Exportar LRC'),
              onTap: () {
                ctx.pop();
                _exportLrc(context);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────

  void _showAddLineDialog(BuildContext context) {
    final position = ref.read(playerProvider).position;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Nova linha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⏱ ${_fmtDuration(position)}',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Letra...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref
                      .read(lyricsProvider.notifier)
                      .addLine(
                        timestamp: position,
                        text: controller.text.trim(),
                      );
                }
                ctx.pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar LRC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cole texto LRC com timestamps [mm:ss.xx]',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '[00:12.50]Primeira linha...',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty)
                ref.read(lyricsProvider.notifier).importLrc(text);
              ctx.pop();
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  void _showPasteTextDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final dc = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Colar letras'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cole as letras — cada linha vira uma entrada. Sincronize depois com Sync Rápido.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: dc.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Primeira linha\nSegunda linha...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final n = ref.read(lyricsProvider.notifier);
                  for (final l
                      in text
                          .split('\n')
                          .map((l) => l.trim())
                          .where((l) => l.isNotEmpty)) {
                    n.addLine(text: l);
                  }
                  n.save();
                }
                ctx.pop();
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  void _exportLrc(BuildContext context) {
    final lrc = ref.read(lyricsProvider.notifier).exportLrc();
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Exportar LRC'),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: SelectableText(
                lrc,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: Text('Fechar', style: TextStyle(color: c.onSurface)),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lrc));
                ctx.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('LRC copiado!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Apagar letras'),
          content: const Text(
            'Todas as letras serão apagadas permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                ref.read(lyricsProvider.notifier).deleteAll();
                ctx.pop();
              },
              child: Text('Apagar', style: TextStyle(color: c.error)),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    final cs = (d.inMilliseconds.remainder(1000) / 10).round();
    return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// LYRICS MINI-PLAYER — barra inferior fixa na tela de letras
// Premium: título/artista + heart, slider e transport compacto.
// ============================================================

