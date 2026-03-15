import 'package:equatable/equatable.dart';

/// Representa uma linha de letra de música.
///
/// [timestamp] é opcional — quando presente, a linha é sincronizada
/// com o tempo de reprodução e fica em negrito durante a passagem.
class LyricLine extends Equatable {
  const LyricLine({this.timestamp, required this.text});

  final Duration? timestamp;
  final String text;

  bool get isSynced => timestamp != null;
  bool get isEmpty => text.trim().isEmpty;

  /// Formata o timestamp no estilo LRC: [m:ss.xx]
  String get formattedTimestamp {
    if (timestamp == null) return '--:--';
    final m = timestamp!.inMinutes;
    final s = timestamp!.inSeconds.remainder(60);
    final cs = (timestamp!.inMilliseconds.remainder(1000) / 10).round();
    return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  LyricLine copyWith({Duration? timestamp, bool clearTimestamp = false, String? text}) {
    return LyricLine(
      timestamp: clearTimestamp ? null : (timestamp ?? this.timestamp),
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp_ms': timestamp?.inMilliseconds,
    'text': text,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    timestamp: json['timestamp_ms'] != null
        ? Duration(milliseconds: json['timestamp_ms'] as int)
        : null,
    text: json['text'] as String? ?? '',
  );

  @override
  List<Object?> get props => [timestamp, text];
}
