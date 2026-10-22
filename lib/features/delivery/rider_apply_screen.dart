import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/rider.dart';
import '../../data/repositories/rider_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';

/// Apply (or update an application) to become a verified JDMart rider.
class RiderApplyScreen extends StatefulWidget {
  final Rider? existing;
  const RiderApplyScreen({super.key, this.existing});

  @override
  State<RiderApplyScreen> createState() => _RiderApplyScreenState();
}

class _RiderApplyScreenState extends State<RiderApplyScreen> {
  final _form = GlobalKey<FormState>();
  late final SessionProvider _session = context.read<SessionProvider>();
  late final _name = TextEditingController(text: widget.existing?.name ?? _session.profile?.name ?? '');
  late final _plate = TextEditingController(text: widget.existing?.plate ?? '');
  late final _phone = TextEditingController(text: _session.phone.isEmpty ? '' : Fmt.display(_session.phone));
  final _idNumber = TextEditingController();
  late String _vehicle = widget.existing?.vehicleType ?? Rider.vehicles.first;
  late String _city = Catalog.safeCity(widget.existing?.city ?? _session.profile?.city);
  String _idType = Rider.idTypes.first;
  Uint8List? _photo;
  Uint8List? _idPhoto;
  String? _photoUrl;
  String? _idPhotoUrl;
  bool _saving = false;

  bool get _needsPlate => _vehicle == 'Motorbike' || _vehicle == 'Keke' || _vehicle == 'Car';

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.existing?.photoUrl;
    final uid = _session.uid;
    if (widget.existing != null && uid != null) {
      context.read<RiderRepository>().kyc(uid).then((k) {
        if (k == null || !mounted) return;
        setState(() {
          _idType = Rider.idTypes.contains(k.idType) ? k.idType : Rider.idTypes.first;
          _idNumber.text = k.idNumber;
          _idPhotoUrl = k.idPhotoUrl;
          if (k.phone.isNotEmpty) _phone.text = Fmt.display(k.phone);
        });
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _plate, _phone, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 900, imageQuality: 80);
      return x == null ? null : await x.readAsBytes();
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't open the camera or gallery.", error: true);
      return null;
    }
  }

  Future<ImageSource?> _askSource() => showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ),
      );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_photo == null && _photoUrl == null) {
      showSnack(context, 'Add a clear photo of your face', error: true);
      return;
    }
    final uid = _session.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final repo = context.read<RiderRepository>();
    try {
      final photo = _photo;
      final idPhoto = _idPhoto;
      final photoUrl = photo != null ? await repo.uploadImage(uid, 'photo', photo) : _photoUrl!;
      final idPhotoUrl = idPhoto != null ? await repo.uploadImage(uid, 'id', idPhoto) : _idPhotoUrl;
      await repo.apply(
        uid: uid,
        isNew: widget.existing == null,
        name: _name.text,
        photoUrl: photoUrl,
        vehicleType: _vehicle,
        plate: _needsPlate ? _plate.text : '',
        city: _city,
        idType: _idType,
        idNumber: _idNumber.text,
        idPhotoUrl: idPhotoUrl,
        phone: Fmt.e164(_phone.text),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Application sent. We\'ll notify you when it\'s reviewed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't send your application ($e)", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget item(Widget child) => FadeSlideIn(delay: Motion.stagger(i++, stepMs: 35, maxSteps: 12), child: child);
    Widget gap() => const SizedBox(height: 14);
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Become a verified rider' : 'Update rider details')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            item(Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Buyers and sellers see your photo, name and number plate so they know who is coming. '
                'Your ID is only seen by JDMart admins.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            )),
            gap(),
            item(Center(
              child: Pressable(
                onTap: () async {
                  final src = await _askSource();
                  if (src == null) return;
                  final b = await _pick(src);
                  if (b != null && mounted) setState(() => _photo = b);
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: context.blueTint,
                      backgroundImage: photo != null
                          ? MemoryImage(photo)
                          : (_photoUrl != null ? netImageProvider(_photoUrl!) : null),
                      child: (photo == null && _photoUrl == null)
                          ? Icon(Icons.face_retouching_natural_rounded, size: 46, color: context.brand)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(gradient: AppColors.orangeGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 6),
            Center(child: Text('Clear photo of your face', style: TextStyle(color: context.muted, fontSize: 12))),
            gap(),
            item(TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name (as on your ID)'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
            )),
            gap(),
            item(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in Rider.vehicles)
                      ChoiceChip(
                        label: Text(v),
                        selected: _vehicle == v,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: _vehicle == v ? Colors.white : context.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _vehicle = v),
                      ),
                  ],
                ),
              ],
            )),
            if (_needsPlate) ...[
              gap(),
              item(TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Number plate', hintText: 'e.g. AKN 123'),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the number plate' : null,
              )),
            ],
            gap(),
            item(DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Area you deliver in'),
              items: [for (final c in Catalog.cities) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _city = v ?? _city),
            )),
            gap(),
            item(TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', hintText: '076 123456'),
              validator: Fmt.validatePhone,
            )),
            gap(),
            item(Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.lock_rounded, size: 18, color: context.muted),
                    const SizedBox(width: 6),
                    const Text('ID (private)', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_idType),
                    initialValue: _idType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ID type'),
                    items: [for (final t in Rider.idTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _idType = v ?? _idType),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idNumber,
                    decoration: const InputDecoration(labelText: 'ID number'),
                    validator: (v) => (v ?? '').trim().length < 3 ? 'Enter your ID number' : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final src = await _askSource();
                      if (src == null) return;
                      final b = await _pick(src);
                      if (b != null && mounted) setState(() => _idPhoto = b);
                    },
                    icon: Icon(_idPhoto != null || _idPhotoUrl != null ? Icons.check_circle_rounded : Icons.badge_outlined),
                    label: Text(_idPhoto != null || _idPhotoUrl != null ? 'ID photo added — change' : 'Add a photo of your ID'),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(widget.existing == null ? 'Send application' : 'Send for review'),
            ),
          ],
        ),
      ),
    );
  }
}
