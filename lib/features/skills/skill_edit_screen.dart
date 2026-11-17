import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/constants/skills_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/skill_pro.dart';
import '../../data/repositories/skill_repository.dart';
import '../../data/services/location_service.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';

/// Create or edit "my skill profile" so people nearby can find and call me.
class SkillEditScreen extends StatefulWidget {
  final SkillPro? existing;
  const SkillEditScreen({super.key, this.existing});

  @override
  State<SkillEditScreen> createState() => _SkillEditScreenState();
}

class _SkillEditScreenState extends State<SkillEditScreen> {
  final _form = GlobalKey<FormState>();
  late final SessionProvider _session = context.read<SessionProvider>();
  SkillPro? _existing;
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _about = TextEditingController();
  final _area = TextEditingController();
  final _phone = TextEditingController();
  final _rate = TextEditingController();
  final _custom = TextEditingController();
  final _skills = <String>[];
  String _city = 'Freetown';
  int _years = 0;
  bool _whatsApp = true;
  bool _available = true;
  bool _visible = true;
  double? _lat;
  double? _lng;
  bool _locating = false;
  Uint8List? _photo;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _existing = widget.existing;
    if (_existing != null) {
      _fill(_existing!);
      _loading = false;
    } else {
      final uid = _session.uid;
      if (uid == null) {
        _loading = false;
      } else {
        context.read<SkillRepository>().mine(uid).then((p) {
          if (!mounted) return;
          setState(() {
            _existing = p;
            if (p != null) {
              _fill(p);
            } else {
              _defaults();
            }
            _loading = false;
          });
        }).catchError((Object _) {
          if (mounted) setState(() => _loading = false);
        });
      }
    }
  }

  void _defaults() {
    final prof = _session.profile;
    _name.text = prof?.name ?? '';
    _city = Catalog.safeCity(prof?.city);
    _phone.text = _session.phone.isEmpty ? '' : Fmt.display(_session.phone);
    _photoUrl = prof?.avatarUrl;
  }

  void _fill(SkillPro p) {
    _name.text = p.name;
    _headline.text = p.headline;
    _about.text = p.about;
    _area.text = p.area;
    _phone.text = p.phone.isEmpty ? '' : Fmt.display(p.phone);
    _rate.text = p.rate;
    _skills
      ..clear()
      ..addAll(p.skills);
    _city = Catalog.safeCity(p.city);
    _years = p.experienceYears;
    _whatsApp = p.whatsApp;
    _available = p.available;
    _visible = p.visible;
    _lat = p.lat;
    _lng = p.lng;
    _photoUrl = p.photoUrl;
  }

  @override
  void dispose() {
    for (final c in [_name, _headline, _about, _area, _phone, _rate, _custom]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _has(String name) => _skills.any((s) => SkillsCatalog.keyOf(s) == SkillsCatalog.keyOf(name));

  void _toggle(SkillType t) => setState(() {
        if (_has(t.name)) {
          _skills.removeWhere((s) => SkillsCatalog.keyOf(s) == t.id);
        } else {
          _skills.add(t.name);
        }
      });

  void _addCustom() {
    final t = _custom.text.trim();
    if (t.length < 2) return;
    if (!_has(t)) setState(() => _skills.add(t));
    _custom.clear();
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 80);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (mounted) setState(() => _photo = b);
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't open your photos.", error: true);
    }
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final err = await LocationService.ensurePermission();
    final pos = err == null ? await LocationService.current() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    });
    showSnack(context, pos != null ? 'Location saved — people nearby will see you first.' : (err ?? "Couldn't get your location."),
        error: pos == null);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_skills.isEmpty) {
      showSnack(context, 'Pick at least one skill', error: true);
      return;
    }
    final uid = _session.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final repo = context.read<SkillRepository>();
    try {
      final photo = _photo;
      final url = photo != null ? await repo.uploadPhoto(uid, photo) : _photoUrl;
      await repo.save(
        uid: uid,
        isNew: _existing == null,
        name: _name.text,
        photoUrl: url,
        headline: _headline.text,
        skills: _skills,
        about: _about.text,
        city: _city,
        area: _area.text,
        lat: _lat,
        lng: _lng,
        phone: Fmt.e164(_phone.text),
        whatsApp: _whatsApp,
        rate: _rate.text,
        experienceYears: _years,
        available: _available,
        visible: _visible,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, _existing == null ? 'You\'re listed! People nearby can now find you.' : 'Skill profile updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save ($e)", error: true);
    }
  }

  Future<void> _delete() async {
    final uid = _session.uid;
    if (uid == null) return;
    if (!await confirmDialog(context,
        title: 'Remove your skill profile?', message: 'People will no longer find you in Find skills.', confirm: 'Remove')) {
      return;
    }
    if (!mounted) return;
    await context.read<SkillRepository>().delete(uid);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Skill profile removed');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('My skill profile')), body: const Center(child: CircularProgressIndicator()));
    }
    var i = 0;
    Widget item(Widget child) => FadeSlideIn(delay: Motion.stagger(i++, stepMs: 35, maxSteps: 12), child: child);
    const gap = SizedBox(height: 14);
    final photo = _photo;
    final url = _photoUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Offer your skills' : 'My skill profile'),
        actions: [
          if (_existing != null)
            IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            item(Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Plumber, electrician, tailor, mechanic…? List your skills and area. People near you will find you and call you directly.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            )),
            gap,
            item(Center(
              child: Pressable(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: context.blueTint,
                      backgroundImage: photo != null ? MemoryImage(photo) : (url != null && url.isNotEmpty ? netImageProvider(url) : null),
                      onBackgroundImageError: (photo != null || (url != null && url.isNotEmpty)) ? (_, __) {} : null,
                      child: (photo == null && (url == null || url.isEmpty))
                          ? Icon(Icons.person_rounded, size: 44, color: context.brand)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(gradient: AppColors.orangeGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            )),
            gap,
            item(TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name or business name'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
            )),
            gap,
            item(TextFormField(
              controller: _headline,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                  labelText: 'What you do', hintText: 'e.g. Experienced plumber — leaks, pipes, water tanks'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Say in a few words what you do' : null,
            )),
            const SizedBox(height: 6),
            item(Text('Your skills', style: TextStyle(fontWeight: FontWeight.w700, color: context.ink))),
            const SizedBox(height: 8),
            item(Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in SkillsCatalog.all)
                  FilterChip(
                    avatar: Icon(t.icon, size: 16, color: _has(t.name) ? Colors.white : t.color),
                    label: Text(t.name),
                    selected: _has(t.name),
                    showCheckmark: false,
                    selectedColor: t.color,
                    labelStyle: TextStyle(
                        color: _has(t.name) ? Colors.white : context.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                    onSelected: (_) => _toggle(t),
                  ),
                for (final s in _skills.where((s) => SkillsCatalog.byKey(SkillsCatalog.keyOf(s)).id == 'other'))
                  InputChip(
                    label: Text(s),
                    selected: true,
                    showCheckmark: false,
                    selectedColor: AppColors.blue,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                    deleteIconColor: Colors.white,
                    onDeleted: () => setState(() => _skills.remove(s)),
                  ),
              ],
            )),
            const SizedBox(height: 10),
            item(Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Another skill (e.g. Shoe repair)', isDense: true),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _addCustom, icon: const Icon(Icons.add_rounded)),
              ],
            )),
            gap,
            item(DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Town / city'),
              items: [for (final c in Catalog.cities) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _city = v ?? _city),
            )),
            gap,
            item(TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Area / neighbourhood', hintText: 'e.g. Wilberforce, Kissy, Lumley'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your area' : null,
            )),
            const SizedBox(height: 8),
            item(OutlinedButton.icon(
              onPressed: _locating ? null : _useLocation,
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_lat != null ? Icons.check_circle_rounded : Icons.my_location_rounded),
              label: Text(_lat != null ? 'Location saved — update' : 'Use my current location (recommended)'),
            )),
            gap,
            item(TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number people can call', hintText: '076 123456'),
              validator: Fmt.validatePhone,
            )),
            item(SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _whatsApp,
              onChanged: (v) => setState(() => _whatsApp = v),
              title: const Text('This number has WhatsApp'),
            )),
            item(TextFormField(
              controller: _rate,
              decoration: const InputDecoration(labelText: 'Price (optional)', hintText: 'e.g. From Le 150 per job'),
            )),
            gap,
            item(Row(
              children: [
                const Expanded(child: Text('Years of experience', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                    onPressed: _years > 0 ? () => setState(() => _years--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('$_years', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(
                    onPressed: _years < 60 ? () => setState(() => _years++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded)),
              ],
            )),
            gap,
            item(TextFormField(
              controller: _about,
              maxLines: 4,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'About you (optional)', hintText: 'Jobs you have done, hours you work, tools you have…'),
            )),
            item(SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              title: const Text('Available for work now'),
              subtitle: const Text('Turn off when you are busy'),
            )),
            item(SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _visible,
              onChanged: (v) => setState(() => _visible = v),
              title: const Text('Show me in Find skills'),
            )),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_existing == null ? 'List me in Find skills' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
