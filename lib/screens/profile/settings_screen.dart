import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_info.dart';
import '../../l10n/app_language.dart';
import '../../l10n/strings.dart';
import '../../services/account_feedback_service.dart';
import '../../services/admin_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/browser_notification_service.dart';
import '../../services/locale_controller.dart';
import '../../services/profile_service.dart';
import '../../services/push_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_dot.dart';
import '../../widgets/push_prompt.dart';
import '../legal/faq_screen.dart';
import '../legal/imprint_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../tutorial/tutorial_screen.dart';
import 'admin_screen.dart';
import 'blocked_users_screen.dart';
import 'feedback_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  bool? _autoArchive;
  bool? _browserNotifications;
  bool _pushBusy = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _profileService.getProfile(SupabaseService.currentUserId!).then((p) {
      if (mounted) {
        setState(() {
          _autoArchive = p.autoArchiveInactiveChats;
          _isAdmin = p.isAdmin;
        });
      }
    });
    BrowserNotificationService.isEnabled().then((v) {
      if (mounted) setState(() => _browserNotifications = v);
    });
  }

  Future<void> _setBrowserNotifications(bool value) async {
    if (!value) {
      await BrowserNotificationService.disable();
      if (!mounted) return;
      setState(() => _browserNotifications = false);
      return;
    }
    final granted = await BrowserNotificationService.requestEnable();
    if (!mounted) return;
    setState(() => _browserNotifications = granted);
    if (!granted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('settings.permissionDenied'))));
    }
  }

  List<Widget> _pushSettings() => [
    Text(t('push.desc'), style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 8),
    ValueListenableBuilder<bool>(
      valueListenable: PushService.active,
      builder: (context, active, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t('push.title')),
        value: active,
        onChanged: _pushBusy
            ? null
            : (on) async {
                setState(() => _pushBusy = true);
                if (on) {
                  await enablePush(context);
                } else {
                  await PushService.disable();
                }
                if (mounted) setState(() => _pushBusy = false);
              },
      ),
    ),
  ];

  Future<void> _setAutoArchive(bool value) async {
    setState(() => _autoArchive = value);
    final profile = await _profileService.getProfile(
      SupabaseService.currentUserId!,
    );
    await _profileService.updateProfile(
      profile.copyWith(autoArchiveInactiveChats: value),
    );
  }

  Future<void> _openFeedback() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FeedbackSheet(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('feedback.thanks'))));
    }
  }

  Future<void> _openMail(String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppInfo.contactEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('settings.mailFailed'))));
    }
  }

  Future<void> _showDoneDialog(String title, String body) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _pauseAccount() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _AccountActionDialog(action: 'pause'),
    );
    if (reason == null) return;
    try {
      final userId = SupabaseService.currentUserId!;
      await AccountFeedbackService().submit(action: 'pause', reason: reason);
      await _profileService.pauseAccount(userId);
      if (!mounted) return;
      await _showDoneDialog(
        t('settings.pauseAccountDoneTitle'),
        t('settings.pauseAccountDoneBody'),
      );
      await AuthService().signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('settings.accountActionFailed', {'error': '$e'})),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _AccountActionDialog(action: 'delete'),
    );
    if (reason == null) return;
    try {
      await AccountFeedbackService().submit(action: 'delete', reason: reason);
      await _profileService.deleteOwnAccount();
      if (!mounted) return;
      await _showDoneDialog(
        t('settings.deleteAccountDoneTitle'),
        t('settings.deleteAccountDoneBody'),
      );
      await AuthService().signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('settings.accountActionFailed', {'error': '$e'})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('settings.title')),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<AppThemeVariant>(
          valueListenable: ThemeController.variant,
          builder: (context, activeVariant, _) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  t('settings.help'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.help_outline, color: AppColors.primary),
                    title: Text(t('settings.howItWorks')),
                    subtitle: Text(t('settings.tutorialSubtitle')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TutorialScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('settings.privacy'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.block, color: AppColors.primary),
                    title: Text(t('settings.blockedUsers')),
                    subtitle: Text(t('settings.blockedUsersSubtitle')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('settings.chats'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('settings.autoArchiveDesc'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('settings.autoArchive')),
                  value: _autoArchive ?? false,
                  onChanged: _autoArchive == null
                      ? null
                      : (v) => _setAutoArchive(v),
                ),
                const SizedBox(height: 24),
                Text(
                  t('settings.notifications'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (PushService.isSupported)
                  ..._pushSettings()
                else if (PushService.needsHomeScreen) ...[
                  Text(
                    t('push.iosDesc'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: Text(t('push.iosButton')),
                    onPressed: () => showIphonePushHelp(context),
                  ),
                ] else ...[
                  Text(
                    BrowserNotificationService.isSupported
                        ? t('settings.notificationsDescSupported')
                        : t('settings.notificationsDescUnsupported'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('settings.browserNotifications')),
                    value: _browserNotifications ?? false,
                    onChanged:
                        (_browserNotifications == null ||
                            !BrowserNotificationService.isSupported)
                        ? null
                        : (v) => _setBrowserNotifications(v),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  t('settings.language'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('settings.languageDesc'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<AppLanguage>(
                  valueListenable: LocaleController.language,
                  builder: (context, activeLanguage, _) {
                    return Wrap(
                      spacing: 8,
                      children: AppLanguage.values.map((lang) {
                        return ChoiceChip(
                          label: Text(lang.label),
                          selected: lang == activeLanguage,
                          onSelected: (_) async {
                            await LocaleController.setLanguage(lang);
                            await _profileService.updateUiLanguage(
                              SupabaseService.currentUserId!,
                              lang.name,
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  t('settings.design'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('settings.designDesc'),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...AppThemeVariant.values.map((variant) {
                  final selected = variant == activeVariant;
                  final palette = variant._previewPalette;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await ThemeController.setVariant(variant);
                        await _profileService.updateThemeVariant(
                          SupabaseService.currentUserId!,
                          variant.name,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? palette.primary
                                : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _PalettePreview(colors: palette),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variant.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    variant.description,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? palette.primary
                                  : AppColors.border,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Text(
                  t('settings.legal'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.help_outline,
                          color: AppColors.primary,
                        ),
                        title: Text(t('settings.faq')),
                        subtitle: Text(t('settings.faqSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FaqScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(t('settings.privacyPolicy')),
                        subtitle: Text(t('settings.privacyPolicySubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.description_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(t('settings.imprint')),
                        subtitle: Text(t('settings.imprintSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ImprintScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.feedback_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(t('settings.feedback')),
                        subtitle: Text(t('settings.feedbackSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openFeedback,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.mail_outline,
                          color: AppColors.primary,
                        ),
                        title: Text(t('settings.contact')),
                        subtitle: Text(t('settings.contactSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openMail('Kontakt'),
                      ),
                      if (_isAdmin) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: ValueListenableBuilder<bool>(
                            valueListenable: AdminNotifier.hasNew,
                            builder: (context, hasNew, _) => NotificationDot(
                              show: hasNew,
                              child: Icon(
                                Icons.admin_panel_settings_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(t('admin.title')),
                          subtitle: Text(t('admin.subtitle')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('settings.account'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.pause_circle_outline,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(t('settings.pauseAccount')),
                        subtitle: Text(t('settings.pauseAccountSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pauseAccount,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          t('settings.deleteAccount'),
                          style: TextStyle(color: AppColors.danger),
                        ),
                        subtitle: Text(t('settings.deleteAccountSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountActionDialog extends StatefulWidget {
  const _AccountActionDialog({required this.action});

  /// 'pause' or 'delete'.
  final String action;

  @override
  State<_AccountActionDialog> createState() => _AccountActionDialogState();
}

class _AccountActionDialogState extends State<_AccountActionDialog> {
  static const _other = '__other__';

  final _reasonCtrl = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _isDelete => widget.action == 'delete';

  List<String> get _reasonLabels => _isDelete
      ? [
          t('settings.deleteReason1'),
          t('settings.deleteReason2'),
          t('settings.deleteReason3'),
        ]
      : [
          t('settings.pauseReason1'),
          t('settings.pauseReason2'),
          t('settings.pauseReason3'),
        ];

  /// The fixed label text if one was picked, the free-text field's content
  /// if "Sonstiges" was picked, or null if nothing was picked yet.
  String? get _resolvedReason {
    if (_selectedReason == null) return null;
    if (_selectedReason != _other) return _selectedReason;
    final text = _reasonCtrl.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isDelete
            ? t('settings.deleteAccountTitle')
            : t('settings.pauseAccountTitle'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isDelete
                  ? t('settings.deleteAccountBody')
                  : t('settings.pauseAccountBody'),
            ),
            const SizedBox(height: 12),
            Text(
              t('settings.accountReasonLabel'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                children: [
                  for (final label in _reasonLabels)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: label,
                      title: Text(label),
                    ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: _other,
                    title: Text(t('settings.reasonOther')),
                  ),
                ],
              ),
            ),
            if (_selectedReason == _other) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t('settings.reasonOtherHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_resolvedReason ?? ''),
          style: _isDelete
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(
            _isDelete
                ? t('settings.deleteAccountConfirm')
                : t('settings.pauseAccountConfirm'),
          ),
        ),
      ],
    );
  }
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.colors});
  final _PreviewColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: _dot(colors.primary, 30)),
          Positioned(right: 0, bottom: 0, child: _dot(colors.secondary, 26)),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _PreviewColors {
  const _PreviewColors(this.primary, this.secondary);
  final Color primary;
  final Color secondary;
}

extension on AppThemeVariant {
  _PreviewColors get _previewPalette {
    switch (this) {
      case AppThemeVariant.standard:
        return const _PreviewColors(Color(0xFF1B4332), Color(0xFF40916C));
      case AppThemeVariant.girly:
        return const _PreviewColors(Color(0xFF9D2953), Color(0xFFE85D8A));
      case AppThemeVariant.sporty:
        return const _PreviewColors(Color(0xFF14181F), Color(0xFFFF6B35));
    }
  }
}
