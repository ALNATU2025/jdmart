import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

/// Pushes the login screen if needed. Returns true when a user is signed in.
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;
  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok == true;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().login(_id.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      showSnack(context, 'Welcome back, ${context.read<AuthProvider>().user!.name.split(' ').first}!');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: JDLogo(height: 120)),
                    const SizedBox(height: 24),
                    const Text('Welcome back',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Sign in to buy and sell on JDMart',
                        style: TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Phone number or email',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pw,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showSnack(context, 'A reset code will be sent by SMS (connect an SMS provider).'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Demo seller account:  076 123456  /  seller123',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () async {
                            final ok = await Navigator.push<bool>(
                                context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                            if (ok == true && context.mounted) Navigator.pop(context, true);
                          },
                          child: const Text('Sign Up',
                              style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
