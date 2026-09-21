import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart' show weekdayLabels;
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/picked_location.dart';
import '../../models/profile.dart';
import '../../services/group_service.dart';
import '../../services/message_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/unread_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/safe_pop.dart';
import '../plan/location_picker_screen.dart';
import 'report_user_dialog.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupService = GroupService();
  final _profileService = ProfileService();

  SportGroup? _group;
  List<Profile> _members = [];
  bool? _myAttendance;
  bool _checkingIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await _groupService.getGroup(widget.groupId);
    final members = await _groupService.getGroupMembers(widget.groupId);
    final myId = SupabaseService.currentUserId;
    bool? myAttendance;
    if (myId != null) {
      await _groupService.markGroupRead(groupId: widget.groupId, userId: myId);
      UnreadController.refresh();
      myAttendance = await _groupService.getAttendance(
        groupId: widget.groupId,
        userId: myId,
      );
    }
    if (!mounted) return;
    setState(() {
      _group = group;
      _members = members;
      _myAttendance = myAttendance;
      _loading = false;
    });
  }

  Future<void> _checkIn(bool attended) async {
    final myId = SupabaseService.currentUserId;
    if (myId == null || _checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      await _groupService.checkIn(
        groupId: widget.groupId,
        userId: myId,
        attended: attended,
      );
      await _profileService.recomputeReliabilityScore(myId);
      if (!mounted) return;
      setState(() {
        _myAttendance = attended;
        _checkingIn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attended
                ? t('group.checkinThanksAttended')
                : t('group.checkinThanks'),
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

  @override
  Widget build(BuildContext context) {
    if (_loading || _group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final group = _group!;
    final myId = SupabaseService.currentUserId;
    final isCreator = group.createdBy == myId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/chat'),
        ),
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: t('group.reportUser'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ReportUserDialog(
                members: _members.where((m) => m.id != myId).toList(),
                groupId: widget.groupId,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                        t('chatList.participants', {
                          'count': '${group.memberCount}',
                        }),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 12),
                  if (isCreator)
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
                      onTap: group.hasMapLocation ? _showMeetingPointMap : null,
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
                ],
              ),
            ),
            if (group.meetingTime != null &&
                group.meetingTime!.isBefore(DateTime.now()) &&
                _myAttendance == null)
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
                                label: Text(t('group.couldNotMake')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _checkingIn
                                    ? null
                                    : () => _checkIn(true),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(t('group.wasThere')),
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
            Expanded(child: _ChatView(groupId: widget.groupId)),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.groupId});
  final String groupId;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _messageService = MessageService();
  final _groupService = GroupService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastSeenMessageId;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await _messageService.sendMessage(
      groupId: widget.groupId,
      senderId: SupabaseService.currentUserId!,
      content: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messageService.streamMessages(widget.groupId),
            builder: (context, snapshot) {
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
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
                            Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 280),
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
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
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
