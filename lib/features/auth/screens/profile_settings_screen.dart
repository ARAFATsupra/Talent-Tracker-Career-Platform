import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/user_model.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_providers.dart';

/// S-06 — Profile Settings Screen (redesigned).
/// Accent color adapts to the signed-in user's role.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  static const _roleGradients = {
    UserRole.student: [Color(0xFF1A237E), Color(0xFF1565C0), Color(0xFF0288D1)],
    UserRole.recruiter: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF8E24AA)],
    UserRole.admin: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in.'));
          }
          final gradient = _roleGradients[user.role] ?? _roleGradients[UserRole.student]!;
          final accentColor = gradient[1];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                leading: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ProfilePhoto(user: user, accentColor: accentColor),
                          const SizedBox(height: 12),
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleLabel(user.role),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                backgroundColor: accentColor,
                title: const Text(
                  'Profile Settings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionCard(
                      icon: Icons.person_outline,
                      iconColor: accentColor,
                      title: 'Account Info',
                      children: [
                        _NameEditor(user: user, accentColor: accentColor),
                        const SizedBox(height: 12),
                        _ReadOnlyField(label: 'Email', value: user.email, icon: Icons.email_outlined),
                        if (user.studentId.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ReadOnlyField(
                            label: 'Student / Staff ID',
                            value: user.studentId,
                            icon: Icons.badge_outlined,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.language_rounded,
                      iconColor: accentColor,
                      title: 'Language',
                      children: [_LanguageToggle(user: user, accentColor: accentColor)],
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      icon: Icons.security_rounded,
                      iconColor: accentColor,
                      title: 'Security',
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showChangePasswordDialog(context, ref, accentColor),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentColor,
                              side: BorderSide(color: accentColor.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text('Change Password'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Log Out'),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showDeleteAccountDialog(context, ref),
                        icon: const Icon(Icons.delete_forever_outlined, size: 18),
                        label: const Text('Delete Account'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'STUDENT';
      case UserRole.recruiter:
        return 'RECRUITER';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context, WidgetRef ref, Color accentColor) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (min 6 characters)'),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.reauthenticate(currentController.text);
      await repo.updatePassword(newController.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated.'),
            backgroundColor: const Color(0xFF00695C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        final message = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Current password is incorrect.'
            : 'Could not update password: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile and sign-in. This cannot be undone. '
              'Enter your password to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    if (passwordController.text.isEmpty) return;

    final repo = ref.read(authRepositoryProvider);
    final uid = repo.currentUser?.uid;
    if (uid == null) return;

    try {
      await repo.reauthenticate(passwordController.text);
      await repo.deleteOwnAccount(uid);
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        final message = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Incorrect password.'
            : 'Could not delete account: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ── Section card wrapper ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── Profile photo ──────────────────────────────────────────────────────
class _ProfilePhoto extends ConsumerStatefulWidget {
  const _ProfilePhoto({required this.user, required this.accentColor});

  final UserModel user;
  final Color accentColor;

  @override
  ConsumerState<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends ConsumerState<_ProfilePhoto> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
          ),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage:
                widget.user.profilePhotoUrl != null ? NetworkImage(widget.user.profilePhotoUrl!) : null,
            child: _uploading
                ? const CircularProgressIndicator(color: Colors.white)
                : widget.user.profilePhotoUrl == null
                    ? Text(
                        widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: widget.accentColor, width: 2),
              ),
              child: Icon(Icons.camera_alt, size: 14, color: widget.accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_photos').child(widget.user.uid).child('avatar.jpg');
      await storageRef.putFile(File(picked.path));
      final url = await storageRef.getDownloadURL();

      await ref.read(authRepositoryProvider).updateProfilePhotoUrl(widget.user.uid, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

// ── Name editor ────────────────────────────────────────────────────────
class _NameEditor extends ConsumerStatefulWidget {
  const _NameEditor({required this.user, required this.accentColor});

  final UserModel user;
  final Color accentColor;

  @override
  ConsumerState<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends ConsumerState<_NameEditor> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.user.fullName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Full name',
        prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.accentColor, width: 1.5),
        ),
        suffixIcon: _saving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                icon: Icon(Icons.check, color: widget.accentColor),
                onPressed: _save,
              ),
      ),
      onSubmitted: (_) => _save(),
    );
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty || newName == widget.user.fullName) return;

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateFullName(widget.user.uid, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Name updated.'),
            backgroundColor: widget.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Read-only field ────────────────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: false,
      controller: TextEditingController(text: value),
      style: TextStyle(color: Colors.grey[500], fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[300], size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}

// ── Language toggle ────────────────────────────────────────────────────
class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle({required this.user, required this.accentColor});

  final UserModel user;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _LangOption(
            label: 'English',
            selected: user.preferredLanguage == 'en',
            accentColor: accentColor,
            onTap: () => ref.read(authRepositoryProvider).updatePreferredLanguage(user.uid, 'en'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LangOption(
            label: 'বাংলা',
            selected: user.preferredLanguage == 'bn',
            accentColor: accentColor,
            onTap: () => ref.read(authRepositoryProvider).updatePreferredLanguage(user.uid, 'bn'),
          ),
        ),
      ],
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accentColor : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[600],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}