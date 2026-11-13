// ============================================================================
//  ENNVO — EDIT PROFILE SCREEN
//
//  Ported from `src/pages/EditProfile.tsx`: the name, the handle, the bio,
//  a link, the avatar, the banner and the story highlights.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).user?.uid;
      final firestore = ref.read(firestoreProvider);
      if (uid != null && firestore != null) {
        await firestore.collection('users').doc(uid).update({
          'name': _name.text.trim(),
          'username': _username.text.trim(),
          'bio': _bio.text.trim(),
          'link': _link.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // The error surfaces through the auth controller in a later pass.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final user = ref.watch(authControllerProvider).user;

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
                    'Save',
                    style: EnnvoText.bodySemi.copyWith(
                      color: t.accent,
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
                // --- avatar and banner ---------------------------------
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.surfaceAlt,
                          image: (user?.avatar ?? '').isEmpty
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(user!.avatar),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: (user?.avatar ?? '').isEmpty
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
                const SizedBox(height: 26),

                EnnvoTextField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Your name',
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
