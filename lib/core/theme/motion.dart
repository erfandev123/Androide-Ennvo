// ============================================================================
//  ENNVO — MOTION SYSTEM
//
//  Every spring and curve in this file is a 1:1 port of the web app's
//  `motion` (Framer Motion) configuration, so the native app moves exactly
//  like the web build.
//
//  Framer Motion's spring uses the same physical model as Flutter's
//  SpringDescription (mass / stiffness / damping), so the numbers transfer
//  without adjustment.
// ============================================================================

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Turns a [SpringDescription] into a [Curve] so it can drive any
/// `TweenAnimationBuilder` — Flutter has no built-in spring curve, but its
/// [SpringSimulation] uses the exact same physical model as Framer Motion.
class SpringCurve extends Curve {
  const SpringCurve(
    this.description, {
    this.tolerance = Tolerance.defaultTolerance,
  });

  final SpringDescription description;
  final Tolerance tolerance;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final simulation = SpringSimulation(description, 0, 1, 0);
    final duration = simulation.duration;
    if (duration <= 0) return 1;
    return simulation.x(t * duration).clamp(-0.5, 1.5);
  }
}

/// Named springs lifted from the web app.
class EnnvoSprings {
  const EnnvoSprings._();

  /// BottomNav active pill — `{ type:'spring', stiffness:520, damping:38 }`.
  static const SpringDescription navPill = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 38,
  );

  /// Reels tab indicator + advanced settings toggles —
  /// `{ stiffness:500, damping:30 }`.
  static const SpringDescription tabIndicator = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 30,
  );

  /// Reel follow button + icon swap — `{ stiffness:500, damping:26 }`.
  static const SpringDescription followButton = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 26,
  );

  /// Post like / repost pop — `{ stiffness:450, damping:18 }`.
  static const SpringDescription likePop = SpringDescription(
    mass: 1,
    stiffness: 450,
    damping: 18,
  );

  /// Profile tab underline — `{ stiffness:450, damping:34 }`.
  static const SpringDescription profileTab = SpringDescription(
    mass: 1,
    stiffness: 450,
    damping: 34,
  );

  /// Reels tab button (scale / y / opacity) — `{ stiffness:420, damping:26 }`.
  static const SpringDescription reelsTab = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 26,
  );

  /// In-app toast — `{ damping:24, stiffness:340, mass:0.6 }`.
  static const SpringDescription toast = SpringDescription(
    mass: 0.6,
    stiffness: 340,
    damping: 24,
  );

  /// Reels welcome card — `{ damping:26, stiffness:340 }`.
  static const SpringDescription welcomeCard = SpringDescription(
    mass: 1,
    stiffness: 340,
    damping: 26,
  );

  /// Pull-to-refresh spinner — `{ damping:25, stiffness:350 }`.
  static const SpringDescription pullRefresh = SpringDescription(
    mass: 1,
    stiffness: 350,
    damping: 25,
  );

  /// Story note viewer reply sheet — `{ damping:25, stiffness:300 }`.
  static const SpringDescription storySheet = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 25,
  );

  /// Mini chat card — `{ damping:26, stiffness:380, mass:0.6 }`.
  static const SpringDescription miniChat = SpringDescription(
    mass: 0.6,
    stiffness: 380,
    damping: 26,
  );

  /// Modal bottom sheets — `{ damping:28, stiffness:350, mass:0.7 }`.
  static const SpringDescription sheet = SpringDescription(
    mass: 0.7,
    stiffness: 350,
    damping: 28,
  );

  /// Upload progress pill — `{ damping:24, stiffness:380 }`.
  static const SpringDescription uploadPill = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 24,
  );

  /// Messages bottom sheet — `{ damping:30, stiffness:320 }`.
  static const SpringDescription messagesSheet = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 30,
  );
}

/// Named curves / durations lifted from the web app.
class EnnvoCurves {
  const EnnvoCurves._();

  /// `--ios-spring: cubic-bezier(0.16, 1, 0.3, 1)`.
  static const Cubic iosSpring = Cubic(0.16, 1.0, 0.3, 1.0);

  /// `--ios-bounce: cubic-bezier(0.34, 1.45, 0.64, 1)`.
  static const Cubic iosBounce = Cubic(0.34, 1.45, 0.64, 1.0);

  /// Chat bubble swipe-to-reply release —
  /// `cubic-bezier(0.2, 0.9, 0.3, 1)`.
  static const Cubic bubbleSwipe = Cubic(0.2, 0.9, 0.3, 1.0);

  /// Bottom sheet dismissal — `cubic-bezier(0.32, 0.72, 0, 1)`.
  static const Cubic sheetDismiss = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Global press feedback — `cubic-bezier(0.22, 1, 0.36, 1)`.
  static const Cubic press = Cubic(0.22, 1.0, 0.36, 1.0);
}

/// Named durations lifted from the web app.
class EnnvoDurations {
  const EnnvoDurations._();

  static const Duration iconSwap = Duration(milliseconds: 120);
  static const Duration panelExit = Duration(milliseconds: 140);
  static const Duration dropdown = Duration(milliseconds: 150);
  static const Duration dropdownAlt = Duration(milliseconds: 160);
  static const Duration modal = Duration(milliseconds: 180);
  static const Duration sheet = Duration(milliseconds: 200);
  static const Duration sheetDismiss = Duration(milliseconds: 220);
  static const Duration welcomeOverlay = Duration(milliseconds: 250);
  static const Duration doubleTapHeart = Duration(milliseconds: 600);
  static const Duration storyProgress = Duration(milliseconds: 1600);
  static const Duration toast = Duration(milliseconds: 4500);
  static const Duration shimmer = Duration(milliseconds: 1500);
  static const Duration equalizer = Duration(milliseconds: 750);
  static const Duration typingDot = Duration(milliseconds: 800);
  static const Duration activityStack = Duration(milliseconds: 650);
}

/// The app's "no press animation" rule.
///
/// The web app hard-disables `:active` scaling:
/// ```css
/// button:active { scale: 1 !important; transition-duration: 0s !important; }
/// ```
/// Flutter's default [InkWell]/[Material] press animation would break visual
/// parity, so every tappable surface uses this instead of a ripple.
class NoPressFeedback extends StatefulWidget {
  const NoPressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<NoPressFeedback> createState() => _NoPressFeedbackState();
}

class _NoPressFeedbackState extends State<NoPressFeedback> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (_pressed && _enabled) {
      // A whisper of opacity only — the web app keeps the layout bounds
      // completely stable, so no scale or translate is used here.
      child = Opacity(opacity: 0.85, child: child);
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: child,
      ),
    );
  }
}
