import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/system_log_model.dart';
import '../providers/admin_providers.dart';

/// S-31 — System Error Log Screen (redesigned).
class SystemErrorLogScreen extends ConsumerStatefulWidget {
  const SystemErrorLogScreen({super.key});

  @override
  ConsumerState<SystemErrorLogScreen> createState() => _SystemErrorLogScreenState();
}

class _SystemErrorLogScreenState extends ConsumerState<SystemErrorLogScreen> {
  LogSeverity? _severityFilter;
  bool _hideResolved = true;

  static const _severityInfo = {
    null: ('All', Color(0xFF00897B)),
    LogSeverity.error: ('ERROR', Color(0xFFD32F2F)),
    LogSeverity.warning: ('WARN', Color(0xFFEF6C00)),
    LogSeverity.info: ('INFO', Color(0xFF1565C0)),
  };

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(systemLogsProvider);

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
              'System Error Log',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          logsAsync.when(
            data: (logs) {
              final filtered = logs.where((l) {
                if (_severityFilter != null && l.severity != _severityFilter) return false;
                if (_hideResolved && l.resolved) return false;
                return true;
              }).toList();

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Filter chips
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _severityInfo.entries.map((entry) {
                          final (label, color) = entry.value;
                          final selected = _severityFilter == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _severityFilter = entry.key),
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
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Hide resolved toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Hide resolved', style: TextStyle(fontSize: 13)),
                          ),
                          Switch(
                            value: _hideResolved,
                            activeColor: const Color(0xFF00897B),
                            onChanged: (value) => setState(() => _hideResolved = value),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('No matching log entries.', style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      for (final log in filtered) _LogTile(log: log),
                    const SizedBox(height: 16),
                  ]),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Could not load system logs: $e'))),
          ),
        ],
      ),
    );
  }
}

// ── Log tile ───────────────────────────────────────────────────────────
class _LogTile extends ConsumerWidget {
  const _LogTile({required this.log});

  final SystemLogModel log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (log.severity) {
      LogSeverity.error => const Color(0xFFD32F2F),
      LogSeverity.warning => const Color(0xFFEF6C00),
      LogSeverity.info => const Color(0xFF1565C0),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              log.severity == LogSeverity.error
                  ? Icons.error_rounded
                  : log.severity == LogSeverity.warning
                      ? Icons.warning_rounded
                      : Icons.info_rounded,
              color: color,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  log.source,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  log.severity.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              log.occurredAt != null ? DateFormat('MMM d, yyyy h:mm a').format(log.occurredAt!) : 'Unknown time',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          trailing: log.resolved
              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00897B), size: 20)
              : const Icon(Icons.expand_more_rounded, color: Colors.grey),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      log.message,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!log.resolved)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => ref.read(adminRepositoryProvider).markLogResolved(log.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 16, color: Colors.white),
                          label: const Text('Mark Resolved', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}