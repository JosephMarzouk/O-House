import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../supabase.dart';
import '../locale_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final locale = ref.watch(localeProvider);
    final pendingCount = ref.watch(outboxCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle)),
      body: ListView(
        children: [
          if (profile != null) ...[
            ListTile(title: Text(profile.name), subtitle: Text(profile.role)),
            if (profile.phone != null) ListTile(title: Text(profile.phone!)),
          ],
          const Divider(),
          ListTile(
            title: Text(t.profileLanguage),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'ar', label: Text('AR')),
              ],
              selected: {locale?.languageCode ?? 'en'},
              onSelectionChanged: (s) async {
                final code = s.first;
                ref.read(localeProvider.notifier).set(code);
                final userId = supabase.auth.currentUser?.id;
                if (userId != null) {
                  await supabase
                      .from('profiles')
                      .update({'locale': code})
                      .eq('id', userId);
                }
              },
            ),
          ),
          ListTile(
            title: Text(t.profileChangePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/set-password'),
          ),
          if (pendingCount > 0)
            ListTile(title: Text(t.profileSyncStatus(pendingCount))),
          const Divider(),
          ListTile(
            title: Text(t.profileLogout),
            leading: const Icon(Icons.logout),
            onTap: () => supabase.auth.signOut(),
          ),
        ],
      ),
    );
  }
}
