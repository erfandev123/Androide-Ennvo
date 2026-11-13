// ============================================================================
//  ENNVO — BUTTONS
//
//  The app uses fully rounded ("pill") buttons everywhere. The primary
//  action is a royal-blue gradient, the secondary action is a white
//  bordered pill.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The primary CTA — royal blue gradient pill.
class EnnvoPrimaryButton extends StatelessWidget {
  const EnnvoPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.gradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: EnnvoDurations.dropdown,
          opacity: enabled ? 1 : 0.6,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient:
                  gradient ??
                  const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x4D2563EB),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: EnnvoText.bodySemi.copyWith(
                            color: Colors.white,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The secondary CTA — white bordered pill.
class EnnvoSecondaryButton extends StatelessWidget {
  const EnnvoSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A custom widget rendered before the label — used by the Google button
  /// so the brand mark keeps the exact pill metrics of the web build.
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF12121A) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: t.borderStrong),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, size: 18, color: t.textPrimary),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: EnnvoText.bodySemi.copyWith(
                    color: t.textPrimary,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill chip — used for filters, tags and status pills.
class EnnvoChip extends StatelessWidget {
  const EnnvoChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: EnnvoDurations.dropdown,
        curve: EnnvoCurves.press,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? t.accentSoft : t.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? t.accent : t.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? t.accent : t.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: EnnvoText.label.copyWith(
                color: isSelected ? t.accent : t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
