import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/community_event.dart';
import '../../models/open_event.dart';
import '../../models/picked_location.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/activity_service.dart';
import '../../services/block_service.dart';
import '../../services/chat_request_service.dart';
import '../../services/circle_controller.dart';
import '../../services/community_event_service.dart';
import '../../services/group_service.dart';
import '../../services/open_event_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/activity_stats.dart';
import '../../utils/display_labels.dart';
import '../../utils/geo.dart';
import '../../utils/matching_preferences.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/venue_status_badge.dart';
import '../../widgets/verified_badge.dart';
import '../plan/location_picker_screen.dart';

class _DiscoverEntry {
  _DiscoverEntry({required this.profile, required this.activity});
  final Profile profile;
  final Activity activity;
}

/// One occurrence of a community or open event, for the chronological "all
/// events" timeline view — a recurring [CommunityEvent] contributes one
/// entry per matching date (see [CommunityEvent.occurrencesBetween]).
class _TimelineEntry {
  _TimelineEntry.community(this.date, CommunityEvent event)
    : community = event,
      open = null,
      _startMinutes = _minutesOf(event.startTime);

  _TimelineEntry.open(this.date, OpenEvent event)
    : community = null,
      open = event,
      _startMinutes = event.startTime.hour * 60 + event.startTime.minute;

  final DateTime date;
  final CommunityEvent? community;
  final OpenEvent? open;
  final int _startMinutes;

  static int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static int compare(_TimelineEntry a, _TimelineEntry b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a._startMinutes.compareTo(b._startMinutes);
  }
}

List<String> get _monthLabels => [
  t('month.jan'),
  t('month.feb'),
  t('month.mar'),
  t('month.apr'),
  t('month.may'),
  t('month.jun'),
  t('month.jul'),
  t('month.aug'),
  t('month.sep'),
  t('month.oct'),
  t('month.nov'),
  t('month.dec'),
];

String _monthYearLabel(DateTime d) => '${_monthLabels[d.month - 1]} ${d.year}';

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
  final _blockService = BlockService();
  final _chatRequestService = ChatRequestService();
  final _communityEventService = CommunityEventService();
  final _openEventService = OpenEventService();

  late DateTime _selectedDate = _dateOnly(DateTime.now());
  late final List<DateTime> _dateRange = List.generate(
    28,
    (i) => _dateOnly(DateTime.now().add(Duration(days: i - 3))),
  );

  bool _loading = true;
  String? _error;
  List<_DiscoverEntry> _entries = [];
  List<CommunityEvent> _communityEvents = [];
  List<OpenEvent> _openEvents = [];
  final Set<String> _contacting = {};
  final Set<String> _joining = {};
  final Set<String> _sendingRequest = {};
  Set<String> _requestedActivityIds = {};

  bool _showCommunityEvents = true;
  Set<SportType> _sportFilter = {};
  RangeValues _timeRange = const RangeValues(0, 24);

  /// "Nur im Umkreis" — shared between the day and timeline views, since
  /// it's about where the viewer wants to look, not which view they're in.
  /// Null center means the filter is off (shows everything, as before).
  /// Persisted locally (not per-account) like the other Entdecken filters.
  PickedLocation? _radiusCenter;
  double _radiusKm = 10;

  /// Chronological "all events" view, as an alternative to picking one day
  /// at a time — see [_buildTimelineBody].
  bool _timelineView = false;
  bool _timelineShowCommunity = true;
  bool _timelineShowOpen = true;
  bool _timelineLoading = true;
  String? _timelineError;
  List<CommunityEvent> _timelineCommunityEvents = [];
  List<OpenEvent> _timelineOpenEvents = [];
  Set<SportType> _timelineSportFilter = {};
  static const _timelineDaysAhead = 120;

  bool get _filtersActive =>
      !_showCommunityEvents ||
      _sportFilter.isNotEmpty ||
      _timeRange.start > 0 ||
      _timeRange.end < 24 ||
      _radiusCenter != null;

  List<_DiscoverEntry> get _filteredEntries => _entries.where((e) {
    if (_sportFilter.isNotEmpty && !_sportFilter.contains(e.activity.sport)) {
      return false;
    }
    if (!_withinRadius(e.activity.latitude, e.activity.longitude)) {
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
      if (!_withinRadius(e.latitude, e.longitude)) return false;
      final parts = e.startTime.split(':');
      return _withinTimeRange(int.parse(parts[0]), int.parse(parts[1]));
    }).toList();
  }

  List<OpenEvent> get _filteredOpenEvents {
    return _openEvents.where((e) {
      if (_sportFilter.isNotEmpty && !_sportFilter.contains(e.sport)) {
        return false;
      }
      if (!_withinRadius(e.latitude, e.longitude)) return false;
      return _withinTimeRange(e.startTime.hour, e.startTime.minute);
    }).toList();
  }

  bool _withinTimeRange(int hour, int minute) {
    final t = hour + minute / 60;
    return t >= _timeRange.start && t <= _timeRange.end;
  }

  /// True when there's no radius filter set, when a candidate has no
  /// coordinates to check (never excluded for missing data), or when it
  /// actually falls within [_radiusKm] of [_radiusCenter].
  bool _withinRadius(double? lat, double? lng) {
    final center = _radiusCenter;
    if (center == null || lat == null || lng == null) return true;
    return distanceKm(center.latitude, center.longitude, lat, lng) <= _radiusKm;
  }

  Future<void> _loadRadiusPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('discover_radius_lat');
    final lng = prefs.getDouble('discover_radius_lng');
    final name = prefs.getString('discover_radius_name');
    final km = prefs.getDouble('discover_radius_km');
    if (!mounted) return;
    setState(() {
      if (lat != null && lng != null && name != null) {
        _radiusCenter = PickedLocation(
          name: name,
          latitude: lat,
          longitude: lng,
        );
      }
      if (km != null) _radiusKm = km;
    });
  }

  Future<void> _saveRadiusPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final center = _radiusCenter;
    if (center == null) {
      await prefs.remove('discover_radius_lat');
      await prefs.remove('discover_radius_lng');
      await prefs.remove('discover_radius_name');
    } else {
      await prefs.setDouble('discover_radius_lat', center.latitude);
      await prefs.setDouble('discover_radius_lng', center.longitude);
      await prefs.setString('discover_radius_name', center.name);
    }
    await prefs.setDouble('discover_radius_km', _radiusKm);
  }

  Future<void> _pickRadiusCenter(StateSetter setSheetState) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _radiusCenter),
      ),
    );
    if (picked == null) return;
    setSheetState(() => _radiusCenter = picked);
    setState(() {});
    await _saveRadiusPrefs();
  }

  void _clearRadiusCenter(StateSetter setSheetState) {
    setSheetState(() => _radiusCenter = null);
    setState(() {});
    _saveRadiusPrefs();
  }

  void _setRadiusKm(StateSetter setSheetState, double km) {
    setSheetState(() => _radiusKm = km);
    setState(() {});
    _saveRadiusPrefs();
  }

  /// Level/pace for sports without a numeric pace (tennis, wandern), keyed
  /// by "sportName:userId" since a user can have a level per sport.
  Map<String, UserSport> _theirSports = {};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
    _loadRadiusPrefs();
    CircleController.active.addListener(_onCircleChanged);
  }

  @override
  void dispose() {
    CircleController.active.removeListener(_onCircleChanged);
    super.dispose();
  }

  void _onCircleChanged() => _load();

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
        circleId: CircleController.active.value?.id,
      );
      final myProfiles = await _profileService.getProfilesByIds([myId]);
      final myProfile = myProfiles.isEmpty ? null : myProfiles.first;
      final userIds = activities.map((a) => a.userId).toSet().toList();
      final profiles = await _profileService.getProfilesByIds(userIds);
      final profilesById = {for (final p in profiles) p.id: p};
      final blockedIds = await _blockService.blockedUserIds();
      final requestedActivityIds = await _chatRequestService.sentActivityIds();

      final entries = <_DiscoverEntry>[];
      for (final a in activities) {
        final p = profilesById[a.userId];
        if (p == null) continue;
        if (p.isSuspended || p.isPaused) continue;
        if (blockedIds.contains(p.id)) continue;
        if (myProfile != null && !isAllowedByPreferences(myProfile, p)) {
          continue;
        }
        entries.add(_DiscoverEntry(profile: p, activity: a));
      }

      final communityEvents = await _communityEventService.getForCityAndDate(
        city: myProfile?.city ?? 'Wien',
        date: _selectedDate,
      );
      final openEvents = await _openEventService.getForCityAndDate(
        city: myProfile?.city ?? 'Wien',
        date: _selectedDate,
        userId: myId,
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
        _openEvents = openEvents;
        _theirSports = theirSports;
        _requestedActivityIds = requestedActivityIds;
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

  Future<void> _toggleTimelineView() async {
    setState(() => _timelineView = !_timelineView);
    if (_timelineView &&
        _timelineCommunityEvents.isEmpty &&
        _timelineOpenEvents.isEmpty) {
      await _loadTimeline();
    }
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _timelineLoading = true;
      _timelineError = null;
    });
    try {
      final myId = SupabaseService.currentUserId!;
      final myProfiles = await _profileService.getProfilesByIds([myId]);
      final city = myProfiles.isEmpty
          ? 'Wien'
          : (myProfiles.first.city ?? 'Wien');
      final today = _dateOnly(DateTime.now());
      final community = await _communityEventService.getAllForCity(city);
      final open = await _openEventService.getUpcomingForCity(
        city: city,
        from: today,
        userId: myId,
        days: _timelineDaysAhead,
      );
      if (!mounted) return;
      setState(() {
        _timelineCommunityEvents = community;
        _timelineOpenEvents = open;
        _timelineLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timelineError = '$e';
        _timelineLoading = false;
      });
    }
  }

  bool get _timelineFiltersActive =>
      _timelineSportFilter.isNotEmpty || _radiusCenter != null;

  List<_TimelineEntry> get _timelineEntries {
    final today = _dateOnly(DateTime.now());
    final to = today.add(const Duration(days: _timelineDaysAhead));
    final entries = <_TimelineEntry>[];
    if (_timelineShowCommunity) {
      for (final event in _timelineCommunityEvents) {
        if (_timelineSportFilter.isNotEmpty &&
            !_timelineSportFilter.contains(event.sport)) {
          continue;
        }
        if (!_withinRadius(event.latitude, event.longitude)) continue;
        for (final date in event.occurrencesBetween(today, to)) {
          entries.add(_TimelineEntry.community(date, event));
        }
      }
    }
    if (_timelineShowOpen) {
      for (final event in _timelineOpenEvents) {
        if (_timelineSportFilter.isNotEmpty &&
            !_timelineSportFilter.contains(event.sport)) {
          continue;
        }
        if (!_withinRadius(event.latitude, event.longitude)) continue;
        entries.add(_TimelineEntry.open(_dateOnly(event.eventDate), event));
      }
    }
    entries.sort(_TimelineEntry.compare);
    return entries;
  }

  Future<void> _contact(_DiscoverEntry entry) async {
    setState(() => _contacting.add(entry.activity.id));
    try {
      final groupId = await _groupService.openDirectChat(
        myId: SupabaseService.currentUserId!,
        otherUserId: entry.profile.id,
        sport: entry.activity.sport,
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
      if (!mounted) return;
      context.push('/group/$groupId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('discover.contactFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _contacting.remove(entry.activity.id));
    }
  }

  Future<void> _sendChatRequest(_DiscoverEntry entry) async {
    setState(() => _sendingRequest.add(entry.activity.id));
    try {
      await _chatRequestService.sendRequest(
        toUser: entry.profile.id,
        activityId: entry.activity.id,
      );
      if (!mounted) return;
      setState(() => _requestedActivityIds.add(entry.activity.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('discover.requestFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest.remove(entry.activity.id));
    }
  }

  /// Refreshes whichever view is currently showing after a join/edit/delete
  /// on an open event — the day view and the timeline load independently.
  Future<void> _reload() => _timelineView ? _loadTimeline() : _load();

  Future<void> _joinOpenEvent(OpenEvent event) async {
    setState(() => _joining.add(event.id));
    try {
      final myId = SupabaseService.currentUserId!;
      await _openEventService.joinEvent(groupId: event.groupId, userId: myId);
      if (!mounted) return;
      context.push('/group/${event.groupId}');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('discover.joinFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _joining.remove(event.id));
    }
  }

  Future<void> _editOpenEvent(OpenEvent event) async {
    final edits = await showDialog<_EventEdits>(
      context: context,
      builder: (context) => _EditOpenEventDialog(event: event),
    );
    if (edits == null) return;
    try {
      await _openEventService.updateEvent(
        id: event.id,
        groupId: event.groupId,
        name: edits.name,
        description: edits.description,
        maxParticipants: edits.maxParticipants,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('discover.editEventFailed', {'error': '$e'}))),
      );
    }
  }

  Future<void> _deleteOpenEvent(OpenEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('discover.deleteEventTitle')),
        content: Text(t('discover.deleteEventBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(t('discover.deleteEventConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _openEventService.deleteEvent(event.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('discover.deleteEventFailed', {'error': '$e'})),
        ),
      );
    }
  }

  Future<void> _hostEvent() async {
    await context.push('/host-event');
    _load();
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('discover.filters.title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('discover.filters.showNearbyEvents')),
                  value: _showCommunityEvents,
                  onChanged: (v) {
                    setSheetState(() => _showCommunityEvents = v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  t('newActivity.sport'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SportType.alphabetical.map((sport) {
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
                  t('discover.filters.time', {
                    'start': _formatHour(_timeRange.start),
                    'end': _formatHour(_timeRange.end),
                    'any': _timeRange.start <= 0 && _timeRange.end >= 24
                        ? t('discover.filters.timeAny')
                        : '',
                  }),
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
                const SizedBox(height: 20),
                _buildRadiusFilterSection(setSheetState),
                const SizedBox(height: 4),
                if (_filtersActive)
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _showCommunityEvents = true;
                        _sportFilter = {};
                        _timeRange = const RangeValues(0, 24);
                        _radiusCenter = null;
                      });
                      setState(() {});
                      _saveRadiusPrefs();
                    },
                    child: Text(t('discover.filters.reset')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Location + km picker for "Nur im Umkreis" — shared between
  /// [_openFilters] and [_openTimelineFilters] since it's the same
  /// underlying state either way.
  Widget _buildRadiusFilterSection(StateSetter setSheetState) {
    final center = _radiusCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('discover.filters.radius'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickRadiusCenter(setSheetState),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    hintText: t('discover.filters.pickCenter'),
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: const Icon(Icons.map_outlined),
                  ),
                  child: Text(
                    center?.name ?? t('discover.filters.pickCenter'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: center == null
                        ? TextStyle(color: AppColors.textSecondary)
                        : null,
                  ),
                ),
              ),
            ),
            if (center != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: t('discover.filters.clearCenter'),
                onPressed: () => _clearRadiusCenter(setSheetState),
              ),
          ],
        ),
        if (center != null) ...[
          const SizedBox(height: 12),
          Text(
            t('discover.filters.radiusKm', {
              'km': _radiusKm.round().toString(),
            }),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            label: '${_radiusKm.round()} km',
            onChanged: (v) => _setRadiusKm(setSheetState, v),
          ),
        ],
      ],
    );
  }

  /// Same sport-filter chip picker as [_openFilters], scoped to the "all
  /// events" timeline instead — its own filter (community/open shown, time
  /// range, ...) doesn't map onto a multi-month list the same way.
  Future<void> _openTimelineFilters() async {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('discover.filters.title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: t('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t('newActivity.sport'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SportType.alphabetical.map((sport) {
                    final selected = _timelineSportFilter.contains(sport);
                    return FilterChip(
                      label: Text(sport.label),
                      selected: selected,
                      onSelected: (_) {
                        setSheetState(() {
                          if (selected) {
                            _timelineSportFilter.remove(sport);
                          } else {
                            _timelineSportFilter.add(sport);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _buildRadiusFilterSection(setSheetState),
                if (_timelineFiltersActive) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _timelineSportFilter = {};
                        _radiusCenter = null;
                      });
                      setState(() {});
                      _saveRadiusPrefs();
                    },
                    child: Text(t('discover.filters.reset')),
                  ),
                ],
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
      title: t('nav.discover'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: t('discover.hostEvent'),
          onPressed: _hostEvent,
        ),
        IconButton(
          icon: Icon(
            (_timelineView ? _timelineFiltersActive : _filtersActive)
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
          ),
          tooltip: t('discover.filters.title'),
          onPressed: _timelineView ? _openTimelineFilters : _openFilters,
        ),
        IconButton(
          icon: Icon(
            _timelineView ? Icons.calendar_view_day : Icons.event_note,
          ),
          tooltip: _timelineView
              ? t('discover.dayView')
              : t('discover.allEventsView'),
          onPressed: _toggleTimelineView,
        ),
      ],
      body: _timelineView
          ? _buildTimelineBody()
          : Column(
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
                child: Text(t('discover.retry')),
              ),
            ],
          ),
        ),
      );
    }
    final entries = _filteredEntries;
    final communityEvents = _filteredCommunityEvents;
    final openEvents = _filteredOpenEvents;
    if (_entries.isEmpty && _communityEvents.isEmpty && _openEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('discover.emptyDay'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _hostEvent,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(t('discover.hostEvent')),
              ),
            ],
          ),
        ),
      );
    }
    if (entries.isEmpty && communityEvents.isEmpty && openEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('discover.emptyFiltered'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openFilters,
                child: Text(t('discover.adjustFilters')),
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
                    t('discover.eventsNearby'),
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
          if (openEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  Icon(Icons.groups, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    t('discover.openEvents'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ...openEvents.map(_buildOpenEventCard),
            const SizedBox(height: 8),
          ],
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                t('discover.matchingPeople'),
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

  Widget _buildTimelineBody() {
    if (_timelineLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_timelineError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                _timelineError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTimeline,
                child: Text(t('discover.retry')),
              ),
            ],
          ),
        ),
      );
    }
    final entries = _timelineEntries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            t('discover.timelineTitle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                label: Text(t('discover.starEvents')),
                selected: _timelineShowCommunity,
                onSelected: (v) => setState(() => _timelineShowCommunity = v),
              ),
              FilterChip(
                avatar: Icon(
                  Icons.groups,
                  size: 16,
                  color: AppColors.secondary,
                ),
                label: Text(t('discover.openEvents')),
                selected: _timelineShowOpen,
                onSelected: (v) => setState(() => _timelineShowOpen = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t('discover.timelineEmpty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTimeline,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final newMonth =
                          i == 0 ||
                          entries[i - 1].date.month != entry.date.month ||
                          entries[i - 1].date.year != entry.date.year;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (newMonth) _MonthHeader(date: entry.date),
                          entry.community != null
                              ? _buildCommunityEventCard(
                                  entry.community!,
                                  entry.date,
                                )
                              : _buildOpenEventCard(entry.open!, entry.date),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommunityEventCard(CommunityEvent event, [DateTime? date]) {
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
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    _EventDateLabel(date: date),
                  ],
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
                        child: Text(t('discover.moreInfo')),
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

  Widget _buildOpenEventCard(OpenEvent event, [DateTime? date]) {
    final joining = _joining.contains(event.id);
    final myId = SupabaseService.currentUserId;
    final isHost = event.hostId == myId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups, color: AppColors.secondary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isHost) ...[
                        InkWell(
                          onTap: () => _editOpenEvent(event),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _deleteOpenEvent(event),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty)
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    _EventDateLabel(date: date),
                  ],
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.maxParticipants == null
                            ? t('discover.participants', {
                                'count': '${event.participantCount}',
                              })
                            : t('discover.participantsMax', {
                                'count': '${event.participantCount}',
                                'max': '${event.maxParticipants}',
                              }),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: event.joined || isHost
                        ? OutlinedButton(
                            onPressed: () =>
                                context.push('/group/${event.groupId}'),
                            child: Text(t('discover.openChat')),
                          )
                        : ElevatedButton(
                            onPressed: (joining || event.isFull)
                                ? null
                                : () => _joinOpenEvent(event),
                            child: joining
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    event.isFull
                                        ? t('discover.full')
                                        : t('discover.join'),
                                  ),
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

  Widget _buildEntryCard(_DiscoverEntry e) {
    final contacting = _contacting.contains(e.activity.id);
    final sendingRequest = _sendingRequest.contains(e.activity.id);
    final requested = _requestedActivityIds.contains(e.activity.id);
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
                              e.profile.firstName,
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
                      genderLabel(e.profile.gender!),
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
                            e.activity.locationLabel!,
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
                    child: e.activity.requiresChatRequest
                        ? OutlinedButton(
                            onPressed: (sendingRequest || requested)
                                ? null
                                : () => _sendChatRequest(e),
                            child: sendingRequest
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    requested
                                        ? t('discover.requestSent')
                                        : t('discover.sendRequest'),
                                  ),
                          )
                        : OutlinedButton(
                            onPressed: contacting ? null : () => _contact(e),
                            child: contacting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(t('discover.contact')),
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

/// Section divider shown whenever the month changes while scrolling the
/// "all events" timeline.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        _monthYearLabel(date),
        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
    );
  }
}

/// The concrete day an event card falls on ("Do, 24.09.") — shown only in
/// the "all events" timeline, where a month can span many dates; the
/// day-picker view already implies the date via its selected day.
class _EventDateLabel extends StatelessWidget {
  const _EventDateLabel({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label =
        '${weekdayLabels[date.weekday - 1]}, '
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.';
    return Row(
      children: [
        Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Room for weekday, day and month — the month line used to spill out
      // of the tile.
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final d = dates[index];
          final showMonth = index == 0 || dates[index - 1].month != d.month;
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
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                  Visibility(
                    visible: showMonth,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      _monthLabels[d.month - 1],
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
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

/// What can actually change about an already-published open event — sport,
/// date/time and location stay fixed once people have joined based on them.
class _EventEdits {
  const _EventEdits({
    required this.name,
    this.description,
    this.maxParticipants,
  });

  final String name;
  final String? description;
  final int? maxParticipants;
}

class _EditOpenEventDialog extends StatefulWidget {
  const _EditOpenEventDialog({required this.event});
  final OpenEvent event;

  @override
  State<_EditOpenEventDialog> createState() => _EditOpenEventDialogState();
}

class _EditOpenEventDialogState extends State<_EditOpenEventDialog> {
  late final _nameCtrl = TextEditingController(text: widget.event.name);
  late final _descriptionCtrl = TextEditingController(
    text: widget.event.description ?? '',
  );
  late final _maxParticipantsCtrl = TextEditingController(
    text: widget.event.maxParticipants?.toString() ?? '',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('discover.editEventTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('discover.editEventLockedHint'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: t('hostEvent.eventTitle')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('hostEvent.descriptionOptional'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxParticipantsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('hostEvent.maxParticipantsOptional'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _EventEdits(
                name: name,
                description: _descriptionCtrl.text.trim().isEmpty
                    ? null
                    : _descriptionCtrl.text.trim(),
                maxParticipants: int.tryParse(_maxParticipantsCtrl.text),
              ),
            );
          },
          child: Text(t('common.save')),
        ),
      ],
    );
  }
}
