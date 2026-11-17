import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ad_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/product_image.dart';
import '../../state/session_provider.dart';

/// Pick an ad package for a listing, pay by mobile money and send the
/// transaction ID for an admin to approve.
class PromoteProductScreen extends StatefulWidget {
  final Product product;
  const PromoteProductScreen({super.key, required this.product});

  @override
  State<PromoteProductScreen> createState() => _PromoteProductScreenState();
}

class _PromoteProductScreenState extends State<PromoteProductScreen> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(
      text: context.read<SessionProvider>().phone.isEmpty ? '' : Fmt.display(context.read<SessionProvider>().phone));
  final _ref = TextEditingController();
  AdPackage? _pkg;
  String _method = 'Orange Money';
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final pkg = _pkg;
    if (pkg == null) {
      showSnack(context, 'Choose how long to advertise', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await context.read<AdRepository>().request(
            p: widget.product,
            package: pkg,
            payMethod: _method,
            payPhone: Fmt.e164(_phone.text),
            payRef: _ref.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Sent! Your ad goes live as soon as we confirm your payment.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, "Couldn't send your request ($e)", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: const Text('Advertise this item')),
      body: StreamView<AdSettings>(
        create: () => context.read<AdRepository>().settings(),
        loading: const Center(child: CircularProgressIndicator()),
        builder: (context, s) {
          if (!s.enabled) {
            return const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Ads are paused',
              message: 'Advertising is not available right now. Please check again later.',
            );
          }
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                FadeSlideIn(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4A1500), Color(0xFFB45309), Color(0xFFF59E0B)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 74,
                            height: 74,
                            child: p.cover == null
                                ? Container(color: Colors.white24, child: const Icon(Icons.image, color: Colors.white))
                                : NetImage(url: p.cover!, error: () => Container(color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 4),
                              const Text(
                                'Shown to every JDMart user: first in the pop-up, plus a phone notification every few hours.',
                                style: TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('1. How long?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    for (final k in s.packages)
                      Pressable(
                        scale: 0.94,
                        onTap: () => setState(() => _pkg = k),
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          decoration: BoxDecoration(
                            color: _pkg == k ? AppColors.orange : context.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _pkg == k ? AppColors.orange : context.line, width: 1.5),
                            boxShadow: _pkg == k
                                ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(k.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _pkg == k ? Colors.white : context.ink,
                                      fontSize: 14.5)),
                              const SizedBox(height: 4),
                              Text(Fmt.price(k.price),
                                  style: TextStyle(
                                      color: _pkg == k ? Colors.white : context.brand,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('2. Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: context.blueTint, borderRadius: BorderRadius.circular(14)),
                  child: s.payNumber.isEmpty
                      ? const Text(
                          'Payment details are being set up. Contact JDMart support to pay, then enter the transaction ID below.',
                          style: TextStyle(fontSize: 13.5, height: 1.4))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send ${_pkg == null ? 'the amount' : Fmt.price(_pkg!.price)} by Orange Money or Afrimoney to:',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${Fmt.display(s.payNumber)}  •  ${s.payName}',
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                ),
                                IconButton(
                                  tooltip: 'Copy number',
                                  icon: const Icon(Icons.copy_rounded, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: Fmt.display(s.payNumber)));
                                    showSnack(context, 'Number copied');
                                  },
                                ),
                              ],
                            ),
                            if (s.instructions.isNotEmpty)
                              Text(s.instructions, style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4)),
                          ],
                        ),
                ),
                const SizedBox(height: 22),
                const Text('3. Tell us about your payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in const ['Orange Money', 'Afrimoney', 'Other'])
                      ChoiceChip(
                        label: Text(m),
                        selected: _method == m,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                            color: _method == m ? Colors.white : context.ink, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _method = m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Number you paid from', hintText: '076 123456'),
                  validator: Fmt.validatePhone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ref,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Transaction ID', hintText: 'From the payment SMS, e.g. PP231117.1234.A12345'),
                  validator: (v) => (v ?? '').trim().length < 4 ? 'Enter the transaction ID from your SMS' : null,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.campaign_rounded),
                  label: Text(_pkg == null ? 'Send for approval' : 'Send for approval • ${Fmt.price(_pkg!.price)}'),
                ),
                const SizedBox(height: 10),
                Text(
                  'We check your payment and start the ad, usually within a few hours. '
                  'If we can\'t find the payment, we\'ll let you know.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
