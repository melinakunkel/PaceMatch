import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

/// Matches tab: pick one of your own scheduled activities to see who fits.
class MatchesHubScreen extends StatefulWidget {
  const MatchesHubScreen({super.key});

  @override
  State<MatchesHubScreen> createState() => _MatchesHubScreenState();
}

class _MatchesHubScreenState extends State<MatchesHubScreen> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = ActivityService().getMyActivities(SupabaseService.currentUserId!);
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
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text(
                      'Trage zuerst eine Sportzeit in deinem Plan ein, '
                      'um passende Leute zu finden.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/new-activity'),
                      child: const Text('Sportzeit eintragen'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final a = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    child: Icon(a.sport.icon, color: AppColors.primary),
                  ),
                  title: Text('${a.sport.label} · ${a.dayLabel}'),
                  subtitle: Text(a.timeRangeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/matches/${a.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
