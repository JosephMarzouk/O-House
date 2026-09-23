import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../club.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/language_toggle.dart';
import '../locale_provider.dart';

/// First launch: the club code the supervisor gives out. A code rather than a
/// list, so one club's staff never see another club's name. The code
/// becomes that club's Supabase project, branding and local database
/// (club.dart), and sign-in happens against it.
class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({super.key});

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final t = AppLocalizations.of(context)!;
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await chooseClub(await lookUpClub(code));
      if (mounted) context.go('/login');
    } on UnknownClubCode {
      if (mounted) setState(() => _error = t.clubCodeUnknown);
    } catch (e) {
      debugPrint('[club] lookup failed: $e');
      if (mounted) setState(() => _error = t.clubCodeConnection);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            AppHeader(
              title: t.clubCodeTitle,
              actions: [
                LanguageToggle(
                  compact: true,
                  selected:
                      locale?.languageCode ??
                      Localizations.localeOf(context).languageCode,
                  onChanged: (code) =>
                      unawaited(ref.read(localeProvider.notifier).set(code)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _continue(),
                    decoration: InputDecoration(hintText: t.clubCodeHint),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.magentaDeep,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _continue,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.clubCodeContinue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
