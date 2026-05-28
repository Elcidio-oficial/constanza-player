import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:constanza_player/core/theme/app_spacing.dart';
import 'package:constanza_player/presentation/providers/artwork_provider.dart';
import 'package:constanza_player/presentation/providers/theme_provider.dart';
import 'package:constanza_player/presentation/providers/user_profile_provider.dart';
import 'package:constanza_player/l10n/gen/app_localizations.dart';

/// Premium header with greeting + avatar. Tap to edit profile.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  String _greeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = DateTime.now().hour;
    if (h < 6) return l10n.profileGreetingLateNight;
    if (h < 12) return l10n.profileGreetingMorning;
    if (h < 18) return l10n.profileGreetingAfternoon;
    return l10n.profileGreetingNight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = ref.watch(userProfileProvider);
    final palette = ref.watch(artworkPaletteProvider);
    final themeState = ref.watch(themeProvider);

    final accent = palette?.vibrant ?? colors.primary;
    final accent2 = palette?.secondary ?? colors.tertiary;
    final accent3 = palette?.muted ?? colors.primaryContainer;

    final l10n = AppLocalizations.of(context);
    final name = profile.hasName ? profile.name! : l10n.profileTapToCreate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showEditSheet(context, ref),
        child: Row(
          children: [
            _PremiumAvatar(
              profile: profile,
              accent: accent,
              accent2: accent2,
              accent3: accent3,
              size: 56,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(context),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 1.4,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      shadows: themeState.hasBackground
                          ? [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: profile.hasName
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w300,
                      fontSize: 22,
                      letterSpacing: -0.3,
                      shadows: themeState.hasBackground
                          ? [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onSurface.withValues(alpha: 0.05),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 16,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showEditSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProfileEditSheet(),
    );
  }
}

class _PremiumAvatar extends StatelessWidget {
  const _PremiumAvatar({
    required this.profile,
    required this.accent,
    required this.accent2,
    required this.accent3,
    required this.size,
  });

  final UserProfile profile;
  final Color accent;
  final Color? accent2;
  final Color accent3;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size - 6;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [accent, accent2 ?? accent3, accent3, accent],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Container(
          width: inner,
          height: inner,
          color: Colors.black,
          child: profile.hasPhoto
              ? Image.file(
                  File(profile.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _InitialsTile(initials: profile.initials, accent: accent),
                )
              : _InitialsTile(initials: profile.initials, accent: accent),
        ),
      ),
    );
  }
}

class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.initials, required this.accent});
  final String initials;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.8),
            accent.withValues(alpha: 0.3),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ============================================================
// EDIT SHEET
// ============================================================

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet();

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(userProfileProvider).name ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final ok = await ref
        .read(userProfileProvider.notifier)
        .pickPhoto(source: source);
    if (!mounted) return;
    if (!ok) return;
  }

  Future<void> _save() async {
    await ref.read(userProfileProvider.notifier).setName(_nameCtrl.text);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = ref.watch(userProfileProvider);
    final palette = ref.watch(artworkPaletteProvider);
    final accent = palette?.vibrant ?? colors.primary;
    final accent2 = palette?.secondary ?? colors.tertiary;
    final accent3 = palette?.muted ?? colors.primaryContainer;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(color: colors.outline.withValues(alpha: 0.15)),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  AppLocalizations.of(context).profileTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GestureDetector(
                  onTap: () => _showPhotoOptions(context, profile.hasPhoto),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _PremiumAvatar(
                        profile: profile,
                        accent: accent,
                        accent2: accent2,
                        accent3: accent3,
                        size: 104,
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(color: colors.surface, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).profileNameLabel,
                    hintText: AppLocalizations.of(context).profileNameHint,
                    counterText: '',
                    filled: true,
                    fillColor: colors.onSurface.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(
                        color: colors.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(
                        color: colors.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).commonSave,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, bool hasPhoto) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                AppLocalizations.of(context).bgSettingsPickFromGallery,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(AppLocalizations.of(context).profileTakePhoto),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context).profileRemovePhoto,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(userProfileProvider.notifier).removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
