import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/services/settings_storage_service.dart';
import 'package:constanza_player/services/artwork_file_service.dart';
import 'package:constanza_player/services/notification_color_service.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';
import 'package:constanza_player/presentation/providers/audio_analysis_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:constanza_player/services/widget_service.dart';

// ============================================================
// STATE
// ============================================================

class PlayerState {
  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.originalQueue = const [],
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.isLoading = false,
    this.audioSessionId,
  });

  final Song? currentSong;
  final List<Song> queue;
  final List<Song> originalQueue;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;
  final bool isLoading;
  final int? audioSessionId;

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get positionFormatted => _fmt(position);
  String get durationFormatted => _fmt(duration);
  bool get hasSong => currentSong != null;

  int get currentIndex {
    if (currentSong == null) return -1;
    return queue.indexWhere((s) => s.id == currentSong!.id);
  }

  bool get hasNext => queue.isNotEmpty && currentIndex < queue.length - 1;
  bool get hasPrevious => queue.isNotEmpty && currentIndex > 0;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    List<Song>? originalQueue,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    bool? isLoading,
    int? audioSessionId,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      originalQueue: originalQueue ?? this.originalQueue,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      isLoading: isLoading ?? this.isLoading,
      audioSessionId: audioSessionId ?? this.audioSessionId,
    );
  }
}

enum RepeatMode { off, all, one }

// ============================================================
// NOTIFIER
// ============================================================

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier(this._handler, this._ref) : super(const PlayerState()) {
    _bindHandler();
    WidgetService.registerActionHandlers(
      onToggleFavorite: toggleFavorite,
      onCycleRepeatMode: cycleRepeatMode,
    );
  }

  final ConstanzaAudioHandler _handler;
  final Ref _ref;
  final Random _rng = Random();
  Timer? _saveTimer;
  int _lastSavedPositionSec = -1;
  Duration _lastEmittedPos = Duration.zero;

  /// Monotonically increasing token to cancel stale _loadAndPlay calls.
  int _loadToken = 0;

  /// Serializa loads concorrentes. Sem isto, o `next` rápido dispara múltiplos
  /// `setUrl` no mesmo AudioPlayer, causando PlatformException no just_audio.
  Future<void>? _loadLock;

  // ── Bind aos streams do handler ──────────────────────────

  final List<StreamSubscription> _subs = [];

  void _bindHandler() {
    _subs.add(
      _handler.playingStream.listen((v) {
        if (mounted) {
          state = state.copyWith(isPlaying: v);
          _updateWidget();
        }
      }),
    );

    // Throttle: só emite estado quando posição muda ≥100ms — evita rebuilds excessivos
    // sem prejudicar a responsividade visual do scrubber
    _subs.add(
      _handler.positionStream.listen((pos) {
        if (!mounted) return;
        final diff = (pos - _lastEmittedPos).abs();
        if (diff < const Duration(milliseconds: 100)) return;
        _lastEmittedPos = pos;
        state = state.copyWith(position: pos);
        // Salvar estado a cada 10s de reprodução para restauração robusta
        final sec = pos.inSeconds;
        if (state.isPlaying && (sec - _lastSavedPositionSec).abs() >= 10) {
          _lastSavedPositionSec = sec;
          savePlaybackState();
        }
      }),
    );

    _subs.add(
      _handler.durationStream.listen((dur) {
        if (mounted && dur != null) state = state.copyWith(duration: dur);
      }),
    );

    _subs.add(
      _handler.processingStateStream.listen((s) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading:
              s == ProcessingState.loading || s == ProcessingState.buffering,
        );
      }),
    );

    _subs.add(
      _handler.androidAudioSessionIdStream.listen((sid) {
        if (mounted && sid != null) state = state.copyWith(audioSessionId: sid);
      }),
    );

    // Callbacks de navegação — acionados pelos botões da notificação
    _handler.onNext = next;
    _handler.onPrevious = previous;
    _handler.onCompleted = _onCompleted;
    _handler.onToggleFavorite = _onToggleFavoriteFromNotification;
  }

  void _onToggleFavoriteFromNotification() {
    toggleFavorite();
    // Sync playlists
    final updatedSongs = _ref.read(libraryProvider).songs;
    _ref.read(playlistProvider.notifier).syncFavorites(updatedSongs);
  }

  // ── Carregar e tocar ─────────────────────────────────────

  Future<void> _loadAndPlay(Song song) async {
    // Incrementa token — qualquer _loadAndPlay anterior é descartado
    final token = ++_loadToken;
    bool stale() => !mounted || token != _loadToken;

    // Serializa com o load anterior. Sem isto, dois setUrl concorrentes no
    // mesmo AudioPlayer lançam PlatformException no just_audio (crash no next rápido).
    final prevLock = _loadLock;
    final completer = Completer<void>();
    _loadLock = completer.future;
    try {
      if (prevLock != null) {
        await prevLock;
      }
    } catch (_) {
      // Ignora falhas do load anterior — não devem bloquear este.
    }
    if (stale()) {
      completer.complete();
      return;
    }

    _handler.setLoadingNewTrack(true);
    _handler.resetVolume();

    try {
      // Fallback síncrono: artwork via content:// do álbum (zero I/O).
      // Sem este caminho, a 1ª inicialização espera por queryArtwork+disk-write
      // do ArtworkFileService — bloqueando setUrl/play e fazendo o áudio
      // antigo continuar tocando enquanto a UI já mostrou a próxima.
      Uri? artworkUri;
      if (song.albumId != null) {
        final albumNumId = int.tryParse(song.albumId!) ?? 0;
        if (albumNumId > 0) {
          artworkUri = Uri.parse(
            'content://media/external/audio/albumart/$albumNumId',
          );
        }
      }

      if (stale()) return;

      // State mutation AFTER stale check to avoid partial state corruption
      state = state.copyWith(
        currentSong: song,
        position: Duration.zero,
        isLoading: true,
      );

      await _handler.loadSong(song, artworkUri: artworkUri);
      if (stale()) return;

      _handler.setFavorite(song.isFavorite);
      state = state.copyWith(isLoading: false);
      _handler.setLoadingNewTrack(false);
      // Fire-and-forget — `_player.play()` retorna um Future que SÓ completa
      // quando o player vai para idle (pause/stop). Awaitar aqui prende o
      // _loadLock indefinidamente: a próxima chamada (Next) bloqueia em
      // `await prevLock` até o usuário pausar, fazendo o áudio antigo continuar
      // e a UI mostrar a faixa nova mas sem som — bug de "first startup".
      unawaited(_handler.play());
      if (stale()) return;

      // Upgrade artwork em background (file URI 600px) — não bloqueia o áudio.
      ArtworkFileService.getArtworkFileUri(song.numericId)
          .then((fileUri) {
            if (fileUri == null || stale()) return;
            _handler.updateArtwork(fileUri);
            _updateWidget(artworkPath: fileUri.toFilePath());
          })
          .catchError((Object e) {
            debugPrint('[PlayerNotifier] artwork upgrade error: $e');
          });

      // Tarefas não-críticas — fire-and-forget
      _sendArtworkToNotification(song.numericId);
      _updateWidget();
      _ref.read(playlistProvider.notifier).trackPlay(song);
      _ref
          .read(audioAnalysisProvider.notifier)
          .analyzeSong(
            song.id,
            song.uri,
            title: song.title,
            artist: song.artist,
          );
      _scheduleSave();
    } catch (e) {
      // Erro no player (ficheiro ausente, codec, etc.) — não crashar
      _handler.setLoadingNewTrack(false);
      if (!stale()) {
        state = state.copyWith(isLoading: false);
      }
    } finally {
      if (!completer.isCompleted) completer.complete();
    }
  }

  void _playIndex(int index) {
    if (index >= 0 && index < state.queue.length) {
      _loadAndPlay(state.queue[index]);
    }
  }

  /// Public wrapper for carousel navigation.
  void playIndex(int index) => _playIndex(index);

  // ── Completed (callback do handler) ──────────────────────

  void _onCompleted() {
    if (state.queue.isEmpty) return;
    switch (state.repeatMode) {
      case RepeatMode.one:
        // Reload the source instead of seek+play: after ProcessingState.completed
        // just_audio's audio pipeline is closed on Android and plain seek+play
        // leaves the player in a mute "zombie" state (position moves, no sound).
        // _loadAndPlay also calls resetVolume(), fixing the crossfade-zeroed-volume case.
        if (state.currentSong != null) _loadAndPlay(state.currentSong!);
      case RepeatMode.all:
        _playIndex((state.currentIndex + 1) % state.queue.length);
      case RepeatMode.off:
        final next = state.currentIndex + 1;
        if (next < state.queue.length) {
          _loadAndPlay(state.queue[next]);
        } else {
          _handler.seek(Duration.zero);
          _handler.pause();
        }
    }
  }

  // ── API Pública ──────────────────────────────────────────

  void playSong(Song song, {List<Song>? queue, bool shuffle = false}) {
    final list = queue ?? [song];
    if (shuffle) {
      final shuffled = _shuffled(list, anchor: null);
      state = state.copyWith(
        queue: shuffled,
        originalQueue: List.of(list),
        shuffleEnabled: true,
      );
      _loadAndPlay(shuffled.first);
      return;
    }
    final active = state.shuffleEnabled
        ? _shuffled(list, anchor: song)
        : List.of(list);
    state = state.copyWith(queue: active, originalQueue: List.of(list));
    _loadAndPlay(song);
  }

  void togglePlayPause() {
    if (!state.hasSong) return;
    state.isPlaying ? _handler.pause() : _handler.play();
  }

  void pause() => _handler.pause();

  void next() {
    if (state.queue.isEmpty) return;
    // Repeat one: restart current song instead of advancing
    if (state.repeatMode == RepeatMode.one) {
      _handler.resetVolume();
      _handler.seek(Duration.zero);
      _handler.play();
      return;
    }
    if (state.shuffleEnabled && state.queue.length > 1) {
      _loadAndPlay(_pickRandom());
      return;
    }
    _playIndex((state.currentIndex + 1) % state.queue.length);
  }

  void previous() {
    if (state.queue.isEmpty) return;
    // Repeat one: restart current song
    if (state.repeatMode == RepeatMode.one) {
      _handler.resetVolume();
      _handler.seek(Duration.zero);
      _handler.play();
      return;
    }
    if (state.position.inSeconds > 3) {
      _handler.seek(Duration.zero);
      return;
    }
    if (state.shuffleEnabled && state.queue.length > 1) {
      _loadAndPlay(_pickRandom());
      return;
    }
    final idx = state.currentIndex;
    _playIndex(idx > 0 ? idx - 1 : state.queue.length - 1);
  }

  void seek(Duration position) {
    _lastEmittedPos = Duration.zero; // force next stream event to emit
    _handler.seek(position);
  }

  void toggleShuffle() {
    if (!state.shuffleEnabled) {
      state = state.copyWith(
        shuffleEnabled: true,
        queue: _shuffled(state.originalQueue, anchor: state.currentSong),
      );
    } else {
      state = state.copyWith(
        shuffleEnabled: false,
        queue: List.of(state.originalQueue),
      );
    }
  }

  void cycleRepeatMode() {
    state = state.copyWith(
      repeatMode: switch (state.repeatMode) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      },
    );
    _updateWidget();
  }

  void toggleFavorite() {
    if (state.currentSong == null) return;
    final songId = state.currentSong!.id;
    final newFav = !state.currentSong!.isFavorite;
    // Persiste via libraryProvider (que salva em SharedPreferences)
    _ref.read(libraryProvider.notifier).toggleFavorite(songId);
    // Atualiza estado local do player
    _updateFavoriteState(newFav);
  }

  /// Syncs player favorite state from library (without re-toggling library).
  void syncFavoriteFromLibrary(String songId, bool isFavorite) {
    if (state.currentSong == null || state.currentSong!.id != songId) return;
    _updateFavoriteState(isFavorite);
  }

  void _updateFavoriteState(bool newFav) {
    if (state.currentSong == null) return;
    final updated = state.currentSong!.copyWith(isFavorite: newFav);
    state = state.copyWith(
      currentSong: updated,
      queue: _replace(state.queue, updated),
      originalQueue: _replace(state.originalQueue, updated),
    );
    // Sync notification icon
    _handler.setFavorite(newFav);
    _updateWidget();
  }

  /// Atualiza metadados da música atual no player (título, artista, etc).
  void updateCurrentSongMetadata(Song updated) {
    if (state.currentSong == null || state.currentSong!.id != updated.id) {
      return;
    }
    final merged = updated.copyWith(isFavorite: state.currentSong!.isFavorite);
    state = state.copyWith(
      currentSong: merged,
      queue: _replace(state.queue, merged),
      originalQueue: _replace(state.originalQueue, merged),
    );
  }

  // ── Gestão de fila ───────────────────────────────────────

  /// Adiciona [song] logo após a música atual na fila.
  void addNextInQueue(Song song) {
    final newQueue = List<Song>.from(state.queue);
    // Remove duplicata (exceto a música atual)
    newQueue.removeWhere((s) => s.id == song.id);
    final insertAt = (state.currentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertAt, song);
    final newOriginal = List<Song>.from(state.originalQueue)
      ..removeWhere((s) => s.id == song.id)
      ..add(song);
    state = state.copyWith(queue: newQueue, originalQueue: newOriginal);
  }

  /// Adiciona [song] no final da fila.
  void addToQueue(Song song) {
    state = state.copyWith(
      queue: [...state.queue, song],
      originalQueue: [...state.originalQueue, song],
    );
  }

  /// Remove a música no [index] da fila (não permite remover a atual).
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    if (state.queue[index].id == state.currentSong?.id) return;
    final newQueue = List<Song>.from(state.queue)..removeAt(index);
    state = state.copyWith(queue: newQueue);
  }

  /// Reordena a fila movendo de [oldIndex] para [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    final newQueue = List<Song>.from(state.queue);
    if (oldIndex < newIndex) newIndex--;
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, song);
    state = state.copyWith(queue: newQueue);
  }

  /// Mantém apenas a música atual na fila.
  void clearQueue() {
    final current = state.currentSong;
    state = state.copyWith(
      queue: current != null ? [current] : [],
      originalQueue: current != null ? [current] : [],
    );
  }

  // ── Configurações de áudio (chamadas pelo AppShell) ──────

  void setSpeed(double speed) => _handler.setSpeed(speed);

  void setCrossfadeDuration(int seconds) =>
      _handler.setCrossfadeDuration(seconds);

  Future<void> applyEqSettings({
    required bool enabled,
    required List<double> bands,
    required double bassBoost,
    required double virtualizer,
  }) => _handler.applyEqSettings(
    enabled: enabled,
    bands: bands,
    bassBoost: bassBoost,
    virtualizer: virtualizer,
  );

  // ── Persistência de estado ──────────────────────────────

  /// Salva o estado atual para restaurar ao reabrir o app.
  Future<void> savePlaybackState() async {
    if (!state.hasSong) return;
    final data = <String, dynamic>{
      'currentSong': state.currentSong!.toJson(),
      'queue': state.queue.map((s) => s.toJson()).toList(),
      'originalQueue': state.originalQueue.map((s) => s.toJson()).toList(),
      'positionMs': state.position.inMilliseconds,
      'shuffleEnabled': state.shuffleEnabled,
      'repeatMode': state.repeatMode.index,
      'audioSessionId': state.audioSessionId,
    };
    await SettingsStorageService.savePlaybackState(data);
  }

  /// Restaura o estado salvo. Carrega a música mas NÃO reproduz (fica pausado).
  /// Ignora se já há uma música carregada (evita reiniciar ao voltar ao app).
  Future<void> restorePlaybackState() async {
    if (state.hasSong) return; // Já tem música — não sobrescrever
    final data = SettingsStorageService.loadPlaybackState();
    if (data == null) return;
    try {
      final currentSongRaw = data['currentSong'];
      if (currentSongRaw is! Map<String, dynamic>) return;
      final song = Song.fromJson(currentSongRaw);

      final queueRaw = data['queue'];
      final queue = (queueRaw is List)
          ? queueRaw
                .whereType<Map<String, dynamic>>()
                .map((e) => Song.fromJson(e))
                .toList()
          : <Song>[];

      final originalQueueRaw = data['originalQueue'];
      final originalQueue = (originalQueueRaw is List)
          ? originalQueueRaw
                .whereType<Map<String, dynamic>>()
                .map((e) => Song.fromJson(e))
                .toList()
          : <Song>[];

      if (queue.isEmpty) return; // dados inconsistentes — ignorar
      final positionMs = data['positionMs'] as int? ?? 0;
      final shuffleEnabled = data['shuffleEnabled'] as bool? ?? false;
      final repeatModeIndex = data['repeatMode'] as int? ?? 0;
      final audioSessionId = data['audioSessionId'] as int?;

      // Caso o foreground service de áudio tenha sobrevivido ao destruir/recriar
      // da UI Flutter (ex.: usuário voltou ao app via notificação após tela
      // bloqueada por muito tempo), o handler já está tocando. Sincronizar a
      // partir dele em vez de chamar loadSong (que reinicia setUrl e zera a
      // posição real, fazendo a faixa "voltar ao início").
      final liveItem = _handler.mediaItem.valueOrNull;
      final handlerActive =
          liveItem != null &&
          _handler.processingState != ProcessingState.idle;
      if (handlerActive) {
        final liveId = liveItem.id;
        final liveSong = queue.firstWhere(
          (s) => s.id == liveId,
          orElse: () => originalQueue.firstWhere(
            (s) => s.id == liveId,
            orElse: () => song,
          ),
        );
        state = state.copyWith(
          currentSong: liveSong,
          queue: queue,
          originalQueue: originalQueue,
          position: _handler.position,
          duration: _handler.duration ?? liveSong.duration,
          isPlaying: _handler.playing,
          shuffleEnabled: shuffleEnabled,
          repeatMode: RepeatMode.values[repeatModeIndex.clamp(0, 2)],
          audioSessionId: audioSessionId,
        );
        return;
      }

      state = state.copyWith(
        currentSong: song,
        queue: queue,
        originalQueue: originalQueue,
        position: Duration(milliseconds: positionMs),
        shuffleEnabled: shuffleEnabled,
        repeatMode: RepeatMode.values[repeatModeIndex.clamp(0, 2)],
        audioSessionId: audioSessionId,
      );

      // Carrega a faixa no player sem reproduzir.
      Uri? artworkUri = await ArtworkFileService.getArtworkFileUri(
        song.numericId,
      );
      if (artworkUri == null && song.albumId != null) {
        final albumNumId = int.tryParse(song.albumId!) ?? 0;
        if (albumNumId > 0) {
          artworkUri = Uri.parse(
            'content://media/external/audio/albumart/$albumNumId',
          );
        }
      }
      await _handler.loadSong(song, artworkUri: artworkUri);
      if (!mounted) return;

      if (positionMs > 0) {
        if (_handler.processingState != ProcessingState.ready) {
          await _handler.processingStateStream
              .firstWhere(
                (s) => s == ProcessingState.ready || s == ProcessingState.idle,
              )
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () => ProcessingState.idle,
              );
        }
        if (!mounted) return;
        if (_handler.processingState == ProcessingState.ready) {
          await _handler.seek(Duration(milliseconds: positionMs));
        }
      }
      if (!mounted) return;
      // Atualiza posição no estado para UI refletir imediatamente
      state = state.copyWith(position: Duration(milliseconds: positionMs));
      // Fica pausado — o usuário decide quando continuar.
    } catch (e) {
      debugPrint('[PlayerNotifier] restorePlaybackState error: $e');
    }
  }

  /// Envia artwork ao plugin nativo para colorizar notificação e lock screen.
  Future<void> _sendArtworkToNotification(int songId) async {
    try {
      final bytes = await OnAudioQuery().queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 300,
        quality: 85,
      );
      if (bytes != null && bytes.isNotEmpty) {
        await NotificationColorService.updateFromArtwork(bytes);
      }
    } catch (e) {
      debugPrint('[PlayerNotifier] sendArtworkToNotification error: $e');
    }
  }

  void _updateWidget({String? artworkPath}) {
    final song = state.currentSong;
    WidgetService.update(
      title: song?.title ?? 'Constanza Músicas',
      artist: song?.artist ?? '',
      isPlaying: state.isPlaying,
      isFavorite: song?.isFavorite ?? false,
      repeatMode: state.repeatMode.index,
      artworkPath: artworkPath,
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), () => savePlaybackState());
  }

  // ── Helpers ──────────────────────────────────────────────

  Song _pickRandom() {
    final others = state.queue
        .where((s) => s.id != state.currentSong?.id)
        .toList();
    final pool = others.isEmpty ? state.queue : others;
    return pool[_rng.nextInt(pool.length)];
  }

  List<Song> _shuffled(List<Song> src, {Song? anchor}) {
    final list = List<Song>.of(src)..shuffle(_rng);
    if (anchor != null) {
      list.removeWhere((s) => s.id == anchor.id);
      list.insert(0, anchor);
    }
    return list;
  }

  List<Song> _replace(List<Song> list, Song updated) =>
      list.map((s) => s.id == updated.id ? updated : s).toList();

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    savePlaybackState();
    _handler.customAction('dispose');
    super.dispose();
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Handler singleton — inicializado em main.dart via AudioService.init().
final audioHandlerProvider = Provider<ConstanzaAudioHandler>(
  (ref) => throw UnimplementedError(
    'audioHandlerProvider must be overridden in ProviderScope via main.dart',
  ),
);

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(ref.watch(audioHandlerProvider), ref),
);
