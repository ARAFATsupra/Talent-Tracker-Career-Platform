import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../app/app_constants.dart';
import '../repository/admin_repository.dart';
import '../providers/admin_providers.dart';

/// S-32 — Data Export & Archive Screen.
/// "Backup all data and archive old placement cycles. Date range picker,
/// data type checkboxes, export as JSON or CSV, Archive This Cycle
/// button."
///
/// FR-27. Shares the same export shape as the Cloud Function's weekly
/// scheduledDataBackup (Section 14.1) — see AdminRepository.exportData.
///
/// 🔶 "Export as CSV" is offered as JSON's natural alternative, but a
/// 3-collection nested export (users + their semesters, placements,
/// jobDescriptions) doesn't flatten into ONE meaningful CSV table the
/// way a single-collection shortlist (S-23) does. JSON is the primary,
/// fully-supported format here; CSV mode exports each included
/// collection as its own flat block (no nested semesters/courses — just
/// top-level fields) rather than silently producing something
/// misleading.
class DataExportArchiveScreen extends ConsumerStatefulWidget {
  const DataExportArchiveScreen({super.key});

  @override
  ConsumerState<DataExportArchiveScreen> createState() => _DataExportArchiveScreenState();
}

class _DataExportArchiveScreenState extends ConsumerState<DataExportArchiveScreen> {
  DateTimeRange? _dateRange;
  bool _includeUsers = true;
  bool _includePlacements = true;
  bool _includeJDs = true;
  bool _exporting = false;
  bool _archiving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Export & Archive')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Date range (applies to Users only)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range_outlined),
            title: Text(_dateRange == null
                ? 'All time'
                : '${DateFormat('MMM d, yyyy').format(_dateRange!.start)} – '
                    '${DateFormat('MMM d, yyyy').format(_dateRange!.end)}'),
            trailing: TextButton(onPressed: _pickDateRange, child: const Text('Change')),
          ),
          const SizedBox(height: 16),
          Text('Data to include', style: Theme.of(context).textTheme.titleMedium),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeUsers,
            title: const Text('Users & student profiles'),
            onChanged: (v) => setState(() => _includeUsers = v ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includePlacements,
            title: const Text('Placements'),
            onChanged: (v) => setState(() => _includePlacements = v ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeJDs,
            title: const Text('Job descriptions'),
            onChanged: (v) => setState(() => _includeJDs = v ?? true),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canExport ? () => _export(asJson: false) : null,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canExport ? () => _export(asJson: true) : null,
                  icon: _exporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.data_object),
                  label: const Text('Export JSON'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text('Archive Placement Cycle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Marks every currently-active job description as archived — a fresh start for '
            'the next placement cycle. This does not delete any data.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.errorRed),
              onPressed: _archiving ? null : _confirmArchiveCycle,
              icon: _archiving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive_outlined),
              label: const Text('ARCHIVE THIS CYCLE'),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canExport => !_exporting && (_includeUsers || _includePlacements || _includeJDs);

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _export({required bool asJson}) async {
    setState(() => _exporting = true);
    try {
      final data = await ref.read(adminRepositoryProvider).exportData(
            includeUsers: _includeUsers,
            includePlacements: _includePlacements,
            includeJDs: _includeJDs,
            dateRange: _dateRange == null
                ? null
                : DateTimeRangeFilter(start: _dateRange!.start, end: _dateRange!.end),
          );

      if (asJson) {
        final jsonText = const JsonEncoder.withIndent('  ').convert(data);
        await _showTextPreview('JSON Export', jsonText);
      } else {
        final buffer = StringBuffer();
        for (final entry in data.entries) {
          if (entry.value is! List) continue;
          final rows = entry.value as List;
          if (rows.isEmpty) continue;
          buffer.writeln('--- ${entry.key} ---');
          final firstRow = rows.first as Map;
          final headers =
              firstRow.keys.where((k) => firstRow[k] is! Map && firstRow[k] is! List).toList();
          buffer.writeln(headers.join(','));
          for (final row in rows) {
            buffer.writeln(headers.map((h) => '${(row as Map)[h] ?? ''}').join(','));
          }
          buffer.writeln();
        }
        await _showTextPreview('CSV Export', buffer.toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showTextPreview(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(content, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Reuses the PDF share sheet to hand the export off the
              // device when the admin wants more than an in-app
              // copy-paste — see the 🔶 note in export_report_screen.dart
              // re: no `share_plus` dependency for a true arbitrary-file
              // share.
              await Printing.sharePdf(
                bytes: Uint8List.fromList(utf8.encode(content)),
                filename: '${title.replaceAll(' ', '_').toLowerCase()}.txt',
              );
            },
            child: const Text('Share'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmArchiveCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive current placement cycle?'),
        content: const Text(
          'Every currently active job description will be marked as archived. Students will '
          'lose these as AI Job Match recommendations until an admin re-activates or adds new '
          'roles. This cannot be undone in bulk — roles would need to be re-activated one by one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _archiving = true);
    try {
      final count = await ref.read(adminRepositoryProvider).archiveCurrentCycle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archived $count job description(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }
}
