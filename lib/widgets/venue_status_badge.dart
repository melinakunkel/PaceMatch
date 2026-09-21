import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';

/// Compact "has a court" / "needs a court" pill, kept separate from the
/// pace/distance stats line so venue-based sports (tennis, ...) don't look
/// cluttered on match/discover cards.
class VenueStatusBadge extends StatelessWidget {
  const VenueStatusBadge({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    if (activity.venueStatusLabel == null) return const SizedBox.shrink();
    final hasVenue = activity.hasVenue;
    final color = hasVenue ? AppColors.secondary : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVenue ? Icons.check_circle_outline : Icons.search,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            hasVenue ? t('venue.hasVenue') : t('venue.needsVenue'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
