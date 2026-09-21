import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/strings.dart';
import '../../models/activity.dart';
import '../../models/interest.dart';
import '../../models/profile.dart';
import '../../models/user_sport.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/display_labels.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/verified_badge.dart';
import 'edit_profile_sheet.dart';
import 'edit_sport_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  Profile? _profile;
  List<UserSport> _sports = [];
  List<bool> _last7Days = List.filled(7, false);
  bool _loading = true;
  bool _uploadingAvatar = false;
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
    final userId = SupabaseService.currentUserId!;
    try {
      final results = await Future.wait([
        _profileService.getProfile(userId),
        _profileService.getUserSports(userId),
        _profileService.getActivityLast7Days(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _sports = results[1] as List<UserSport>;
        _last7Days = results[2] as List<bool>;
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

  Future<void> _editSport([UserSport? existing]) async {
    final userId = SupabaseService.currentUserId!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditSportSheet(userId: userId, existing: existing),
    );
    _load();
  }

  Future<void> _editProfile() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProfileSheet(profile: _profile!),
    );
    _load();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final url = await _profileService.uploadAvatar(
        userId: SupabaseService.currentUserId!,
        bytes: bytes,
        fileExtension: ext,
      );
      await _profileService.updateProfile(_profile!.copyWith(avatarUrl: url));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('profile.avatarUploadFailed', {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 4,
      title: t('profile.title'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: t('profile.signOut'),
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text(t('discover.retry')),
                    ),
                  ],
                ),
              ),
            )
          : _profile == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.secondaryLight,
                              backgroundImage: _profile!.avatarUrl != null
                                  ? NetworkImage(_profile!.avatarUrl!)
                                  : null,
                              child: _profile!.avatarUrl != null
                                  ? null
                                  : (_uploadingAvatar
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 2,
                                          )
                                        : Text(
                                            _profile!.fullName.isNotEmpty
                                                ? _profile!.fullName[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 28,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )),
                            ),
                            if (_uploadingAvatar && _profile!.avatarUrl != null)
                              const Positioned.fill(
                                child: CircleAvatar(
                                  backgroundColor: Colors.black38,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
                                    _profile!.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_profile!.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const VerifiedBadge(),
                                ],
                              ],
                            ),
                            Text(
                              [
                                if (_profile!.age != null)
                                  t('profile.ageYears', {
                                    'age': '${_profile!.age}',
                                  }),
                                if (_profile!.gender != null)
                                  genderLabel(_profile!.gender!),
                                if (_profile!.city != null) _profile!.city!,
                              ].join(' · '),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: t('profile.editProfile'),
                        onPressed: _editProfile,
                      ),
                    ],
                  ),
                  if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(_profile!.bio!),
                  ],
                  if (!_profile!.isVerified) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(t('profile.verifyTitle')),
                          content: Text(t('profile.verifyBody')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(t('profile.okay')),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(t('profile.verifyProfile')),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('profile.sportsAndLevel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editSport(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(t('profile.add')),
                      ),
                    ],
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
                        subtitle: s.level != null
                            ? Text(levelLabel(s.level!))
                            : null,
                        trailing: s.sport.usesPace
                            ? Text(
                                s.rangeLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                        onTap: () => _editSport(s),
                      ),
                    ),
                  ),
                  if (_profile!.interests.isNotEmpty ||
                      _profile!.languages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      t('profile.interestsAndLanguages'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._profile!.languages.map(
                          (l) => Chip(
                            avatar: const Icon(Icons.language, size: 16),
                            label: Text(kLanguageOptions[l] ?? l),
                          ),
                        ),
                        ..._profile!.interests.map(
                          (i) => Chip(label: Text(interestLabel(i))),
                        ),
                      ],
                    ),
                  ],
                  if (_profile!.prompts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      t('profile.myPrompts'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._profile!.prompts.map(
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
                    t('profile.reliability'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _profile!.reliabilityScore / 100,
                            minHeight: 10,
                            backgroundColor: AppColors.secondaryLight,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_profile!.reliabilityScore.round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t('profile.activeLast7Days'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final active = _last7Days[i];
                      return Column(
                        children: [
                          Icon(
                            active
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: active
                                ? AppColors.secondary
                                : AppColors.border,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weekdayLabels[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
    );
  }
}
