import 'package:flutter_riverpod/legacy.dart';
import 'package:constanza_player/domain/entities/lyric_line.dart';
import 'package:constanza_player/services/lyrics_service.dart';

// ============================================================
// STATE
// ============================================================

class LyricsState {
  const LyricsState({
    this.songId,
    this.lines = const [],
    this.isEditing = false,
    this.isLoaded = false,
    this.onlineMiss = false,
  });

  final String? songId;
  final List<LyricLine> lines;
  final bool isEditing;
  final bool isLoaded;

  /// `true` quando já se confirmou que não existe letra online para esta
  /// música (busca feita e esgotada). Persistido entre sessões.
  final bool onlineMiss;

  bool get isEmpty => lines.isEmpty;
  bool get hasSyncedLines => lines.any((l) => l.isSynced);

  /// Retorna o índice da linha mais recente ≤ [position], ou -1 se nenhuma.
  int currentLineIndex(Duration position) {
    if (!hasSyncedLines) return -1;
    int idx = -1;
    for (int i = 0; i < lines.length; i++) {
      final ts = lines[i].timestamp;
      if (ts != null && ts <= position) idx = i;
    }
    return idx;
  }

  LyricsState copyWith({
    String? songId,
    List<LyricLine>? lines,
    bool? isEditing,
    bool? isLoaded,
    bool? onlineMiss,
  }) {
    return LyricsState(
      songId: songId ?? this.songId,
      lines: lines ?? this.lines,
      isEditing: isEditing ?? this.isEditing,
      isLoaded: isLoaded ?? this.isLoaded,
      onlineMiss: onlineMiss ?? this.onlineMiss,
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================

class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier() : super(const LyricsState());

  // ── Carregamento ─────────────────────────────────────────

  Future<void> loadForSong(String songId) async {
    if (state.songId == songId && state.isLoaded) return;
    await LyricsService.init();
    final lines = LyricsService.load(songId);
    state = LyricsState(
      songId: songId,
      lines: lines,
      isLoaded: true,
      onlineMiss: lines.isEmpty && LyricsService.isMarkedMissing(songId),
    );
  }

  void unload() {
    state = const LyricsState();
  }

  /// Aplica letras vindas de uma busca online para [songId].
  ///
  /// Persiste **sempre** na chave correta ([songId]); só atualiza o estado
  /// visível quando o provider ainda está nessa música. É o guard de corrida:
  /// sem ele, uma busca lenta da faixa anterior aplicava o resultado na faixa
  /// atual após um skip ("letra da música A aparecendo na B"). O trabalho de
  /// rede não se perde — fica gravado na música certa para quando voltar a ela.
  Future<void> applyOnlineResult(String songId, List<LyricLine> lines) async {
    if (lines.isEmpty) return;
    await LyricsService.init();
    await LyricsService.save(songId, lines);
    if (state.songId == songId) {
      state = state.copyWith(lines: lines, onlineMiss: false, isLoaded: true);
    }
  }

  /// Regista o resultado de uma busca online esgotada (nada encontrado) para
  /// [songId], persistindo para não repetir a busca automática. Mesmo guard de
  /// corrida do [applyOnlineResult]: só reflete no estado se ainda for a música
  /// atual — assim um skip não marca a faixa nova como "sem letra".
  Future<void> markOnlineMissFor(String songId) async {
    await LyricsService.init();
    await LyricsService.markMissing(songId);
    if (state.songId == songId) {
      state = state.copyWith(onlineMiss: true);
    }
  }

  // ── Modo edição ─────────────────────────────────────────

  void toggleEdit() => state = state.copyWith(isEditing: !state.isEditing);

  void cancelEdit() => state = state.copyWith(isEditing: false);

  // ── CRUD de linhas ───────────────────────────────────────

  void addLine({Duration? timestamp, String text = ''}) {
    final newLine = LyricLine(timestamp: timestamp, text: text);
    final updated = List<LyricLine>.from(state.lines)..add(newLine);
    _sortAndUpdate(updated);
  }

  void updateLine(
    int index, {
    Duration? timestamp,
    bool clearTimestamp = false,
    String? text,
  }) {
    if (index < 0 || index >= state.lines.length) return;
    final updated = List<LyricLine>.from(state.lines);
    updated[index] = updated[index].copyWith(
      timestamp: timestamp,
      clearTimestamp: clearTimestamp,
      text: text,
    );
    _sortAndUpdate(updated);
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final updated = List<LyricLine>.from(state.lines)..removeAt(index);
    state = state.copyWith(lines: updated);
  }

  void reorderLines(int oldIndex, int newIndex) {
    final updated = List<LyricLine>.from(state.lines);
    if (oldIndex < newIndex) newIndex--;
    final line = updated.removeAt(oldIndex);
    updated.insert(newIndex, line);
    state = state.copyWith(lines: updated);
  }

  // ── Persistência ─────────────────────────────────────────

  Future<void> save() async {
    if (state.songId == null) return;
    await LyricsService.save(state.songId!, state.lines);
    state = state.copyWith(isEditing: false);
  }

  Future<void> deleteAll() async {
    if (state.songId == null) return;
    await LyricsService.delete(state.songId!);
    state = state.copyWith(lines: [], isEditing: false);
  }

  // ── Importação LRC ───────────────────────────────────────

  Future<void> importLrc(String lrcText) async {
    final lines = LyricsService.parseLrc(lrcText);
    state = state.copyWith(lines: lines, onlineMiss: false);
    // Persiste imediatamente
    if (state.songId != null) {
      await LyricsService.save(state.songId!, lines);
    }
  }

  Future<void> importPlainText(String text) async {
    final lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => LyricLine(text: l.trim()))
        .toList();
    state = state.copyWith(lines: lines, onlineMiss: false);
    if (state.songId != null) {
      await LyricsService.save(state.songId!, lines);
    }
  }

  String exportLrc() => LyricsService.exportLrc(state.lines);

  // ── Helpers ──────────────────────────────────────────────

  void _sortAndUpdate(List<LyricLine> lines) {
    // Linhas sincronizadas ficam ordenadas por timestamp;
    // linhas sem timestamp ficam no final na ordem de inserção.
    final synced = lines.where((l) => l.isSynced).toList()
      ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
    final unsynced = lines.where((l) => !l.isSynced).toList();
    state = state.copyWith(lines: [...synced, ...unsynced]);
  }
}

// ============================================================
// PROVIDER
// ============================================================

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>(
  (ref) => LyricsNotifier(),
);
