import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  late String _city;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: u.name);
    _email = TextEditingController(text: u.email);
    _bio = TextEditingController(text: u.bio);
    _city = SeedData.deliveryFees.containsKey(u.city) ? u.city : 'Freetown';
    _avatar = u.avatarPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x != null) setState(() => _avatar = x.path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AuthProvider>().updateProfile(
          name: _name.text.trim(),
          email: _email.text.trim(),
          city: _city,
          bio: _bio.text.trim(),
          avatarPath: _avatar,
        );
    if (!mounted) return;
    showSnack(context, 'Profile updated');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    UserAvatar(user: u, imagePath: _avatar, radius: 50),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_avatar != u.avatarPath)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('New photo selected — save to apply',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.orange, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name / shop name'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: u.phone,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Phone (verified)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _city,
              decoration: const InputDecoration(labelText: 'City / Town'),
              items: SeedData.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'About you / your shop'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save changes')),
          ],
        ),
      ),
    );
  }
}
