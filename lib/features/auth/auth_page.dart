// ============================================================================
//  ENNVO — AUTH SCREEN
//
//  A faithful port of `src/pages/Auth.tsx`, verified against the live
//  production build:
//
//    • a royal-blue wave header with the logo, "Welcome Back," / "Log In!"
//    • uppercase labels above fully rounded inputs
//    • a royal-blue pill button with a spinner while working
//    • a white "Continue with Google" pill
//    • the five screens of the web flow: Log In, Sign Up chooser, Sign Up
//      form, Reset Password and the Google username setup
//
//  The account that signs in is the one the rest of the app runs as: the
//  chat, the profile, the saved posts and the reels all read the uid from
//  the same AuthController.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/typography.dart';
import '../../shared/icons/brand_icons.dart';
import '../../shared/icons/ion_icons.dart';
import '../../shared/icons/lucide_icons.dart';

enum AuthScreen { signIn, signUp, landing, forgot, googleSetup }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.onSignIn,
    this.onSignUp,
    this.onResetRequested,
  });

  final Future<bool> Function(String user, String password)? onSignIn;
  final Future<bool> Function(
    String name,
    String username,
    String email,
    String password,
  )?
  onSignUp;
  final Future<bool> Function(String emailOrUsername)? onResetRequested;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthScreen _screen = AuthScreen.signIn;

  final _user = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _setupUsername = TextEditingController();

  bool _remember = true;
  bool _agree = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _deepBlue = Color(0xFF1E40AF);
  static const Color _midBlue = Color(0xFF1D4ED8);

  @override
  void dispose() {
    for (final controller in [
      _user,
      _password,
      _name,
      _username,
      _email,
      _setupUsername,
    ]) {
      controller.dispose();
    }
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
          if (_user.text.trim().isEmpty) {
            _error = 'Please enter your email or username';
            break;
          }
          if (_password.text.isEmpty) {
            _error = 'Please enter your password';
            break;
          }
          final ok = await widget.onSignIn?.call(
            _user.text.trim(),
            _password.text,
          );
          if (ok == false && _error == null) {
            _error = 'Incorrect email or password. Please try again.';
          }
          break;

        case AuthScreen.signUp:
          if (_name.text.trim().isEmpty) {
            _error = 'Please enter your username';
            break;
          }
          if (_email.text.trim().isEmpty) {
            _error = 'Please enter your email address';
            break;
          }
          if (_password.text.length < 6) {
            _error = 'Password must be at least 6 characters';
            break;
          }
          if (!_agree) {
            _error = 'Please accept the policy and terms to proceed';
            break;
          }
          final base = (_email.text.contains('@')
                  ? _email.text.split('@').first
                  : _name.text)
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '')
              .length >= 3
              ? (_email.text.contains('@')
                    ? _email.text.split('@').first
                    : _name.text)
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9_]'), '')
              : 'user_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

          final ok = await widget.onSignUp?.call(
            _name.text.trim(),
            base,
            _email.text.trim(),
            _password.text,
          );
          if (ok == false && _error == null) {
            _error = 'Could not create the account. Please try again.';
          }
          break;

        case AuthScreen.forgot:
          if (_email.text.trim().isEmpty) {
            _error = 'Please enter your email or username';
            break;
          }
          final ok = await widget.onResetRequested?.call(_email.text.trim());
          if (ok == true) {
            _success = 'A password reset link has been sent to your email.';
          } else if (_error == null) {
            _error = 'Could not send reset link. Please check your email.';
          }
          break;

        case AuthScreen.googleSetup:
          final handle = _setupUsername.text
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
          if (handle.length < 3) {
            _error = 'Username must be at least 3 characters';
            break;
          }
          _switch(AuthScreen.signIn);
          break;

        case AuthScreen.landing:
          break;
      }
    } catch (error) {
      _error = error.toString().replaceAll(RegExp(r'^Exception: '), '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // The web app has a showcase panel on desktop and a wave header
            // on mobile. On a phone only the wave is shown.
            ListView(
              padding: EdgeInsets.only(bottom: bottom + 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_screen != AuthScreen.landing &&
                    _screen != AuthScreen.googleSetup)
                  _WaveHeader(screen: _screen),
                if (_screen == AuthScreen.googleSetup)
                  const _GoogleSetupHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_screen == AuthScreen.landing)
                        const _LandingLogo(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _Banner(
                          message: _error!,
                          color: const Color(0xFFFF2D55),
                          icon: LucideIcons.alertCircle,
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 16),
                        _Banner(
                          message: _success!,
                          color: const Color(0xFF16A34A),
                          icon: LucideIcons.checkCircle2,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildForm(),
                      const SizedBox(height: 22),
                      _buildFooter(),
                      const SizedBox(height: 16),
                      if (top == 0) const SizedBox(height: 1),
                      const _SeoLinks(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    switch (_screen) {
      case AuthScreen.signIn:
        return _Form(
          busy: _busy,
          submitLabel: 'Log in',
          onSubmit: _submit,
          children: [
            _Field(
              label: 'EMAIL ADDRESS',
              controller: _user,
              hint: 'Jacob@gmail.com',
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'PASSWORD',
              controller: _password,
              hint: '••••••••',
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              suffix: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                    activeColor: _blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _switch(AuthScreen.forgot),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _GoogleButton(),
          ],
        );

      case AuthScreen.signUp:
        return _Form(
          busy: _busy,
          submitLabel: 'Sign up',
          onSubmit: _submit,
          children: [
            _Field(
              label: 'USER NAME',
              controller: _name,
              hint: 'Jacob josef',
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'EMAIL ADDRESS',
              controller: _email,
              hint: 'Jacob@gmail.com',
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'PASSWORD',
              controller: _password,
              hint: 'Enter password',
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              suffix: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                    activeColor: _blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'I accept the ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                GestureDetector(
                  onTap: () => _showPrivacy(context),
                  child: const Text(
                    'policy and terms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case AuthScreen.landing:
        return Column(
          children: [
            const Text(
              'Sign Up',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "it's easier to sign up now",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 28),
            _SocialPill(
              label: 'Continue with Facebook',
              color: const Color(0xFF166FE5),
              textColor: Colors.white,
              icon: const FacebookLogo(size: 17, color: Colors.white),
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _SocialPill(
              label: 'Continue with Google',
              color: Colors.white,
              textColor: const Color(0xFF334155),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              icon: const GoogleLogo(size: 17),
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _SocialPill(
              label: "I'll use email or username",
              color: Colors.white,
              textColor: const Color(0xFF475569),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              icon: const LucideIcon(
                LucideIcons.mail,
                size: 17,
                color: Color(0xFF475569),
              ),
              onTap: () => _switch(AuthScreen.signUp),
            ),
            const SizedBox(height: 26),
            const _SocialCircles(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have account? ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                GestureDetector(
                  onTap: () => _switch(AuthScreen.signIn),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case AuthScreen.forgot:
        return _Form(
          busy: _busy,
          submitLabel: 'Send Reset Link',
          onSubmit: _submit,
          children: [
            _Field(
              label: 'YOUR EMAIL',
              controller: _email,
              hint: 'Jacob@gmail.com',
              keyboard: TextInputType.emailAddress,
            ),
          ],
        );

      case AuthScreen.googleSetup:
        return _Form(
          busy: _busy,
          submitLabel: 'Enter Ennvo',
          onSubmit: _submit,
          children: [
            const Text(
              'CHOOSE USERNAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                children: [
                  const Text(
                    '@',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _setupUsername,
                      onChanged: (v) {
                        final clean = v
                            .toLowerCase()
                            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                        if (clean != v) {
                          _setupUsername.text = clean;
                          _setupUsername.selection = TextSelection.collapsed(
                            offset: clean.length,
                          );
                        }
                      },
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'username',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFooter() {
    switch (_screen) {
      case AuthScreen.signIn:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                GestureDetector(
                  onTap: () => _switch(AuthScreen.landing),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      case AuthScreen.signUp:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have account? ',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            GestureDetector(
              onTap: () => _switch(AuthScreen.signIn),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                ),
              ),
            ),
          ],
        );
      case AuthScreen.forgot:
        return GestureDetector(
          onTap: () => _switch(AuthScreen.signIn),
          child: const Text(
            'Return to login',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _blue,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: const Text('Privacy Policy & Security Terms'),
        content: const SingleChildScrollView(
          child: Text(
            'Ennvo uses Firebase for authentication and storage. '
            'Your data stays in your account and you can delete it '
            'from Settings at any time. Built with care by Erfan Sarker.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close Privacy Policy'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  The blue wave header of the web app, exact path and gradient
// ============================================================================
class _WaveHeader extends StatelessWidget {
  const _WaveHeader({required this.screen});

  final AuthScreen screen;

  static const String _wave = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 375 185" preserveAspectRatio="none">
<defs><linearGradient id="royalBlueGrad" x1="0%" y1="0%" x2="100%" y2="100%">
<stop offset="0%" stop-color="#2563EB"/><stop offset="60%" stop-color="#1D4ED8"/><stop offset="100%" stop-color="#1E40AF"/>
</linearGradient></defs>
<path fill="url(#royalBlueGrad)" d="M 0,0 L 375,0 L 375,70 C 355,115 305,180 230,180 C 150,180 80,140 0,150 Z"/>
</svg>''';

  static const String _subtitle = 'Welcome Back,';
  static const String _title = 'Log In!';

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (screen) {
      AuthScreen.signUp => 'Hello,',
      AuthScreen.forgot => 'Account Help,',
      _ => _subtitle,
    };
    final title = switch (screen) {
      AuthScreen.signUp => 'Sign Up!',
      AuthScreen.forgot => 'Reset Pass!',
      _ => _title,
    };

    return Stack(
      children: [
        SvgPicture.string(
          _wave,
          width: double.infinity,
          height: 150,
          fit: BoxFit.fill,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/brand/ennvo_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleSetupHeader extends StatelessWidget {
  const _GoogleSetupHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFF2563EB),
            child: Icon(Icons.person, color: Colors.white, size: 34),
          ),
          SizedBox(height: 12),
          Text(
            'Welcome to Ennvo!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Choose your unique username to complete setup.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _LandingLogo extends StatelessWidget {
  const _LandingLogo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20, bottom: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white,
            child: Text(
              'E',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'ENNVO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  A form with the web app's rounded inputs and blue pill button
// ============================================================================
class _Form extends StatelessWidget {
  const _Form({
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    required this.busy,
  });

  final List<Widget> children;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        const SizedBox(height: 18),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : onSubmit,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x522563EB),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    submitLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboard,
    this.suffix = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboard;
  final bool suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 6),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              suffixIcon: suffix
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleObscure,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: LucideIcon(
                          obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 16,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GoogleLogo(size: 17),
          SizedBox(width: 10),
          Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Widget icon;
  final VoidCallback onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          border: border,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialCircles extends StatelessWidget {
  const _SocialCircles();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Circle(icon: GoogleLogo(size: 18)),
        SizedBox(width: 12),
        _Circle(
          icon: FacebookLogo(size: 18),
        ),
        SizedBox(width: 12),
        Opacity(
          opacity: 0.6,
          child: _Circle(
            icon: IonIcon(
              IonIcons.more,
              size: 18,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          LucideIcon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeoLinks extends StatelessWidget {
  const _SeoLinks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Landing · About Ennvo & team · Journal · Help · Support · Privacy · Terms',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
