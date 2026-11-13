// ============================================================================
//  ENNVO — AUTH SCREEN
//
//  A port of `src/pages/Auth.tsx`. The layout was verified against the live
//  production build at https://ennvo.vercel.app:
//
//    • a royal-blue showcase panel (desktop) / hero header (mobile)
//    • "Log In to Ennvo" heading with a sub line
//    • uppercase labels above fully rounded inputs, 50px tall
//    • a royal-blue "Log In" pill
//    • a white "Continue with Google" pill
//    • a muted footer link row
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/icons/brand_icons.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/inputs.dart';

enum AuthScreen { signIn, signUp, forgot }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.onSignIn,
    this.onSignUp,
    this.onResetRequested,
  });

  final Future<bool> Function(String user, String password)? onSignIn;
  final Future<bool> Function(String name, String username, String email, String password)?
  onSignUp;
  final Future<bool> Function(String emailOrUsername)? onResetRequested;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthScreen _screen = AuthScreen.signIn;

  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _rememberMe = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _switch(AuthScreen screen) {
    setState(() {
      _screen = screen;
      _error = null;
      _success = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      switch (_screen) {
        case AuthScreen.signIn:
          final ok = await widget.onSignIn?.call(
                _userController.text.trim(),
                _passwordController.text,
              ) ??
              false;
          if (!ok && mounted) {
            setState(() => _error = 'Wrong username or password.');
          }
        case AuthScreen.signUp:
          final ok = await widget.onSignUp?.call(
                _nameController.text.trim(),
                _usernameController.text.trim(),
                _emailController.text.trim(),
                _passwordController.text,
              ) ??
              false;
          if (!ok && mounted) {
            setState(() => _error = 'Could not create that account.');
          }
        case AuthScreen.forgot:
          final ok = await widget.onResetRequested?.call(
                _emailController.text.trim(),
              ) ??
              false;
          if (mounted) {
            setState(() {
              _success = ok
                  ? 'We sent a reset link. Check your inbox.'
                  : null;
              if (!ok) _error = 'We could not find that account.';
            });
          }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 880;
          return isWide ? _buildWide(context) : _buildNarrow(context);
        },
      ),
    );
  }

  // ======================================================================
  //  Desktop / tablet — showcase panel on the left
  // ======================================================================
  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 44, child: _ShowcasePanel(showFooter: true)),
        Expanded(
          flex: 56,
          child: Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _FormCard(this),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ======================================================================
  //  Mobile — blue hero header with the form underneath
  // ======================================================================
  Widget _buildNarrow(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.34).clamp(200.0, 320.0),
          child: const _ShowcasePanel(showFooter: false),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _FormCard(this),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  The blue showcase panel
// ============================================================================
class _ShowcasePanel extends StatelessWidget {
  const _ShowcasePanel({required this.showFooter});

  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6BE8), Color(0xFF1D4ED8)],
        ),
      ),
      child: Stack(
        children: [
          // Soft radial highlight behind the logo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 0.9,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 40,
              vertical: showFooter ? 48 : 28,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EnnvoAppLogo(size: 76),
                const SizedBox(height: 20),
                Text(
                  'Welcome to',
                  style: EnnvoText.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Ennvo', style: EnnvoText.brandHero),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Connect, share moments, and explore short videos with people around the world.',
                    style: EnnvoText.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
                if (showFooter) ...[
                  const Spacer(),
                  Text(
                    'CONNECT  ·  CREATE  ·  EXPLORE',
                    style: EnnvoText.overlineXs.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The form
// ============================================================================
class _FormCard extends StatelessWidget {
  const _FormCard(this.state);

  final _AuthPageState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final isSignIn = state._screen == AuthScreen.signIn;
    final isSignUp = state._screen == AuthScreen.signUp;
    final isForgot = state._screen == AuthScreen.forgot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSignIn
              ? 'Log In to Ennvo'
              : (isSignUp ? 'Join Ennvo' : 'Reset your password'),
          style: EnnvoText.pageHero.copyWith(
            fontSize: 30,
            color: const Color(0xFF0B1220),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isSignIn
              ? 'Welcome back! Please enter your details.'
              : (isSignUp
                    ? 'Create your account and start sharing moments.'
                    : 'Enter your email and we will send you a reset link.'),
          style: EnnvoText.body.copyWith(color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 26),

        if (state._error != null) ...[
          _Banner(
            text: state._error!,
            background: const Color(0x1FDC2626),
            foreground: const Color(0xFFB91C1C),
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(height: 16),
        ],
        if (state._success != null) ...[
          _Banner(
            text: state._success!,
            background: const Color(0x1F10B981),
            foreground: const Color(0xFF047857),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 16),
        ],

        if (isSignUp) ...[
          EnnvoTextField(
            label: 'Full name',
            controller: state._nameController,
            hint: 'Your name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          EnnvoTextField(
            label: 'Username',
            controller: state._usernameController,
            hint: 'yourhandle',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          EnnvoTextField(
            label: 'Email address',
            controller: state._emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
        ],

        if (isForgot) ...[
          EnnvoTextField(
            label: 'Email address or username',
            controller: state._emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => state._submit(),
          ),
        ] else ...[
          EnnvoTextField(
            label: isSignUp ? 'Username or email' : 'Username or email',
            controller: state._userController,
            hint: 'yourhandle',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          EnnvoTextField(
            label: 'Password',
            controller: state._passwordController,
            hint: '••••••••',
            obscure: state._obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => state._submit(),
            suffix: IconButton(
              onPressed: () => state.setState(
                () => state._obscure = !state._obscure,
              ),
              icon: Icon(
                state._obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: const Color(0xFF9CA3AF),
              ),
              tooltip: state._obscure ? 'Show password' : 'Hide password',
            ),
          ),
        ],

        if (isSignIn) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              EnnvoCheckbox(
                value: state._rememberMe,
                onChanged: (v) => state.setState(() => state._rememberMe = v),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => state._switch(AuthScreen.forgot),
                child: Text(
                  'Remember me',
                  style: EnnvoText.label.copyWith(color: t.textSecondary),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => state._switch(AuthScreen.forgot),
                child: Text(
                  'Forgot password?',
                  style: EnnvoText.label.copyWith(color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        EnnvoPrimaryButton(
          label: isSignIn
              ? 'Log In'
              : (isSignUp ? 'Sign Up' : 'Send reset link'),
          isLoading: state._busy,
          onPressed: state._submit,
        ),

        if (!isForgot) ...[
          const SizedBox(height: 14),
          EnnvoSecondaryButton(
            label: 'Continue with Google',
            leading: const GoogleLogo(size: 17),
            onPressed: state._busy ? null : () {},
          ),
        ],

        const SizedBox(height: 22),
        Center(
          child: isSignIn
              ? _InlineLink(
                  before: "Don't have an account? ",
                  link: 'Sign Up',
                  onTap: () => state._switch(AuthScreen.signUp),
                )
              : (isSignUp
                    ? _InlineLink(
                        before: 'Already have an account? ',
                        link: 'Log In',
                        onTap: () => state._switch(AuthScreen.signIn),
                      )
                    : _InlineLink(
                        before: 'Remembered your password? ',
                        link: 'Log In',
                        onTap: () => state._switch(AuthScreen.signIn),
                      )),
        ),
        const SizedBox(height: 26),
        const _FooterLinks(),
      ],
    );
  }
}

/// Draws the Google mark inside the secondary button without changing the
/// button's own layout.
class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.before,
    required this.link,
    required this.onTap,
  });

  final String before;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          text: before,
          style: EnnvoText.body.copyWith(color: const Color(0xFF6B7280)),
          children: [
            TextSpan(
              text: link,
              style: EnnvoText.body.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: EnnvoText.caption.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context) {
    const links = [
      'Landing',
      'About Ennvo & team',
      'Journal',
      'Help',
      'Support',
      'Privacy',
      'Terms',
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0)
            Text(
              '·',
              style: EnnvoText.tiny.copyWith(color: const Color(0xFF9CA3AF)),
            ),
          Text(
            links[i],
            style: EnnvoText.tiny.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
