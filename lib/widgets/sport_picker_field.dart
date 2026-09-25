import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/sport_type.dart';
import '../theme/app_theme.dart';

/// Picks one sport: a field showing the current one, tapping it opens a
/// scrollable list — instead of a wall of chips, now that there are many
/// sports.
class SportPickerField extends StatelessWidget {
  const SportPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.sports,
  });

  final SportType value;
  final ValueChanged<SportType> onChanged;

  /// Defaults to every selectable sport.
  final List<SportType>? sports;

  Future<void> _open(BuildContext context) async {
    final options = sports ?? SportType.selectable;
    final picked = await showModalBottomSheet<SportType>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SportListSheet(options: options, selected: value),
    );
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(value.icon, color: AppColors.primary),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(value.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SportListSheet extends StatelessWidget {
  const _SportListSheet({required this.options, required this.selected});

  final List<SportType> options;
  final SportType selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('sportPicker.title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t('common.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final sport in options)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondaryLight,
                        child: Icon(sport.icon, color: AppColors.primary),
                      ),
                      title: Text(
                        sport.label,
                        style: TextStyle(
                          fontWeight: sport == selected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: sport == selected
                          ? Icon(Icons.check, color: AppColors.secondary)
                          : null,
                      onTap: () => Navigator.of(context).pop(sport),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
