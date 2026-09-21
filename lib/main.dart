import 'package:flutter/material.dart';

import 'app.dart';
import 'services/locale_controller.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await ThemeController.loadSaved();
  await LocaleController.loadSaved();
  runApp(const SamepaceApp());
}
