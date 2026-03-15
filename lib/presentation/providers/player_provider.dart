import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/services/audio_handler.dart';
import 'package:constanza_player/presentation/providers/playlist_provider.dart';
import 'package:constanza_player/presentation/providers/library_provider.dart';

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
  }

  final ConstanzaAudioHandler _handler;
  final Ref _ref;
  final Random _rng = Random();

  // ── Bind aos streams do handler ──────────────────────────

  void _bindHandler() {
    _handler.playingStream.listen((v) {
      if (mounted) state = state.copyWith(isPlaying: v);
    });

    _handler.positionStream.listen((pos) {
      if (mounted) state = state.copyWith(position: pos);
    });

    _handler.durationStream.listen((dur) {
      if (mounted && dur != null) state = state.copyWith(duration: dur);
    });

    _handler.processingStateStream.listen((s) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: s == ProcessingState.loading ||
            s == ProcessingState.buffering,
      );
    });

    _handler.androidAudioSessionIdStream.listen((sid) {
      if (mounted && sid != null) state = state.copyWith(audioSessionId: sid);
    });

    // Callbacks de navegação — acionados pelos botões da notificação
    _handler.onNext = next;
    _handler.onPrevious = previous;
    _handler.onCompleted = _onCompleted;
  }

  // ── Carregar e tocar ─────────────────────────────────────

  Future<void> _loadAndPlay(Song song) async {
    _handler.resetVolume();
    state = state.copyWith(
      currentSong: song,
      position: Duration.zero,
      isLoading: true,
    );

    // URI do MediaStore para capa na notificação/tela de bloqueio.
    // A URI correta usa o albumId (não o songId / numericId).
    Uri? artworkUri;
    if (song.albumId != null) {
      final albumNumId = int.tryParse(song.albumId!) ?? 0;
      if (albumNumId > 0) {
        artworkUri = Uri.parse(
          'content://media/external/audio/albumart/$albumNumId',
        );
      }
    }

    await _handler.loadSong(song, artworkUri: artworkUri);
    state = state.copyWith(isLoading: false);
    await _handler.play();

    // Registra a reprodução nas smart playlists (Recentes + Mais Tocadas)
    _ref.read(playlistProvider.notifier).trackPlay(song);
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
    switch (state.repeatMode) {
      case RepeatMode.one:
        _handler.seek(Duration.zero);
        _handler.play();
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
    final active =
        state.shuffleEnabled ? _shuffled(list, anchor: song) : List.of(list);
    state = state.copyWith(
      queue: active,
      originalQueue: List.of(list),
    );
    _loadAndPlay(song);
  }

  void togglePlayPause() {
    if (!state.hasSong) return;
    state.isPlaying ? _handler.pause() : _handler.play();
  }

  void pause() => _handler.pause();

  void next() {
    if (state.queue.isEmpty) return;
    if (state.shuffleEnabled && state.queue.length > 1) {
      _loadAndPlay(_pickRandom());
      return;
    }
    _playIndex((state.currentIndex + 1) % state.queue.length);
  }

  void previous() {
    if (state.queue.isEmpty) return;
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

  void seek(Duration position) => _handler.seek(position);

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
  }

  void toggleFavorite() {
    if (state.currentSong == null) return;
    final songId = state.currentSong!.id;
    final newFav = !state.currentSong!.isFavorite;
    // Persiste via libraryProvider (que salva em SharedPreferences)
    _ref.read(libraryProvider.notifier).toggleFavorite(songId);
    // Atualiza estado local do player
    final updated = state.currentSong!.copyWith(isFavorite: newFav);
    state = state.copyWith(
      currentSong: updated,
      queue: _replace(state.queue, updated),
      originalQueue: _replace(state.originalQueue, updated),
    );
  }

  // ── Gestão de fila ───────────────────────────────────────

  /// Adiciona [song] logo após a música atual na fila.
  void addNextInQueue(Song song) {
    final newQueue = List<Song>.from(state.queue);
    // Remove duplicata (exceto a música atual)
    newQueue.removeWhere((s) => s.id == song.id && s.id != state.currentSong?.id);
    final insertAt = (state.currentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertAt, song);
    final newOriginal = List<Song>.from(state.originalQueue)
      ..removeWhere((s) => s.id == song.id && s.id != state.currentSong?.id)
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
  }) =>
      _handler.applyEqSettings(
        enabled: enabled,
        bands: bands,
        bassBoost: bassBoost,
        virtualizer: virtualizer,
      );

  // ── Helpers ──────────────────────────────────────────────

  Song _pickRandom() {
    final others =
        state.queue.where((s) => s.id != state.currentSong?.id).toList();
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
