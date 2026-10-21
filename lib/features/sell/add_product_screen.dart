import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/misc_repositories.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/local_image.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';
import '../catalog/product_detail_screen.dart';

/// A photo on the form: either already uploaded (url) or just picked (file).
class _Photo {
  final String? url;
  final XFile? file;
  const _Photo.url(this.url) : file = null;
  const _Photo.file(this.file) : url = null;
}

class AddProductScreen extends StatefulWidget {
  final Product? existing;
  const AddProductScreen({super.key, this.existing});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _oldPrice;
  late final TextEditingController _stock;
  late final List<_Photo> _photos;
  final List<String> _removedUrls = [];
  String? _category;
  String _condition = 'New';
  late String _city;
  bool _negotiable = false;
  bool _saving = false;
  String _progress = '';

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final me = context.read<SessionProvider>().profile;
    _title = TextEditingController(text: p?.title ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : _num(p.price));
    _oldPrice = TextEditingController(text: p?.oldPrice == null ? '' : _num(p!.oldPrice!));
    _stock = TextEditingController(text: '${p?.stock ?? 1}');
    _photos = (p?.images ?? const <String>[]).map((u) => _Photo.url(u)).toList();
    _category = p?.categoryId;
    _condition = p?.condition ?? 'New';
    _negotiable = p?.negotiable ?? false;
    _city = Catalog.safeCity(p?.city ?? me?.city);
  }

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _oldPrice, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _room => AppConfig.maxListingPhotos - _photos.length;

  Future<void> _addPhotos() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.blue),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.blue),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Resized and compressed on the phone to save the seller's mobile data.
      if (source == ImageSource.camera) {
        final x = await _picker.pickImage(source: source, maxWidth: 1400, imageQuality: 78);
        if (x != null) setState(() => _photos.add(_Photo.file(x)));
      } else {
        final xs = await _picker.pickMultiImage(maxWidth: 1400, imageQuality: 78);
        setState(() => _photos.addAll(xs.take(_room).map((x) => _Photo.file(x))));
      }
    } catch (e) {
      if (mounted) showSnack(context, "Couldn't open the camera or gallery.", error: true);
    }
  }

  void _removePhoto(int i) {
    final p = _photos[i];
    if (p.url != null) _removedUrls.add(p.url!);
    setState(() => _photos.removeAt(i));
  }

  void _makeCover(int i) {
    if (i == 0) return;
    setState(() => _photos.insert(0, _photos.removeAt(i)));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showSnack(context, 'Please fix the highlighted fields', error: true);
      return;
    }
    if (_photos.isEmpty) {
      showSnack(context, 'Add at least one photo — listings with photos sell much faster', error: true);
      return;
    }
    final session = context.read<SessionProvider>();
    final me = session.profile!;
    final repo = context.read<ProductRepository>();
    final media = context.read<MediaRepository>();
    setState(() {
      _saving = true;
      _progress = 'Uploading photos…';
    });

    try {
      final id = widget.existing?.id ?? repo.newId();
      final urls = <String>[];
      var n = 0;
      final total = _photos.where((p) => p.file != null).length;
      for (final p in _photos) {
        if (p.url != null) {
          urls.add(p.url!);
        } else {
          n++;
          if (mounted) setState(() => _progress = 'Uploading photo $n of $total…');
          urls.add(await media.uploadProductPhoto(me.id, id, p.file!));
        }
      }
      if (mounted) setState(() => _progress = 'Saving…');

      final price = double.parse(_price.text.replaceAll(',', ''));
      final old = _oldPrice.text.trim().isEmpty ? null : double.tryParse(_oldPrice.text.replaceAll(',', ''));
      final stock = int.tryParse(_stock.text) ?? 1;
      final draft = ProductDraft(
        title: _title.text,
        description: _desc.text,
        price: price,
        oldPrice: old,
        categoryId: _category!,
        condition: _condition,
        city: _city,
        stock: stock,
        negotiable: _negotiable,
        images: urls,
      );

      if (_editing) {
        final wasSold = widget.existing!.status == ProductStatus.sold;
        await repo.update(id, draft, reactivate: wasSold && stock > 0);
        for (final u in _removedUrls) {
          media.deleteByUrl(u);
        }
        if (!mounted) return;
        showSnack(context, 'Listing updated');
        Navigator.pop(context);
      } else {
        await repo.create(id: id, sellerId: me.id, sellerName: me.name, sellerVerified: me.verified, draft: draft);
        if (!mounted) return;
        showSnack(context, 'Your item is live on JDMart!');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save your listing. Check your connection and try again.", error: true);
    }
  }

  Future<void> _delete() async {
    final p = widget.existing!;
    if (!await confirmDialog(context,
        title: 'Delete listing?', message: 'This permanently removes "${p.title}".', confirm: 'Delete', danger: true)) {
      return;
    }
    if (!mounted) return;
    final err = await runWithProgress(context, () => context.read<ProductRepository>().delete(p.id), label: 'Deleting…');
    if (!mounted) return;
    showSnack(context, err ?? 'Listing deleted', error: err != null);
    if (err == null) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'Sell an item')),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card('Photos', 'Add up to ${AppConfig.maxListingPhotos} clear photos. Tap a photo to make it the cover.',
                    _photosRow()),
                const SizedBox(height: 14),
                _card('Details', null, _details()),
                const SizedBox(height: 14),
                _card('Price & stock', 'Prices are in new Leones (SLE).', _pricing()),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                            const SizedBox(width: 12),
                            Text(_progress),
                          ],
                        )
                      : Text(_editing ? 'Save changes' : 'Post item for free'),
                ),
                if (_editing) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    label: const Text('Delete listing', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photosRow() => SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (_room > 0)
              GestureDetector(
                onTap: _addPhotos,
                child: Container(
                  width: 96,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.4), width: 1.4),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.blue),
                      SizedBox(height: 4),
                      Text('Add photo', style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ...List.generate(_photos.length, (i) {
              final p = _photos[i];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _makeCover(i),
                  child: Stack(
                    children: [
                      p.file != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: LocalImage(file: p.file!, width: 96, height: 96),
                            )
                          : ProductImage(
                              url: p.url,
                              categoryId: _category ?? 'other',
                              width: 96,
                              height: 96,
                              borderRadius: BorderRadius.circular(16),
                            ),
                      if (i == 0)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Cover',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(i),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );

  Widget _details() => Column(
        children: [
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 70,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Tecno Camon 30, 256GB, brand new'),
            validator: (v) => (v == null || v.trim().length < 4) ? 'Enter a clear title' : null,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: Catalog.categories
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [
                        CategoryIcon(category: c, size: 22),
                        const SizedBox(width: 10),
                        Text(c.name),
                      ]),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: Catalog.conditions
                  .map((c) => ChoiceChip(
                        label: Text(c),
                        selected: _condition == c,
                        showCheckmark: false,
                        selectedColor: AppColors.blue,
                        labelStyle: TextStyle(color: _condition == c ? Colors.white : AppColors.navy),
                        onSelected: (_) => setState(() => _condition = c),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _desc,
            maxLines: 5,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              hintText: 'Condition, size, colour, warranty, what is included…',
            ),
            validator: (v) => (v == null || v.trim().length < 10) ? 'Describe your item (10+ characters)' : null,
          ),
        ],
      );

  Widget _pricing() => Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Price', prefixText: 'Le '),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', ''));
                    if (n == null || n <= 0) return 'Enter a price';
                    if (n > 10000000) return 'Price too high';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _oldPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Was (optional)', prefixText: 'Le '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '') ?? 0;
                    if (n < 1) return 'At least 1';
                    if (n > 10000) return 'Too many';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _city,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: Catalog.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _city = v ?? _city),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _negotiable,
            activeThumbColor: AppColors.orange,
            onChanged: (v) => setState(() => _negotiable = v),
            title: const Text('Price is negotiable'),
          ),
        ],
      );

  Widget _card(String title, String? sub, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: AppColors.grey, fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
