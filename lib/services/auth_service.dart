import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Where Supabase redirects back to after an email link (confirmation,
/// password reset). Must be listed under Authentication -> URL
/// Configuration -> Redirect URLs in the Supabase project.
const appBaseUrl = 'https://melinakunkel.github.io/PaceMatch/';

class AuthService {
  final _client = SupabaseService.client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String uiLanguage = 'de',
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'ui_language': uiLanguage},
    );
  }

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: appBaseUrl);
  }

  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
