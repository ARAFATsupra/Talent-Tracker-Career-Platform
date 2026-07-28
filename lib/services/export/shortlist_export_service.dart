import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/placement_model.dart';

/// FR-19 / S-23 — Export Report Screen.
/// "Format selector (CSV or PDF), field checkboxes to include/remove
/// columns, Export button, Share via Email or Drive."
///
/// Mirrors RoadmapPdfService's pattern (S-16): a pure generation service
/// with no Firebase/UI dependency, consumed by the screen via the
/// `printing` package's PdfPreview/Printing.sharePdf for the actual
/// share sheet.
class ShortlistExportService {
  const ShortlistExportService._();

  /// All exportable column keys, in the order S-23's "field checkboxes"
  /// should default to (all checked). Matches the fields actually shown
  /// elsewhere for a shortlist row (S-20's "position, student name,
  /// CGPA, match %") plus what a recruiter would want in a downloadable
  /// report (status, notes, search date) — CGPA itself isn't on
  /// PlacementModel (it's the JOINED student's CGPA at scan time, not
  /// persisted per-placement), so it's intentionally NOT in this list;
  /// see the 🔶 note in the screen for why.
  static const List<String> availableColumns = [
    'studentName',
    'jobTitle',
    'matchPercentage',
    'status',
    'notes',
    'searchedAt',
  ];

  static String columnLabel(String key) {
    switch (key) {
      case 'studentName':
        return 'Student Name';
      case 'jobTitle':
        return 'Job Title';
      case 'matchPercentage':
        return 'Match %';
      case 'status':
        return 'Status';
      case 'notes':
        return 'Notes';
      case 'searchedAt':
        return 'Search Date';
      default:
        return key;
    }
  }

  static String _cellValue(PlacementModel p, String key) {
    switch (key) {
      case 'studentName':
        return p.studentName;
      case 'jobTitle':
        return p.jobTitle;
      case 'matchPercentage':
        return '${p.matchPercentage.toStringAsFixed(1)}%';
      case 'status':
        return p.status.label;
      case 'notes':
        return p.notes;
      case 'searchedAt':
        return p.searchedAt?.toIso8601String().split('T').first ?? '';
      default:
        return '';
    }
  }

  /// CSV export — returns the file content as a UTF-8 string, ready to
  /// write to disk or hand to a share sheet.
  static String generateCsv({required List<PlacementModel> rows, required List<String> columns}) {
    final headers = columns.map(columnLabel).toList();
    final data = rows.map((p) => columns.map((c) => _cellValue(p, c)).toList()).toList();
    return const ListToCsvConverter().convert([headers, ...data]);
  }

  /// PDF export — same column selection, rendered as a simple table.
  static Future<List<int>> generatePdf({
    required List<PlacementModel> rows,
    required List<String> columns,
    required String recruiterName,
  }) async {
    final doc = pw.Document();
    final headers = columns.map(columnLabel).toList();
    final data = rows.map((p) => columns.map((c) => _cellValue(p, c)).toList()).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Candidate Shortlist Export',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Exported by $recruiterName', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('No rows match the current filters.')
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
        ],
      ),
    );

    return doc.save();
  }
}
