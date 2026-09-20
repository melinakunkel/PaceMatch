import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/activity.dart';
import '../../models/community_event.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/activity_service.dart';
import '../../services/community_event_service.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/activity_stats.dart';
import '../../utils/matching_preferences.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/venue_status_badge.dart';
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
  final _communityEventService = CommunityEventService();

  late DateTime _selectedDate = _dateOnly(DateTime.now());
  late final List<DateTime> _dateRange = List.generate(
    28,
    (i) => _dateOnly(DateTime.now().add(Duration(days: i - 3))),
  );

  bool _loading = true;
  String? _error;
  List<_DiscoverEntry> _entries = [];
  List<CommunityEvent> _communityEvents = [];
  final Set<String> _contacting = {};

  bool _showCommunityEvents = true;
  Set<SportType> _sportFilter = {};
  RangeValues _timeRange = const RangeValues(0, 24);

  bool get _filtersActive =>
      !_showCommunityEvents ||
      _sportFilter.isNotEmpty ||
      _timeRange.start > 0 ||
      _timeRange.end < 24;

  List<_DiscoverEntry> get _filteredEntries => _entries.where((e) {
    if (_sportFilter.isNotEmpty && !_sportFilter.contains(e.activity.sport)) {
      return false;
    }
    return _withinTimeRange(
      e.activity.startTime.hour,
      e.activity.startTime.minute,
    );
  }).toList();

  List<CommunityEvent> get _filteredCommunityEvents {
    if (!_showCommunityEvents) return [];
    return _communityEvents.where((e) {
      if (_sportFilter.isNotEmpty && !_sportFilter.contains(e.sport)) {
        return false;
      }
      final parts = e.startTime.split(':');
      return _withinTimeRange(int.parse(parts[0]), int.parse(parts[1]));
    }).toList();
  }

  bool _withinTimeRange(int hour, int minute) {
    final t = hour + minute / 60;
    return t >= _timeRange.start && t <= _timeRange.end;
  }

  /// Level/pace for sports without a numeric pace (tennis, wandern), keyed
  /// by "sportName:userId" since a user can have a level per sport.
  Map<String, UserSport> _theirSports = {};

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
        if (myProfile != null && !isAllowedByPreferences(myProfile, p)) {
          continue;
        }
        entries.add(_DiscoverEntry(profile: p, activity: a));
      }

      final communityEvents = await _communityEventService.getForCityAndDate(
        city: myProfile?.city ?? 'Wien',
        date: _selectedDate,
      );

      final byNonPaceSport = <SportType, List<String>>{};
      for (final e in entries) {
        if (!e.activity.sport.usesPace) {
          (byNonPaceSport[e.activity.sport] ??= []).add(e.profile.id);
        }
      }
      final theirSports = <String, UserSport>{};
      for (final sportEntry in byNonPaceSport.entries) {
        final map = await _profileService.getUserSportsForUsers(
          sportEntry.value,
          sportEntry.key,
        );
        map.forEach(
          (userId, us) => theirSports['${sportEntry.key.name}:$userId'] = us,
        );
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _communityEvents = communityEvents;
        _theirSports = theirSports;
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
      final existingId = await _groupService.findSharedGroupId(
        entry.profile.id,
      );
      String groupId;
      if (existingId != null) {
        groupId = existingId;
      } else {
        final group = await _groupService.createGroup(
          createdBy: me,
          sport: entry.activity.sport,
          name: '${entry.activity.sport.label} mit ${entry.profile.fullName}',
          meetingPoint: entry.activity.locationName,
          latitude: entry.activity.latitude,
          longitude: entry.activity.longitude,
          meetingTime: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            entry.activity.startTime.hour,
            entry.activity.startTime.minute,
          ),
          activityId: entry.activity.id,
        );
        await _groupService.joinGroup(
          groupId: group.id,
          userId: entry.profile.id,
        );
        groupId = group.id;
      }
      if (!mounted) return;
      context.push('/group/$groupId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kontakt fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _contacting.remove(entry.activity.id));
    }
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Events in der Nähe anzeigen'),
                  value: _showCommunityEvents,
                  onChanged: (v) {
                    setSheetState(() => _showCommunityEvents = v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sportart',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SportType.values.map((sport) {
                    final selected = _sportFilter.contains(sport);
                    return FilterChip(
                      label: Text(sport.label),
                      selected: selected,
                      onSelected: (_) {
                        setSheetState(() {
                          if (selected) {
                            _sportFilter.remove(sport);
                          } else {
                            _sportFilter.add(sport);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Uhrzeit: ${_formatHour(_timeRange.start)} - '
                  '${_formatHour(_timeRange.end)}'
                  '${_timeRange.start <= 0 && _timeRange.end >= 24 ? ' (egal)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                RangeSlider(
                  values: _timeRange,
                  min: 0,
                  max: 24,
                  divisions: 48,
                  labels: RangeLabels(
                    _formatHour(_timeRange.start),
                    _formatHour(_timeRange.end),
                  ),
                  onChanged: (v) {
                    setSheetState(() => _timeRange = v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                if (_filtersActive)
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _showCommunityEvents = true;
                        _sportFilter = {};
                        _timeRange = const RangeValues(0, 24);
                      });
                      setState(() {});
                    },
                    child: const Text('Filter zurücksetzen'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatHour(double h) {
    final hour = h.floor().clamp(0, 24);
    final minute = ((h - h.floor()) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      title: 'Entdecken',
      actions: [
        IconButton(
          icon: Icon(
            _filtersActive ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          tooltip: 'Filter',
          onPressed: _openFilters,
        ),
      ],
      body: Column(
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
              Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }
    final entries = _filteredEntries;
    final communityEvents = _filteredCommunityEvents;
    if (_entries.isEmpty && _communityEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'An diesem Tag hat noch niemand eine Sportzeit eingetragen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (entries.isEmpty && communityEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nichts passt zu deinen Filtern.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openFilters,
                child: const Text('Filter anpassen'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (communityEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'Events in der Nähe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ...communityEvents.map(_buildCommunityEventCard),
            const SizedBox(height: 8),
          ],
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Passende Leute',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ...entries.map(_buildEntryCard),
        ],
      ),
    );
  }

  Widget _buildCommunityEventCard(CommunityEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.secondaryLight.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (event.source != null)
                    Text(
                      event.source!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        event.sport.icon,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(event.sport.label),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(event.timeRangeLabel),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.url != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () => launchUrl(
                          Uri.parse(event.url!),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Mehr Infos'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(_DiscoverEntry e) {
    final contacting = _contacting.contains(e.activity.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/profile/${e.profile.id}'),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.secondaryLight,
                backgroundImage: e.profile.avatarUrl != null
                    ? NetworkImage(e.profile.avatarUrl!)
                    : null,
                child: e.profile.avatarUrl != null
                    ? null
                    : Text(
                        e.profile.fullName.isNotEmpty
                            ? e.profile.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile/${e.profile.id}'),
                    child: Row(
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
                  ),
                  if (e.profile.gender != null)
                    Text(
                      e.profile.gender!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        e.activity.sport.icon,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(e.activity.sport.label),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(e.activity.timeRangeLabel),
                    ],
                  ),
                  if (e.activity.locationName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            e.activity.locationName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        VenueStatusBadge(activity: e.activity),
                        Builder(
                          builder: (context) {
                            final stats = activityStatsLabel(
                              e.activity,
                              _theirSports['${e.activity.sport.name}:${e.profile.id}'],
                            );
                            if (stats == null) return const SizedBox.shrink();
                            return Text(
                              stats,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.dates,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mär',
    'Apr',
    'Mai',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Okt',
    'Nov',
    'Dez',
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
          final isSelected =
              d.year == selected.year &&
              d.month == selected.month &&
              d.day == selected.day;
          final isToday =
              d.year == DateTime.now().year &&
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
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
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
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
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
