import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import 'new_activity_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _activityService = ActivityService();
  late Future<List<Activity>> _future;
  int _selectedDay = DateTime.now().weekday; // 1 = Monday

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = SupabaseService.currentUserId!;
    _future = _activityService.getMyActivities(userId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 1,
      title: 'Mein Sportplan',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        onPressed: () async {
          await context.push('/new-activity');
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Sportzeit hinzufügen'),
      ),
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final activities = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                _WeekBar(
                  activities: activities,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _DayList(
                    activities: activities
                        .where((a) => a.dayOfWeek == _selectedDay)
                        .toList(),
                    onDeleted: _refresh,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.activities,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<Activity> activities;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = day == selectedDay;
          final count = activities.where((a) => a.dayOfWeek == day).length;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: count > 0
                            ? (selected ? Colors.white : AppColors.secondary)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.activities, required this.onDeleted});

  final List<Activity> activities;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Noch keine Sportzeit an diesem Tag.\nTippe unten, um eine hinzuzufügen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
            title: Text(
              '${a.timeRangeLabel}  ·  ${a.sport.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              a.isRecurring
                  ? (a.locationName ?? 'Ohne festen Ort')
                  : 'Einmalig, ${a.specificDateLabel}  ·  ${a.locationName ?? "Ohne festen Ort"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.people_outline, color: AppColors.secondary),
                  tooltip: 'Passende Leute anzeigen',
                  onPressed: () => context.push('/matches/${a.id}'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewActivityScreen(existing: a),
                        ),
                      );
                      onDeleted();
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sportzeit löschen?'),
                          content: Text(
                            '${a.sport.label} am ${a.dayLabel}, ${a.timeRangeLabel} wirklich löschen?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Abbrechen'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                'Löschen',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ActivityService().deleteActivity(a.id);
                        onDeleted();
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
