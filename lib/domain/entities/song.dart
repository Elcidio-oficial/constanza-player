import 'package:equatable/equatable.dart';

/// Entidade que representa uma música.
class Song extends Equatable {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.uri = '',
    this.filePath = '',
    this.trackNumber,
    this.albumId,
    this.artistId,
    this.dateAdded,
    this.genre,
    this.composer,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String uri;
  final String filePath;
  final int? trackNumber;
  final String? albumId;
  final String? artistId;
  final DateTime? dateAdded;
  final String? genre;
  final String? composer;
  final bool isFavorite;

  /// Pasta onde o ficheiro está.
  String get folderPath {
    if (filePath.isEmpty) return '';
    final idx = filePath.lastIndexOf('/');
    return idx > 0 ? filePath.substring(0, idx) : filePath;
  }

  /// Duração formatada (m:ss).
  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// ID numérico para buscar artwork.
  int get numericId => int.tryParse(id) ?? 0;

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? uri,
    String? filePath,
    int? trackNumber,
    String? albumId,
    String? artistId,
    DateTime? dateAdded,
    String? genre,
    String? composer,
    bool? isFavorite,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      filePath: filePath ?? this.filePath,
      trackNumber: trackNumber ?? this.trackNumber,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      dateAdded: dateAdded ?? this.dateAdded,
      genre: genre ?? this.genre,
      composer: composer ?? this.composer,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration.inMilliseconds,
    'uri': uri,
    'filePath': filePath,
    'trackNumber': trackNumber,
    'albumId': albumId,
    'artistId': artistId,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
    'genre': genre,
    'composer': composer,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    duration: Duration(milliseconds: json['duration'] as int),
    uri: json['uri'] as String? ?? '',
    filePath: json['filePath'] as String? ?? '',
    trackNumber: json['trackNumber'] as int?,
    albumId: json['albumId'] as String?,
    artistId: json['artistId'] as String?,
    dateAdded: json['dateAdded'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['dateAdded'] as int)
        : null,
    genre: json['genre'] as String?,
    composer: json['composer'] as String?,
  );

  @override
  List<Object?> get props => [id];
}
