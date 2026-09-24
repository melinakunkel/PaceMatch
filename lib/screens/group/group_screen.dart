import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../services/giphy_service.dart';
import '../../services/group_service.dart';
import '../../services/message_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/calendar_export.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/safety_notice.dart';
import '../plan/location_picker_screen.dart';
import 'gif_picker_sheet.dart';
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

  Future<void> _load() async {
    final group = await _groupService.getGroup(widget.groupId);
    final members = await _groupService.getGroupMembers(widget.groupId);
    final myId = SupabaseService.currentUserId;
    DateTime? checkedInFor;
    if (myId != null) {
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
    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _checkedInFor = checkedInFor;
      _loading = false;
    });
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

  Future<void> _showMeetingPointMap() async {
    final group = _group;
    if (group == null || !group.hasMapLocation) return;
    final point = LatLng(group.latitude!, group.longitude!);
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
                      group.meetingPoint ?? t('group.meetingPoint'),
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

  Future<void> _addToCalendar() async {
    final group = _group;
    final meetingTime = group?.meetingTime;
    if (group == null || meetingTime == null) return;
    final end = meetingTime.add(const Duration(hours: 1));
    final myId = SupabaseService.currentUserId;
    final partner = group.isDirect
        ? _members.where((m) => m.id != myId).firstOrNull
        : null;
    final title = partner == null
        ? group.name
        : t('discover.groupNameWith', {
            'sport': group.sport.label,
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
              location: group.meetingPoint,
            ),
          )
        : Uri.parse(
            buildIcsDataUri(
              title: title,
              start: meetingTime,
              end: end,
              location: group.meetingPoint,
            ),
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: t('group.reportUser'),
            onPressed: () async {
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
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_inputFocus.hasFocus)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          group.sport.icon,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          group.isDirect
                              ? group.sport.label
                              : t('chatList.participants', {
                                  'count': '${group.memberCount}',
                                }),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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
                    if (canEditMeetingPoint)
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
                            group.meetingPoint ?? t('group.setMeetingPoint'),
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
                                group.meetingPoint!,
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
                    if (group.sport == SportType.kinderSpielen) ...[
                      const SizedBox(height: 12),
                      SafetyNotice(text: t('safety.childMeetupNotice')),
                    ],
                    if (group.meetingTime != null &&
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
              child: _ChatView(groupId: widget.groupId, focusNode: _inputFocus),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.groupId, required this.focusNode});
  final String groupId;
  final FocusNode focusNode;

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
  late final AppLifecycleListener _lifecycle;
  Timer? _retryTimer;

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
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    // Scrolled up to read older messages? Jump back down to my new one.
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    await _messageService.sendMessage(
      groupId: widget.groupId,
      senderId: SupabaseService.currentUserId!,
      content: text,
    );
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
              // Like WhatsApp: newest message at the bottom, right above the
              // input. A reversed list starts there by itself and stays
              // there as new messages arrive.
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
                  final mine = m.senderId == myId;
                  final showDateDivider =
                      index == 0 ||
                      !_isSameDay(messages[index - 1].createdAt, m.createdAt);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateDivider) _DateDivider(date: m.createdAt),
                      Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (m.gifUrl != null &&
                                GiphyService.allowedUrl.hasMatch(m.gifUrl!))
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                  maxHeight: 260,
                                  minWidth: 80,
                                  minHeight: 80,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: GifImage(url: m.gifUrl!),
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? AppColors.secondary
                                      : AppColors.surface,
                                  border: mine
                                      ? null
                                      : Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m.content,
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _formatMessageTime(m.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
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

String _formatMessageTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
