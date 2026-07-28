import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../providers/admin_providers.dart';

/// S-26 — User Management Screen (redesigned).
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _query = '';
  UserRole? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            leading: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF004D40),
                      Color(0xFF00695C),
                      Color(0xFF00897B),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF00695C),
            title: const Text(
              'User Management',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          usersAsync.when(
            data: (users) {
              final filtered = users.where((u) {
                final matchesQuery = _query.isEmpty ||
                    u.fullName.toLowerCase().contains(_query.toLowerCase()) ||
                    u.email.toLowerCase().contains(_query.toLowerCase());
                final matchesRole = _roleFilter == null || u.role == _roleFilter;
                return matchesQuery && matchesRole;
              }).toList();

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Search box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search name or email…',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Role filter chips
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _RoleFilterChip(
                            label: 'All',
                            color: const Color(0xFF00897B),
                            selected: _roleFilter == null,
                            onTap: () => setState(() => _roleFilter = null),
                          ),
                          const SizedBox(width: 8),
                          for (final role in UserRole.values) ...[
                            _RoleFilterChip(
                              label: _roleLabel(role),
                              color: _roleColor(role),
                              selected: _roleFilter == role,
                              onTap: () => setState(() => _roleFilter = role),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No users match your search.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      )
                    else
                      for (final user in filtered) _UserRow(user: user),
                    const SizedBox(height: 16),
                  ]),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Could not load users: $e'))),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.recruiter:
        return 'Recruiter';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const Color(0xFF1565C0);
      case UserRole.recruiter:
        return const Color(0xFF6A1B9A);
      case UserRole.admin:
        return const Color(0xFF00897B);
    }
  }
}

// ── Role filter chip ───────────────────────────────────────────────────
class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ── User row card ──────────────────────────────────────────────────────
class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = _roleColor(user.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_roleIcon(user.role), color: roleColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: user.isActive,
                activeColor: const Color(0xFF00897B),
                onChanged: (value) => ref.read(adminRepositoryProvider).setUserActive(user.uid, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _roleLabel(user.role),
                  style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              _MiniActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF1565C0),
                onTap: () => _showEditRoleDialog(context, ref),
              ),
              const SizedBox(width: 8),
              _MiniActionButton(
                icon: Icons.delete_outline,
                color: const Color(0xFFD32F2F),
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
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

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const Color(0xFF1565C0);
      case UserRole.recruiter:
        return const Color(0xFF6A1B9A);
      case UserRole.admin:
        return const Color(0xFF00897B);
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school_rounded;
      case UserRole.recruiter:
        return Icons.business_center_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Future<void> _showEditRoleDialog(BuildContext context, WidgetRef ref) async {
    final selected = await showDialog<UserRole>(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change role — ${user.fullName}'),
        children: UserRole.values
            .map((role) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, role),
                  child: Row(
                    children: [
                      if (role == user.role) Icon(Icons.check, size: 18, color: _roleColor(role)),
                      if (role == user.role) const SizedBox(width: 8),
                      Text(_roleLabel(role)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null && selected != user.role) {
      await ref.read(adminRepositoryProvider).setUserRole(user.uid, selected);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this profile?'),
        content: Text(
          'This removes ${user.fullName}\'s Firestore profile. Their Firebase Auth '
          'account is NOT deleted. Consider deactivating instead unless you '
          'specifically need this.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminRepositoryProvider).deleteUserProfile(user.uid);
    }
  }
}

// ── Mini action button ─────────────────────────────────────────────────
class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}