import 'package:equatable/equatable.dart';
import 'package:constanza_player/domain/entities/song.dart';

/// Entidade que representa uma playlist.
class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.iconData,
    this.isSmartPlaylist = false,
    this.createdAt,
    this.updatedAt,
    this.imagePath,
    this.description,
  });

  final String id;
  final String name;
  final List<Song> songs;
  final int? iconData;
  final bool isSmartPlaylist;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Caminho da imagem personalizada da playlist (file picker)
  final String? imagePath;
  /// Descrição opcional da playlist
  final String? description;

  int get songCount => songs.length;

  bool get hasCustomImage => imagePath != null && imagePath!.isNotEmpty;

  /// Duração total formatada
  String get totalDuration {
    final total = songs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}min';
    return '$minutes min';
  }

  Playlist copyWith({
    String? id,
    String? name,
    List<Song>? songs,
    int? iconData,
    bool? isSmartPlaylist,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? description,
    bool clearImage = false,
    bool clearDescription = false,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      iconData: iconData ?? this.iconData,
      isSmartPlaylist: isSmartPlaylist ?? this.isSmartPlaylist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  /// Serializa para persistência (apenas metadados, sem músicas).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isSmartPlaylist': isSmartPlaylist,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'imagePath': imagePath,
    'description': description,
    'songIds': songs.map((s) => s.id).toList(),
  };

  /// Reconstrói a partir de JSON (sem músicas — serão resolvidas pelo provider).
  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    isSmartPlaylist: json['isSmartPlaylist'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
        : null,
    imagePath: json['imagePath'] as String?,
    description: json['description'] as String?,
  );

  /// IDs de músicas salvos no JSON (usados na restauração).
  static List<String> songIdsFromJson(Map<String, dynamic> json) {
    final raw = json['songIds'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  @override
  List<Object?> get props => [id];
}
