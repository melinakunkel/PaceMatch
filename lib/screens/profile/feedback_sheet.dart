import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/admin_items.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

/// Feedback straight into the app's database (shown in the admin view),
/// instead of relying on the user's mail app.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key, this.service});

  /// Injectable for tests.
  final FeedbackService? service;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  late final _service = widget.service ?? FeedbackService();
  final _textCtrl = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.idea;
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendFeedback(category: _category, message: text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('feedback.failed', {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('feedback.title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            t('feedback.subtitle'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in FeedbackCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            decoration: InputDecoration(hintText: t('feedback.hint')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _textCtrl.text.trim().isEmpty || _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('feedback.send')),
          ),
        ],
      ),
    );
  }
}
