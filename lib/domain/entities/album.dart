import 'package:equatable/equatable.dart';

/// Entidade que representa um álbum.
class Album extends Equatable {
  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.songCount = 0,
    this.year,
  });

  final String id;
  final String name;
  final String artist;
  final int songCount;
  final int? year;

  /// ID numérico para buscar artwork.
  int get numericId => int.tryParse(id) ?? 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artist': artist,
    'songCount': songCount,
    'year': year,
  };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json['id'] as String,
    name: json['name'] as String,
    artist: json['artist'] as String,
    songCount: json['songCount'] as int? ?? 0,
    year: json['year'] as int?,
  );

  @override
  List<Object?> get props => [id];
}
