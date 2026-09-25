import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/picked_location.dart';
import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/activity_service.dart';
import '../../services/circle_controller.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';
import '../../utils/meeting_days.dart';
import '../../utils/pace_format.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/pace_picker_field.dart';
import '../../widgets/safety_notice.dart';
import '../../widgets/sport_picker_field.dart';
import 'location_picker_screen.dart';

class NewActivityScreen extends StatefulWidget {
  const NewActivityScreen({
    super.key,
    this.initialSport = SportType.laufen,
    this.existing,
    this.today = false,
  });

  /// Preselected sport when creating a new activity from the Home screen.
  final SportType initialSport;

  /// When set, the screen edits this activity in place instead of creating
  /// new ones, and day selection is single-choice.
  final Activity? existing;

  /// Spontaneous mode from Home: preset to a one-off today, starting at
  /// the next half hour.
  final bool today;

  bool get isEditing => existing != null;

  @override
  State<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends State<NewActivityScreen> {
  static const _levels = ['Anfänger', 'Fortgeschritten', 'Profi'];
  static const _childGenders = ['weiblich', 'männlich', 'divers'];

  final _activityService = ActivityService();
  late final _radiusCtrl = TextEditingController(
    text: '${widget.existing?.radiusKm ?? 3}',
  );
  late final _distanceMinCtrl = TextEditingController(
    text: widget.existing?.distanceMinKm?.toString() ?? '',
  );
  late final _distanceMaxCtrl = TextEditingController(
    text: widget.existing?.distanceMaxKm?.toString() ?? '',
  );

  late SportType _sport = widget.existing?.sport ?? widget.initialSport;
  late final Set<int> _selectedDays = {
    widget.existing?.dayOfWeek ?? DateTime.now().weekday,
  };
  late TimeOfDay _start =
      widget.existing?.startTime ??
      (widget.today
          ? spontaneousStart(DateTime.now())
          : const TimeOfDay(hour: 18, minute: 0));
  late TimeOfDay _end =
      widget.existing?.endTime ??
      (widget.today
          ? oneHourAfter(_start)
          : const TimeOfDay(hour: 19, minute: 0));
  late PickedLocation? _location = widget.existing == null
      ? null
      : (widget.existing!.locationName == null
            ? null
            : PickedLocation(
                name: widget.existing!.locationName!,
                latitude: widget.existing!.latitude ?? 0,
                longitude: widget.existing!.longitude ?? 0,
              ));
  late double? _paceMin = widget.existing?.paceMin;
  late double? _paceMax = widget.existing?.paceMax;
  late String? _venueStatus = widget.existing?.venueStatus;
  late String? _level = widget.existing?.level;
  late String? _bikeType = widget.existing?.bikeType;
  late String? _runType = widget.existing?.runType;
  late bool? _hasDog = widget.existing?.hasDog;
  late final _childAgeCtrl = TextEditingController(
    text: widget.existing?.childAge?.toString() ?? '',
  );
  late String? _childGender = widget.existing?.childGender;
  late bool _isRecurring = widget.existing?.isRecurring ?? !widget.today;
  late DateTime? _specificDate =
      widget.existing?.specificDate ?? (widget.today ? _dateOnly(0) : null);
  late String _discoverVisibility =
      widget.existing?.discoverVisibility ?? 'open';
  bool _saving = false;
  Map<SportType, UserSport> _mySports = {};

  @override
  void initState() {
    super.initState();
    if (!widget.isEditing) _loadMySports();
  }

  Future<void> _loadMySports() async {
    final sports = await ProfileService().getUserSports(
      SupabaseService.currentUserId!,
    );
    if (!mounted) return;
    setState(() {
      _mySports = {for (final s in sports) s.sport: s};
      _applyProfileDefaults(_sport);
    });
  }

  /// Prefills the pace (or level, for sports without one) from the user's
  /// profile, when creating a new activity (never overrides while editing).
  void _applyProfileDefaults(SportType sport) {
    final saved = _mySports[sport];
    if (saved == null) return;
    if (sport.usesPace) {
      _paceMin = saved.valueLow;
      _paceMax = saved.valueHigh;
    } else {
      _level = saved.level;
    }
  }

  @override
  void dispose() {
    _radiusCtrl.dispose();
    _distanceMinCtrl.dispose();
    _distanceMaxCtrl.dispose();
    _childAgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  static DateTime _dateOnly(int daysFromToday) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + daysFromToday);
  }

  void _setSpecificDate(DateTime date) {
    setState(() {
      _specificDate = date;
      _selectedDays
        ..clear()
        ..add(date.weekday);
    });
  }

  bool _isSpecificDate(int daysFromToday) {
    final d = _specificDate;
    if (d == null) return false;
    final target = _dateOnly(daysFromToday);
    return d.year == target.year &&
        d.month == target.month &&
        d.day == target.day;
  }

  /// "Werktags" / "Wochenende" / "Jeden Tag" in one tap — matching needs the
  /// same weekday, so offering several days finds far more people.
  Widget _dayPresets() {
    Widget preset(String label, Set<int> days) {
      final selected =
          _selectedDays.length == days.length &&
          _selectedDays.containsAll(days);
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _selectedDays
            ..clear()
            ..addAll(days);
        }),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        preset(t('newActivity.weekdays'), {1, 2, 3, 4, 5}),
        preset(t('newActivity.weekend'), {6, 7}),
        preset(t('newActivity.everyDay'), {1, 2, 3, 4, 5, 6, 7}),
      ],
    );
  }

  Future<void> _pickSpecificDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    _setSpecificDate(picked);
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) return;
    if (!_isRecurring && _specificDate == null) return;
    setState(() => _saving = true);
    try {
      final radiusKm =
          double.tryParse(_radiusCtrl.text.replaceAll(',', '.')) ?? 3;
      final distanceMinKm = _sport.usesDistance
          ? double.tryParse(_distanceMinCtrl.text.replaceAll(',', '.'))
          : null;
      final distanceMaxKm = _sport.usesDistance
          ? double.tryParse(_distanceMaxCtrl.text.replaceAll(',', '.'))
          : null;
      final paceMin = _sport.usesPace ? _paceMin : null;
      final paceMax = _sport.usesPace ? _paceMax : null;
      final venueStatus = _sport.usesVenueQuestion ? _venueStatus : null;
      final level = (!_sport.usesPace && _sport.usesLevel) ? _level : null;
      final bikeType = _sport.usesBikeType ? _bikeType : null;
      final runType = _sport.usesRunType ? _runType : null;
      final hasDog = _sport.usesDogQuestion ? _hasDog : null;
      final childAge = _sport.usesChildInfo
          ? int.tryParse(_childAgeCtrl.text)
          : null;
      final childGender = _sport.usesChildInfo ? _childGender : null;
      final specificDate = _isRecurring ? null : _specificDate;

      if (widget.isEditing) {
        final updated = await _activityService.updateActivity(
          id: widget.existing!.id,
          sport: _sport,
          dayOfWeek: _selectedDays.first,
          startTime: _start,
          endTime: _end,
          locationName: _location?.name,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          radiusKm: radiusKm,
          distanceMinKm: distanceMinKm,
          distanceMaxKm: distanceMaxKm,
          paceMin: paceMin,
          paceMax: paceMax,
          venueStatus: venueStatus,
          level: level,
          bikeType: bikeType,
          runType: runType,
          hasDog: hasDog,
          childAge: childAge,
          childGender: childGender,
          specificDate: specificDate,
          discoverVisibility: _discoverVisibility,
        );
        if (!mounted) return;
        context.pushReplacement('/matches/${updated.id}');
        return;
      }

      final userId = SupabaseService.currentUserId!;
      final days = _selectedDays.toList()..sort();
      final created = <Activity>[];
      for (final day in days) {
        created.add(
          await _activityService.createActivity(
            userId: userId,
            sport: _sport,
            dayOfWeek: day,
            startTime: _start,
            endTime: _end,
            locationName: _location?.name,
            latitude: _location?.latitude,
            longitude: _location?.longitude,
            radiusKm: radiusKm,
            distanceMinKm: distanceMinKm,
            distanceMaxKm: distanceMaxKm,
            paceMin: paceMin,
            paceMax: paceMax,
            venueStatus: venueStatus,
            level: level,
            bikeType: bikeType,
            runType: runType,
            hasDog: hasDog,
            childAge: childAge,
            childGender: childGender,
            specificDate: specificDate,
            circleId: CircleController.active.value?.id,
            discoverVisibility: _discoverVisibility,
          ),
        );
      }
      if (!mounted) return;
      if (created.length == 1) {
        context.pushReplacement('/matches/${created.first.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('newActivity.added', {'count': '${created.length}'}),
            ),
          ),
        );
        context.pushReplacement('/plan');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('common.saveFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = paceUnitLabel(_sport.defaultUnit);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/plan'),
        ),
        title: Text(
          widget.isEditing
              ? t('newActivity.editTitle')
              : t('newActivity.title'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (!widget.isEditing)
              ValueListenableBuilder(
                valueListenable: CircleController.active,
                builder: (context, circle, _) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        circle == null
                            ? Icons.public_outlined
                            : Icons.groups_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        circle == null
                            ? t('newActivity.publishPublic')
                            : t('newActivity.publishInCircle', {
                                'circle': circle.name,
                              }),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _SectionLabel(t('newActivity.sport')),
            SportPickerField(
              value: _sport,
              favorites: SportType.selectable
                  .where(_mySports.containsKey)
                  .toList(),
              // "Weitere" is only kept when editing an old sport time
              // that already uses it.
              sports: [
                ...SportType.alphabetical,
                if (_sport == SportType.sonstige) SportType.sonstige,
              ],
              onChanged: (sport) => setState(() {
                _sport = sport;
                if (!widget.isEditing) _applyProfileDefaults(sport);
              }),
            ),
            if (_sport.usesVenueQuestion) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.hasVenue')),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t('newActivity.hasVenueYes')),
                    selected: _venueStatus == 'has_venue',
                    onSelected: (_) =>
                        setState(() => _venueStatus = 'has_venue'),
                  ),
                  ChoiceChip(
                    label: Text(t('newActivity.hasVenueNo')),
                    selected: _venueStatus == 'needs_venue',
                    onSelected: (_) =>
                        setState(() => _venueStatus = 'needs_venue'),
                  ),
                ],
              ),
            ],
            if (_sport.usesBikeType) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.bikeType')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BikeType.values.map((b) {
                  return ChoiceChip(
                    label: Text(b.label),
                    selected: _bikeType == b.name,
                    onSelected: (_) => setState(() => _bikeType = b.name),
                  );
                }).toList(),
              ),
            ],
            if (_sport.usesRunType) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.runType')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RunType.values.map((r) {
                  final selected = _runType == r.name;
                  return ChoiceChip(
                    label: Text(r.label),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _runType = selected ? null : r.name),
                  );
                }).toList(),
              ),
            ],
            if (_sport.usesDogQuestion) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.hasDog')),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t('newActivity.hasDogYes')),
                    selected: _hasDog == true,
                    onSelected: (_) => setState(() => _hasDog = true),
                  ),
                  ChoiceChip(
                    label: Text(t('newActivity.hasDogNo')),
                    selected: _hasDog == false,
                    onSelected: (_) => setState(() => _hasDog = false),
                  ),
                ],
              ),
            ],
            if (_sport.usesChildInfo) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.childInfo')),
              TextField(
                controller: _childAgeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t('newActivity.childAge'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _childGenders.map((g) {
                  return ChoiceChip(
                    label: Text(genderLabel(g)),
                    selected: _childGender == g,
                    onSelected: (_) => setState(() => _childGender = g),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SafetyNotice(text: t('safety.childMeetupNotice')),
            ],
            if (!_sport.usesPace && _sport.usesLevel) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.level')),
              Wrap(
                spacing: 8,
                children: _levels.map((l) {
                  return ChoiceChip(
                    label: Text(levelLabel(l)),
                    selected: _level == l,
                    onSelected: (_) => setState(() => _level = l),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel(t('newActivity.when')),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(t('newActivity.everyWeek')),
                  selected: _isRecurring,
                  onSelected: (_) => setState(() => _isRecurring = true),
                ),
                ChoiceChip(
                  label: Text(t('newActivity.oneOffOn')),
                  selected: !_isRecurring,
                  onSelected: (_) => setState(() => _isRecurring = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isRecurring && !widget.isEditing) ...[
              _dayPresets(),
              const SizedBox(height: 8),
            ],
            if (!_isRecurring) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t('newActivity.today')),
                    selected: _isSpecificDate(0),
                    onSelected: (_) => _setSpecificDate(_dateOnly(0)),
                  ),
                  ChoiceChip(
                    label: Text(t('newActivity.tomorrow')),
                    selected: _isSpecificDate(1),
                    onSelected: (_) => _setSpecificDate(_dateOnly(1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_isRecurring)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final selected = _selectedDays.contains(day);
                  if (widget.isEditing) {
                    return ChoiceChip(
                      label: Text(weekdayLabels[i]),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _selectedDays
                          ..clear()
                          ..add(day);
                      }),
                    );
                  }
                  return FilterChip(
                    label: Text(weekdayLabels[i]),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      if (value) {
                        _selectedDays.add(day);
                      } else if (_selectedDays.length > 1) {
                        _selectedDays.remove(day);
                      }
                    }),
                  );
                }),
              )
            else
              InkWell(
                onTap: _pickSpecificDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    hintText: t('newActivity.pickDate'),
                    prefixIcon: const Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    _specificDate == null
                        ? t('newActivity.pickDate')
                        : '${weekdayFullLabels[_specificDate!.weekday - 1]}, '
                              '${_specificDate!.day.toString().padLeft(2, '0')}.'
                              '${_specificDate!.month.toString().padLeft(2, '0')}.'
                              '${_specificDate!.year}',
                    style: _specificDate == null
                        ? TextStyle(color: AppColors.textSecondary)
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: t('common.from'),
                    time: _start,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: t('common.to'),
                    time: _end,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(t('newActivity.where')),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: t('newActivity.pickLocation'),
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: const Icon(Icons.map_outlined),
                ),
                child: Text(
                  _location?.name ?? t('newActivity.pickLocation'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _location == null
                      ? TextStyle(color: AppColors.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: t('newActivity.radius'),
                prefixIcon: const Icon(Icons.social_distance_outlined),
              ),
            ),
            if (_sport.usesDistance) ...[
              const SizedBox(height: 20),
              _SectionLabel(t('newActivity.distance')),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _distanceMinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: t('common.from')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _distanceMaxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: t('common.to')),
                    ),
                  ),
                ],
              ),
            ],
            if (_sport.usesPace) ...[
              const SizedBox(height: 20),
              _SectionLabel(
                t('onboarding.step2.paceRange', {
                  'sport': _sport.label,
                  'unit': unitLabel,
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: PacePickerField(
                      label: t('common.from'),
                      unit: _sport.defaultUnit,
                      value: _paceMin,
                      onChanged: (v) => setState(() => _paceMin = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PacePickerField(
                      label: t('common.to'),
                      unit: _sport.defaultUnit,
                      value: _paceMax,
                      onChanged: (v) => setState(() => _paceMax = v),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel(t('newActivity.visibility')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(t('newActivity.visibilityOpen')),
                  selected: _discoverVisibility == 'open',
                  onSelected: (_) =>
                      setState(() => _discoverVisibility = 'open'),
                ),
                ChoiceChip(
                  label: Text(t('newActivity.visibilityRequest')),
                  selected: _discoverVisibility == 'request',
                  onSelected: (_) =>
                      setState(() => _discoverVisibility = 'request'),
                ),
                ChoiceChip(
                  label: Text(t('newActivity.visibilityHidden')),
                  selected: _discoverVisibility == 'hidden',
                  onSelected: (_) =>
                      setState(() => _discoverVisibility = 'hidden'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving || (!_isRecurring && _specificDate == null)
                  ? null
                  : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditing
                          ? t('newActivity.save')
                          : _selectedDays.length > 1
                          ? t('newActivity.publishMultiple', {
                              'count': '${_selectedDays.length}',
                            })
                          : t('newActivity.publish'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(Activity.formatTime(time)),
      ),
    );
  }
}
