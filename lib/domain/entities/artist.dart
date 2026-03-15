import 'package:equatable/equatable.dart';

/// Entidade que representa um artista.
class Artist extends Equatable {
  const Artist({
    required this.id,
    required this.name,
    this.songCount = 0,
    this.albumCount = 0,
  });

  final String id;
  final String name;
  final int songCount;
  final int albumCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songCount': songCount,
    'albumCount': albumCount,
  };

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json['id'] as String,
    name: json['name'] as String,
    songCount: json['songCount'] as int? ?? 0,
    albumCount: json['albumCount'] as int? ?? 0,
  );

  @override
  List<Object?> get props => [id];
}
