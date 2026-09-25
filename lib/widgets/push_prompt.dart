import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';

/// Turns push on and tells the user how it went. Call it directly from the
/// tap (see [PushService.enable]).
Future<void> enablePush(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await PushService.enable();
  if (!context.mounted) return;
  switch (result) {
    case PushEnableResult.enabled:
      messenger.showSnackBar(SnackBar(content: Text(t('push.enabled'))));
    case PushEnableResult.needsHomeScreen:
      await showIphonePushHelp(context);
    case PushEnableResult.denied:
      messenger.showSnackBar(SnackBar(content: Text(t('push.denied'))));
    case PushEnableResult.unsupported:
      messenger.showSnackBar(SnackBar(content: Text(t('push.unsupported'))));
    case PushEnableResult.failed:
      messenger.showSnackBar(SnackBar(content: Text(t('push.failed'))));
  }
}

Future<void> showIphonePushHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('push.iosTitle')),
      content: Text(t('push.iosSteps')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.close')),
        ),
      ],
    ),
  );
}

/// Small card at the top of the chat list inviting to turn push on — shown
/// until push is on or the card is dismissed.
class PushPromptCard extends StatefulWidget {
  const PushPromptCard({super.key});

  @override
  State<PushPromptCard> createState() => _PushPromptCardState();
}

class _PushPromptCardState extends State<PushPromptCard> {
  static const _dismissedKey = 'push_prompt_dismissed';
  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _dismissed = prefs.getBool(_dismissedKey) ?? false);
      }
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed ||
        !(PushService.isSupported || PushService.needsHomeScreen)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: PushService.active,
      builder: (context, active, _) {
        if (active) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.secondaryLight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('push.promptTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('push.promptBody'),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () => enablePush(context),
                        child: Text(
                          PushService.needsHomeScreen
                              ? t('push.iosButton')
                              : t('push.promptAction'),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t('common.close'),
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
