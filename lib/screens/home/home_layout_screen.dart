import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/home_layout.dart';
import '../../models/sport_type.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Lets the user drag the Home screen's sport buttons into their own order
/// and toggle each one on/off — saved per account (see
/// ProfileService.updateHomeLayout) so it's the same on every login.
/// Pops with the new [HomeLayout] on save, or null if cancelled.
class HomeLayoutScreen extends StatefulWidget {
  const HomeLayoutScreen({super.key, required this.initial});
  final HomeLayout initial;

  @override
  State<HomeLayoutScreen> createState() => _HomeLayoutScreenState();
}

class _HomeLayoutScreenState extends State<HomeLayoutScreen> {
  late final List<SportType> _order = widget.initial.fullOrder();
  late final Set<String> _hidden = widget.initial.hidden.toSet();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final layout = HomeLayout(
        order: _order.map((s) => s.name).toList(),
        hidden: _hidden.toList(),
      );
      await ProfileService().updateHomeLayout(
        SupabaseService.currentUserId!,
        layout,
      );
      if (!mounted) return;
      Navigator.of(context).pop(layout);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('homeLayout.saveFailed', {'error': '$e'}))),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t('homeLayout.title')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('homeLayout.save')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                t('homeLayout.subtitle'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _order.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final sport = _order.removeAt(oldIndex);
                    _order.insert(newIndex, sport);
                  });
                },
                itemBuilder: (context, i) {
                  final sport = _order[i];
                  final visible = !_hidden.contains(sport.name);
                  return Card(
                    key: ValueKey(sport.name),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        sport.icon,
                        color: visible
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        sport.label,
                        style: TextStyle(
                          color: visible ? null : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: visible,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _hidden.remove(sport.name);
                              } else {
                                _hidden.add(sport.name);
                              }
                            }),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
