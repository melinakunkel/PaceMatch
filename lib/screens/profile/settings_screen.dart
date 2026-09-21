import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/strings.dart';
import '../../services/browser_notification_service.dart';
import '../../services/locale_controller.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../tutorial/tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  bool? _autoArchive;
  bool? _browserNotifications;

  @override
  void initState() {
    super.initState();
    _profileService.getProfile(SupabaseService.currentUserId!).then((p) {
      if (mounted) setState(() => _autoArchive = p.autoArchiveInactiveChats);
    });
    BrowserNotificationService.isEnabled().then((v) {
      if (mounted) setState(() => _browserNotifications = v);
    });
  }

  Future<void> _setBrowserNotifications(bool value) async {
    if (!value) {
      await BrowserNotificationService.disable();
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

  Future<void> _setAutoArchive(bool value) async {
    setState(() => _autoArchive = value);
    final profile = await _profileService.getProfile(
      SupabaseService.currentUserId!,
    );
    await _profileService.updateProfile(
      profile.copyWith(autoArchiveInactiveChats: value),
    );
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
              ],
            );
          },
        ),
      ),
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
