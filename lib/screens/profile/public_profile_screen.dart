import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../models/interest.dart';
import '../../models/profile.dart';
import '../../models/sport_type.dart';
import '../../models/user_sport.dart';
import '../../services/group_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/verified_badge.dart';

/// Read-only view of another user's profile, reachable by tapping their
/// name/avatar in matches, "Entdecken", or a group's member list.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _profileService = ProfileService();
  final _groupService = GroupService();
  Profile? _profile;
  List<UserSport> _sports = [];
  bool _loading = true;
  bool _contacting = false;
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
      final results = await Future.wait([
        _profileService.getProfile(widget.userId),
        _profileService.getUserSports(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _sports = results[1] as List<UserSport>;
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

  Future<void> _contact() async {
    setState(() => _contacting = true);
    try {
      final me = SupabaseService.currentUserId!;
      final existingId = await _groupService.findSharedGroupId(widget.userId);
      String groupId;
      if (existingId != null) {
        groupId = existingId;
      } else {
        final group = await _groupService.createGroup(
          createdBy: me,
          sport: _sports.isNotEmpty ? _sports.first.sport : SportType.sonstige,
          name: t('publicProfile.chatWith', {'name': _profile?.fullName ?? ''}),
        );
        await _groupService.joinGroup(groupId: group.id, userId: widget.userId);
        groupId = group.id;
      }
      if (!mounted) return;
      context.push('/group/$groupId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('discover.contactFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context, '/'),
        ),
        title: Text(_profile?.fullName ?? t('publicProfile.title')),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.secondaryLight,
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl != null
                  ? null
                  : Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 6),
                        const VerifiedBadge(),
                      ],
                    ],
                  ),
                  Text(
                    [
                      if (profile.age != null)
                        t('profile.ageYears', {'age': '${profile.age}'}),
                      if (profile.gender != null) genderLabel(profile.gender!),
                      if (profile.city != null) profile.city!,
                    ].join(' · '),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(profile.bio!),
        ],
        if (profile.prompts.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...profile.prompts.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promptQuestionLabel(p.question),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.answer,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          t('publicProfile.sportsAndLevel'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_sports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t('profile.noSports'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ..._sports.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(s.sport.icon, color: AppColors.primary),
              title: Text(s.sport.label),
              subtitle: s.level != null ? Text(levelLabel(s.level!)) : null,
              trailing: s.sport.usesPace
                  ? Text(
                      s.rangeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
          ),
        ),
        if (profile.interests.isNotEmpty || profile.languages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t('profile.interestsAndLanguages'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...profile.languages.map(
                (l) => Chip(
                  avatar: const Icon(Icons.language, size: 16),
                  label: Text(kLanguageOptions[l] ?? l),
                ),
              ),
              ...profile.interests.map(
                (i) => Chip(label: Text(interestLabel(i))),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(
          t('profile.reliability'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: profile.reliabilityScore / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.secondaryLight,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${profile.reliabilityScore.round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _contacting ? null : _contact,
          icon: _contacting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.chat_bubble_outline),
          label: Text(t('publicProfile.sendMessage')),
        ),
      ],
    );
  }
}
