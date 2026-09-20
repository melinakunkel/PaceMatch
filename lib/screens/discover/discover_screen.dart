import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/profile.dart';
import '../../services/activity_service.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/matching_preferences.dart';
import '../../widgets/verified_badge.dart';

class _DiscoverEntry {
  _DiscoverEntry({required this.profile, required this.activity});
  final Profile profile;
  final Activity activity;
}

/// "Entdecken": pick a date and browse what everyone else has scheduled
/// that day, across all sports — not just matches for one of your own
/// activities.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _activityService = ActivityService();
  final _profileService = ProfileService();
  final _groupService = GroupService();

  late DateTime _selectedDate = _dateOnly(DateTime.now());
  late final List<DateTime> _dateRange = List.generate(
    28,
    (i) => _dateOnly(DateTime.now().add(Duration(days: i - 3))),
  );

  bool _loading = true;
  String? _error;
  List<_DiscoverEntry> _entries = [];
  final Set<String> _contacting = {};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final myId = SupabaseService.currentUserId!;
      final activities = await _activityService.getActivitiesForDate(
        date: _selectedDate,
        excludeUserId: myId,
      );
      final myProfiles = await _profileService.getProfilesByIds([myId]);
      final myProfile = myProfiles.isEmpty ? null : myProfiles.first;
      final userIds = activities.map((a) => a.userId).toSet().toList();
      final profiles = await _profileService.getProfilesByIds(userIds);
      final profilesById = {for (final p in profiles) p.id: p};

      final entries = <_DiscoverEntry>[];
      for (final a in activities) {
        final p = profilesById[a.userId];
        if (p == null) continue;
        if (myProfile != null && !isAllowedByPreferences(myProfile, p)) continue;
        entries.add(_DiscoverEntry(profile: p, activity: a));
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _contact(_DiscoverEntry entry) async {
    setState(() => _contacting.add(entry.activity.id));
    try {
      final me = SupabaseService.currentUserId!;
      final group = await _groupService.createGroup(
        createdBy: me,
        sport: entry.activity.sport,
        name: '${entry.activity.sport.label} mit ${entry.profile.fullName}',
        meetingPoint: entry.activity.locationName,
        activityId: entry.activity.id,
      );
      await _groupService.joinGroup(groupId: group.id, userId: entry.profile.id);
      if (!mounted) return;
      context.push('/group/${group.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kontakt fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _contacting.remove(entry.activity.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Entdecken'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DateStrip(
              dates: _dateRange,
              selected: _selectedDate,
              onSelect: (d) {
                setState(() => _selectedDate = d);
                _load();
              },
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'An diesem Tag hat noch niemand eine Sportzeit eingetragen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final e = _entries[index];
          final contacting = _contacting.contains(e.activity.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondaryLight,
                    backgroundImage:
                        e.profile.avatarUrl != null ? NetworkImage(e.profile.avatarUrl!) : null,
                    child: e.profile.avatarUrl != null
                        ? null
                        : Text(
                            e.profile.fullName.isNotEmpty
                                ? e.profile.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                [
                                  e.profile.fullName,
                                  if (e.profile.age != null) '${e.profile.age}',
                                ].join(', '),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (e.profile.isVerified) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 14),
                            ],
                          ],
                        ),
                        if (e.profile.gender != null)
                          Text(e.profile.gender!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(e.activity.sport.icon, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(e.activity.sport.label),
                            const SizedBox(width: 10),
                            const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(e.activity.timeRangeLabel),
                          ],
                        ),
                        if (e.activity.locationName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(e.activity.locationName!,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: contacting ? null : () => _contact(e),
                            child: contacting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Kontaktieren'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.dates, required this.selected, required this.onSelect});

  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final d = dates[index];
          final isSelected = d.year == selected.year && d.month == selected.month && d.day == selected.day;
          final isToday = d.year == DateTime.now().year &&
              d.month == DateTime.now().month &&
              d.day == DateTime.now().day;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isToday ? AppColors.secondary : AppColors.border),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayLabels[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _monthLabels[d.month - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
