import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/circle.dart';
import '../services/circle_controller.dart';
import '../services/circle_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Persistent, always-reachable button that shows the active "Kreis"
/// context (or "Öffentlich") and opens the switcher sheet — lives in
/// [AppScaffold]'s app bar so it's available from every tab.
class CircleSwitcherButton extends StatelessWidget {
  const CircleSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Circle?>(
      valueListenable: CircleController.active,
      builder: (context, circle, _) {
        return IconButton(
          tooltip: circle == null
              ? t('circles.tooltipPublic')
              : t('circles.tooltipCircle', {'circle': circle.name}),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                circle == null ? Icons.public_outlined : Icons.groups_outlined,
              ),
              if (circle != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => _openCircleSheet(context),
        );
      },
    );
  }
}

Future<void> _openCircleSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CircleSheet(),
  );
}

class _CircleSheet extends StatefulWidget {
  const _CircleSheet();

  @override
  State<_CircleSheet> createState() => _CircleSheetState();
}

class _CircleSheetState extends State<_CircleSheet> {
  final _circleService = CircleService();
  late Future<List<Circle>> _future = _load();
  bool _busy = false;

  Future<List<Circle>> _load() {
    return _circleService.getMyCircles(SupabaseService.currentUserId!);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _select(Circle? circle) async {
    await CircleController.setActive(circle);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leave(Circle circle) async {
    setState(() => _busy = true);
    try {
      await _circleService.leaveCircle(
        circleId: circle.id,
        userId: SupabaseService.currentUserId!,
      );
      if (CircleController.active.value?.id == circle.id) {
        await CircleController.setActive(null);
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('circles.leaveFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCircle() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final circle = await _circleService.createCircle(
        name: name.trim(),
        createdBy: SupabaseService.currentUserId!,
      );
      await CircleController.setActive(circle);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => _InviteCodeDialog(circle: circle),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('circles.createFailed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinCircle() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _JoinDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final circle = await _circleService.joinByCode(code);
      await CircleController.setActive(circle);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('circles.joined', {'circle': circle.name}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('circles.switchTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t('circles.switchSubtitle'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<Circle?>(
              valueListenable: CircleController.active,
              builder: (context, active, _) => RadioListTile<String?>(
                contentPadding: EdgeInsets.zero,
                value: null,
                groupValue: active?.id,
                onChanged: _busy ? null : (_) => _select(null),
                secondary: const Icon(Icons.public_outlined),
                title: Text(t('circles.public')),
                subtitle: Text(t('circles.publicSubtitle')),
              ),
            ),
            FutureBuilder<List<Circle>>(
              future: _future,
              builder: (context, snapshot) {
                final circles = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (circles.isEmpty) return const SizedBox.shrink();
                return ValueListenableBuilder<Circle?>(
                  valueListenable: CircleController.active,
                  builder: (context, active, _) => Column(
                    children: circles.map((c) {
                      return RadioListTile<String?>(
                        contentPadding: EdgeInsets.zero,
                        value: c.id,
                        groupValue: active?.id,
                        onChanged: _busy ? null : (_) => _select(c),
                        secondary: IconButton(
                          icon: const Icon(Icons.exit_to_app),
                          tooltip: t('circles.leaveCircle'),
                          onPressed: _busy ? null : () => _leave(c),
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          t('circles.code', {'code': c.inviteCode}),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _createCircle,
                    icon: const Icon(Icons.add),
                    label: Text(t('circles.createCircle')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _joinCircle,
                    icon: const Icon(Icons.login),
                    label: Text(t('circles.join')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('circles.createCircle')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: t('circles.createHint')),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(t('circles.create')),
        ),
      ],
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('circles.joinTitle')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: t('circles.inviteCode')),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(t('circles.join')),
        ),
      ],
    );
  }
}

class _InviteCodeDialog extends StatelessWidget {
  const _InviteCodeDialog({required this.circle});
  final Circle circle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('circles.createdTitle', {'circle': circle.name})),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('circles.shareCode')),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              circle.inviteCode,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.done')),
        ),
      ],
    );
  }
}
