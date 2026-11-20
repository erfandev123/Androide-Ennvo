// ============================================================================
//  ENNVO — EDIT PROFILE SCREEN
//
//  Ported from `src/pages/EditProfile.tsx`: avatar upload, name, handle,
//  multiline bio, and link, synced back into AuthController.
// ============================================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/services/upload_service.dart';
import '../../shared/icons/lucide_icons.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/inputs.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _link;

  File? _pickedAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _username = TextEditingController(text: user?.username ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _link = TextEditingController(text: user?.link ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      setState(() => _pickedAvatar = File(photo.path));
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final auth = ref.read(authControllerProvider);
      final uid = auth.user?.uid;
      final firestore = ref.read(firestoreProvider);

      String? uploadedAvatarUrl;
      if (_pickedAvatar != null) {
        try {
          final uploaded = await UploadService.uploadFile(
            file: _pickedAvatar!,
            folder: 'avatars',
          );
          uploadedAvatarUrl = uploaded.url;
        } catch (_) {
          uploadedAvatarUrl = null;
        }
      }

      final name = _name.text.trim();
      final username = _username.text.trim();
      final bio = _bio.text.trim();
      final link = _link.text.trim();

      if (uid != null && firestore != null) {
        final updates = <String, dynamic>{
          'name': name,
          'username': username,
          'bio': bio,
          'link': link,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (uploadedAvatarUrl != null && uploadedAvatarUrl.isNotEmpty) {
          updates['avatar'] = uploadedAvatarUrl;
        }
        await firestore
            .collection('users')
            .doc(uid)
            .set(updates, SetOptions(merge: true));
      }

      auth.updateLocalProfile(
        name: name,
        username: username,
        bio: bio,
        link: link,
        avatar: uploadedAvatarUrl,
      );
      await auth.refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      ref.read(navControllerProvider).popPage();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save profile changes.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final user = ref.watch(authControllerProvider).user;
    final avatarUrl = user?.avatar ?? '';

    ImageProvider? avatarImage;
    if (_pickedAvatar != null) {
      avatarImage = FileImage(_pickedAvatar!);
    } else if (avatarUrl.isNotEmpty) {
      avatarImage = ResizeImage(NetworkImage(avatarUrl), width: 180);
    }

    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(6, top + 6, 16, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => ref.read(navControllerProvider).popPage(),
                  icon: LucideIcon(
                    LucideIcons.arrowLeft,
                    size: 22,
                    strokeWidth: 2.3,
                    color: t.textPrimary,
                  ),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saving...' : 'Save',
                    style: EnnvoText.bodySemi.copyWith(
                      color: _saving ? t.textTertiary : t.accent,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.surfaceAlt,
                            image: avatarImage == null
                                ? null
                                : DecorationImage(
                                    image: avatarImage,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: avatarImage == null
                              ? Icon(
                                  Icons.person_outline_rounded,
                                  size: 40,
                                  color: t.textTertiary,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppGradients.settingsTile,
                              border: Border.all(
                                color: t.background,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                EnnvoTextField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Your name',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                EnnvoTextField(
                  label: 'Username',
                  controller: _username,
                  hint: 'yourhandle',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                EnnvoTextField(
                  label: 'Bio',
                  controller: _bio,
                  hint: 'Tell people about yourself',
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 18),
                EnnvoTextField(
                  label: 'Link',
                  controller: _link,
                  hint: 'https://',
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 26),

                EnnvoPrimaryButton(
                  label: 'Save changes',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
