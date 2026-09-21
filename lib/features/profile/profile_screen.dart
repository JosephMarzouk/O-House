import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../supabase.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/language_toggle.dart';
import '../home/home_header.dart';
import '../locale_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final locale = ref.watch(localeProvider);
    final pendingCount = ref.watch(outboxCountProvider).valueOrNull ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            // Same date/name/role block as Home's collapsed header, so the
            // two headers show identical content, not just identical chrome.
            AppHeader(content: HeaderText(profile: profile)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  8,
                  22,
                  22 + navBarExtent(context),
                ),
                children: [
                  _SectionLabel(t.profileAccountSection),
                  _ProfileRow(
                    icon: Icons.call_outlined,
                    label: t.loginPhoneLabel,
                    trailing: Text(
                      profile?.phone ?? '—',
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.language,
                    label: t.profileLanguage,
                    trailing: LanguageToggle(
                      compact: true,
                      selected: locale?.languageCode ?? 'en',
                      onChanged: (code) async {
                        ref.read(localeProvider.notifier).set(code);
                        if (supabase.auth.currentUser != null) {
                          await supabase.rpc(
                            'set_locale',
                            params: {'p_locale': code},
                          );
                        }
                      },
                    ),
                  ),
                  if (pendingCount > 0)
                    _ProfileRow(
                      icon: Icons.cloud_upload_outlined,
                      label: t.profileSyncStatus(pendingCount),
                    ),
                  _SectionLabel(t.profileAboutSection),
                  _ProfileRow(
                    icon: Icons.info_outline,
                    label: t.profileAboutOHouse,
                    trailing: const Icon(Icons.chevron_right, color: _muted),
                    onTap: () => _showInfoSheet(
                      context,
                      t.profileAboutOHouse,
                      t.profileAboutOHouseBody,
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.description_outlined,
                    label: t.profilePolicies,
                    trailing: const Icon(Icons.chevron_right, color: _muted),
                    onTap: () => _showInfoSheet(
                      context,
                      t.profilePolicies,
                      t.profilePoliciesBody,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileRow(
                    icon: Icons.logout,
                    label: t.profileLogout,
                    iconColor: AppColors.magenta,
                    labelColor: AppColors.magentaDeep,
                    onTap: () => supabase.auth.signOut(),
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

const _muted = Color(0x99201E1D); // text @ 60%

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
    child: Text(text.toUpperCase(), style: kSectionLabel),
  );
}

/// One floating settings row: a leading icon, a label, and an optional
/// trailing value/control — its own [kShadowMd] card rather than a flat
/// ListTile, matching TaskCard/SubtaskTile's "lifted off the paper" language.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadius,
        boxShadow: [kShadowMd],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: kRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kControlHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor ?? _muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.text,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A bottom sheet fixed to 66% of the screen height, for static content
/// ("About O-House", "Policies") that has no dedicated route yet.
Future<void> _showInfoSheet(BuildContext context, String title, String body) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.66,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
