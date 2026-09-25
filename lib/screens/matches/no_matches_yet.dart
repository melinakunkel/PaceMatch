import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/match_candidate.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/community_event_service.dart';
import '../../services/match_service.dart';
import '../../services/open_event_service.dart';
import '../../services/profile_service.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/share/share_stub.dart'
    if (dart.library.js_interop) '../../utils/share/share_web.dart';
import '../../widgets/push_prompt.dart';

/// Shown instead of an empty match list: nobody fits exactly *yet*, but
/// here's who almost fits, what's on in your city, and a way to bring a
/// friend — plus the promise of a push once someone matches.
class NoMatchesYet extends StatefulWidget {
  const NoMatchesYet({
    super.key,
    required this.activity,
    required this.onDayAdded,
  });

  final Activity activity;

  /// Called with the new activity after "add Saturday too".
  final ValueChanged<Activity> onDayAdded;

  @override
  State<NoMatchesYet> createState() => _NoMatchesYetState();
}

class _EventItem {
  const _EventItem({
    required this.date,
    required this.title,
    required this.subtitle,
    this.url,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final String? url;
}

class _NoMatchesYetState extends State<NoMatchesYet> {
  NearMisses _nearMisses = const NearMisses();
  List<_EventItem> _events = [];
  bool _loading = true;
  int? _addingDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _nearMisses = await MatchService().findNearMisses(widget.activity);
    } catch (_) {
      // Suggestions are a bonus — never show an error for them.
    }
    try {
      _events = await _loadEvents();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<List<_EventItem>> _loadEvents() async {
    final a = widget.activity;
    final city = (await ProfileService().getProfile(a.userId)).city;
    if (city == null || city.trim().isEmpty) return [];
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 14));
    final items = <_EventItem>[];

    final community = await CommunityEventService().getAllForCity(city);
    for (final e in community.where((e) => e.sport == a.sport)) {
      final next = e.occurrencesBetween(from, to);
      if (next.isEmpty) continue;
      items.add(
        _EventItem(
          date: next.first,
          title: e.name,
          subtitle:
              '${_dateLabel(next.first)} · ${e.timeRangeLabel} · ${e.locationName}',
          url: e.url,
        ),
      );
    }
    final open = await OpenEventService().getUpcomingForCity(
      city: city,
      from: from,
      userId: a.userId,
      days: 14,
    );
    for (final e in open.where((e) => e.sport == a.sport)) {
      items.add(
        _EventItem(
          date: e.eventDate,
          title: e.name,
          subtitle:
              '${_dateLabel(e.eventDate)} · ${e.timeRangeLabel} · ${e.locationName}',
        ),
      );
    }
    items.sort((x, y) => x.date.compareTo(y.date));
    return items.take(3).toList();
  }

  static String _dateLabel(DateTime d) =>
      '${weekdayLabels[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.';

  Future<void> _addDay(int day) async {
    setState(() => _addingDay = day);
    try {
      final created = await ActivityService().copyToDay(widget.activity, day);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('noMatches.dayAdded', {'day': weekdayFullLabels[day - 1]}),
          ),
        ),
      );
      widget.onDayAdded(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingDay = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    }
  }

  String get _inviteText {
    final a = widget.activity;
    return t('noMatches.inviteMessage', {
      'sport': a.sport.label,
      'day': a.isRecurring ? a.dayLabel : a.specificDateLabel,
      'url': appBaseUrl,
    });
  }

  Future<void> _openInvite(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('circles.inviteFailed'))));
    }
  }

  void _inviteViaWhatsApp() => _openInvite(
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_inviteText)}'),
  );

  // "?&body=" works on both iPhone and Android.
  void _inviteViaSms() =>
      _openInvite(Uri.parse('sms:?&body=${Uri.encodeComponent(_inviteText)}'));

  /// Signal has no link that pre-fills a message, so this opens the
  /// phone's share sheet (where Signal is listed) — or copies the text
  /// where there is none.
  Future<void> _inviteViaShareSheet() async {
    final text = _inviteText;
    if (await shareText(text)) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('noMatches.inviteCopied'))));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _waitingCard(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (_nearMisses.otherDays.isNotEmpty) ..._otherDaysSection(),
          if (_nearMisses.otherTimes.isNotEmpty) ..._otherTimesSection(),
          if (_events.isNotEmpty) ..._eventsSection(),
          _inviteCard(),
        ],
      ],
    );
  }

  Widget _waitingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<bool>(
          valueListenable: PushService.active,
          builder: (context, pushOn, _) {
            final canPush =
                PushService.isSupported || PushService.needsHomeScreen;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_top, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t('noMatches.title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pushOn
                      ? t('noMatches.pushOn')
                      : canPush
                      ? t('noMatches.pushOff')
                      : t('noMatches.noPush'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (!pushOn && canPush) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      PushService.needsHomeScreen
                          ? t('push.iosButton')
                          : t('noMatches.enablePush'),
                    ),
                    onPressed: () => enablePush(context),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  List<Widget> _otherDaysSection() {
    final days = _nearMisses.otherDays.keys.toList()
      ..sort(
        (a, b) => _nearMisses.otherDays[b]!.length.compareTo(
          _nearMisses.otherDays[a]!.length,
        ),
      );
    return [
      _sectionTitle(t('noMatches.otherDaysTitle')),
      for (final day in days.take(4))
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _Avatars(_nearMisses.otherDays[day]!),
            title: Text(
              t('noMatches.peopleOnDay', {
                'day': weekdayFullLabels[day - 1],
                'count': '${_nearMisses.otherDays[day]!.length}',
              }),
            ),
            subtitle: Text(
              _nearMisses.otherDays[day]!
                  .map((c) => c.profile.firstName)
                  .take(3)
                  .join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _addingDay == day
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _addingDay == null ? () => _addDay(day) : null,
                    child: Text(
                      t('noMatches.addDay', {'day': weekdayLabels[day - 1]}),
                    ),
                  ),
          ),
        ),
    ];
  }

  List<Widget> _otherTimesSection() {
    return [
      _sectionTitle(
        t('noMatches.otherTimesTitle', {
          'day': widget.activity.isRecurring
              ? widget.activity.dayLabel
              : widget.activity.specificDateLabel,
        }),
      ),
      for (final c in _nearMisses.otherTimes.take(5))
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _Avatar(c),
            title: Text(c.profile.firstName),
            subtitle: Text(c.theirActivity.timeRangeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/${c.profile.id}'),
          ),
        ),
    ];
  }

  List<Widget> _eventsSection() {
    return [
      _sectionTitle(t('noMatches.eventsTitle')),
      for (final e in _events)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.groups_outlined, color: AppColors.primary),
            title: Text(e.title),
            subtitle: Text(
              e.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final url = e.url;
              if (url != null && url.isNotEmpty) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } else {
                context.go('/discover');
              }
            },
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.go('/discover'),
          child: Text(t('noMatches.allEvents')),
        ),
      ),
    ];
  }

  Widget _inviteCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        color: AppColors.secondaryLight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('noMatches.inviteTitle'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                t('noMatches.inviteBody'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                    onPressed: _inviteViaWhatsApp,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('SMS'),
                    onPressed: _inviteViaSms,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: Text(t('noMatches.inviteMore')),
                    onPressed: _inviteViaShareSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.candidate, {this.radius = 20});

  final MatchCandidate candidate;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = candidate.profile.avatarUrl;
    final name = candidate.profile.firstName;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondaryLight,
      backgroundImage: url == null ? null : NetworkImage(url),
      child: url == null
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(color: AppColors.primary),
            )
          : null,
    );
  }
}

/// Up to three overlapping avatars.
class _Avatars extends StatelessWidget {
  const _Avatars(this.candidates);

  final List<MatchCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final shown = candidates.take(3).toList();
    return SizedBox(
      width: 40.0 + (shown.length - 1) * 14,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 14.0,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                child: _Avatar(shown[i], radius: 18),
              ),
            ),
        ],
      ),
    );
  }
}
