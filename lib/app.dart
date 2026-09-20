import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router/app_router.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

class SamepaceApp extends StatefulWidget {
  const SamepaceApp({super.key});

  @override
  State<SamepaceApp> createState() => _SamepaceAppState();
}

class _SamepaceAppState extends State<SamepaceApp> {
  late final GoRouter _router = buildRouter();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // A clicked "reset password" email link lands here with a valid
    // (temporary) session; send the user straight to the reset form
    // instead of letting them land on Home with no context.
    _authSub = SupabaseService.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _router.go('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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
