import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/app_constants.dart';
import '../../../services/export/roadmap_pdf_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// S-16 — Roadmap PDF Export Screen.
/// "PDF preview panel, Export button, Share options (WhatsApp, Email,
/// Google Drive)."
///
/// FR-14 ("Should Have"). Uses the `printing` package's [PdfPreview]
/// widget for both the preview panel AND the share sheet — see the 🔶
/// note in pubspec.yaml about this being an addition beyond Section
/// 13.3's package table, since `pdf` alone only generates bytes.
class RoadmapPdfExportScreen extends ConsumerWidget {
  const RoadmapPdfExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(roadmapJdEvaluationProvider);
    final roadmap = ref.watch(roadmapEntriesProvider);
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Roadmap PDF')),
      body: evaluation == null
          ? const _EmptyState(message: 'No job role selected yet — pick one from Desired Role Selector.')
          : userAsync.when(
              data: (user) => PdfPreview(
                // PdfPreview's built-in toolbar already provides
                // print/share/page-navigation controls, satisfying both
                // the "PDF preview panel" and "Share options" UI
                // components in one widget.
                build: (format) async => Uint8List.fromList(
                  await RoadmapPdfService.generate(
                    studentName: user?.fullName ?? 'Student',
                    jobTitle: evaluation.score.jobTitle,
                    roadmap: roadmap,
                  ),
                ),
                pdfFileName:
                    'roadmap_${evaluation.score.jobTitle.replaceAll(' ', '_').toLowerCase()}.pdf',
                allowPrinting: true,
                allowSharing: true,
                canChangeOrientation: false,
                canChangePageFormat: false,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load your profile: $e')),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}