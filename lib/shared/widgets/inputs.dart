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
import '../icons/lucide_icons.dart';

class EnnvoTextField extends StatefulWidget {
  const EnnvoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.focusNode,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;

  @override
  State<EnnvoTextField> createState() => _EnnvoTextFieldState();
}

class _EnnvoTextFieldState extends State<EnnvoTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isMultiline = widget.maxLines == null || widget.maxLines! > 1;
    final radius = BorderRadius.circular(
      isMultiline ? AppRadius.lg : AppRadius.pill,
    );
    final baseBorderColor = t.isDark
        ? const Color(0x33FFFFFF)
        : const Color(0xFFD6DEE8);

    final effectiveSuffix = widget.suffix ??
        (widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: LucideIcon(
                  _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  strokeWidth: 2,
                  color: t.textTertiary,
                ),
              )
            : null);

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
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: widget.obscure ? 1 : widget.minLines,
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
            suffixIcon: effectiveSuffix,
            isDense: false,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMultiline ? 16 : 20,
              vertical: isMultiline ? 14 : 15,
            ),
            border: isMultiline
                ? OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: baseBorderColor),
                  )
                : null,
            enabledBorder: isMultiline
                ? OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: baseBorderColor),
                  )
                : null,
            focusedBorder: isMultiline
                ? OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: t.accent, width: 1.6),
                  )
                : null,
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
                ? const LucideIcon(
                    LucideIcons.check,
                    size: 13,
                    strokeWidth: 2.6,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
