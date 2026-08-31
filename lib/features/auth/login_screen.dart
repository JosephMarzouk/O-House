import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:o_house/features/auth/custom_widgets/LanguageToggle.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/profile.dart';
import '../../supabase.dart';
import '../../theme.dart';
import '../../widgets/brand_panel.dart';
import '../../widgets/ink_handoff_panel.dart';
import '../locale_provider.dart';
import '../splash_handoff.dart';

// TODO(confirm): dial code assumed from the project's Africa/Cairo
// convention already baked into the schema (§2) — confirm with the club.
const _dialCode = '+20';

/// Height of the collapsed ink header: the safe-area inset plus the brand
/// block with the design's 34/38 breathing room above and below it.
const _headerContentHeight = 256.0;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SplashHandoffAnimation<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  /// Reddens both field borders specifically for a rejected phone/password
  /// pair — not for the empty-field guard or a dropped connection, since
  /// those aren't "your credentials are wrong."
  bool _invalidCredentials = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations t) async {
    final phone = _phone.text.replaceAll(RegExp(r'\s'), '');
    if (phone.isEmpty || _password.text.isEmpty) {
      setState(() => _error = t.loginMissingFields);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _invalidCredentials = false;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: phoneToSyntheticEmail('$_dialCode$phone'),
        password: _password.text,
      );
    } on AuthException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = t.loginError;
          _invalidCredentials = true;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = t.loginConnectionError;
        });
      }
      return;
    }
    ref.invalidate(currentProfileProvider);
    Profile? profile;
    try {
      profile = await ref
          .read(currentProfileProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Session exists but we couldn't confirm whose it is — same call the
      // splash makes on a bad connection: let them into Home rather than
      // stranding them on a spinning button.
    }
    if (!mounted) return;
    if (profile != null) {
      ref.read(localeProvider.notifier).set(profile.locale);
    }
    context.go(
      profile?.mustChangePassword ?? false ? '/set-password' : '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final topInset = MediaQuery.paddingOf(context).top;
    final idealHeader = topInset + _headerContentHeight;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final headerHeight = idealHeader < screenHeight * 0.42
        ? idealHeader
        : screenHeight * 0.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: InkHandoffPanel(
          expanded: expanded,
          collapsedHeight: headerHeight,
          // BrandPanel doesn't change between expanded and collapsed — only
          // the box around it does — so Center alone gives it continuous,
          // literal motion as that box shrinks; no separate animation needed.
          panel: const SafeArea(
            bottom: false,
            child: Center(child: BrandPanel()),
          ),
          body: _form(t),
        ),
      ),
    );
  }

  /// Clears the red-border state the moment they start correcting the input
  /// — leaving it lit until the next submit would blame a field they've
  /// already fixed.
  void _clearCredentialsError() {
    if (_invalidCredentials) {
      setState(() {
        _invalidCredentials = false;
        _error = null;
      });
    }
  }

  Widget _form(AppLocalizations t) {
    final locale = ref.watch(localeProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth < 480 ? screenWidth : 480.0;
    final errorBorder = _invalidCredentials
        ? const OutlineInputBorder(
            borderRadius: kRadius,
            borderSide: BorderSide(color: AppColors.magenta, width: 1.5),
          )
        : null;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: SizedBox(
          width: contentWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: LanguageToggle(
                    selected: locale?.languageCode ?? 'en',
                    onChanged: (code) =>
                        ref.read(localeProvider.notifier).set(code),
                  ),
                ),
                const SizedBox(height: 34),

                Text(t.loginPhoneLabel.toUpperCase(), style: kSectionLabel),
                const SizedBox(height: 9),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _phone,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    onChanged: (_) => _clearCredentialsError(),
                    style: const TextStyle(fontSize: 18, letterSpacing: 0.36),
                    decoration: InputDecoration(
                      enabledBorder: errorBorder,
                      focusedBorder: errorBorder,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minHeight: kControlHeight,
                        minWidth: 0,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        margin: const EdgeInsets.only(right: 4),
                        color: const Color(0x0D201E1D), // ink @ 5%
                        child: const Center(
                          widthFactor: 1,
                          child: Text(
                            _dialCode,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0x99201E1D), // ink @ 60%
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(t.loginPasswordLabel.toUpperCase(), style: kSectionLabel),
                const SizedBox(height: 9),
                TextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 18, letterSpacing: 0.36),
                  onSubmitted: (_) => _loading ? null : _submit(t),
                  onChanged: (_) => _clearCredentialsError(),
                  decoration: InputDecoration(
                    enabledBorder: errorBorder,
                    focusedBorder: errorBorder,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      color: AppColors.cyan,
                      tooltip: _obscure
                          ? t.loginShowPassword
                          : t.loginHidePassword,
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.magenta,
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Text(
                  t.loginForgotPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.cyanDark,
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _loading ? null : () => _submit(t),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.paper,
                          ),
                        )
                      : Text(t.loginButton),
                ),
                const SizedBox(height: 16),
                Text(
                  t.loginFooter,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x73201E1D),
                  ), // ink @ 45%
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}