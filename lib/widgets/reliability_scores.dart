import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/meetup_review.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';

/// The two public reliability sub-scores (shows up / details match) from
/// the others' anonymous reviews. Pass [summary] only on my own profile: it
/// adds what lowered the scores, which nobody else can see.
class ReliabilityScores extends StatelessWidget {
  const ReliabilityScores({super.key, required this.profile, this.summary});

  final Profile profile;
  final ReviewSummary? summary;

  @override
  Widget build(BuildContext context) {
    final attendance = profile.attendanceScore;
    final accuracy = profile.accuracyScore;
    final summary = this.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('profile.reliability'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (attendance == null)
          Text(
            t('profile.noReviewsYet'),
            style: TextStyle(color: AppColors.textSecondary),
          )
        else ...[
          _ScoreBar(
            label: t('profile.attendanceScore'),
            value: attendance,
            detail: summary == null
                ? null
                : t('profile.outOf', {
                    'count': '${summary.showedUp}',
                    'total': '${summary.total}',
                  }),
          ),
          const SizedBox(height: 10),
          _ScoreBar(
            label: t('profile.accuracyScore'),
            value: accuracy,
            detail: summary == null || summary.ratedDetails == 0
                ? null
                : t('profile.outOf', {
                    'count': '${summary.detailsMatched}',
                    'total': '${summary.ratedDetails}',
                  }),
          ),
        ],
        if (summary != null && summary.mismatches.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            t('profile.mismatchesTitle'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            t('profile.mismatchesOnlyYou'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final entry in summary.mismatches.entries)
                Chip(label: Text('${entry.key.label} · ${entry.value}×')),
            ],
          ),
        ],
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value, this.detail});

  final String label;

  /// Null = nobody has rated this yet.
  final double? value;

  /// e.g. "9 von 10" — only on my own profile.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            if (detail != null)
              Text(
                detail!,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (value ?? 0) / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.secondaryLight,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              child: Text(
                value == null ? '–' : '${value.round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
