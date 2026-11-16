// ============================================================================
//  ENNVO — APP ROOT
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'features/auth/auth_page.dart';
import 'features/shell/app_shell.dart';
import 'shared/widgets/brand_splash.dart';

class EnnvoApp extends ConsumerStatefulWidget {
  const EnnvoApp({super.key});

  @override
  ConsumerState<EnnvoApp> createState() => _EnnvoAppState();
}

class _EnnvoAppState extends ConsumerState<EnnvoApp> {
  @override
  void initState() {
    super.initState();
    // Restore the persisted Firebase session in the background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Ennvo',
      debugShowCheckedModeBanner: false,
      theme: EnnvoTheme.light(),
      darkTheme: EnnvoTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: EnnvoDurations.welcomeOverlay,
      themeAnimationCurve: EnnvoCurves.iosSpring,
      builder: (context, child) {
        // The web app clamps text rendering with `text-size-adjust: 100%`.
        // Flutter honours the OS font scale, which is the right native
        // behaviour, but a very large scale can break the dense reels
        // layout, so it is capped at 1.3.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: switch (auth.status) {
        AuthStatus.unknown => const _SplashScreen(),
        AuthStatus.signedIn => const AppShell(),
        AuthStatus.signedOut => AuthPage(
          onSignIn: (user, password) =>
              ref.read(authControllerProvider).signIn(user, password),
          onSignUp: (name, username, email, password) => ref
              .read(authControllerProvider)
              .signUp(
                name: name,
                username: username,
                email: email,
                password: password,
              ),
          onResetRequested: (email) =>
              ref.read(authControllerProvider).sendPasswordReset(email),
        ),
      },
    );
  }
}

/// Shown while the persisted session is being restored.
///
/// The purple and the mark of the Android window, so the hand over from the
/// launcher is invisible — and the mark is seen exactly once.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kEnnvoPurple,
      body: EnnvoSplash(),
    );
  }
}
