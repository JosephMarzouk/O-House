import 'dart:io';
import 'dart:math';

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
      expect(c.appNameEn, isNotEmpty);
      expect(c.appNameAr, isNotEmpty);
      expect(c.logo, 'assets/tenants/${t.name}/${t.name}.png');
      // A renamed logo once broke the build silently: the path must exist.
      expect(File(c.logo).existsSync(), isTrue, reason: '${t.name} logo');
    }
  });

  test('every tenant\'s brand colours stay readable', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (max(x, y) + 0.05) / (min(x, y) + 0.05);
    }

    for (final t in Tenant.values) {
      final c = tenantConfigs[t]!;
      // Link and label text on the page ground (WCAG AA body text).
      expect(contrast(c.accentDark, AppColors.paper), greaterThanOrEqualTo(4.5),
          reason: '${t.name} accentDark on paper');
      // Header text on the ink block.
      expect(contrast(AppColors.paper, c.ink), greaterThanOrEqualTo(4.5),
          reason: '${t.name} paper on ink');
      // Button labels and chips on an accent fill (large/bold text, UI).
      expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(3),
          reason: '${t.name} onAccent on accent');
    }
  });

  test("the API client names this build's club on every call", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(apiClientProvider).club, 'ohouse');
  });

  test("O West's brand colours are its members'-app palette", () {
    expect(AppColors.ink, const Color(0xFF1D2749)); // primary 500
    expect(AppColors.cyan, const Color(0xFF229BA8)); // secondary 500
  });

  group('F-08 / MOB-04: which API a build talks to', () {
    test('a release build with no defines uses the deployed API over https', () {
      expect(resolveApiUrl(environment: 'prod', override: '', release: true), prodApiUrl);
      expect(prodApiUrl, startsWith('https://'));
    });

    test('a debug build defaults to this computer', () {
      expect(resolveApiUrl(environment: 'dev', override: '', release: false), 'http://127.0.0.1:4000');
    });

    test('a release build refuses plain http, from either source', () {
      expect(() => resolveApiUrl(environment: 'dev', override: '', release: true), throwsStateError);
      expect(() => resolveApiUrl(environment: 'prod', override: 'http://10.0.0.2:4000', release: true), throwsStateError);
    });

    test('API_URL overrides the environment', () {
      expect(resolveApiUrl(environment: 'prod', override: 'https://api.example.test', release: true), 'https://api.example.test');
    });
  });
}
