import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../services/locale_controller.dart';
import '../theme/app_theme.dart';

/// Small DE/EN pill switcher — used on the Login and Register screens,
/// where the language needs to be changeable before there's an account (or
/// a signed-in session) to persist the choice to.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, active, _) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              final selected = lang == active;
              return GestureDetector(
                onTap: () => LocaleController.setLanguage(lang),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    lang.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
