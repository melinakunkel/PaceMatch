import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _rememberMe = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await SupabaseService.setRememberMe(_rememberMe);
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Anmeldung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terrain, size: 48, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    'SAMEPACE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gemeinsam Sport machen, wenn es zeitlich passt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Gültige E-Mail eingeben' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mind. 6 Zeichen' : null,
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? true),
                      ),
                      const Text('Eingeloggt bleiben'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => ForgotPasswordDialog(initialEmail: _emailCtrl.text),
                        ),
                        child: const Text('Passwort vergessen?'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!, style: TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Anmelden'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Noch kein Konto? Jetzt registrieren'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
