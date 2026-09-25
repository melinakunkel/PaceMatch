import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/open_event.dart';
import '../../models/picked_location.dart';
import '../../models/sport_type.dart';
import '../../services/open_event_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/sport_picker_field.dart';
import '../plan/location_picker_screen.dart';

/// Lets a user host a publicly joinable open event — distinct from a 1:1
/// match, anyone can join up to [_maxParticipantsCtrl] participants.
class HostEventScreen extends StatefulWidget {
  const HostEventScreen({super.key});

  @override
  State<HostEventScreen> createState() => _HostEventScreenState();
}

class _HostEventScreenState extends State<HostEventScreen> {
  final _eventService = OpenEventService();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();

  SportType _sport = SportType.laufen;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay? _end;
  PickedLocation? _location;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : (_end ?? _start),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (picked != null) setState(() => _location = picked);
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && _location != null;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUserId!;
      final myProfile = await ProfileService().getProfile(userId);
      final OpenEvent event = await _eventService.createEvent(
        hostId: userId,
        name: _nameCtrl.text.trim(),
        sport: _sport,
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        eventDate: _date,
        startTime: _start,
        endTime: _end,
        locationName: _location!.name,
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        city: myProfile.city,
        maxParticipants: int.tryParse(_maxParticipantsCtrl.text),
      );
      if (!mounted) return;
      context.pushReplacement('/group/${event.groupId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('hostEvent.createFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/discover'),
        ),
        title: Text(t('hostEvent.title')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t('hostEvent.eventTitle'),
                hintText: t('hostEvent.eventTitleHint'),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(t('newActivity.sport')),
            SportPickerField(
              value: _sport,
              onChanged: (sport) => setState(() => _sport = sport),
            ),
            const SizedBox(height: 20),
            _SectionLabel(t('newActivity.when')),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  '${weekdayFullLabels[_date.weekday - 1]}, '
                  '${_date.day.toString().padLeft(2, '0')}.'
                  '${_date.month.toString().padLeft(2, '0')}.'
                  '${_date.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(true),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t('common.from'),
                        prefixIcon: const Icon(Icons.schedule),
                      ),
                      child: Text(Activity.formatTime(_start)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(false),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t('hostEvent.untilOptional'),
                        prefixIcon: const Icon(Icons.schedule),
                      ),
                      child: Text(
                        _end == null ? '-' : Activity.formatTime(_end!),
                        style: _end == null
                            ? TextStyle(color: AppColors.textSecondary)
                            : null,
                      ),
                    ),
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
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('hostEvent.descriptionOptional'),
                hintText: t('hostEvent.descriptionHint'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _maxParticipantsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('hostEvent.maxParticipantsOptional'),
                prefixIcon: const Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: (_saving || !_canSave) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(t('hostEvent.publish')),
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
