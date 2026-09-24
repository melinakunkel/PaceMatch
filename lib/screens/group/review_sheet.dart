import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/meetup_review.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../theme/app_theme.dart';

/// After a meetup: rate each other participant — did they show up, and did
/// their details match? Pops with the reviews, or null when dismissed.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.members, required this.sport});

  /// Everyone to review (the group's members except me).
  final List<Profile> members;
  final SportType sport;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  final _showedUp = <String, bool>{};
  final _detailsMatched = <String, bool>{};
  final _mismatches = <String, Set<ReviewMismatch>>{};

  List<ReviewMismatch> get _options => [
    if (widget.sport.usesPace) ReviewMismatch.pace,
    if (!widget.sport.usesPace && widget.sport.usesLevel) ReviewMismatch.level,
    if (widget.sport.usesDistance) ReviewMismatch.distance,
    ReviewMismatch.punctuality,
    ReviewMismatch.meetingPoint,
    ReviewMismatch.other,
  ];

  bool get _complete => widget.members.every((m) {
    final showedUp = _showedUp[m.id];
    if (showedUp == null) return false;
    return !showedUp || _detailsMatched[m.id] != null;
  });

  void _submit() {
    Navigator.of(context).pop([
      for (final m in widget.members)
        MeetupReview(
          revieweeId: m.id,
          showedUp: _showedUp[m.id]!,
          detailsMatched: _detailsMatched[m.id],
          mismatches: _mismatches[m.id] ?? const {},
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('group.review.title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              t('group.review.hint'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, m) in widget.members.indexed) ...[
                      if (i > 0) const Divider(height: 28),
                      _buildMember(m),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _complete ? _submit : null,
                child: Text(t('group.review.submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMember(Profile m) {
    final showedUp = _showedUp[m.id];
    final matched = _detailsMatched[m.id];
    final mismatches = _mismatches[m.id] ?? const <ReviewMismatch>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondaryLight,
              backgroundImage: m.avatarUrl != null
                  ? NetworkImage(m.avatarUrl!)
                  : null,
              child: m.avatarUrl != null
                  ? null
                  : Text(
                      m.firstName.isNotEmpty
                          ? m.firstName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.firstName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _question(
          t('group.review.showedUp'),
          showedUp,
          (v) => setState(() => _showedUp[m.id] = v),
        ),
        if (showedUp == true)
          _question(
            t('group.review.detailsMatched'),
            matched,
            (v) => setState(() => _detailsMatched[m.id] = v),
          ),
        if (showedUp == true && matched == false) ...[
          const SizedBox(height: 4),
          Text(
            t('group.review.whatDidntMatch'),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _options.map((o) {
              return FilterChip(
                label: Text(o.label),
                selected: mismatches.contains(o),
                onSelected: (selected) => setState(() {
                  final next = {...?_mismatches[m.id]};
                  selected ? next.add(o) : next.remove(o);
                  _mismatches[m.id] = next;
                }),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _question(String label, bool? value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ChoiceChip(
            label: Text(t('group.review.yes')),
            selected: value == true,
            onSelected: (_) => onChanged(true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(t('group.review.no')),
            selected: value == false,
            onSelected: (_) => onChanged(false),
          ),
        ],
      ),
    );
  }
}
