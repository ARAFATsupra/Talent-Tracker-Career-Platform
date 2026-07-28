import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/admin_providers.dart';

/// S-30 — Broadcast Notification Screen (redesigned).
class BroadcastNotificationScreen extends ConsumerStatefulWidget {
  const BroadcastNotificationScreen({super.key});

  @override
  ConsumerState<BroadcastNotificationScreen> createState() => _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState extends ConsumerState<BroadcastNotificationScreen> {
  String _target = 'all';
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  DateTime? _scheduledFor;
  bool _sending = false;

  static const _targetInfo = {
    'all': (Icons.groups_rounded, 'All'),
    'student': (Icons.school_rounded, 'Students'),
    'recruiter': (Icons.business_center_rounded, 'Recruiters'),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'Broadcast Notification',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Target card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.send_to_mobile_rounded, size: 16, color: Color(0xFF00897B)),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Send To',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: _targetInfo.entries.map((entry) {
                          final selected = _target == entry.key;
                          final (icon, label) = entry.value;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () => setState(() => _target = entry.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)])
                                        : null,
                                    color: selected ? null : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selected ? Colors.transparent : Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(icon, size: 20, color: selected ? Colors.white : Colors.grey[500]),
                                      const SizedBox(height: 6),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                          color: selected ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Message card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF00897B)),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Message',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _titleController,
                        label: 'Message title',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _bodyController,
                        label: 'Message body',
                        maxLines: 4,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Schedule card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFE65100)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scheduledFor == null ? 'Send immediately' : 'Scheduled',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (_scheduledFor != null)
                              Text(
                                DateFormat('MMM d, yyyy h:mm a').format(_scheduledFor!),
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                      ),
                      if (_scheduledFor != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: Colors.grey[400],
                          onPressed: () => setState(() => _scheduledFor = null),
                        ),
                      TextButton(
                        onPressed: _pickSchedule,
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF00897B)),
                        child: Text(_scheduledFor == null ? 'Schedule' : 'Change'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Send button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _canSend
                          ? const [Color(0xFF00695C), Color(0xFF00897B)]
                          : [Colors.grey[400]!, Colors.grey[400]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canSend
                        ? [BoxShadow(color: const Color(0xFF00695C).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _canSend ? _send : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _sending
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    _scheduledFor == null ? 'SEND NOW' : 'QUEUE BROADCAST',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSend =>
      !_sending && _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty;

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final count = await ref.read(adminRepositoryProvider).sendBroadcast(
            target: _target,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            scheduledFor: _scheduledFor,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast sent to $count recipient(s).'),
            backgroundColor: const Color(0xFF00695C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _titleController.clear();
        _bodyController.clear();
        setState(() => _scheduledFor = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send broadcast: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ── Reusable field ─────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
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
          borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}