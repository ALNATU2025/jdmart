import 'dart:async';
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

enum _Step { phone, code, profile }

/// Phone number -> SMS code -> (first time only) name & town.
/// Pops with `true` once the user is signed in with a profile.
class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  _Step _step = _Step.phone;
  bool _busy = false;
  bool _finished = false;

  final _phoneForm = GlobalKey<FormState>();
  final _profileForm = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _city = 'Freetown';
  bool _showPhone = true;
  bool _agree = false;

  String? _verificationId;
  int? _resendToken;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionProvider>();
    if (s.needsProfile) _step = _Step.profile;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_phone, _code, _name, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_phoneForm.currentState!.validate()) return;
    if (!resend && !_agree) {
      showSnack(context, 'Please accept the Terms and Privacy Policy', error: true);
      return;
    }
    setState(() => _busy = true);
    await context.read<SessionProvider>().auth.sendCode(
          phoneE164: Fmt.e164(_phone.text),
          resendToken: resend ? _resendToken : null,
          onCodeSent: (id, token) {
            if (!mounted) return;
            setState(() {
              _verificationId = id;
              _resendToken = token;
              _busy = false;
              _step = _Step.code;
            });
            _startResendTimer();
          },
          onError: (msg) {
            if (!mounted) return;
            setState(() => _busy = false);
            showSnack(context, msg, error: true);
          },
          onAutoVerified: () {
            if (mounted) setState(() => _busy = true);
          },
        );
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6 || _verificationId == null) {
      showSnack(context, 'Enter the 6-digit code from the SMS', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<SessionProvider>().auth.verifyCode(_verificationId!, code);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      showSnack(context, err, error: true);
    }
    // On success the session listener below moves us on.
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
            phone: session.phone, // E.164, e.g. +23276123456
            email: _email.text,
            showPhone: _showPhone,
          );
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
        if (mounted) setState(() {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_step == _Step.code ? Icons.arrow_back_rounded : Icons.close_rounded),
          onPressed: _busy
              ? null
              : () {
                  if (_step == _Step.code) {
                    setState(() => _step = _Step.phone);
                  } else {
                    Navigator.pop(context, false);
                  }
                },
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
                  _Step.phone => _phoneStep(),
                  _Step.code => _codeStep(),
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

  Widget _phoneStep() {
    return Form(
      key: _phoneForm,
      child: Column(
        key: const ValueKey('phone'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: JDLogo(height: 110)),
          const SizedBox(height: 24),
          const Text('Sign in or sign up', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Enter your phone number. We'll text you a 6-digit code.", style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
            decoration: const InputDecoration(
              hintText: '076 123456',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+232  ',
            ),
            validator: Fmt.validatePhone,
            onFieldSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.blue,
            title: const LegalAgreementText(),
          ),
          const SizedBox(height: 12),
          _primary('Send code', _sendCode),
          const SizedBox(height: 16),
          const Text('Standard SMS rates may apply.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _codeStep() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.sms_outlined, size: 56, color: AppColors.orange),
        const SizedBox(height: 16),
        const Text('Enter the code', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('We sent a 6-digit code to ${Fmt.display(_phone.text)}.', style: const TextStyle(color: AppColors.grey)),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 26, letterSpacing: 12, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: 20),
        _primary('Verify', _verify),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy || _resendIn > 0 ? null : () => _sendCode(resend: true),
          child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code'),
        ),
      ],
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
          const Text('Tell buyers and sellers who you are.', style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name or shop name', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(labelText: 'Town', prefixIcon: Icon(Icons.location_city_outlined)),
            items: Catalog.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _city = v ?? _city),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Invalid email';
            },
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
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
