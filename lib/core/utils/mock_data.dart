import 'package:constanza_player/domain/entities/song.dart';
import 'package:constanza_player/domain/entities/album.dart';
import 'package:constanza_player/domain/entities/artist.dart';

/// Dados mock para desenvolvimento da UI.
/// Será removido na Fase 4 quando conectarmos ao dispositivo.
abstract final class MockData {
  static const List<Song> songs = [
    Song(
      id: '1',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      album: 'A Night at the Opera',
      duration: Duration(minutes: 5, seconds: 55),
      isFavorite: true,
    ),
    Song(
      id: '2',
      title: 'Stairway to Heaven',
      artist: 'Led Zeppelin',
      album: 'Led Zeppelin IV',
      duration: Duration(minutes: 8, seconds: 2),
    ),
    Song(
      id: '3',
      title: 'Hotel California',
      artist: 'Eagles',
      album: 'Hotel California',
      duration: Duration(minutes: 6, seconds: 30),
      isFavorite: true,
    ),
    Song(
      id: '4',
      title: 'Comfortably Numb',
      artist: 'Pink Floyd',
      album: 'The Wall',
      duration: Duration(minutes: 6, seconds: 22),
    ),
    Song(
      id: '5',
      title: 'Sweet Child O\' Mine',
      artist: 'Guns N\' Roses',
      album: 'Appetite for Destruction',
      duration: Duration(minutes: 5, seconds: 56),
    ),
    Song(
      id: '6',
      title: 'Imagine',
      artist: 'John Lennon',
      album: 'Imagine',
      duration: Duration(minutes: 3, seconds: 7),
      isFavorite: true,
    ),
    Song(
      id: '7',
      title: 'Smells Like Teen Spirit',
      artist: 'Nirvana',
      album: 'Nevermind',
      duration: Duration(minutes: 5, seconds: 1),
    ),
    Song(
      id: '8',
      title: 'Billie Jean',
      artist: 'Michael Jackson',
      album: 'Thriller',
      duration: Duration(minutes: 4, seconds: 54),
    ),
    Song(
      id: '9',
      title: 'Yesterday',
      artist: 'The Beatles',
      album: 'Help!',
      duration: Duration(minutes: 2, seconds: 5),
    ),
    Song(
      id: '10',
      title: 'Purple Rain',
      artist: 'Prince',
      album: 'Purple Rain',
      duration: Duration(minutes: 8, seconds: 41),
      isFavorite: true,
    ),
    Song(
      id: '11',
      title: 'Like a Rolling Stone',
      artist: 'Bob Dylan',
      album: 'Highway 61 Revisited',
      duration: Duration(minutes: 6, seconds: 13),
    ),
    Song(
      id: '12',
      title: 'What\'s Going On',
      artist: 'Marvin Gaye',
      album: 'What\'s Going On',
      duration: Duration(minutes: 3, seconds: 53),
    ),
  ];

  static const List<Album> albums = [
    Album(
      id: 'a1',
      name: 'A Night at the Opera',
      artist: 'Queen',
      songCount: 12,
      year: 1975,
    ),
    Album(
      id: 'a2',
      name: 'Led Zeppelin IV',
      artist: 'Led Zeppelin',
      songCount: 8,
      year: 1971,
    ),
    Album(
      id: 'a3',
      name: 'Hotel California',
      artist: 'Eagles',
      songCount: 9,
      year: 1976,
    ),
    Album(
      id: 'a4',
      name: 'The Wall',
      artist: 'Pink Floyd',
      songCount: 26,
      year: 1979,
    ),
    Album(
      id: 'a5',
      name: 'Thriller',
      artist: 'Michael Jackson',
      songCount: 9,
      year: 1982,
    ),
    Album(
      id: 'a6',
      name: 'Nevermind',
      artist: 'Nirvana',
      songCount: 12,
      year: 1991,
    ),
  ];

  static const List<Artist> artists = [
    Artist(id: 'ar1', name: 'Queen', albumCount: 1, songCount: 1),
    Artist(id: 'ar2', name: 'Led Zeppelin', albumCount: 1, songCount: 1),
    Artist(id: 'ar3', name: 'Eagles', albumCount: 1, songCount: 1),
    Artist(id: 'ar4', name: 'Pink Floyd', albumCount: 1, songCount: 1),
    Artist(id: 'ar5', name: 'Michael Jackson', albumCount: 1, songCount: 1),
    Artist(id: 'ar6', name: 'Nirvana', albumCount: 1, songCount: 1),
    Artist(id: 'ar7', name: 'John Lennon', albumCount: 1, songCount: 1),
    Artist(id: 'ar8', name: 'The Beatles', albumCount: 1, songCount: 1),
    Artist(id: 'ar9', name: 'Prince', albumCount: 1, songCount: 1),
    Artist(id: 'ar10', name: 'Bob Dylan', albumCount: 1, songCount: 1),
  ];
}
