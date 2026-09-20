import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router/app_router.dart';
import 'services/match_notifier.dart';
import 'services/profile_service.dart';
import 'services/supabase_service.dart';
import 'services/unread_controller.dart';
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
      if (data.session != null) {
        UnreadController.startListening();
        UnreadController.refresh();
        MatchNotifier.startListening();
        MatchNotifier.refresh();
        _syncThemeFromProfile();
      } else {
        UnreadController.stopListening();
        MatchNotifier.stopListening();
      }
    });
    if (SupabaseService.currentUserId != null) {
      UnreadController.startListening();
      UnreadController.refresh();
      MatchNotifier.startListening();
      MatchNotifier.refresh();
      _syncThemeFromProfile();
    }
  }

  /// Applies the design saved on the account, if any, so a returning user
  /// (or a login on a different device/browser) sees their chosen theme
  /// instead of whatever this browser's local storage happens to have.
  Future<void> _syncThemeFromProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final saved = await ProfileService().getThemeVariant(userId);
      if (saved == null) return;
      for (final v in AppThemeVariant.values) {
        if (v.name == saved && v != ThemeController.variant.value) {
          await ThemeController.setVariant(v);
          break;
        }
      }
    } catch (_) {
      // Offline or transient error — local theme stays as-is.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    UnreadController.stopListening();
    MatchNotifier.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeVariant>(
      valueListenable: ThemeController.variant,
      builder: (context, variant, _) {
        return MaterialApp.router(
          key: ValueKey(variant),
          title: 'SAMEPACE',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        );
      },
    );
  }
}
