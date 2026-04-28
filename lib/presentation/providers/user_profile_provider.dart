import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:constanza_player/services/settings_storage_service.dart';

class UserProfile {
  const UserProfile({this.name, this.photoPath});

  final String? name;
  final String? photoPath;

  bool get hasName => name != null && name!.trim().isNotEmpty;
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  String get initials {
    if (!hasName) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _load();
  }

  void _load() {
    state = UserProfile(
      name: SettingsStorageService.loadProfileName(),
      photoPath: SettingsStorageService.loadProfilePhoto(),
    );
  }

  Future<void> setName(String? name) async {
    final trimmed = name?.trim();
    state = state.copyWith(name: trimmed);
    await SettingsStorageService.saveProfileName(trimmed);
  }

  /// Opens image picker and copies the chosen image to app documents.
  Future<bool> pickPhoto({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last;
    final dest =
        '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(picked.path).copy(dest);

    // Remove previous photo file
    final prev = state.photoPath;
    if (prev != null && prev.isNotEmpty) {
      try {
        final f = File(prev);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    state = state.copyWith(photoPath: dest);
    await SettingsStorageService.saveProfilePhoto(dest);
    return true;
  }

  Future<void> removePhoto() async {
    final prev = state.photoPath;
    if (prev != null && prev.isNotEmpty) {
      try {
        final f = File(prev);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    state = state.copyWith(clearPhoto: true);
    await SettingsStorageService.saveProfilePhoto(null);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
      (ref) => UserProfileNotifier(),
    );
