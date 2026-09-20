import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/match_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

class _MatchedActivity {
  _MatchedActivity({required this.activity, required this.matchCount});
  final Activity activity;
  final int matchCount;
}

/// Matches tab: only your own activities that actually have people matching
/// them right now, ranked to jump straight into who fits.
class MatchesHubScreen extends StatefulWidget {
  const MatchesHubScreen({super.key});

  @override
  State<MatchesHubScreen> createState() => _MatchesHubScreenState();
}

class _MatchesHubScreenState extends State<MatchesHubScreen> {
  final _activityService = ActivityService();
  final _matchService = MatchService();
  late Future<List<_MatchedActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_MatchedActivity>> _load() async {
    final activities = await _activityService.getMyActivities(
      SupabaseService.currentUserId!,
    );
    final results = <_MatchedActivity>[];
    for (final a in activities) {
      final matches = await _matchService.findMatches(a);
      if (matches.isNotEmpty) {
        results.add(_MatchedActivity(activity: a, matchCount: matches.length));
      }
    }
    results.sort((a, b) => b.matchCount.compareTo(a.matchCount));
    return results;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2,
      title: 'Matches',
      actions: [
        IconButton(
          icon: const Icon(Icons.explore_outlined),
          tooltip: 'Entdecken',
          onPressed: () => context.push('/discover'),
        ),
      ],
      body: FutureBuilder<List<_MatchedActivity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final matched = snapshot.data ?? [];
          if (matched.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aktuell gibt es noch keine passenden Leute zu deinen '
                    'Sportzeiten. Trag weitere Zeiten ein oder schau später nochmal vorbei.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.push('/new-activity'),
                      child: const Text('Sportzeit eintragen'),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: matched.length,
              itemBuilder: (context, index) {
                final m = matched[index];
                final a = m.activity;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondaryLight,
                      child: Icon(a.sport.icon, color: AppColors.primary),
                    ),
                    title: Text('${a.sport.label} · ${a.dayLabel}'),
                    subtitle: Text(a.timeRangeLabel),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${m.matchCount}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onTap: () => context.push('/matches/${a.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
