import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/theme.dart';

void main() {
  group('buildTheme', () {
    test('uses the Broadsheet cyan as the primary color', () {
      expect(buildTheme().colorScheme.primary, AppColors.cyan);
    });

    test('sets Source Serif 4 as the typeface', () {
      expect(buildTheme().textTheme.bodyMedium?.fontFamily, 'Source Serif 4');
    });

    test('uses the sharp 2px corner radius on cards', () {
      final shape = buildTheme().cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, kRadius);
    });
  });
}
