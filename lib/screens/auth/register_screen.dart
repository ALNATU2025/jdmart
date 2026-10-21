import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/seed_data.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String _city = 'Freetown';
  bool _agree = true;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      showSnack(context, 'Please accept the terms to continue', error: true);
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().register(
          name: _name.text,
          phone: Fmt.normalizePhone(_phone.text),
          email: _email.text,
          password: _pw.text,
          city: _city,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      showSnack(context, 'Account created. Welcome to JDMart!');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Join JDMart', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('One account to buy and sell anywhere in Sierra Leone.',
                        style: TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          hintText: 'Full name or shop name', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '076 123456',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+232  ',
                      ),
                      validator: Fmt.validatePhone,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          hintText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _city,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city_outlined)),
                      items: SeedData.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _city = v ?? _city),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pw,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Password (min. 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.blue,
                      title: const Text('I agree to the JDMart Terms & Privacy Policy',
                          style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Create Account'),
                    ),
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
