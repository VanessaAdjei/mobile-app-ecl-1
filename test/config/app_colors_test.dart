import 'package:eclapp/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('primary has correct hex value', () {
      expect(AppColors.primary, const Color(0xFF20AF67));
    });

    test('primaryDark has correct hex value', () {
      expect(AppColors.primaryDark, const Color(0xFF1A8F55));
    });

    test('primaryLight has correct hex value', () {
      expect(AppColors.primaryLight, const Color(0xFF4BCF8F));
    });

    test('whatsapp has correct hex value', () {
      expect(AppColors.whatsapp, const Color(0xFF25D366));
    });

    test('accent has correct hex value', () {
      expect(AppColors.accent, const Color(0xFF2E7D32));
    });
  });
}
