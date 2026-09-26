import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart' show weekdayLabels;
import '../../models/group.dart';
import '../../models/meetup_review.dart';
import '../../models/message.dart';
import '../../models/picked_location.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../services/activity_service.dart';
import '../../services/giphy_service.dart';
import '../../services/group_service.dart';
import '../../services/message_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/calendar_export.dart';
import '../../utils/display_labels.dart';
import '../../utils/safe_pop.dart';
import '../../utils/shared_sport_times.dart';
import '../../widgets/safety_notice.dart';
import '../plan/location_picker_screen.dart';
import 'gif_picker_sheet.dart';
import 'message_row.dart';
import 'report_user_dialog.dart';
import 'review_sheet.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupService = GroupService();

  SportGroup? _group;
  List<Profile> _members = [];

  /// The meeting time I last answered "did it happen?" for.
  DateTime? _checkedInFor;
  bool _checkingIn = false;
  bool _loading = true;

  /// In a private chat: the other sport times we have in common, besides
  /// the chat's own meetup — the header pages through them (page 0 is the
  /// chat's meetup, 1.. are these).
  List<SharedSportTime> _otherTimes = [];
  int _page = 0;

  /// The message field's focus: while typing, the header (members, meeting
  /// point, check-in card) is hidden so the messages still fit above the
  /// on-screen keyboard.
  final _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_onInputFocusChanged);
    _load();
  }

  void _onInputFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inputFocus.removeListener(_onInputFocusChanged);
    _inputFocus.dispose();
    super.dispose();
  }

  bool _muted = false;

  Future<void> _toggleMuted() async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    final muted = !_muted;
    setState(() => _muted = muted);
    try {
      await _groupService.setMuted(
        groupId: widget.groupId,
        userId: myId,
        muted: muted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(muted ? t('group.mutedOn') : t('group.mutedOff')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _muted = !muted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    }
  }

  Future<void> _load() async {
    final SportGroup group;
    final List<Profile> members;
    try {
      group = await _groupService.getGroup(widget.groupId);
      members = await _groupService.getGroupMembers(widget.groupId);
    } catch (_) {
      // The chat is gone — e.g. the other person deleted our private chat.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('group.chatGone'))));
      safeBack(context, '/chat');
      return;
    }
    final myId = SupabaseService.currentUserId;
    DateTime? checkedInFor;
    var muted = false;
    if (myId != null) {
      try {
        muted = await _groupService.isMuted(
          groupId: widget.groupId,
          userId: myId,
        );
      } catch (_) {}
      await _groupService.markGroupRead(groupId: widget.groupId, userId: myId);
      UnreadController.refresh();
      try {
        checkedInFor = await _groupService.getCheckedInFor(
          groupId: widget.groupId,
          userId: myId,
        );
      } catch (_) {
        // Only drives the "did it happen?" prompt — never block the chat.
      }
    }
    final otherTimes = await _loadOtherTimes(group, members, myId);
    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _checkedInFor = checkedInFor;
      _muted = muted;
      _otherTimes = otherTimes;
      _page = _page.clamp(0, otherTimes.length);
      _loading = false;
    });
  }

  Future<List<SharedSportTime>> _loadOtherTimes(
    SportGroup group,
    List<Profile> members,
    String? myId,
  ) async {
    final partner = members.where((m) => m.id != myId).firstOrNull;
    if (!group.isDirect || myId == null || partner == null) return [];
    try {
      final activityService = ActivityService();
      final results = await Future.wait([
        activityService.getActiveActivitiesOf(myId),
        activityService.getActiveActivitiesOf(partner.id),
      ]);
      return sharedSportTimes(results[0], results[1])
          .where(
            (s) =>
                !s.involves(group.activityId) &&
                !(s.mine.sport == group.sport &&
                    group.meetingTime != null &&
                    s.nextOccurrence.isAtSameMomentAs(group.meetingTime!)),
          )
          .toList();
    } catch (_) {
      // Only extra paging — never block the chat.
      return [];
    }
  }

  /// Makes one of our other shared sport times the chat's meetup.
  Future<void> _useAsMeetup(SharedSportTime time) async {
    try {
      await _groupService.setMeetup(
        groupId: widget.groupId,
        sport: time.mine.sport,
        meetingTime: time.nextOccurrence,
        meetingPoint: time.locationName,
        latitude: time.latitude,
        longitude: time.longitude,
        activityId: time.mine.id,
      );
      _page = 0;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('group.setMeetupFailed', {'error': '$e'}))),
      );
    }
  }

  Future<void> _openReview() async {
    final myId = SupabaseService.currentUserId;
    final group = _group;
    if (myId == null || group == null) return;
    final reviews = await showModalBottomSheet<List<MeetupReview>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReviewSheet(
        members: _members.where((m) => m.id != myId).toList(),
        sport: group.sport,
      ),
    );
    if (reviews == null) return;
    await _checkIn(true, reviews: reviews);
  }

  Future<void> _checkIn(
    bool attended, {
    List<MeetupReview> reviews = const [],
  }) async {
    final myId = SupabaseService.currentUserId;
    final meetingTime = _group?.meetingTime;
    if (myId == null || meetingTime == null || _checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      await _groupService.submitReviews(
        groupId: widget.groupId,
        reviewerId: myId,
        meetingTime: meetingTime,
        reviews: reviews,
      );
      await _groupService.checkIn(
        groupId: widget.groupId,
        userId: myId,
        attended: attended,
        meetingTime: meetingTime,
      );
      if (!mounted) return;
      setState(() {
        _checkedInFor = meetingTime;
        _checkingIn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attended ? t('group.review.thanks') : t('group.checkinThanks'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('group.checkinFailed', {'error': '$e'}))),
      );
    }
  }

  Future<void> _pickMeetingPoint() async {
    final group = _group;
    if (group == null) return;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: group.meetingPoint == null || !group.hasMapLocation
              ? null
              : PickedLocation(
                  name: group.meetingPoint!,
                  latitude: group.latitude!,
                  longitude: group.longitude!,
                ),
        ),
      ),
    );
    if (picked == null) return;
    await _groupService.updateMeetingPoint(
      groupId: widget.groupId,
      meetingPoint: picked.name,
      latitude: picked.latitude,
      longitude: picked.longitude,
    );
    _load();
  }

  Future<void> _showMeetingPointMap({
    String? name,
    double? latitude,
    double? longitude,
  }) async {
    final group = _group;
    if (group == null) return;
    final lat = latitude ?? group.latitude;
    final lng = longitude ?? group.longitude;
    if (lat == null || lng == null) return;
    final title = latitude != null ? name : group.meetingPoint;
    final point = LatLng(lat, lng);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title == null
                          ? t('group.meetingPoint')
                          : placeLabel(title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.samepace.samepace',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.location_pin,
                          color: AppColors.secondary,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.openstreetmap.org/?mlat=${point.latitude}'
                      '&mlon=${point.longitude}#map=17/${point.latitude}/${point.longitude}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(t('group.openInOsm')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCalendar({
    DateTime? start,
    SportType? sport,
    String? location,
  }) async {
    final group = _group;
    final meetingTime = start ?? group?.meetingTime;
    if (group == null || meetingTime == null) return;
    final place = start != null ? location : group.meetingPoint;
    final calendarSport = sport ?? group.sport;
    final end = meetingTime.add(const Duration(hours: 1));
    final myId = SupabaseService.currentUserId;
    final partner = group.isDirect
        ? _members.where((m) => m.id != myId).firstOrNull
        : null;
    final title = partner == null
        ? group.name
        : t('discover.groupNameWith', {
            'sport': calendarSport.label,
            'name': partner.firstName,
          });
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(t('group.addToCalendarGoogle')),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(t('group.addToCalendarIcs')),
              onTap: () => Navigator.of(context).pop('ics'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final uri = choice == 'google'
        ? Uri.parse(
            buildGoogleCalendarUrl(
              title: title,
              start: meetingTime,
              end: end,
              location: place,
            ),
          )
        : Uri.parse(
            buildIcsDataUri(
              title: title,
              start: meetingTime,
              end: end,
              location: place,
            ),
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Sport + next date. In a private chat with several shared sport times,
  /// arrows page through them (page 0 = the chat's own meetup).
  Widget _buildMeetupTitleRow(SportGroup group) {
    final other = _page > 0 ? _otherTimes[_page - 1] : null;
    final sport = other?.mine.sport ?? group.sport;
    final time = other?.nextOccurrence ?? group.meetingTime;
    final pageCount = _otherTimes.length + 1;
    final showTime =
        time != null &&
        (other != null ||
            time.isAfter(DateTime.now().subtract(const Duration(hours: 12))));
    final label = group.isDirect
        ? [sport.label, if (showTime) formatMeetupTime(time)].join(' · ')
        : t('chatList.participants', {'count': '${group.memberCount}'});
    final title = Row(
      children: [
        Icon(sport.icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
    if (pageCount < 2) return title;

    void go(int delta) => setState(() => _page = (_page + delta) % pageCount);
    return GestureDetector(
      // Swiping works too, not just the arrows.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        go(v < 0 ? 1 : pageCount - 1);
      },
      child: Row(
        children: [
          _PagerArrow(
            icon: Icons.chevron_left,
            tooltip: t('group.previousSportTime'),
            onPressed: () => go(pageCount - 1),
          ),
          Expanded(child: title),
          Text(
            '${_page + 1}/$pageCount',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          _PagerArrow(
            icon: Icons.chevron_right,
            tooltip: t('group.nextSportTime'),
            onPressed: () => go(1),
          ),
        ],
      ),
    );
  }

  /// Place, calendar and "make this our meetup" for another shared sport
  /// time — read-only; its place comes from the sport times themselves.
  Widget _buildOtherTimeDetails(SharedSportTime time) {
    final place = time.locationName;
    final hasMap = time.latitude != null && time.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('group.otherSportTimeHint'),
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (place != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: hasMap
                ? () => _showMeetingPointMap(
                    name: place,
                    latitude: time.latitude,
                    longitude: time.longitude,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    placeLabel(place),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasMap) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          children: [
            TextButton.icon(
              onPressed: () => _useAsMeetup(time),
              icon: const Icon(Icons.event_available, size: 18),
              label: Text(t('group.useAsMeetup')),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addToCalendar(
                start: time.nextOccurrence,
                sport: time.mine.sport,
                location: place,
              ),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(t('group.addToCalendar')),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final group = _group!;
    final myId = SupabaseService.currentUserId;
    final isCreator = group.createdBy == myId;
    // A private chat is about the other person: their name is the title and
    // both of them can set the next meetup.
    final partner = group.isDirect
        ? _members.where((m) => m.id != myId).firstOrNull
        : null;
    final canEditMeetingPoint = isCreator || group.isDirect;
    final shownSport = _page > 0
        ? _otherTimes[_page - 1].mine.sport
        : group.sport;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/chat'),
        ),
        title: partner == null
            ? Text(group.isDirect ? t('chatList.directChat') : group.name)
            : InkWell(
                onTap: () => context.push('/profile/${partner.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Avatar(profile: partner, radius: 16),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        partner.firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
        // One menu with words instead of two bare symbols — a bell and a
        // flag were too easy to tap by accident and too hard to read.
        actions: [
          PopupMenuButton<String>(
            tooltip: t('group.menu'),
            onSelected: (choice) async {
              if (choice == 'mute') {
                await _toggleMuted();
                return;
              }
              final blocked = await showDialog<bool>(
                context: context,
                builder: (_) => ReportUserDialog(
                  members: _members.where((m) => m.id != myId).toList(),
                  groupId: widget.groupId,
                ),
              );
              // Blocking removes me from this chat server-side — leave the
              // screen instead of showing a group I'm no longer part of.
              if (blocked == true && context.mounted) {
                safeBack(context, '/chat');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _muted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(_muted ? t('group.unmute') : t('group.mute')),
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(t('group.reportUser')),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_muted)
              Material(
                color: AppColors.secondaryLight,
                child: InkWell(
                  onTap: _toggleMuted,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t('group.mutedBanner'))),
                        Text(
                          t('group.unmuteShort'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_inputFocus.hasFocus)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeetupTitleRow(group),
                    if (!group.isDirect) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _members
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => context.push(
                                      m.id == myId
                                          ? '/profile'
                                          : '/profile/${m.id}',
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.secondaryLight,
                                      backgroundImage: m.avatarUrl != null
                                          ? NetworkImage(m.avatarUrl!)
                                          : null,
                                      child: m.avatarUrl != null
                                          ? null
                                          : Text(
                                              m.fullName.isNotEmpty
                                                  ? m.fullName[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_page > 0)
                      _buildOtherTimeDetails(_otherTimes[_page - 1])
                    else if (canEditMeetingPoint)
                      InkWell(
                        onTap: _pickMeetingPoint,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            hintText: t('group.setMeetingPoint'),
                            prefixIcon: const Icon(Icons.place_outlined),
                            suffixIcon: const Icon(Icons.map_outlined),
                            isDense: true,
                          ),
                          child: Text(
                            group.meetingPoint == null
                                ? t('group.setMeetingPoint')
                                : placeLabel(group.meetingPoint!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: group.meetingPoint == null
                                ? TextStyle(color: AppColors.textSecondary)
                                : null,
                          ),
                        ),
                      )
                    else if (group.meetingPoint != null)
                      InkWell(
                        onTap: group.hasMapLocation
                            ? _showMeetingPointMap
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                placeLabel(group.meetingPoint!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.hasMapLocation) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.map_outlined,
                                size: 16,
                                color: AppColors.secondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (shownSport == SportType.kinderSpielen) ...[
                      const SizedBox(height: 12),
                      SafetyNotice(text: t('safety.childMeetupNotice')),
                    ],
                    if (_page == 0 &&
                        group.meetingTime != null &&
                        group.meetingTime!.isAfter(DateTime.now()))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addToCalendar,
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: Text(t('group.addToCalendar')),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!_inputFocus.hasFocus &&
                group.meetingTime != null &&
                group.meetingTime!.isBefore(DateTime.now()) &&
                !(_checkedInFor?.isAtSameMomentAs(group.meetingTime!) ??
                    false) &&
                _members.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Card(
                  color: AppColors.secondaryLight,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('group.didMeetingHappen'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('group.checkinHint'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _checkingIn
                                    ? null
                                    : () => _checkIn(false),
                                icon: const Icon(Icons.close, size: 18),
                                label: Text(t('group.review.notMet')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _checkingIn ? null : _openReview,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(t('group.review.start')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _ChatView(
                groupId: widget.groupId,
                focusNode: _inputFocus,
                members: _members,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.groupId,
    required this.focusNode,
    required this.members,
  });
  final String groupId;
  final FocusNode focusNode;

  /// For names in replies ("Antwort an Anna").
  final List<Profile> members;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageService = MessageService();
  final _groupService = GroupService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastSeenMessageId;

  // Created once, not in build(): every rebuild (keyboard opening, the
  // parent's setState) would otherwise tear down the realtime subscription
  // and start a new one, dropping messages that arrive in between.
  late Stream<List<ChatMessage>> _messages = _messageService.streamMessages(
    widget.groupId,
  );
  late Stream<List<MessageReaction>> _reactions = _messageService
      .streamReactions(widget.groupId);
  late final AppLifecycleListener _lifecycle;
  Timer? _retryTimer;

  /// The message I'm answering (shown above the input), if any.
  ChatMessage? _replyTo;

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  String _nameOf(String userId) {
    if (userId == SupabaseService.currentUserId) return t('group.you');
    for (final m in widget.members) {
      if (m.id == userId) return m.firstName;
    }
    return '…';
  }

  void _startReply(ChatMessage m) {
    setState(() => _replyTo = m);
    widget.focusNode.requestFocus();
  }

  Future<void> _react(ChatMessage m, String? emoji) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null) return;
    try {
      await _messageService.setReaction(
        messageId: m.id,
        groupId: widget.groupId,
        userId: myId,
        emoji: emoji,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('group.reactFailed'))));
    }
  }

  /// Long press: emoji bar, reply, copy — like WhatsApp.
  Future<void> _showMessageActions(ChatMessage m, String? myEmoji) async {
    widget.focusNode.unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in _quickReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).pop('react:$e'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: e == myEmoji
                              ? AppColors.secondaryLight
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(t('group.reply')),
                onTap: () => Navigator.of(context).pop('reply'),
              ),
              if (m.gifUrl == null)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(t('group.copy')),
                  onTap: () => Navigator.of(context).pop('copy'),
                ),
              if (myEmoji != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(t('group.removeReaction')),
                  onTap: () => Navigator.of(context).pop('unreact'),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'reply') {
      _startReply(m);
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.content));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('group.copied'))));
    } else if (choice == 'unreact') {
      await _react(m, null);
    } else if (choice.startsWith('react:')) {
      final emoji = choice.substring(6);
      await _react(m, emoji == myEmoji ? null : emoji);
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resubscribe);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _retryTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Mobile browsers drop the realtime connection while the tab is in the
  /// background, and it doesn't replay what was missed — start a fresh
  /// subscription, which refetches the full history. The StreamBuilder
  /// keeps showing the previous messages in the meantime.
  void _resubscribe() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!mounted) return;
    setState(() {
      _messages = _messageService.streamMessages(widget.groupId);
      _reactions = _messageService.streamReactions(widget.groupId);
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final replyTo = _replyTo;
    _textCtrl.clear();
    setState(() => _replyTo = null);
    // Scrolled up to read older messages? Jump back down to my new one.
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    try {
      await _messageService.sendMessage(
        groupId: widget.groupId,
        senderId: SupabaseService.currentUserId!,
        content: text,
        replyTo: replyTo?.id,
      );
    } catch (_) {
      if (!mounted) return;
      // Give the text (and the reply) back instead of silently losing it.
      if (_textCtrl.text.isEmpty) _textCtrl.text = text;
      setState(() => _replyTo ??= replyTo);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('group.sendFailed'))));
    }
  }

  Future<void> _pickGif() async {
    widget.focusNode.unfocus();
    final gif = await showModalBottomSheet<Gif>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const GifPickerSheet(),
    );
    if (gif == null || !mounted) return;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    try {
      await _messageService.sendMessage(
        groupId: widget.groupId,
        senderId: SupabaseService.currentUserId!,
        content: 'GIF',
        gifUrl: gif.url,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('group.gifSendFailed', {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _retryTimer ??= Timer(const Duration(seconds: 3), _resubscribe);
              }
              final messages = snapshot.data ?? [];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    t('group.noMessages'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              final lastMessage = messages.last;
              if (lastMessage.id != _lastSeenMessageId) {
                _lastSeenMessageId = lastMessage.id;
                if (myId != null) {
                  _groupService
                      .markGroupRead(groupId: widget.groupId, userId: myId)
                      .then((_) => UnreadController.refresh());
                }
              }
              final byId = {for (final m in messages) m.id: m};
              // Like WhatsApp: newest message at the bottom, right above the
              // input. A reversed list starts there by itself and stays
              // there as new messages arrive.
              return StreamBuilder<List<MessageReaction>>(
                stream: _reactions,
                builder: (context, reactionSnapshot) {
                  // Before the reactions table exists (or on a hiccup) the
                  // chat simply shows no reactions.
                  final reactionsByMessage = <String, List<MessageReaction>>{};
                  for (final r
                      in reactionSnapshot.data ?? <MessageReaction>[]) {
                    (reactionsByMessage[r.messageId] ??= []).add(r);
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    // Swiping the messages closes the keyboard, which also
                    // brings the header back.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, reversedIndex) {
                      final index = messages.length - 1 - reversedIndex;
                      final m = messages[index];
                      final showDateDivider =
                          index == 0 ||
                          !_isSameDay(
                            messages[index - 1].createdAt,
                            m.createdAt,
                          );
                      final reactions = reactionsByMessage[m.id] ?? const [];
                      final myEmoji = reactions
                          .where((r) => r.userId == myId)
                          .map((r) => r.emoji)
                          .firstOrNull;
                      final quoted = m.replyTo == null ? null : byId[m.replyTo];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateDivider) _DateDivider(date: m.createdAt),
                          MessageRow(
                            message: m,
                            mine: m.senderId == myId,
                            hasReply: m.replyTo != null,
                            quoted: quoted,
                            quotedName: quoted == null
                                ? null
                                : _nameOf(quoted.senderId),
                            reactions: reactions,
                            myEmoji: myEmoji,
                            onReply: () => _startReply(m),
                            onLongPress: () => _showMessageActions(m, myEmoji),
                            // Double tap: quick ❤️ (again removes it).
                            onDoubleTap: () =>
                                _react(m, myEmoji == '❤️' ? null : '❤️'),
                            onReactionTap: (emoji) =>
                                _react(m, myEmoji == emoji ? null : emoji),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_replyTo != null)
          ReplyComposerBar(
            name: _nameOf(_replyTo!.senderId),
            text: _replyTo!.gifUrl != null ? 'GIF' : _replyTo!.content,
            onClose: () => setState(() => _replyTo = null),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                if (GiphyService.isEnabled) ...[
                  IconButton(
                    tooltip: t('group.sendGif'),
                    onPressed: _pickGif,
                    icon: Icon(
                      Icons.gif_box_outlined,
                      size: 30,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: widget.focusNode,
                    decoration: InputDecoration(
                      hintText: t('group.messagePlaceholder'),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String _formatDateDividerLabel(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  if (_isSameDay(local, now)) return t('group.today');
  if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
    return t('group.yesterday');
  }
  return '${weekdayLabels[local.weekday - 1]}, '
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatDateDividerLabel(date),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.radius});

  final Profile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondaryLight,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url != null
          ? null
          : Text(
              profile.fullName.isNotEmpty
                  ? profile.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

class _PagerArrow extends StatelessWidget {
  const _PagerArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      color: AppColors.primary,
    );
  }
}
