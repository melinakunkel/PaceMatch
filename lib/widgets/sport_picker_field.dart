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
    this.favorites = const [],
  });

  final SportType value;
  final ValueChanged<SportType> onChanged;

  /// Defaults to every selectable sport, alphabetically.
  final List<SportType>? sports;

  /// The user's own sports — listed first under "Deine Sportarten".
  final List<SportType> favorites;

  Future<void> _open(BuildContext context) async {
    final options = sports ?? SportType.alphabetical;
    final picked = await showModalBottomSheet<SportType>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SportListSheet(
        options: options,
        favorites: favorites.where(options.contains).toList(),
        selected: value,
      ),
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
  const _SportListSheet({
    required this.options,
    required this.favorites,
    required this.selected,
  });

  final List<SportType> options;
  final List<SportType> favorites;
  final SportType selected;

  Widget _tile(BuildContext context, SportType sport) => ListTile(
    leading: CircleAvatar(
      backgroundColor: AppColors.secondaryLight,
      child: Icon(sport.icon, color: AppColors.primary),
    ),
    title: Text(
      sport.label,
      style: TextStyle(
        fontWeight: sport == selected ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
    trailing: sport == selected
        ? Icon(Icons.check, color: AppColors.secondary)
        : null,
    onTap: () => Navigator.of(context).pop(sport),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

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
                  if (favorites.isNotEmpty) ...[
                    _header(t('sportPicker.mine')),
                    for (final sport in favorites) _tile(context, sport),
                    _header(t('sportPicker.all')),
                  ],
                  for (final sport in options)
                    if (!favorites.contains(sport)) _tile(context, sport),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
