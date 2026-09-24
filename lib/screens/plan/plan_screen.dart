import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/circle_controller.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/activity_stats.dart';
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
  static const _hourStartKey = 'plan_hour_start';
  static const _hourEndKey = 'plan_hour_end';

  final _activityService = ActivityService();
  late Future<List<Activity>> _future;
  int _selectedDay = DateTime.now().weekday; // 1 = Monday
  _PlanViewMode _viewMode = _PlanViewMode.list;
  RangeValues _hourRange = const RangeValues(7, 21);

  @override
  void initState() {
    super.initState();
    _load();
    _loadViewMode();
    _loadHourRange();
    CircleController.active.addListener(_onCircleChanged);
  }

  @override
  void dispose() {
    CircleController.active.removeListener(_onCircleChanged);
    super.dispose();
  }

  void _onCircleChanged() => _refresh();

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

  Future<void> _loadHourRange() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getDouble(_hourStartKey);
    final end = prefs.getDouble(_hourEndKey);
    if (start != null && end != null && mounted) {
      setState(() => _hourRange = RangeValues(start, end));
    }
  }

  Future<void> _setHourRange(RangeValues range) async {
    setState(() => _hourRange = range);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hourStartKey, range.start);
    await prefs.setDouble(_hourEndKey, range.end);
  }

  Future<void> _openHourRangeSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          var range = _hourRange;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('plan.hourRange.title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('plan.hourRange.subtitle'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  t('plan.hourRange.value', {
                    'start': _formatHour(range.start),
                    'end': _formatHour(range.end),
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: 24,
                  divisions: 48,
                  labels: RangeLabels(
                    _formatHour(range.start),
                    _formatHour(range.end),
                  ),
                  onChanged: (v) {
                    setSheetState(() => range = v);
                    _setHourRange(v);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatHour(double h) =>
      '${h.floor().clamp(0, 24).toString().padLeft(2, '0')}:00';

  void _load() {
    final userId = SupabaseService.currentUserId!;
    _future = _activityService.getMyActivities(
      userId,
      circleId: CircleController.active.value?.id,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 1,
      title: t('plan.title'),
      actions: [
        if (_viewMode == _PlanViewMode.week)
          IconButton(
            icon: const Icon(Icons.schedule_outlined),
            tooltip: t('plan.hourRange.title'),
            onPressed: _openHourRangeSheet,
          ),
        IconButton(
          icon: Icon(
            _viewMode == _PlanViewMode.list
                ? Icons.view_week_outlined
                : Icons.view_agenda_outlined,
          ),
          tooltip: _viewMode == _PlanViewMode.list
              ? t('plan.weekView')
              : t('plan.listView'),
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
        label: Text(t('plan.addActivity')),
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
                preferredMinHour: _hourRange.start.round(),
                preferredMaxHour: _hourRange.end.round(),
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
      title: Text(t('plan.deleteTitle')),
      content: Text(
        t('plan.deleteConfirm', {
          'sport': a.sport.label,
          'day': a.dayLabel,
          'time': a.timeRangeLabel,
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            t('common.delete'),
            style: TextStyle(color: AppColors.danger),
          ),
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
              t('plan.emptyDay'),
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
        final stats = activityStatsLabel(a, null);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showActivitySheet(context, a, onDeleted),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    child: Icon(a.sport.icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.sport.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a.timeRangeLabel,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                a.isRecurring
                                    ? (a.locationLabel ??
                                          t('plan.noFixedLocation'))
                                    : t('plan.oneOffLocation', {
                                        'date': a.specificDateLabel,
                                        'location':
                                            a.locationLabel ??
                                            t('plan.noFixedLocation'),
                                      }),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (stats != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            stats,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.people_outline,
                      color: AppColors.secondary,
                    ),
                    tooltip: t('plan.showMatches'),
                    onPressed: () => context.push('/matches/${a.id}'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A compact week-at-a-glance timetable, tied to real calendar dates: one
/// column per weekday of the currently viewed week, activities placed by
/// their start/end time. Recurring activities repeat every week on their
/// [Activity.dayOfWeek]; one-off activities ([Activity.specificDate]) only
/// show up in the week they actually fall in.
class _WeekCalendarView extends StatefulWidget {
  const _WeekCalendarView({
    required this.activities,
    required this.onChanged,
    required this.preferredMinHour,
    required this.preferredMaxHour,
  });

  final List<Activity> activities;
  final Future<void> Function() onChanged;

  /// The hour range to display, set via the "Sichtbarer Zeitraum" setting —
  /// this is the actual grid range shown; activities outside it are clipped
  /// (or partially shown, for ones that only start/end outside it) so the
  /// setting reliably shrinks or enlarges the timetable.
  final int preferredMinHour;
  final int preferredMaxHour;

  @override
  State<_WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends State<_WeekCalendarView> {
  static const _hourHeight = 52.0;
  static const _hourLabelWidth = 34.0;

  late DateTime _weekStart = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Activity> _activitiesForDate(DateTime date, int weekday) {
    return widget.activities.where((a) {
      if (a.specificDate != null) return _isSameDate(a.specificDate!, date);
      return a.dayOfWeek == weekday;
    }).toList();
  }

  void _shiftWeek(int days) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: days)));

  void _goToToday() => setState(() => _weekStart = _mondayOf(DateTime.now()));

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              t('plan.emptyWeek'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    final dates = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final byDay = List.generate(7, (i) => _activitiesForDate(dates[i], i + 1));
    final weekActivities = byDay.expand((l) => l).toList();
    final today = DateTime.now();
    final isCurrentWeek = _isSameDate(_weekStart, _mondayOf(today));

    final minHour = widget.preferredMinHour.clamp(0, 23);
    final maxHour = widget.preferredMaxHour.clamp(minHour + 1, 24);
    final hourCount = maxHour - minHour;
    final gridHeight = hourCount * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftWeek(-7),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_fmtDate(dates.first)} - ${_fmtDate(dates.last)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (!isCurrentWeek)
                      GestureDetector(
                        onTap: _goToToday,
                        child: Text(
                          t('plan.goToThisWeek'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftWeek(7),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: _hourLabelWidth),
              ...List.generate(7, (i) {
                final isToday = _isSameDate(dates[i], today);
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        weekdayLabels[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isToday ? AppColors.primary : null,
                        ),
                      ),
                      Text(
                        _fmtDate(dates[i]),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w700 : null,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
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
                  return Expanded(
                    child: _DayColumn(
                      activities: byDay[i],
                      minHour: minHour,
                      hourCount: hourCount,
                      hourHeight: _hourHeight,
                      onChanged: widget.onChanged,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (weekActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t('plan.emptyWeekShort'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One activity placed in a side-by-side "lane" among others that overlap
/// it in time, plus how many lanes its overlap cluster needs in total —
/// enough to size and position it without covering its neighbors.
class _LanedActivity {
  const _LanedActivity(this.activity, this.column, this.columnCount);
  final Activity activity;
  final int column;
  final int columnCount;
}

/// Greedily assigns each activity a column so time-overlapping ones sit
/// side by side instead of stacked exactly on top of each other (which
/// used to hide all but the last one drawn). Non-overlapping activities
/// each still get the full column width.
List<_LanedActivity> _layoutLanes(List<Activity> activities) {
  final sorted = [...activities]
    ..sort((a, b) {
      final aStart = a.startTime.hour * 60 + a.startTime.minute;
      final bStart = b.startTime.hour * 60 + b.startTime.minute;
      return aStart.compareTo(bStart);
    });

  final result = <_LanedActivity>[];
  final active = <(Activity, int, int)>[]; // (activity, column, endMinutes)
  var cluster = <(Activity, int)>[]; // (activity, column)
  var clusterColumns = 0;

  void flushCluster() {
    for (final entry in cluster) {
      result.add(_LanedActivity(entry.$1, entry.$2, clusterColumns));
    }
    cluster = [];
    clusterColumns = 0;
  }

  for (final a in sorted) {
    final startMin = a.startTime.hour * 60 + a.startTime.minute;
    final endMin = a.endTime.hour * 60 + a.endTime.minute;
    active.removeWhere((e) => e.$3 <= startMin);
    if (active.isEmpty && cluster.isNotEmpty) flushCluster();
    final usedColumns = active.map((e) => e.$2).toSet();
    var column = 0;
    while (usedColumns.contains(column)) {
      column++;
    }
    active.add((a, column, endMin));
    cluster.add((a, column));
    if (column + 1 > clusterColumns) clusterColumns = column + 1;
  }
  flushCluster();
  return result;
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
    final laned = _layoutLanes(activities);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: height,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.hardEdge,
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
              ...laned.map((l) {
                final a = l.activity;
                final rawStart =
                    (a.startTime.hour - minHour) * 60 + a.startTime.minute;
                final rawEnd =
                    (a.endTime.hour - minHour) * 60 + a.endTime.minute;
                // Clip to the visible range instead of assuming every
                // activity fits — the grid only spans [minHour, maxHour]
                // now, so one outside it would otherwise render off-canvas.
                final top = (rawStart / 60 * hourHeight).clamp(0.0, height);
                final bottom = (rawEnd / 60 * hourHeight).clamp(0.0, height);
                final blockHeight = bottom - top;
                if (blockHeight < 2) return const SizedBox.shrink();
                final colWidth = totalWidth / l.columnCount;
                final left = l.column * colWidth;
                return Positioned(
                  top: top,
                  left: left + 1,
                  width: (colWidth - 2).clamp(0, totalWidth),
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
                        border: Border.all(
                          color: AppColors.secondary,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        a.sport.icon,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
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
                  ? (a.locationLabel ?? t('plan.noFixedLocation'))
                  : t('plan.oneOffLocation', {
                      'date': a.specificDateLabel,
                      'location': a.locationLabel ?? t('plan.noFixedLocation'),
                    }),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (activityStatsLabel(a, null) != null) ...[
              const SizedBox(height: 4),
              Text(
                activityStatsLabel(a, null)!,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
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
                    label: Text(t('plan.suggestions')),
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
                    label: Text(t('common.edit')),
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
                  t('common.delete'),
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
