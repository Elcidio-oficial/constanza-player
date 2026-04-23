import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de persistência de configurações usando SharedPreferences.
///
/// Salva/carrega ThemeState e AudioSettingsState como JSON.
class SettingsStorageService {
  static const _keyTheme = 'constanza_theme_settings';
  static const _keyAudio = 'constanza_audio_settings';
  static const _keyLibrary = 'constanza_library_settings';
  static const _keyFavorites = 'constanza_favorite_ids';
  static const _keyRecentSearches = 'constanza_recent_searches';
  static const _keyLibraryCache = 'constanza_library_cache';
  static const _keyMusicFolders = 'constanza_music_folders';
  static const _keyUserPlaylists = 'constanza_user_playlists';

  static SharedPreferences? _prefs;

  /// Whether init() has been called and completed.
  static bool get isInitialized => _prefs != null;

  /// Acesso seguro ao SharedPreferences — nunca retorna null após init().
  static SharedPreferences get _safePrefs {
    final p = _prefs;
    if (p == null) {
      throw StateError(
        'SettingsStorageService.init() must be called before use',
      );
    }
    return p;
  }

  /// Inicializa o SharedPreferences. Deve ser chamado uma vez no main().
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── THEME ───

  static Map<String, dynamic>? loadTheme() {
    final json = _safePrefs.getString(_keyTheme);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTheme(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyTheme, jsonEncode(data));
  }

  // ─── AUDIO SETTINGS ───

  static Map<String, dynamic>? loadAudioSettings() {
    final json = _safePrefs.getString(_keyAudio);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAudioSettings(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyAudio, jsonEncode(data));
  }

  // ─── LIBRARY SETTINGS ───

  static Map<String, dynamic>? loadLibrarySettings() {
    final json = _safePrefs.getString(_keyLibrary);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLibrarySettings(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyLibrary, jsonEncode(data));
  }

  // ─── FAVORITES ───

  static Set<String> loadFavorites() {
    final list = _safePrefs.getStringList(_keyFavorites);
    return list != null ? Set<String>.from(list) : {};
  }

  static Future<void> saveFavorites(Set<String> ids) async {
    await _safePrefs.setStringList(_keyFavorites, ids.toList());
  }

  // ─── RECENT SEARCHES ───

  static List<String> loadRecentSearches() {
    return _safePrefs.getStringList(_keyRecentSearches) ?? [];
  }

  static Future<void> saveRecentSearches(List<String> searches) async {
    await _safePrefs.setStringList(_keyRecentSearches, searches);
  }

  // ─── LIBRARY CACHE ───

  static Map<String, dynamic>? loadLibraryCache() {
    final json = _safePrefs.getString(_keyLibraryCache);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLibraryCache(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyLibraryCache, jsonEncode(data));
  }

  static bool get hasLibraryCache => _safePrefs.containsKey(_keyLibraryCache);

  // ─── MUSIC FOLDERS ───

  /// Carrega pastas de música selecionadas. Null = nunca configurou (1ª vez).
  static List<String>? loadMusicFolders() {
    final list = _safePrefs.getStringList(_keyMusicFolders);
    return list;
  }

  /// Salva pastas de música selecionadas.
  static Future<void> saveMusicFolders(List<String> folders) async {
    await _safePrefs.setStringList(_keyMusicFolders, folders);
  }

  /// Verifica se o usuário já configurou pastas.
  static bool get hasMusicFolders => _safePrefs.containsKey(_keyMusicFolders);

  // ─── USER PLAYLISTS ───

  static String? loadUserPlaylists() {
    return _safePrefs.getString(_keyUserPlaylists);
  }

  static Future<void> saveUserPlaylists(String jsonString) async {
    await _safePrefs.setString(_keyUserPlaylists, jsonString);
  }

  // ─── PLAYBACK HISTORY ───

  static const _keyHistory = 'constanza_play_history';

  static Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    await _safePrefs.setString(_keyHistory, jsonEncode(history));
  }

  static List<Map<String, dynamic>> loadHistory() {
    final raw = _safePrefs.getString(_keyHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── PLAY COUNTS ───

  static const _keyPlayCounts = 'constanza_play_counts';

  static Future<void> savePlayCounts(Map<String, int> counts) async {
    await _safePrefs.setString(_keyPlayCounts, jsonEncode(counts));
  }

  static Map<String, int> loadPlayCounts() {
    final raw = _safePrefs.getString(_keyPlayCounts);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  // ─── PLAYBACK STATE ───

  static const _keyPlaybackState = 'constanza_playback_state';

  static Future<void> savePlaybackState(Map<String, dynamic> data) async {
    await _safePrefs.setString(_keyPlaybackState, jsonEncode(data));
  }

  static Map<String, dynamic>? loadPlaybackState() {
    final json = _safePrefs.getString(_keyPlaybackState);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── HELPERS ───

  // ignore: deprecated_member_use
  /// Converte Color para int (para serialização).
  // ignore: deprecated_member_use
  static int? colorToInt(Color? color) => color?.value;

  /// Converte int para Color.
  // ignore: deprecated_member_use
  static Color? intToColor(int? value) => value != null ? Color(value) : null;
}
