// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, unused_element_parameter
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
  int _scrollAttempt = 0;
  bool _scrollScheduled = false;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;
  static const _scrollCooldown = Duration(seconds: 5);

  bool _isSearching = false;

  /// Música para a qual já se disparou a busca automática nesta sessão de
  /// tela — evita repetir a chamada a cada rebuild.
  String? _autoSearchedSongId;

  /// Tamanho da fonte (3 níveis)
  double _baseFontSize = 22.0;
  static const _fontSizes = [18.0, 22.0, 28.0];
  int _fontIdx = 1;

  String _fontLabel(AppLocalizations l10n, int idx) {
    switch (idx) {
      case 0:
        return l10n.lyricsFontSmall;
      case 2:
        return l10n.lyricsFontLarge;
      default:
        return l10n.lyricsFontMedium;
    }
  }

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

  /// Agenda uma centralização da linha [idx] para depois do frame atual.
  /// Garante uma única cadeia de scroll ativa — evita "tempestade" de
  /// callbacks, já que o build dispara a cada tick de posição da música.
  void _scheduleScroll(int idx) {
    if (idx < 0 ||
        _userIsScrolling ||
        idx == _lastScrolledIndex ||
        _scrollScheduled) {
      return;
    }
    _armScroll(idx);
  }

  void _armScroll(int idx) {
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted) _scrollToLine(idx);
    });
  }

  void _scrollToLine(int idx) {
    if (idx < 0 || _userIsScrolling || !mounted) return;
    if (idx == _lastScrolledIndex) return;

    final ctx = _lineKeys[idx]?.currentContext;
    if (ctx != null) {
      // Linha já renderizada — centra com precisão. alignment 0.5 ignora a
      // altura variável da linha (fontes maiores ou texto que quebra).
      _lastScrolledIndex = idx;
      _scrollAttempt = 0;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
      return;
    }

    // Linha-alvo fora da área renderizada — acontece ao abrir/reabrir a tela
    // com a música já a meio: o ListView só constrói os itens visíveis, então
    // a GlobalKey ainda não tem context. Aproximamo-nos com saltos instantâneos
    // até a linha existir e, no frame seguinte, centramos suavemente.
    if (!_scroll.hasClients || _scrollAttempt >= 40) {
      _scrollAttempt = 0;
      return;
    }
    _scrollAttempt++;
    final pos = _scroll.position;
    final vp = pos.viewportDimension;
    final built = _lineKeys.entries
        .where((e) => e.value.currentContext != null)
        .map((e) => e.key)
        .toList();
    double target;
    if (built.isNotEmpty && built.every((i) => i < idx)) {
      target = pos.pixels + vp * 0.85; // alvo está abaixo
    } else if (built.isNotEmpty && built.every((i) => i > idx)) {
      target = pos.pixels - vp * 0.85; // alvo está acima
    } else {
      target = idx * 64.0; // direção indefinida — estimativa por índice
    }
    _scroll.jumpTo(target.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    _armScroll(idx);
  }

  void _cycleFontSize() {
    setState(() {
      _fontIdx = (_fontIdx + 1) % _fontSizes.length;
      _baseFontSize = _fontSizes[_fontIdx];
      _lastScrolledIndex = -1;
    });
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.lyricsFontSizeApplied(_fontLabel(l10n, _fontIdx))),
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
    final l10n = AppLocalizations.of(context);
    final text = ref.read(lyricsProvider).lines.map((l) => l.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.lyricsCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Busca online ────────────────────────────────────────────

  /// Id da faixa tocando agora (fallback para a que abriu a tela). Usado pelos
  /// guards de corrida das buscas online.
  String _currentSongId() =>
      ref.read(playerProvider).currentSong?.id ?? widget.song.id;

  Future<void> _searchOnline({bool auto = false}) async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    // Sempre usar a música atual do player — não a que abriu a tela. Capturada
    // ANTES do try para que o guard de corrida (e o catch) saibam qual faixa
    // originou esta busca, mesmo que o utilizador pule de música durante o await.
    final song = ref.read(playerProvider).currentSong ?? widget.song;
    final targetId = song.id;
    try {
      // Garante que o lyricsProvider está vinculado a esta música antes de
      // qualquer escrita (evita salvar letras na chave errada).
      await ref.read(lyricsProvider.notifier).loadForSong(targetId);
      final lines = await LyricsFetchService.fetch(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      );
      if (!mounted) return;

      // A faixa ainda é a que originou a busca? Se o utilizador pulou durante
      // o await, o resultado é persistido na chave certa (targetId) mas NÃO é
      // mostrado por cima da faixa nova.
      final stillCurrent = _currentSongId() == targetId;
      final notifier = ref.read(lyricsProvider.notifier);

      if (lines != null && lines.isNotEmpty) {
        await notifier.applyOnlineResult(targetId, lines);
        if (stillCurrent && mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.lyricsLinesFound(lines.length)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Busca esgotada sem resultado — estado definitivo e persistido.
        // O _EmptyLyrics passa a mostrar "Nenhuma letra encontrada" com
        // botão de re-tentar, em vez de um snackbar ambíguo.
        await notifier.markOnlineMissFor(targetId);
        if (stillCurrent && mounted && !auto) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.lyricsNoneOnline),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } on LyricsNetworkException {
      // Falha de rede — NÃO marcar "sem letra". A próxima tentativa (ao reabrir
      // ou tocar de novo) volta a buscar automaticamente. Silencioso no auto e
      // se o utilizador já trocou de faixa.
      if (mounted && !auto && _currentSongId() == targetId) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lyricsSearchError('sem conexão')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lyricsSearchError(e.toString())),
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

    ref.listen<String?>(playerProvider.select((s) => s.currentSong?.id), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        _lineKeys.clear();
        _lastScrolledIndex = -1;
        _scrollAttempt = 0;
        _scrollScheduled = false;
        _userScrollTimer?.cancel();
        _userIsScrolling = false;
        _autoSearchedSongId = null;
        ref.read(lyricsProvider.notifier).loadForSong(next);
      }
    });

    // Busca automática ao abrir letras vazias: sem letra local e ainda
    // sem confirmação de que não existe online. Resolve o "clicar duas
    // vezes" — o utilizador já vê o resultado sem nenhuma ação.
    if (lyrics.isLoaded &&
        lyrics.isEmpty &&
        !lyrics.isEditing &&
        !lyrics.onlineMiss &&
        !_isSearching &&
        _autoSearchedSongId != currentSong.id) {
      _autoSearchedSongId = currentSong.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchOnline(auto: true);
      });
    }

    // Auto-scroll no view mode — centraliza a linha cantada em tempo real,
    // inclusive ao abrir/reabrir a tela com a música já em andamento.
    if (!lyrics.isEditing && curIdx >= 0) {
      _scheduleScroll(curIdx);
    }

    final Widget bodyContent = !lyrics.isLoaded
        ? const Center(child: CircularProgressIndicator())
        : lyrics.isEmpty && !lyrics.isEditing
        ? _EmptyLyrics(
            onAdd: () => ref.read(lyricsProvider.notifier).toggleEdit(),
            onImportLrc: () => _showImportDialog(context),
            onPasteText: () => _showPasteTextDialog(context),
            onSearchOnline: _searchOnline,
            onManualSearch: () => _showManualSearchDialog(context),
            isSearching: _isSearching,
            attempted: lyrics.onlineMiss,
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
            horizontalPadding: isLandscape ? AppSpacing.xl : AppSpacing.lg,
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
    final l10n = AppLocalizations.of(context);
    if (lyrics.isEditing) {
      return [
        if (lyrics.lines.any((l) => !l.isSynced))
          IconButton(
            icon: Icon(Icons.timer_rounded, size: 20, color: colors.primary),
            tooltip: l10n.lyricsQuickSyncShort,
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
          child: Text(l10n.commonSave, style: TextStyle(color: colors.primary)),
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
      // isScrollControlled: o sheet pode crescer além de ~9/16 da tela; com
      // o SingleChildScrollView abaixo a lista nunca estoura ("BOTTOM
      // OVERFLOWED") em janelas baixas (desktop) — apenas rola.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
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
                  title: Text(l10n.lyricsSearchOnline),
                  subtitle: Text(
                    l10n.lyricsSearchOnlineDescription,
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
                  title: Text(l10n.lyricsCopy),
                  onTap: () {
                    ctx.pop();
                    _copyLyrics(colors);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: Text(l10n.lyricsEdit),
                  onTap: () {
                    ctx.pop();
                    ref.read(lyricsProvider.notifier).toggleEdit();
                  },
                ),
                if (lyrics.lines.any((l) => !l.isSynced))
                  ListTile(
                    leading: Icon(Icons.timer_rounded, color: colors.primary),
                    title: Text(l10n.lyricsQuickSyncShort),
                    subtitle: Text(
                      l10n.lyricsQuickSyncDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    onTap: () {
                      ctx.pop();
                      ref.read(lyricsProvider.notifier).save();
                      Navigator.of(context).push(
                        AppPageRoute(page: _QuickSyncPage(song: widget.song)),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(l10n.lyricsImportLrc),
                  onTap: () {
                    ctx.pop();
                    _showImportDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: Text(l10n.lyricsPastePlain),
                  onTap: () {
                    ctx.pop();
                    _showPasteTextDialog(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.image_outlined, color: colors.primary),
                  title: Text(AppLocalizations.of(context).lyricsSharePoster),
                  subtitle: Text(
                    AppLocalizations.of(context).lyricsSharePosterDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  onTap: () {
                    ctx.pop();
                    _shareLyricsPoster(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_rounded),
                  title: Text(l10n.lyricsExportLrc),
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
      },
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────

  void _showAddLineDialog(BuildContext context) {
    final position = ref.read(playerProvider).position;
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.lyricsNewLine),
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
                decoration: InputDecoration(
                  hintText: l10n.lyricsTextHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: Text(l10n.commonCancel),
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
              child: Text(l10n.lyricsAdd),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lyricsImportLrc),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.lyricsImportHint,
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
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty)
                ref.read(lyricsProvider.notifier).importLrc(text);
              ctx.pop();
            },
            child: Text(l10n.commonImport),
          ),
        ],
      ),
    );
  }

  void _showPasteTextDialog(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final dc = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.lyricsPasteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.lyricsPasteHint,
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
              child: Text(l10n.commonCancel),
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
              child: Text(l10n.lyricsAdd),
            ),
          ],
        );
      },
    );
  }

  // ── Busca manual (seletor de candidatos) ────────────────────

  Future<void> _showManualSearchDialog(BuildContext context) async {
    final song = ref.read(playerProvider).currentSong ?? widget.song;
    // Garante que o provider está vinculado a esta música antes de importar.
    await ref.read(lyricsProvider.notifier).loadForSong(song.id);
    if (!mounted) return;

    final hit = await showModalBottomSheet<LyricsHit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => _ManualSearchSheet(
        initialTitle: song.title,
        initialArtist: song.artist,
      ),
    );
    if (hit == null || !mounted) return;

    // Mesmo guard de corrida da busca automática: a faixa pode ter avançado
    // com o bottom sheet aberto. Grava na chave de origem (song.id) e só mostra
    // se ainda for a música atual.
    final lines = hit.toLines();
    if (lines == null || lines.isEmpty) return;
    await ref.read(lyricsProvider.notifier).applyOnlineResult(song.id, lines);
    if (!mounted || _currentSongId() != song.id) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.lyricsLinesFound(lines.length)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareLyricsPoster(BuildContext context) {
    final lyrics = ref.read(lyricsProvider);
    final position = ref.read(playerProvider).position;
    final song = ref.read(playerProvider).currentSong ?? widget.song;
    final palette = ref.read(artworkPaletteProvider);
    final hl = lyrics.currentLineIndex(position);
    ShareService.shareLyrics(
      context: context,
      song: song,
      lines: lyrics.lines,
      highlightIndex: hl >= 0 ? hl : null,
      palette: palette,
    );
  }

  void _exportLrc(BuildContext context) {
    final lrc = ref.read(lyricsProvider.notifier).exportLrc();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.lyricsExportLrc),
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
              child: Text(
                l10n.commonClose,
                style: TextStyle(color: c.onSurface),
              ),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lrc));
                ctx.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.lyricsLrcCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(l10n.lyricsCopy2),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.lyricsDeleteTitle),
          content: Text(l10n.lyricsDeleteBody),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                ref.read(lyricsProvider.notifier).deleteAll();
                ctx.pop();
              },
              child: Text(l10n.lyricsDelete, style: TextStyle(color: c.error)),
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
// BUSCA MANUAL — bottom sheet com seletor de candidatos LRCLIB
// Permite ajustar título/artista e escolher entre vários resultados,
// com badge de "sincronizada" e duração para acertar a faixa certa.
// ============================================================

class _ManualSearchSheet extends StatefulWidget {
  const _ManualSearchSheet({
    required this.initialTitle,
    required this.initialArtist,
  });

  final String initialTitle;
  final String initialArtist;

  @override
  State<_ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends State<_ManualSearchSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  bool _loading = false;
  bool _searched = false;
  List<LyricsHit> _results = const [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _artistCtrl = TextEditingController(text: widget.initialArtist);
    // Primeira busca automática com os dados da faixa atual.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final hits = await LyricsFetchService.search(
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _results = hits;
          _searched = true;
        });
      }
    } on LyricsNetworkException {
      // Falha de rede: não apresenta "nada encontrado" (seria enganoso) — avisa
      // para tentar de novo. _searched fica false → o utilizador pode repetir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).lyricsSearchError('sem conexão'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _searched = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: c.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lyricsManualSearchTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.lyricsManualSearchHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.lyricsFieldTitle,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _artistCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _run(),
                      decoration: InputDecoration(
                        labelText: l10n.lyricsFieldArtist,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _run,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(l10n.lyricsSearchAction),
                      ),
                    ),
                  ],
                ),
              ),
              if (_searched && !_loading && _results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.lyricsResultsCount(_results.length),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              const Divider(height: AppSpacing.md),
              Expanded(
                child: _loading && _results.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : (_searched && _results.isEmpty)
                    ? Center(
                        child: Text(
                          l10n.lyricsNoResults,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (_, i) {
                          final h = _results[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            title: Text(
                              h.trackName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                h.artistName,
                                if (h.albumName?.isNotEmpty ?? false)
                                  h.albumName,
                                if (h.duration != null) _fmt(h.duration),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: h.hasSynced
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      l10n.lyricsSyncedBadge,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: c.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(h),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LYRICS MINI-PLAYER — barra inferior fixa na tela de letras
// Premium: título/artista + heart, slider e transport compacto.
// ============================================================
