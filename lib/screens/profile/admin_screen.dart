import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/admin_items.dart';
import '../../models/profile.dart';
import '../../services/admin_notifier.dart';
import '../../services/feedback_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/csv_export.dart';

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.'
    '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// The operator's view of everything users sent: reports, in-app feedback
/// and why accounts were paused/deleted — always live from the database,
/// each tab downloadable as an Excel-ready CSV. Only reachable for admins;
/// the database (RLS) only returns these rows to admins anyway.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.service});

  /// Injectable for tests.
  final FeedbackService? service;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final _service = widget.service ?? FeedbackService();
  List<ReportItem> _reports = [];
  List<FeedbackItem> _feedback = [];
  List<AccountFeedbackItem> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Clears the red dot on Profil / settings / this entry.
    if (widget.service == null) AdminNotifier.markSeen();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getReports(),
        _service.getFeedback(),
        _service.getAccountFeedback(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<ReportItem>;
        _feedback = results[1] as List<FeedbackItem>;
        _accounts = results[2] as List<AccountFeedbackItem>;
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

  Future<void> _toggle(String table, String id, bool done) async {
    try {
      await _service.setStatus(table: table, id: id, done: done);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _export(int tab) {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final ok = switch (tab) {
      0 => downloadCsv(
        'samepace-meldungen-$stamp.csv',
        [
          'Datum',
          'Status',
          'Gemeldet von',
          'Gemeldete Person',
          'Meldungen gesamt',
          'Gesperrt',
          'Grund',
          'Details',
          'Chat gespeichert',
        ],
        [
          for (final r in _reports)
            [
              _fmt(r.createdAt),
              r.done ? 'erledigt' : 'neu',
              r.reporterName,
              r.reportedName,
              '${r.reportedCount}',
              r.reportedSuspended ? 'ja' : 'nein',
              r.reason,
              r.details,
              r.hasChat ? 'ja' : 'nein',
            ],
        ],
      ),
      1 => downloadCsv(
        'samepace-feedback-$stamp.csv',
        ['Datum', 'Status', 'Von', 'Art', 'Nachricht'],
        [
          for (final f in _feedback)
            [
              _fmt(f.createdAt),
              f.done ? 'erledigt' : 'neu',
              f.userName ?? 'gelöschtes Konto',
              f.category.label,
              f.message,
            ],
        ],
      ),
      _ => downloadCsv(
        'samepace-konto-feedback-$stamp.csv',
        ['Datum', 'Aktion', 'Person', 'Grund'],
        [
          for (final a in _accounts)
            [
              _fmt(a.createdAt),
              a.isDeletion ? 'gelöscht' : 'pausiert',
              a.userName ?? 'gelöschtes Konto',
              a.reason,
            ],
        ],
      ),
    };
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('admin.exportUnavailable'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final newReports = _reports.where((r) => !r.done).length;
    final newFeedback = _feedback.where((f) => !f.done).length;
    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(t('admin.title')),
            actions: [
              IconButton(
                tooltip: t('admin.refresh'),
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
              IconButton(
                tooltip: t('admin.export'),
                icon: const Icon(Icons.download),
                onPressed: _loading
                    ? null
                    : () {
                        final tab = DefaultTabController.of(context).index;
                        if (tab < 3) _export(tab);
                      },
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: '${t('admin.reports')} ($newReports)'),
                Tab(text: '${t('admin.feedback')} ($newFeedback)'),
                Tab(text: t('admin.accounts')),
                Tab(text: t('admin.admins')),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      t('admin.loadFailed', {'error': _error!}),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : TabBarView(
                  children: [
                    _list(
                      _reports.map(
                        (r) => _ItemCard(
                          date: r.createdAt,
                          title: t('admin.reportTitle', {
                            'reporter': r.reporterName ?? '?',
                            'reported': r.reportedName ?? '?',
                          }),
                          tag: r.reason,
                          body: r.details,
                          footnote: [
                            t('admin.reportCount', {
                              'count': '${r.reportedCount}',
                            }),
                            if (r.reportedSuspended) t('admin.suspended'),
                            if (r.hasChat) t('admin.chatKept'),
                          ].join(' · '),
                          done: r.done,
                          onDone: (v) => _toggle('reports', r.id, v),
                        ),
                      ),
                    ),
                    _list(
                      _feedback.map(
                        (f) => _ItemCard(
                          date: f.createdAt,
                          title: f.userName ?? t('admin.deletedAccount'),
                          tag: f.category.label,
                          body: f.message,
                          done: f.done,
                          onDone: (v) => _toggle('feedback', f.id, v),
                        ),
                      ),
                    ),
                    _list(
                      _accounts.map(
                        (a) => _ItemCard(
                          date: a.createdAt,
                          title: a.userName ?? t('admin.deletedAccount'),
                          tag: a.isDeletion
                              ? t('admin.deleted')
                              : t('admin.paused'),
                          body: a.reason ?? t('admin.noReason'),
                        ),
                      ),
                    ),
                    _AdminsTab(service: _service),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _list(Iterable<Widget> cards) {
    final items = cards.toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    t('admin.empty'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            )
          : ListView(padding: const EdgeInsets.all(16), children: items),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.date,
    required this.title,
    required this.tag,
    this.body,
    this.footnote,
    this.done,
    this.onDone,
  });

  final DateTime date;
  final String title;
  final String tag;
  final String? body;
  final String? footnote;

  /// Null = no status (account feedback).
  final bool? done;
  final ValueChanged<bool>? onDone;

  @override
  Widget build(BuildContext context) {
    final done = this.done;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: done == true ? AppColors.textSecondary : null,
                    ),
                  ),
                ),
                if (done != null)
                  FilterChip(
                    label: Text(done ? t('admin.done') : t('admin.new')),
                    selected: done,
                    onSelected: onDone,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_fmt(date)} · $tag',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(body!),
            ],
            if (footnote != null && footnote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                footnote!,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Who else can see this view: list the admins, appoint someone by name,
/// or remove an admin (the database keeps at least one).
class _AdminsTab extends StatefulWidget {
  const _AdminsTab({required this.service});

  final FeedbackService service;

  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  late Future<List<Profile>> _admins = widget.service.getAdmins();

  void _reload() {
    setState(() {
      _admins = widget.service.getAdmins();
    });
  }

  Future<void> _change(Profile p, bool admin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(admin ? t('admin.addTitle') : t('admin.removeTitle')),
        content: Text(
          t(admin ? 'admin.addConfirm' : 'admin.removeConfirm', {
            'name': p.fullName,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(admin ? t('admin.add') : t('admin.remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.setAdmin(p.id, admin);
      _reload();
    } catch (e) {
      if (!mounted) return;
      final last = '$e'.contains('last admin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            last
                ? t('admin.lastAdmin')
                : t('admin.changeFailed', {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Future<void> _pickNewAdmin() async {
    final picked = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSearchSheet(service: widget.service),
    );
    if (picked != null) await _change(picked, true);
  }

  @override
  Widget build(BuildContext context) {
    String? myId;
    try {
      myId = SupabaseService.currentUserId;
    } catch (_) {
      // No Supabase (tests) — just don't mark anyone as "you".
    }
    return FutureBuilder<List<Profile>>(
      future: _admins,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final admins = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('admin.adminsHint'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final a in admins)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    backgroundImage: a.avatarUrl != null
                        ? NetworkImage(a.avatarUrl!)
                        : null,
                    child: a.avatarUrl != null
                        ? null
                        : Text(
                            a.fullName.isNotEmpty
                                ? a.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: AppColors.primary),
                          ),
                  ),
                  title: Text(
                    a.id == myId
                        ? t('admin.you', {'name': a.fullName})
                        : a.fullName,
                  ),
                  subtitle: a.city == null ? null : Text(a.city!),
                  trailing: admins.length > 1
                      ? IconButton(
                          tooltip: t('admin.remove'),
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _change(a, false),
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickNewAdmin,
              icon: const Icon(Icons.person_add_alt),
              label: Text(t('admin.addButton')),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileSearchSheet extends StatefulWidget {
  const _ProfileSearchSheet({required this.service});

  final FeedbackService service;

  @override
  State<_ProfileSearchSheet> createState() => _ProfileSearchSheetState();
}

class _ProfileSearchSheetState extends State<_ProfileSearchSheet> {
  List<Profile> _results = [];
  int _requestId = 0;

  Future<void> _search(String q) async {
    final id = ++_requestId;
    final results = await widget.service.searchProfiles(q);
    if (!mounted || id != _requestId) return;
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('admin.addTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: t('admin.searchHint'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in _results)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(p.fullName),
                      subtitle: p.city == null ? null : Text(p.city!),
                      onTap: () => Navigator.of(context).pop(p),
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
