

import 'package:flutter/material.dart';
import 'package:o_house/theme.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: kRadius,
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _option('en', 'English'),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.divider,
            ),
            _option('ar', 'العربية'),
          ],
        ),
      ),
    );
  }

  Widget _option(String code, String label) {
    final active = selected == code;
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: () => onChanged(code),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          alignment: Alignment.center,
          color: active ? AppColors.cyan : Colors.transparent,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.paper : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
