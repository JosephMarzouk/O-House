import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../supabase.dart';

/// Forced on first login and after any admin password reset (§4, §6).
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});
  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit(AppLocalizations t) async {
    if (_password.text != _confirm.text || _password.text.length < 8) {
      setState(() => _error = t.setPasswordMismatch);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      // Must go through the RPC. `authenticated` holds an UPDATE grant on
      // profiles.name ONLY, so writing must_change_password directly raises
      // 42501 — and with no catch below, that silently stranded the user here
      // with their new password already applied, bounced straight back to this
      // screen on every launch. complete_password_change() is SECURITY DEFINER
      // and does exactly this one write for auth.uid().
      await ref.read(apiClientProvider).post('/me/password-changed');
      ref.invalidate(profileFetchProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      // Never swallow: the flag not flipping is what makes the loop, so the
      // user has to be told rather than left staring at a cleared spinner.
      debugPrint('SetPasswordScreen._submit failed: $e');
      if (mounted) setState(() => _error = t.setPasswordError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.setPasswordTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.setPasswordLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.setPasswordConfirmLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : () => _submit(t),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.setPasswordButton),
            ),
          ],
        ),
      ),
    );
  }
}
