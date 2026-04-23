import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:constanza_player/domain/entities/lyric_line.dart';

/// Serviço de persistência de letras de músicas.
///
/// Cada canção tem suas letras guardadas em SharedPreferences com a chave
/// `lyrics_v1_{songId}` como JSON array de linhas.
/// Suporta importação e exportação no formato LRC padrão.
class LyricsService {
  static const _prefix = 'lyrics_v1_';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ── CRUD ───────────────────────────────────────────────────

  static List<LyricLine> load(String songId) {
    final raw = _prefs?.getString('$_prefix$songId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String songId, List<LyricLine> lines) async {
    await _prefs?.setString(
      '$_prefix$songId',
      jsonEncode(lines.map((l) => l.toJson()).toList()),
    );
  }

  static Future<void> delete(String songId) async {
    await _prefs?.remove('$_prefix$songId');
  }

  // ── LRC Import/Export ───────────────────────────────────────

  /// Parseia texto no formato LRC e retorna lista de [LyricLine].
  /// Suporta `[m:ss.xx]`, `[m:ss.x]`, `[mm:ss]`.
  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final lineRegex = RegExp(r'^\[(\d+):(\d+)(?:\.(\d+))?\](.*)$');
    final metaRegex = RegExp(r'^\[(ar|ti|al|by|offset|length):.*\]$');

    for (final rawLine in lrc.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      if (metaRegex.hasMatch(trimmed)) continue; // ignora tags LRC de metadados

      final match = lineRegex.firstMatch(trimmed);
      if (match != null) {
        final mins = int.parse(match.group(1)!);
        final secs = int.parse(match.group(2)!);
        final cs = match.group(3);
        final msExtra = cs != null ? _centisToMs(cs) : 0;
        final ms = (mins * 60 + secs) * 1000 + msExtra;
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(
            LyricLine(
              timestamp: Duration(milliseconds: ms),
              text: text,
            ),
          );
        }
      } else if (!trimmed.startsWith('[')) {
        // Linha sem timestamp — adicionada como não sincronizada
        lines.add(LyricLine(text: trimmed));
      }
    }

    // Ordena as linhas sincronizadas por timestamp
    lines.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    return lines;
  }

  /// Exporta a lista de linhas no formato LRC padrão.
  static String exportLrc(List<LyricLine> lines) {
    final buf = StringBuffer();
    for (final line in lines) {
      if (line.isSynced) {
        final m = line.timestamp!.inMinutes;
        final s = line.timestamp!.inSeconds.remainder(60);
        final cs = (line.timestamp!.inMilliseconds.remainder(1000) / 10)
            .round();
        buf.writeln(
          '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}]${line.text}',
        );
      } else {
        buf.writeln(line.text);
      }
    }
    return buf.toString().trimRight();
  }

  static int _centisToMs(String cs) {
    // Converte "xx", "x" ou "xxx" para millisegundos
    if (cs.length == 1) return int.parse(cs) * 100;
    if (cs.length == 2) return int.parse(cs) * 10;
    if (cs.length >= 3) return int.parse(cs.substring(0, 3));
    return 0;
  }
}
