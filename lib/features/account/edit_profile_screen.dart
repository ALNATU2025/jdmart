import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/misc_repositories.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/local_image.dart';
import '../../state/session_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late String _city;
  bool _showPhone = true;
  XFile? _newAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionProvider>();
    final u = s.profile!;
    _name = TextEditingController(text: u.name);
    _bio = TextEditingController(text: u.bio);
    _city = Catalog.safeCity(u.city);
    _showPhone = u.contactPhone != null;
    _phone = TextEditingController(text: Fmt.display(s.phone));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x != null) setState(() => _newAvatar = x);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final users = context.read<UserRepository>();
    final media = context.read<MediaRepository>();
    final uid = session.uid!;
    setState(() => _saving = true);
    try {
      String? url;
      if (_newAvatar != null) url = await media.uploadAvatar(uid, _newAvatar!);
      await users.updateProfile(
        uid: uid,
        name: _name.text,
        city: _city,
        bio: _bio.text,
        email: session.email,
        showPhone: _showPhone,
        phone: Fmt.e164(_phone.text),
        avatarUrl: url,
      );
      if (!mounted) return;
      showSnack(context, 'Profile updated');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save. Check your connection and try again.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final u = session.profile;
    if (u == null) return Scaffold(appBar: AppBar());
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
                    _newAvatar != null
                        ? ClipOval(child: LocalImage(file: _newAvatar!, width: 100, height: 100))
                        : UserAvatar(name: u.name, imageUrl: u.avatarUrl, radius: 50),
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
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name / shop name'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: session.email,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Sign-in email'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number (for deliveries)', hintText: '076 123456'),
              validator: Fmt.validatePhone,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Town'),
              items: Catalog.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'About you / your shop'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showPhone,
              activeThumbColor: AppColors.orange,
              onChanged: (v) => setState(() => _showPhone = v),
              title: const Text('Show my phone number to buyers'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
