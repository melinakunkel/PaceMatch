import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/locale_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/stock_photos.dart';
import '../../utils/safe_pop.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/network_photo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        uiLanguage: LocaleController.language.value.name,
      );
      if (mounted) context.go('/onboarding');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = t('register.signUpFailed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Reached with go('/register'), so there's nothing to pop — the
        // arrow leads back to the login explicitly.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: t('register.backToLogin'),
          onPressed: () => safeBack(context, '/login'),
        ),
        title: Text(t('register.title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 140,
                    child: NetworkPhoto(
                      url: StockPhotos.teamHighFive,
                      fallbackIcon: Icons.groups_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      t('register.language'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const LanguageToggle(),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: t('register.name')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t('register.nameRequired')
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: t('login.email')),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? t('login.emailInvalid')
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t('login.password')),
                  validator: (v) => (v == null || v.length < 6)
                      ? t('login.passwordTooShort')
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
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
                      : Text(t('register.submit')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(t('register.haveAccount')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
