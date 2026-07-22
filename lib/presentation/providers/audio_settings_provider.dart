import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/presentation/providers/player_provider.dart';
import 'package:constanza_player/services/settings_storage_service.dart';

// ============================================================
// PRESETS DO EQUALIZADOR
// ============================================================

class EqPreset {
  const EqPreset({required this.id, required this.name, required this.bands});
  final String id;
  final String name;
  final List<double> bands; // 5 bandas em dB: 60Hz, 250Hz, 1kHz, 4kHz, 16kHz
}

const kEqPresets = [
  EqPreset(id: 'flat', name: 'Flat', bands: [0, 0, 0, 0, 0]),
  EqPreset(id: 'rock', name: 'Rock', bands: [4, 2, -1, 3, 5]),
  EqPreset(id: 'pop', name: 'Pop', bands: [-1, 2, 5, 2, -1]),
  EqPreset(id: 'jazz', name: 'Jazz', bands: [3, 1, -2, 1, 4]),
  EqPreset(id: 'classical', name: 'Clássico', bands: [4, 2, 0, 2, 4]),
  EqPreset(id: 'hiphop', name: 'Hip Hop', bands: [5, 4, 0, 1, 3]),
  EqPreset(id: 'electronic', name: 'Eletrônica', bands: [5, 3, 0, 2, 5]),
  EqPreset(id: 'vocal', name: 'Vocal', bands: [-2, 0, 4, 3, 0]),
  EqPreset(id: 'bass_boost', name: 'Bass+', bands: [6, 4, 0, 0, 0]),
  EqPreset(id: 'treble_boost', name: 'Agudos+', bands: [0, 0, 0, 4, 6]),
  EqPreset(id: 'custom', name: 'Custom', bands: [0, 0, 0, 0, 0]),
];

const kBandLabels = ['60Hz', '250Hz', '1kHz', '4kHz', '16kHz'];

// ============================================================
// STATE
// ============================================================

class AudioSettingsState {
  const AudioSettingsState({
    this.eqEnabled = false,
    this.eqPresetId = 'flat',
    this.eqBands = const [0, 0, 0, 0, 0],
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.crossfadeDuration = 0,
    this.playbackSpeed = 1.0,
    this.volumeNormalization = false,
    this.gaplessPlayback = false,
    this.sleepTimerMinutes = 0,
    this.sleepTimerEndTime,
    this.sleepTimerTick = 0, // incrementado a cada minuto → força rebuild
    this.sleepTimerEndOfTrack = false,
    this.sleepTimerFadeOut = true,
    this.sleepTimerLastUsedMinutes = 15,
  });

  final bool eqEnabled;
  final String eqPresetId;
  final List<double> eqBands;
  final double bassBoost;
  final double virtualizer;
  final int crossfadeDuration; // segundos (0 = off)
  final double playbackSpeed;
  final bool volumeNormalization;
  final bool gaplessPlayback;
  final int sleepTimerMinutes; // minutos configurados (0 = off)
  final DateTime? sleepTimerEndTime;
  final int sleepTimerTick; // contador interno para forçar rebuild do label
  final bool sleepTimerEndOfTrack; // modo "fim da música atual" (transient)
  final bool sleepTimerFadeOut; // pref persistido — fade out nos últimos 10s
  final int sleepTimerLastUsedMinutes; // último valor escolhido (persistido)

  // ── Getters calculados ──────────────────────────────────

  bool get hasSleepTimer =>
      sleepTimerEndOfTrack ||
      (sleepTimerMinutes > 0 && sleepTimerEndTime != null);

  /// Label dinâmico com tempo restante — atualiza a cada tick do timer UI.
  String get sleepTimerLabel {
    if (!hasSleepTimer) return 'Desligado';
    if (sleepTimerEndOfTrack) return 'Fim da música';
    final endTime = sleepTimerEndTime;
    if (endTime == null) return 'Desligado';
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return 'Desligado';
    final totalMins = remaining.inMinutes;
    final secs = remaining.inSeconds.remainder(60);
    if (totalMins == 0) return '${secs}s restantes';
    if (secs == 0) return '$totalMins min restantes';
    return '${totalMins}min ${secs}s restantes';
  }

  String get crossfadeLabel =>
      crossfadeDuration == 0 ? 'Desligado' : '${crossfadeDuration}s';

  String get speedLabel {
    final s = playbackSpeed;
    if ((s - s.roundToDouble()).abs() < 0.01) {
      return '${s.round()}x';
    }
    return '${s.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '')}x';
  }

  EqPreset get currentPreset => kEqPresets.firstWhere(
    (p) => p.id == eqPresetId,
    orElse: () => kEqPresets.first,
  );

  // ── Serialização ──────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'eqEnabled': eqEnabled,
    'eqPresetId': eqPresetId,
    'eqBands': eqBands,
    'bassBoost': bassBoost,
    'virtualizer': virtualizer,
    'crossfadeDuration': crossfadeDuration,
    'playbackSpeed': playbackSpeed,
    'volumeNormalization': volumeNormalization,
    'gaplessPlayback': gaplessPlayback,
    // sleepTimer ativo é transiente; persistimos só as PREFERÊNCIAS
    'sleepTimerFadeOut': sleepTimerFadeOut,
    'sleepTimerLastUsedMinutes': sleepTimerLastUsedMinutes,
  };

  factory AudioSettingsState.fromJson(Map<String, dynamic> json) {
    return AudioSettingsState(
      eqEnabled: json['eqEnabled'] as bool? ?? false,
      eqPresetId: json['eqPresetId'] as String? ?? 'flat',
      eqBands:
          (json['eqBands'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0, 0, 0, 0, 0],
      bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0.0,
      virtualizer: (json['virtualizer'] as num?)?.toDouble() ?? 0.0,
      crossfadeDuration: json['crossfadeDuration'] as int? ?? 0,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      volumeNormalization: json['volumeNormalization'] as bool? ?? false,
      gaplessPlayback: json['gaplessPlayback'] as bool? ?? false,
      sleepTimerFadeOut: json['sleepTimerFadeOut'] as bool? ?? true,
      sleepTimerLastUsedMinutes:
          json['sleepTimerLastUsedMinutes'] as int? ?? 15,
    );
  }

  AudioSettingsState copyWith({
    bool? eqEnabled,
    String? eqPresetId,
    List<double>? eqBands,
    double? bassBoost,
    double? virtualizer,
    int? crossfadeDuration,
    double? playbackSpeed,
    bool? volumeNormalization,
    bool? gaplessPlayback,
    int? sleepTimerMinutes,
    DateTime? sleepTimerEndTime,
    int? sleepTimerTick,
    bool? sleepTimerEndOfTrack,
    bool? sleepTimerFadeOut,
    int? sleepTimerLastUsedMinutes,
    bool clearSleepTimer = false,
  }) {
    return AudioSettingsState(
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqPresetId: eqPresetId ?? this.eqPresetId,
      eqBands: eqBands ?? this.eqBands,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      sleepTimerMinutes: clearSleepTimer
          ? 0
          : (sleepTimerMinutes ?? this.sleepTimerMinutes),
      sleepTimerEndTime: clearSleepTimer
          ? null
          : (sleepTimerEndTime ?? this.sleepTimerEndTime),
      sleepTimerTick: sleepTimerTick ?? this.sleepTimerTick,
      sleepTimerEndOfTrack: clearSleepTimer
          ? false
          : (sleepTimerEndOfTrack ?? this.sleepTimerEndOfTrack),
      sleepTimerFadeOut: sleepTimerFadeOut ?? this.sleepTimerFadeOut,
      sleepTimerLastUsedMinutes:
          sleepTimerLastUsedMinutes ?? this.sleepTimerLastUsedMinutes,
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================

class AudioSettingsNotifier extends StateNotifier<AudioSettingsState> {
  AudioSettingsNotifier(this._ref) : super(const AudioSettingsState()) {
    _loadFromStorage();
  }

  final Ref _ref;

  Timer? _sleepCountdownTimer; // tick a cada 1s → atualiza label
  Timer? _sleepFireTimer; // dispara 1x quando o tempo acabar
  Timer? _sleepFadeStartTimer; // agenda o início do fade (T - 10s)
  Timer? _sleepFadeTickTimer; // tick a cada 100ms durante os 10s de fade

  // Duração do fade-out em segundos.
  static const _kFadeOutSeconds = 10;
  // Quantidade de ticks durante o fade (100ms cada → 100 ticks em 10s).
  static const _kFadeOutTicks = 100;

  // ── Persistência ────────────────────────────────────────

  void _loadFromStorage() {
    final json = SettingsStorageService.loadAudioSettings();
    if (json != null) {
      state = AudioSettingsState.fromJson(json);
    }
  }

  /// Recarrega as configurações de áudio do SharedPreferences — chamado após backup.
  void reloadFromStorage() => _loadFromStorage();

  void _save() => SettingsStorageService.saveAudioSettings(state.toJson());

  // ── EQ ──────────────────────────────────────────────────

  void toggleEq() {
    state = state.copyWith(eqEnabled: !state.eqEnabled);
    _save();
  }

  void setPreset(String presetId) {
    final preset = kEqPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => kEqPresets.first,
    );
    state = state.copyWith(
      eqPresetId: presetId,
      eqBands: List<double>.from(preset.bands),
    );
    _save();
  }

  void setBand(int index, double value) {
    final bands = List<double>.from(state.eqBands);
    bands[index] = value.clamp(-12.0, 12.0);
    state = state.copyWith(eqBands: bands, eqPresetId: 'custom');
    _save();
  }

  void setBassBoost(double value) {
    state = state.copyWith(bassBoost: value.clamp(0.0, 10.0));
    _save();
  }

  void setVirtualizer(double value) {
    state = state.copyWith(virtualizer: value.clamp(0.0, 10.0));
    _save();
  }

  // ── Reprodução ──────────────────────────────────────────

  void setCrossfade(int seconds) {
    state = state.copyWith(crossfadeDuration: seconds.clamp(0, 12));
    _save();
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed.clamp(0.5, 2.0));
    _save();
  }

  void toggleVolumeNormalization() {
    state = state.copyWith(volumeNormalization: !state.volumeNormalization);
    _save();
  }

  void toggleGapless() {
    state = state.copyWith(gaplessPlayback: !state.gaplessPlayback);
    _save();
  }

  // ── Sleep Timer ─────────────────────────────────────────

  /// Configura o sleep timer com [minutes] minutos. [minutes] == 0 cancela.
  /// Se [fadeOut] for omitido, usa a preferência salva.
  void setSleepTimer(int minutes, {bool? fadeOut}) {
    _cancelTimers();

    if (minutes == 0) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    final useFade = fadeOut ?? state.sleepTimerFadeOut;
    final endTime = DateTime.now().add(Duration(minutes: minutes));
    state = state.copyWith(
      sleepTimerMinutes: minutes,
      sleepTimerEndTime: endTime,
      sleepTimerTick: 0,
      sleepTimerEndOfTrack: false,
      sleepTimerLastUsedMinutes: minutes,
    );
    _save();

    // Countdown — atualiza UI a cada segundo (label dinâmico).
    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      state = state.copyWith(sleepTimerTick: state.sleepTimerTick + 1);
    });

    // Fade-out: agenda o início para T - 10s. Só faz sentido se o timer ≥ 11s
    // (margem para o fade caber inteiro antes do pause).
    final totalSecs = minutes * 60;
    if (useFade && totalSecs > _kFadeOutSeconds) {
      _sleepFadeStartTimer = Timer(
        Duration(seconds: totalSecs - _kFadeOutSeconds),
        _runFadeOut,
      );
    }

    // Fire principal — pause + reset volume + clear state.
    _sleepFireTimer = Timer(Duration(minutes: minutes), _onTimerExpire);
  }

  /// Modo "fim da música atual" — sem countdown; pausa quando a faixa terminar.
  /// O hook está em PlayerNotifier._onCompleted que chama [onTrackCompleted].
  void setSleepTimerEndOfTrack() {
    _cancelTimers();
    state = state.copyWith(
      sleepTimerMinutes: 0,
      sleepTimerEndTime: null,
      sleepTimerEndOfTrack: true,
      sleepTimerTick: 0,
    );
  }

  /// Chamado pelo PlayerNotifier quando a faixa atual completou E o modo EoT está ativo.
  void onTrackCompleted() {
    if (!state.sleepTimerEndOfTrack) return;
    _onTimerExpire();
  }

  /// Toggle do fade-out — persiste a preferência.
  void setFadeOut(bool enabled) {
    state = state.copyWith(sleepTimerFadeOut: enabled);
    _save();
  }

  void cancelSleepTimer() {
    _cancelTimers();
    // Restaura volume caso o fade tenha começado.
    _ref.read(playerProvider.notifier).setPlayerVolume(1.0);
    state = state.copyWith(clearSleepTimer: true);
  }

  /// Roda o fade-out de 10s — 100 ticks de 100ms, volume linear 1.0 → 0.0.
  void _runFadeOut() {
    _sleepFadeStartTimer = null;
    var tick = 0;
    _sleepFadeTickTimer = Timer.periodic(const Duration(milliseconds: 100), (
      t,
    ) {
      tick++;
      if (!mounted) {
        t.cancel();
        return;
      }
      final progress = tick / _kFadeOutTicks;
      final v = (1.0 - progress).clamp(0.0, 1.0);
      _ref.read(playerProvider.notifier).setPlayerVolume(v);
      if (tick >= _kFadeOutTicks) {
        t.cancel();
        _sleepFadeTickTimer = null;
      }
    });
  }

  /// Disparado quando o timer principal expira (ou EoT termina): pausa,
  /// limpa estado e RESTAURA o volume para a próxima reprodução.
  void _onTimerExpire() {
    _cancelTimers();
    final notifier = _ref.read(playerProvider.notifier);
    final playerState = _ref.read(playerProvider);
    if (playerState.isPlaying) {
      notifier.pause();
    }
    // Restaura volume — sem isto, a próxima play arranca em volume 0.
    notifier.setPlayerVolume(1.0);
    if (mounted) state = state.copyWith(clearSleepTimer: true);
  }

  void _cancelTimers() {
    _sleepCountdownTimer?.cancel();
    _sleepCountdownTimer = null;
    _sleepFireTimer?.cancel();
    _sleepFireTimer = null;
    _sleepFadeStartTimer?.cancel();
    _sleepFadeStartTimer = null;
    _sleepFadeTickTimer?.cancel();
    _sleepFadeTickTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

// ============================================================
// PROVIDER
// ============================================================

final audioSettingsProvider =
    StateNotifierProvider<AudioSettingsNotifier, AudioSettingsState>(
      (ref) => AudioSettingsNotifier(ref),
    );
