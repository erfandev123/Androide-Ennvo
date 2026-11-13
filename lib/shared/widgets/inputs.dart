// ============================================================================
//  ENNVO — FORM INPUTS
//
//  The auth screen uses uppercase labels above fully rounded ("pill")
//  inputs: `rounded-full`, height 50px, padding 14/20, 14px text.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class EnnvoTextField extends StatefulWidget {
  const EnnvoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<EnnvoTextField> createState() => _EnnvoTextFieldState();
}

class _EnnvoTextFieldState extends State<EnnvoTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label.toUpperCase(),
            style: EnnvoText.overlineXs.copyWith(
              color: t.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          style: EnnvoText.body.copyWith(
            fontSize: 14,
            color: t.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: t.accent,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: EnnvoText.body.copyWith(
              fontSize: 14,
              color: t.textTertiary,
              fontWeight: FontWeight.w400,
            ),
            errorText: widget.errorText,
            errorStyle: EnnvoText.caption.copyWith(color: t.danger),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffix,
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// A pill shaped checkbox with the app's blue accent.
class EnnvoCheckbox extends StatelessWidget {
  const EnnvoCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: AnimatedContainer(
            duration: EnnvoDurations.dropdown,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: value ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? t.accent : t.borderStrong,
                width: 1.6,
              ),
            ),
            child: value
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
