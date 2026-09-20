import 'package:flutter/material.dart';

import 'app.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await ThemeController.loadSaved();
  runApp(const SamepaceApp());
}
