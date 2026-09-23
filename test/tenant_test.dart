import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/tenant.dart';
import 'package:o_house/theme.dart';

void main() {
  group('resolveTenant: a build never guesses its club', () {
    test('the flavor names the club', () {
      expect(resolveTenant('owest', ''), Tenant.owest);
      expect(resolveTenant('owest', 'OWEST'), Tenant.owest); // CI's TENANT_NAME
    });

    test('a missing or unknown flavor fails fast', () {
      expect(() => resolveTenant(null, ''), throwsStateError);
      expect(() => resolveTenant('', ''), throwsStateError);
      expect(() => resolveTenant('owset', ''), throwsStateError);
    });

    test('TENANT_NAME disagreeing with the flavor fails fast', () {
      expect(() => resolveTenant('owest', 'KODE'), throwsStateError);
    });
  });

  test('every tenant has a complete config', () {
    for (final t in Tenant.values) {
      final c = tenantConfigs[t]!;
      expect(c.clubSlug, isNotEmpty);
      expect(c.supabaseUrl, startsWith('https://'));
      expect(c.publishableKey, startsWith('sb_publishable_'));
      expect(c.logo, 'assets/tenants/${t.name}/logo.png');
    }
  });

  test("the API client names this build's club on every call", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(apiClientProvider).club, 'ohouse');
  });

  test("O West's brand colours are the Broadsheet ones the app shipped with", () {
    expect(AppColors.ink, const Color(0xFF0E213F));
    expect(AppColors.cyan, const Color(0xFF0088B0));
  });
}
