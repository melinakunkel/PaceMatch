import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/activity.dart';
import '../../models/interest.dart';
import '../../models/profile.dart';
import '../../models/user_sport.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/verified_badge.dart';
import 'edit_profile_sheet.dart';
import 'edit_sport_sheet.dart';
import 'settings_screen.dart';

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
        SnackBar(content: Text('Foto konnte nicht hochgeladen werden: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 4,
      title: 'Mein Profil',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Einstellungen',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Abmelden',
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
                      child: const Text('Erneut versuchen'),
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
                                  '${_profile!.age} Jahre',
                                if (_profile!.gender != null) _profile!.gender!,
                                if (_profile!.city != null) _profile!.city!,
                              ].join(' · '),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Profil bearbeiten',
                        onPressed: _editProfile,
                      ),
                    ],
                  ),
                  if (!_profile!.isVerified) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Profil verifizieren'),
                          content: const Text(
                            'Die Verifizierung ist bald verfügbar. Damit kannst du '
                            'anderen zeigen, dass dein Profil echt ist.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Okay'),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Profil verifizieren'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meine Sportarten & Level',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editSport(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Hinzufügen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_sports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Noch keine Sportart hinterlegt.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ..._sports.map(
                    (s) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(s.sport.icon, color: AppColors.primary),
                        title: Text(s.sport.label),
                        subtitle: s.level != null ? Text(s.level!) : null,
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
                    const Text(
                      'Interessen & Sprachen',
                      style: TextStyle(
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
                        ..._profile!.interests.map((i) => Chip(label: Text(i))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Zuverlässigkeit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                  const Text(
                    'Aktiv in den letzten 7 Tagen',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
