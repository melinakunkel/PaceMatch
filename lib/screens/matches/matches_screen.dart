import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/match_candidate.dart';
import '../../services/activity_service.dart';
import '../../services/group_service.dart';
import '../../services/match_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _activityService = ActivityService();
  final _matchService = MatchService();
  final _groupService = GroupService();

  Activity? _activity;
  List<MatchCandidate> _candidates = [];
  final Set<String> _selectedUserIds = {};
  bool _loading = true;
  bool _creatingGroup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await _activityService.getActivityById(widget.activityId);
      final candidates = await _matchService.findMatches(activity);
      setState(() {
        _activity = activity;
        _candidates = candidates;
        _selectedUserIds
          ..clear()
          ..addAll(candidates.map((c) => c.profile.id));
      });
    } catch (e) {
      setState(() => _error = 'Matches konnten nicht geladen werden.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final activity = _activity;
    if (activity == null || _selectedUserIds.isEmpty) return;
    setState(() => _creatingGroup = true);
    try {
      final me = SupabaseService.currentUserId!;
      final group = await _groupService.createGroup(
        createdBy: me,
        sport: activity.sport,
        name: '${activity.sport.label} · ${activity.locationName ?? activity.dayLabel}',
        meetingPoint: activity.locationName,
        activityId: activity.id,
      );
      for (final userId in _selectedUserIds) {
        if (userId == me) continue;
        await _groupService.joinGroup(groupId: group.id, userId: userId);
      }
      if (!mounted) return;
      context.pushReplacement('/group/${group.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruppe konnte nicht erstellt werden.')),
      );
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_activity == null
            ? 'Passende Leute'
            : '${_activity!.sport.label} · ${_activity!.dayLabel}'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final activity = _activity!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(activity.timeRangeLabel),
              const SizedBox(width: 16),
              const Icon(Icons.place_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(activity.locationName ?? 'Ort flexibel')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _candidates.isEmpty
                  ? 'Noch keine passenden Leute gefunden.'
                  : 'Heute passen ${_candidates.length} Leute zu dir.',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _candidates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Sobald jemand eine ähnliche Sportzeit einträgt, '
                      'erscheint er oder sie hier.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: _candidates.length,
                  itemBuilder: (context, index) {
                    final c = _candidates[index];
                    final selected = _selectedUserIds.contains(c.profile.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedUserIds.add(c.profile.id);
                          } else {
                            _selectedUserIds.remove(c.profile.id);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.secondaryLight,
                          backgroundImage: c.profile.avatarUrl != null
                              ? NetworkImage(c.profile.avatarUrl!)
                              : null,
                          child: c.profile.avatarUrl != null
                              ? null
                              : Text(
                                  c.profile.fullName.isNotEmpty
                                      ? c.profile.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: AppColors.primary),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                [
                                  c.profile.fullName,
                                  if (c.profile.age != null) '${c.profile.age}',
                                ].join(', '),
                              ),
                            ),
                            _MatchBadge(percent: c.matchPercent),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (c.profile.gender != null) c.profile.gender!,
                            c.theirActivity.timeRangeLabel,
                            c.theirActivity.locationName ?? 'Ort flexibel',
                          ].join(' · '),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_candidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed:
                  (_creatingGroup || _selectedUserIds.isEmpty) ? null : _createGroup,
              child: _creatingGroup
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gruppe erstellen'),
            ),
          ),
      ],
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
