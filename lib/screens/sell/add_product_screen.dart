import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/seed_data.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import '../product_detail_screen.dart';
import '../../widgets/category_icon.dart';

class AddProductScreen extends StatefulWidget {
  final Product? existing;
  const AddProductScreen({super.key, this.existing});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const _maxPhotos = 6;
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _oldPrice;
  late final TextEditingController _stock;
  late List<String> _images;
  String? _category;
  String _condition = 'New';
  late String _city;
  bool _negotiable = false;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final me = context.read<AuthProvider>().user!;
    _title = TextEditingController(text: p?.title ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : _num(p.price));
    _oldPrice = TextEditingController(text: p?.oldPrice == null ? '' : _num(p!.oldPrice!));
    _stock = TextEditingController(text: '${p?.stock ?? 1}');
    _images = List.of(p?.images ?? const []);
    _category = p?.categoryId;
    _condition = p?.condition ?? 'New';
    _negotiable = p?.negotiable ?? false;
    final city = p?.city ?? me.city;
    _city = SeedData.deliveryFees.containsKey(city) ? city : 'Freetown';
  }

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _oldPrice, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

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
      if (source == ImageSource.camera) {
        final x = await _picker.pickImage(source: source, maxWidth: 1400, imageQuality: 80);
        if (x != null) setState(() => _images.add(x.path));
      } else {
        final xs = await _picker.pickMultiImage(maxWidth: 1400, imageQuality: 80);
        setState(() => _images.addAll(xs.map((x) => x.path).take(_maxPhotos - _images.length)));
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open camera/gallery: $e', error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showSnack(context, 'Please fix the highlighted fields', error: true);
      return;
    }
    setState(() => _saving = true);
    final me = context.read<AuthProvider>().user!;
    final provider = context.read<ProductProvider>();
    final price = double.parse(_price.text.replaceAll(',', ''));
    final old = _oldPrice.text.trim().isEmpty ? null : double.tryParse(_oldPrice.text.replaceAll(',', ''));
    final stock = int.tryParse(_stock.text) ?? 1;

    if (_editing) {
      final p = widget.existing!
        ..title = _title.text.trim()
        ..description = _desc.text.trim()
        ..price = price
        ..oldPrice = (old != null && old > price) ? old : null
        ..categoryId = _category!
        ..condition = _condition
        ..images = _images
        ..city = _city
        ..stock = stock
        ..negotiable = _negotiable;
      if (stock > 0 && p.isSold) p.isSold = false;
      await provider.updateProduct(p);
      if (!mounted) return;
      showSnack(context, 'Listing updated');
      Navigator.pop(context);
    } else {
      final p = await provider.addProduct(Product(
        id: StorageService.newId('p'),
        title: _title.text.trim(),
        description: _desc.text.trim(),
        price: price,
        oldPrice: (old != null && old > price) ? old : null,
        categoryId: _category!,
        condition: _condition,
        images: _images,
        sellerId: me.id,
        sellerName: me.name,
        sellerPhone: me.phone,
        city: _city,
        stock: stock,
        negotiable: _negotiable,
      ));
      if (!mounted) return;
      showSnack(context, '🎉 Your item is live on JDMart!');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'Sell an item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              'Photos',
              'Add up to $_maxPhotos clear photos. The first one is the cover.',
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_images.length < _maxPhotos)
                      GestureDetector(
                        onTap: _addPhotos,
                        child: Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.blue.withOpacity(0.4), width: 1.4),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.blue),
                              SizedBox(height: 4),
                              Text('Add photo',
                                  style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ..._images.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ProductImage(
                                path: e.value,
                                categoryId: _category ?? 'other',
                                width: 96,
                                height: 96,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              if (e.key == 0)
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: AppColors.orange, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Cover',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(e.key)),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _card(
              'Details',
              null,
              Column(
                children: [
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 70,
                    decoration: const InputDecoration(
                        labelText: 'Title', hintText: 'e.g. Tecno Camon 30, 256GB, brand new'),
                    validator: (v) => (v == null || v.trim().length < 4) ? 'Enter a clear title' : null,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: SeedData.categories
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
                      children: ['New', 'Used', 'Refurbished']
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
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      hintText: 'Condition, size, colour, warranty, what is included…',
                    ),
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Describe your item (10+ characters)' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              'Price & stock',
              'Prices are in new Leones (SLE).',
              Column(
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
                            return (n == null || n <= 0) ? 'Enter a price' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _oldPrice,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          decoration: const InputDecoration(labelText: 'Old price (optional)', prefixText: 'Le '),
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
                          decoration: const InputDecoration(labelText: 'Quantity available'),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _city,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Location'),
                          items: SeedData.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _city = v ?? _city),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _negotiable,
                    activeColor: AppColors.orange,
                    onChanged: (v) => setState(() => _negotiable = v),
                    title: const Text('Price is negotiable'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(_editing ? 'Save changes' : 'Post item for free'),
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Delete listing?',
                      message: 'This will permanently remove "${widget.existing!.title}".',
                      confirm: 'Delete',
                      danger: true)) {
                    if (!context.mounted) return;
                    await context.read<ProductProvider>().deleteProduct(widget.existing!.id);
                    if (!context.mounted) return;
                    showSnack(context, 'Listing deleted');
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                label: const Text('Delete listing', style: TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

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
