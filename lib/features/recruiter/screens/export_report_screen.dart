import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/app_constants.dart';
import '../../../models/placement_model.dart';
import '../../../services/export/shortlist_export_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/recruiter_providers.dart';

/// S-23 — Export Report Screen.
/// "Format selector (CSV or PDF), field checkboxes to include/remove
/// columns, Export button, Share via Email or Drive."
///
/// FR-19. Exports the signed-in recruiter's full `placements` pipeline
/// (not just one search's results) — there's no "export THIS shortlist"
/// hand-off point in the spec's navigation flow from S-20/S-22 to S-23,
/// so this exports everything in the pipeline and relies on the
/// existing Pipeline Board / Job Request Log screens for narrowing down
/// to one search if needed.
///
/// 🔶 CGPA isn't included as an exportable column — [PlacementModel]
/// doesn't persist it (a student's CGPA is read live from `users/{uid}`
/// at scan time, Section 12.6, and isn't snapshotted onto the
/// placement record). Adding a `cgpaAtSearch` field to `placements`
/// would be a reasonable follow-up if exports specifically need it.
///
/// 🔶 PDF export uses the `printing` package's native share sheet
/// (Section "Share via Email or Drive"). CSV export shows an in-app
/// preview with a copy-to-clipboard action instead of a true file share
/// — cross-platform "share an arbitrary file" needs the `share_plus`
/// package, which isn't in Section 13.3's package table. Recommended as
/// a small follow-up if native CSV file-sharing (vs. the PDF path,
/// which `printing` already covers) is specifically needed.
class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() => _ExportReportScreenState();
}

enum _ExportFormat { csv, pdf }

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  _ExportFormat _format = _ExportFormat.csv;
  final Set<String> _selectedColumns = {...ShortlistExportService.availableColumns};

  @override
  Widget build(BuildContext context) {
    final placementsAsync = ref.watch(placementsProvider);
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Report')),
      body: placementsAsync.when(
        data: (placements) {
          if (placements.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Your pipeline is empty — nothing to export yet.', textAlign: TextAlign.center),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Format', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<_ExportFormat>(
                segments: const [
                  ButtonSegment(
                      value: _ExportFormat.csv, label: Text('CSV'), icon: Icon(Icons.table_chart_outlined)),
                  ButtonSegment(
                      value: _ExportFormat.pdf, label: Text('PDF'), icon: Icon(Icons.picture_as_pdf_outlined)),
                ],
                selected: {_format},
                onSelectionChanged: (selection) => setState(() => _format = selection.first),
              ),
              const SizedBox(height: 20),
              Text('Columns to include', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${placements.length} row${placements.length == 1 ? '' : 's'} from your pipeline will be exported.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final col in ShortlistExportService.availableColumns)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedColumns.contains(col),
                  title: Text(ShortlistExportService.columnLabel(col)),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedColumns.add(col);
                    } else {
                      _selectedColumns.remove(col);
                    }
                  }),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selectedColumns.isEmpty
                      ? null
                      : () => _export(placements, userAsync.valueOrNull?.fullName ?? 'Recruiter'),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('EXPORT'),
                ),
              ),
              if (_selectedColumns.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Select at least one column to export.',
                  style: TextStyle(color: AppColors.errorRed, fontSize: 12),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load your pipeline: $e')),
      ),
    );
  }

  Future<void> _export(List<PlacementModel> placements, String recruiterName) async {
    final columns = ShortlistExportService.availableColumns.where(_selectedColumns.contains).toList();

    if (_format == _ExportFormat.csv) {
      final csv = ShortlistExportService.generateCsv(rows: placements, columns: columns);
      await _showCsvPreview(csv);
    } else {
      final bytes = await ShortlistExportService.generatePdf(
        rows: placements,
        columns: columns,
        recruiterName: recruiterName,
      );
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'shortlist_export.pdf');
    }
  }

  Future<void> _showCsvPreview(String csv) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Export'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
