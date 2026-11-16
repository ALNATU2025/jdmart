import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/common.dart';
import '../../state/session_provider.dart';
import '../account/legal_links.dart';
import '../../core/theme/palette.dart';
import '../onboarding/welcome_tour.dart';

enum _Step { email, profile }

/// Email + password (sign in or create an account) -> (first time only) name,
/// phone & town. Pops with `true` once the user is signed in with a profile.
class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  _Step _step = _Step.email;
  bool _busy = false;
  bool _finished = false;
  bool _creating = false; // false = sign in, true = create account
  bool _hidePassword = true;

  final _emailForm = GlobalKey<FormState>();
  final _profileForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _city = 'Freetown';
  bool _showPhone = true;
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionProvider>();
    if (s.needsProfile) _step = _Step.profile;
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();

  bool _validEmail(String t) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);

  Future<void> _submit() async {
    if (_busy || !_emailForm.currentState!.validate()) return;
    if (_creating && !_agree) {
      showSnack(context, 'Please accept the Terms and Privacy Policy', error: true);
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<SessionProvider>().auth;
    final err = _creating
        ? await auth.signUp(_emailValue, _password.text)
        : await auth.signIn(_emailValue, _password.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      showSnack(context, err, error: true);
    }
    // On success the session listener below moves us on.
  }

  Future<void> _forgotPassword() async {
    final t = _emailValue;
    if (!_validEmail(t)) {
      showSnack(context, 'Type your email address above first', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<SessionProvider>().auth.resetPassword(t);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined, size: 44, color: AppColors.orange),
        title: const Text('Check your email'),
        content: Text('If $t has a JDMart account, we sent it a link to set a new password. '
            'Open it, choose a password, then come back and sign in.\n\n'
            'It can take a minute — check your Spam or Promotions folder too.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final uid = session.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await context.read<UserRepository>().createProfile(
            uid: uid,
            name: _name.text,
            city: _city,
            phone: Fmt.e164(_phone.text),
            email: session.email,
            showPhone: _showPhone,
          );
      await markNewUser(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, "Couldn't save your profile. Check your connection and try again.", error: true);
    }
  }

  void _react(SessionProvider s) {
    if (_finished || !s.ready || s.authUser == null) return;
    if (s.isLoggedIn) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSnack(context, 'Welcome, ${s.profile!.firstName}!');
        Navigator.pop(context, true);
      });
    } else if (s.needsProfile && _step != _Step.profile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _step = _Step.profile;
          _busy = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _react(context.watch<SessionProvider>());
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _busy ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (_step) {
                  _Step.email => _emailStep(),
                  _Step.profile => _profileStep(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primary(String label, VoidCallback onPressed) => ElevatedButton(
        onPressed: _busy ? null : onPressed,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label),
      );

  Widget _modeTab(String label, bool creating) {
    final on = _creating == creating;
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : () => setState(() => _creating = creating),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? context.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)] : null,
          ),
          child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w700, color: on ? context.brand : context.muted)),
        ),
      ),
    );
  }

  Widget _emailStep() {
    return Form(
      key: _emailForm,
      child: AutofillGroup(
        child: Column(
          key: const ValueKey('email'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: JDLogo(height: 100)),
            const SizedBox(height: 20),
            Text(_creating ? 'Create your account' : 'Welcome back',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_creating ? 'Buy and sell anywhere in Sierra Leone.' : 'Sign in with your email and password.',
                style: TextStyle(color: context.muted)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: context.soft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [_modeTab('Sign in', false), _modeTab('Create account', true)]),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'you@gmail.com', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter your email address';
                return _validEmail(t) ? null : 'Enter a valid email address';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                hintText: _creating ? 'Choose a password (6+ characters)' : 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: (v) {
                final t = v ?? '';
                if (t.isEmpty) return 'Enter your password';
                if (_creating && t.length < 6) return 'Use at least 6 characters';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (!_creating)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.blue,
                title: const LegalAgreementText(),
              ),
            ],
            const SizedBox(height: 10),
            _primary(_creating ? 'Create account' : 'Sign in', _submit),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'Used JDMart before with an email code? Type your email, tap "Forgot password?" '
                'and we\'ll email you a link to set a password.',
                style: TextStyle(fontSize: 12.5, color: context.ink, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStep() {
    return Form(
      key: _profileForm,
      child: Column(
        key: const ValueKey('profile'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('Welcome to JDMart', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Tell buyers and sellers who you are.', style: TextStyle(color: context.muted)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name or shop name', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
            decoration: const InputDecoration(
              labelText: 'Phone number (for deliveries)',
              hintText: '076 123456',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: Fmt.validatePhone,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(labelText: 'Town', prefixIcon: Icon(Icons.location_city_outlined)),
            items: Catalog.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _city = v ?? _city),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showPhone,
            activeThumbColor: AppColors.orange,
            onChanged: (v) => setState(() => _showPhone = v),
            title: const Text('Show my phone number to buyers'),
            subtitle: const Text('Buyers can call you about your listings. You can change this later.'),
          ),
          const SizedBox(height: 16),
          _primary('Continue', _saveProfile),
          if (AppConfig.supportEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Need help? ${AppConfig.supportEmail}',
                textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
