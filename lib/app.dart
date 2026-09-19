import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SamepaceApp extends StatefulWidget {
  const SamepaceApp({super.key});

  @override
  State<SamepaceApp> createState() => _SamepaceAppState();
}

class _SamepaceAppState extends State<SamepaceApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SAMEPACE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
