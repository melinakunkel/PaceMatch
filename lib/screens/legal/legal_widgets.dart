import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A value that still needs the real legal/contact details filled in before
/// a legal page can go live — rendered with an obvious highlight so it
/// can't accidentally ship unnoticed.
String placeholder(String hint) => '[$hint]';

/// Banner explaining that placeholder values (see [placeholder]) on this
/// page still need to be filled in with real details.
class PlaceholderNotice extends StatelessWidget {
  const PlaceholderNotice({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// A heading + one or more paragraph lines, the recurring building block on
/// both the Impressum and the Datenschutzerklärung.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.heading, required this.lines});
  final String heading;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: const TextStyle(height: 1.4)),
            ),
        ],
      ),
    );
  }
}
