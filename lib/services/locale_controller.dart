import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';

/// Holds the app's active display language and persists the choice, both
/// locally (works before login, e.g. on the Login screen) and — once
/// signed in — on the account, so it follows the user across devices. The
/// root widget listens to [language] and rebuilds the whole app when it
/// changes, the same way [ThemeController] does for the color scheme.
class LocaleController {
  LocaleController._();

  static const _prefsKey = 'app_language';
  static final ValueNotifier<AppLanguage> language = ValueNotifier(
    AppLanguage.de,
  );

  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) language.value = AppLanguage.fromCode(saved);
  }

  static Future<void> setLanguage(AppLanguage lang) async {
    language.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.name);
  }
}
