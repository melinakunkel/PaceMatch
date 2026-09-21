import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../services/auth_service.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = t('login.emailInvalid'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AuthService().sendPasswordResetEmail(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = t('forgotPassword.sendFailed', {'error': '$e'}),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('forgotPassword.title')),
      content: _sent
          ? Text(t('forgotPassword.sentMessage'))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('forgotPassword.instructions')),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: t('login.email')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_sent ? t('common.close') : t('common.cancel')),
        ),
        if (!_sent)
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('forgotPassword.send')),
          ),
      ],
    );
  }
}
