import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';

/// Admins: send a notification (with an optional picture and listing link) to
/// every user or to one town.
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Uint8List? _image;
  Product? _product;
  String _audience = 'all';
  String _city = 'Freetown';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 82);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (mounted) setState(() => _image = b);
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't open your photos.", error: true);
    }
  }

  Future<void> _pickProduct() async {
    final list = await context.read<ProductRepository>().newest(limit: 40).first.catchError((Object _) => <Product>[]);
    if (!mounted) return;
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text('Link to a listing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tapping the notification opens this item.', style: TextStyle(color: ctx.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            for (final p in list)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: p.cover == null
                        ? Container(color: ctx.blueTint)
                        : NetImage(url: p.cover!, error: () => Container(color: ctx.blueTint)),
                  ),
                ),
                title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${Fmt.price(p.price)} • ${p.sellerName}'),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (p != null && mounted) {
      setState(() {
        _product = p;
        if (_title.text.trim().isEmpty) _title.text = p.title;
        if (_body.text.trim().isEmpty) _body.text = '${Fmt.price(p.price)} • ${p.city} — tap to see it on JDMart';
      });
    }
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 3 || body.length < 3) {
      showSnack(context, 'Write a title and a message', error: true);
      return;
    }
    final who = _audience == 'all' ? 'every JDMart user' : 'users in $_city';
    if (!await confirmDialog(context, title: 'Send to $who?', message: '"$title"\n$body', confirm: 'Send')) return;
    if (!mounted) return;
    setState(() => _sending = true);
    final session = context.read<SessionProvider>();
    try {
      String? url;
      final img = _image;
      if (img != null) {
        url = await context.read<AdminRepository>().uploadBannerImage(img);
      } else {
        url = _product?.cover;
      }
      if (!mounted) return;
      await context.read<NotificationRepository>().sendBroadcast(
            title: title,
            body: body,
            imageUrl: url,
            audience: _audience,
            city: _audience == 'city' ? _city : '',
            productId: _product?.id,
            by: session.uid ?? '',
            byName: session.profile?.name ?? session.email,
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _title.clear();
        _body.clear();
        _image = null;
        _product = null;
      });
      showSnack(context, 'Notification sent to $who');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, "Couldn't send ($e)", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<NotificationRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Send notification')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          FadeSlideIn(child: _Preview(title: _title.text, body: _body.text, image: _image, imageUrl: _product?.cover)),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. 🔥 Weekend deals are live!'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            maxLength: 400,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message', hintText: 'Up to 50% off phones and fashion in Freetown…'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(_image != null ? Icons.check_circle_rounded : Icons.image_outlined),
                  label: Text(_image != null ? 'Picture added' : 'Add picture'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickProduct,
                  icon: Icon(_product != null ? Icons.check_circle_rounded : Icons.link_rounded),
                  label: Text(_product != null ? 'Listing linked' : 'Link a listing', overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          if (_image != null || _product != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _image = null;
                  _product = null;
                }),
                child: const Text('Remove picture / link'),
              ),
            ),
          const SizedBox(height: 14),
          const Text('Send to', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final a in const [('all', 'Everyone'), ('city', 'One town')])
                ChoiceChip(
                  label: Text(a.$2),
                  selected: _audience == a.$1,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: _audience == a.$1 ? Colors.white : context.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _audience = a.$1),
                ),
            ],
          ),
          if (_audience == 'city') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Town'),
              items: [for (final c in Catalog.cities) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Send notification'),
          ),
          const SizedBox(height: 22),
          StreamBuilder<bool>(
            stream: repo.serverPush(),
            builder: (_, snap) {
              final on = snap.data ?? false;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  onChanged: (v) => repo.setServerPush(v),
                  title: const Text('Server push is working', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    on
                        ? 'Phones get notifications instantly from the server, even when JDMart is closed.'
                        : 'Turn on once Firebase billing is fixed and functions are deployed. Until then, phones show '
                            'announcements when people open JDMart.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const Text('Sent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder<List<Broadcast>>(
            stream: repo.broadcasts(),
            builder: (_, snap) {
              final list = snap.data ?? const <Broadcast>[];
              if (list.isEmpty) {
                return Text('Nothing sent yet.', style: TextStyle(color: context.muted));
              }
              return Column(
                children: [
                  for (final b in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration:
                          BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(14), boxShadow: softShadow()),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(b.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5)),
                                const SizedBox(height: 4),
                                Text(
                                  '${b.audience == 'city' ? b.city : 'Everyone'} • ${Fmt.ago(b.createdAt)}'
                                  '${b.pushed ? ' • pushed to phones' : ' • shown in app'}',
                                  style: TextStyle(color: context.muted, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => repo.deleteBroadcast(b.id),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Looks like an Android heads-up notification.
class _Preview extends StatelessWidget {
  final String title;
  final String body;
  final Uint8List? image;
  final String? imageUrl;
  const _Preview({required this.title, required this.body, this.image, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final img = image;
    final url = imageUrl;
    final pic = img != null
        ? Image.memory(img, fit: BoxFit.cover)
        : (url != null ? NetImage(url: url, error: () => const SizedBox.shrink()) : null);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF2B2B2E), borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(6),
            child: const JDLogo(height: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title.isEmpty ? 'Your title' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const Text('now', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body.isEmpty ? 'Your message' : body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          if (pic != null) ...[
            const SizedBox(width: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 80, height: 52, child: pic)),
          ],
        ],
      ),
    );
  }
}
