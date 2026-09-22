import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/stock_photos.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/network_photo.dart';
import '../tutorial/tutorial_screen.dart';
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
      final userId = SupabaseService.currentUserId!;
      final profile = await ProfileService().getProfile(userId);
      if (profile.isPaused) {
        await ProfileService().reactivateAccount(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('login.accountReactivated'))),
          );
        }
      }
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = t('login.signInFailed', {'error': '$e'}));
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
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 160,
                          child: NetworkPhoto(
                            url: StockPhotos.runningGroup,
                            fallbackIcon: Icons.terrain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Icon(Icons.terrain, size: 32, color: AppColors.primary),
                      const SizedBox(height: 4),
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
                        t('app.tagline'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TutorialScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: Text(t('login.howItWorks')),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: t('login.email'),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? t('login.emailInvalid')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: t('login.password'),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? t('login.passwordTooShort')
                            : null,
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? true),
                          ),
                          Text(t('login.rememberMe')),
                          const Spacer(),
                          TextButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => ForgotPasswordDialog(
                                initialEmail: _emailCtrl.text,
                              ),
                            ),
                            child: Text(t('login.forgotPassword')),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(t('login.signIn')),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(t('login.noAccount')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: const LanguageToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
