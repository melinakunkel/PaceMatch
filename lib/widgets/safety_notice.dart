import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A safety reminder banner for meetups that call for extra caution (e.g.
/// child playdates) — same warning styling as the legal screens'
/// placeholder alerts, reused here because the content is just as worth
/// interrupting the flow for.
class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.danger, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
