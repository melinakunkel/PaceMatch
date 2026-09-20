import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import 'new_activity_screen.dart';

enum _PlanViewMode { list, week }

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const _viewModeKey = 'plan_view_mode';

  final _activityService = ActivityService();
  late Future<List<Activity>> _future;
  int _selectedDay = DateTime.now().weekday; // 1 = Monday
  _PlanViewMode _viewMode = _PlanViewMode.list;

  @override
  void initState() {
    super.initState();
    _load();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_viewModeKey);
    if (saved == _PlanViewMode.week.name && mounted) {
      setState(() => _viewMode = _PlanViewMode.week);
    }
  }

  Future<void> _setViewMode(_PlanViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode.name);
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
      actions: [
        IconButton(
          icon: Icon(
            _viewMode == _PlanViewMode.list
                ? Icons.view_week_outlined
                : Icons.view_agenda_outlined,
          ),
          tooltip: _viewMode == _PlanViewMode.list
              ? 'Wochen-Kalender-Ansicht'
              : 'Listen-Ansicht',
          onPressed: () => _setViewMode(
            _viewMode == _PlanViewMode.list
                ? _PlanViewMode.week
                : _PlanViewMode.list,
          ),
        ),
      ],
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
          if (_viewMode == _PlanViewMode.week) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _WeekCalendarView(
                activities: activities,
                onChanged: _refresh,
              ),
            );
          }
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

Future<void> _editActivity(BuildContext context, Activity a) {
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => NewActivityScreen(existing: a)));
}

Future<bool> _confirmDeleteActivity(BuildContext context, Activity a) async {
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
          child: Text('Löschen', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ActivityService().deleteActivity(a.id);
  return true;
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
                      await _editActivity(context, a);
                      onDeleted();
                    } else if (value == 'delete') {
                      if (await _confirmDeleteActivity(context, a)) {
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

/// A compact week-at-a-glance timetable: one column per weekday, activities
/// placed by their start/end time. Same underlying weekly pattern as the
/// list view (activities bucketed by [Activity.dayOfWeek]), just laid out
/// as a calendar instead of picked one day at a time.
class _WeekCalendarView extends StatelessWidget {
  const _WeekCalendarView({required this.activities, required this.onChanged});

  final List<Activity> activities;
  final Future<void> Function() onChanged;

  static const _hourHeight = 52.0;
  static const _hourLabelWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Noch keine Sportzeiten eingetragen.\nTippe unten, um eine hinzuzufügen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    var minHour = 7;
    var maxHour = 21;
    for (final a in activities) {
      minHour = minHour < a.startTime.hour ? minHour : a.startTime.hour;
      final endHour = a.endTime.minute > 0
          ? a.endTime.hour + 1
          : a.endTime.hour;
      maxHour = maxHour > endHour ? maxHour : endHour;
    }
    final hourCount = maxHour - minHour;
    final gridHeight = hourCount * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _hourLabelWidth),
              ...List.generate(7, (i) {
                return Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabels[i],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: gridHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _hourLabelWidth,
                  height: gridHeight,
                  child: Stack(
                    children: List.generate(hourCount + 1, (i) {
                      return Positioned(
                        top: i * _hourHeight - 7,
                        right: 4,
                        child: Text(
                          '${minHour + i}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                ...List.generate(7, (i) {
                  final day = i + 1;
                  final dayActivities = activities
                      .where((a) => a.dayOfWeek == day)
                      .toList();
                  return Expanded(
                    child: _DayColumn(
                      activities: dayActivities,
                      minHour: minHour,
                      hourCount: hourCount,
                      hourHeight: _hourHeight,
                      onChanged: onChanged,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.activities,
    required this.minHour,
    required this.hourCount,
    required this.hourHeight,
    required this.onChanged,
  });

  final List<Activity> activities;
  final int minHour;
  final int hourCount;
  final double hourHeight;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final height = hourCount * hourHeight;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: height,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        children: [
          ...List.generate(
            hourCount + 1,
            (i) => Positioned(
              top: i * hourHeight,
              left: 0,
              right: 0,
              child: Divider(height: 1, color: AppColors.border),
            ),
          ),
          ...activities.map((a) {
            final startMinutes =
                (a.startTime.hour - minHour) * 60 + a.startTime.minute;
            final endMinutes =
                (a.endTime.hour - minHour) * 60 + a.endTime.minute;
            final top = startMinutes / 60 * hourHeight;
            final blockHeight = ((endMinutes - startMinutes) / 60 * hourHeight)
                .clamp(20, height);
            return Positioned(
              top: top,
              left: 1,
              right: 1,
              height: blockHeight.toDouble(),
              child: GestureDetector(
                onTap: () => _showActivitySheet(context, a, onChanged),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    border: Border.all(color: AppColors.secondary, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(a.sport.icon, size: 12, color: AppColors.primary),
                      if (blockHeight > 34)
                        Text(
                          a.startTime.hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

Future<void> _showActivitySheet(
  BuildContext context,
  Activity a,
  Future<void> Function() onChanged,
) async {
  await showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(a.sport.icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${a.sport.label} · ${a.timeRangeLabel}',
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
              a.isRecurring
                  ? (a.locationName ?? 'Ohne festen Ort')
                  : 'Einmalig, ${a.specificDateLabel}  ·  ${a.locationName ?? "Ohne festen Ort"}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/matches/${a.id}');
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Matches'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _editActivity(context, a);
                      onChanged();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Bearbeiten'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (await _confirmDeleteActivity(context, a)) onChanged();
                },
                icon: Icon(Icons.delete_outline, color: AppColors.danger),
                label: Text(
                  'Löschen',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
