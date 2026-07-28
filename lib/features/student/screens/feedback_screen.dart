import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_constants.dart';
import '../../../models/feedback_model.dart';
import '../../auth/providers/auth_providers.dart';

/// S-33 — Feedback Screen.
/// "1 to 5 star rating selector, optional text comment box, submit
/// button."
///
/// Writes to `feedback/{id}` — Section 9.5: student creates their own
/// document, write-once (no edit/delete), Admin-only read.
/// [FeedbackModel.isValid] enforces the 1-5 range before submission.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: _submitted ? const _ThankYouState() : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How has your experience with Talent Tracker AI been?',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return IconButton(
                iconSize: 40,
                icon: Icon(
                  starValue <= _rating ? Icons.star : Icons.star_border,
                  color: AppColors.warningAmber,
                ),
                onPressed: () => setState(() => _rating = starValue),
              );
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _commentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Comments (optional)',
              hintText: 'Tell us what worked well or what could be better…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_rating >= 1 && !_submitting) ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('SUBMIT FEEDBACK'),
            ),
          ),
          if (_rating == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Please select a star rating to submit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;

    final feedback = FeedbackModel(
      studentUid: uid,
      rating: _rating,
      comment: _commentController.text.trim(),
    );
    if (!feedback.isValid) return; // defence in depth — UI already enforces 1-5

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection(FirestoreCollections.feedback).add(feedback.toMap());
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit feedback: $e')),
        );
      }
    }
  }
}

class _ThankYouState extends StatelessWidget {
  const _ThankYouState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 64, color: AppColors.errorRed),
            const SizedBox(height: 16),
            Text('Thank you for your feedback!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Your input helps the placement office improve the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
