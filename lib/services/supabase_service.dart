import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
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
