import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const _rememberMeKey = 'remember_me';

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    // "Eingeloggt bleiben" was unchecked at the last login: a persisted
    // session survives this same browser session (so the app keeps working
    // while open), but a cold restart signs the user back out.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rememberMeKey) == false &&
        client.auth.currentSession != null) {
      await client.auth.signOut();
    }
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static String? get currentUserId => auth.currentUser?.id;

  /// Refreshes the access token if the current session is expired or about
  /// to expire. The web tab can be backgrounded for a while (e.g. switching
  /// apps to check a confirmation email), which pauses the SDK's auto-refresh
  /// timer and leaves a stale token that RLS then rejects as unauthenticated.
  /// Call this right before a write that depends on auth.uid().
  static Future<void> ensureFreshSession() async {
    final session = auth.currentSession;
    if (session == null || !session.isExpired) return;
    try {
      await auth.refreshSession();
    } catch (_) {
      // Refresh token invalid/expired too — the caller's request will fail
      // with a clear RLS/auth error and the user can sign in again.
    }
  }
}
