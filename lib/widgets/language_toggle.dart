import 'package:flutter/material.dart';

import '../theme.dart';

/// Two tap targets in a bordered row. `SegmentedButton` would need as much
/// style override to lose its M3 pill shape and checkmark as this whole
/// widget.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  /// Tighter padding for sitting inline next to a row label (Profile's
  /// Account section) instead of standing alone (Login's header).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: kRadiusControl,
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
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 26),
          alignment: Alignment.center,
          color: active ? AppColors.cyan : Colors.transparent,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12.5 : 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.onCyan : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
