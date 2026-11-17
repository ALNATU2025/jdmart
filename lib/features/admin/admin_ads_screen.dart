import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/sponsored_ad.dart';
import '../../data/repositories/ad_repository.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../state/session_provider.dart';
import '../ads/my_ads_screen.dart';
import '../catalog/product_detail_screen.dart';

/// Approve paid ads after checking the mobile-money payment; set prices.
class AdminAdsScreen extends StatelessWidget {
  const AdminAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdRepository>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ads'),
          actions: [
            IconButton(
              tooltip: 'Prices & payment number',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdSettingsScreen())),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'To approve'), Tab(text: 'Live'), Tab(text: 'All')]),
        ),
        body: StreamView<List<SponsoredAd>>(
          create: () => repo.all(),
          loading: const ListSkeleton(),
          builder: (context, all) {
            final pending = all.where((a) => a.status == 'pending').toList();
            final live = all.where((a) => a.isLive || (a.status == 'active' && !a.isExpired)).toList();
            return TabBarView(children: [
              _list(context, pending, 'No ads waiting', 'New ad requests appear here.'),
              _list(context, live, 'No live ads', 'Approved ads show here while they run.'),
              _list(context, all, 'No ads yet', 'Sellers can advertise from their listing page.'),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<SponsoredAd> ads, String title, String message) {
    if (ads.isEmpty) return EmptyState(icon: Icons.campaign_outlined, title: title, message: message);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: ads.length,
      itemBuilder: (_, i) => FadeSlideIn(
        delay: Motion.stagger(i),
        child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _AdminAdCard(ad: ads[i])),
      ),
    );
  }
}

class _AdminAdCard extends StatelessWidget {
  final SponsoredAd ad;
  const _AdminAdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdRepository>();
    final a = ad;
    final details = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: context.soft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Seller', a.sellerName),
          _row(context, 'Paid with', a.payMethod),
          _row(context, 'From number', a.payPhone.isEmpty ? '—' : Fmt.display(a.payPhone)),
          Row(
            children: [
              Expanded(child: _row(context, 'Transaction ID', a.payRef)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: a.payRef));
                  showSnack(context, 'Copied');
                },
              ),
            ],
          ),
          _row(context, 'Requested', Fmt.ago(a.createdAt)),
          if (a.startsAt != null) _row(context, 'Runs', '${Fmt.date(a.startsAt!)} → ${a.endsAt == null ? '' : Fmt.date(a.endsAt!)}'),
        ],
      ),
    );
    final actions = Row(
      children: [
        TextButton.icon(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: a.productId))),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View item'),
        ),
        const Spacer(),
        if (a.status == 'pending') ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 40)),
            onPressed: () async {
              final note = await _askReason(context);
              if (note != null) await repo.reject(a, note);
            },
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 40)),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Approve this ad?',
                  message: 'Only approve after you have received ${Fmt.price(a.amount)} '
                      '(transaction ${a.payRef}). It will run for ${a.days == 1 ? '1 day' : '${a.days} days'}.',
                  confirm: 'Approve');
              if (!ok || !context.mounted) return;
              await repo.approve(a, context.read<SessionProvider>().uid ?? '');
              if (context.mounted) showSnack(context, 'Ad is live');
            },
            child: const Text('Approve'),
          ),
        ] else if (a.isLive)
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 40)),
            onPressed: () async {
              if (await confirmDialog(context,
                      title: 'Stop this ad now?', message: 'It will stop showing to users.', confirm: 'Stop', danger: true) &&
                  context.mounted) {
                await repo.stop(a);
              }
            },
            child: const Text('Stop'),
          ),
      ],
    );
    return AdTile(ad: a, extra: Column(children: [details, const SizedBox(height: 6), actions]));
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: TextStyle(color: context.muted, fontSize: 12.5))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Future<String?> _askReason(BuildContext context) {
    final c = TextEditingController(text: "We couldn't find your payment. Please check the transaction ID.");
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason (seller will see this)'),
        content: TextField(controller: c, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Reject')),
        ],
      ),
    );
  }
}

/// Ad prices, payment number and reminder frequency.
class AdSettingsScreen extends StatefulWidget {
  const AdSettingsScreen({super.key});

  @override
  State<AdSettingsScreen> createState() => _AdSettingsScreenState();
}

class _AdSettingsScreenState extends State<AdSettingsScreen> {
  static const _durations = [1, 2, 3, 4, 5, 7, 14, 30];
  final _prices = {for (final d in _durations) d: TextEditingController()};
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  bool _enabled = true;
  int _hours = 2;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    context.read<AdRepository>().settingsOnce().then((s) {
      if (!mounted) return;
      setState(() {
        for (final p in s.packages) {
          _prices[p.days]?.text = '${p.price}';
        }
        _number.text = s.payNumber.isEmpty ? '' : Fmt.display(s.payNumber);
        _name.text = s.payName;
        _instructions.text = s.instructions;
        _enabled = s.enabled;
        _hours = s.reminderHours;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [..._prices.values, _number, _name, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final pk = <AdPackage>[];
    for (final d in _durations) {
      final v = int.tryParse(_prices[d]!.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (v != null && v > 0) pk.add(AdPackage(d, v));
    }
    if (pk.isEmpty) {
      showSnack(context, 'Set a price for at least one option', error: true);
      return;
    }
    final number = _number.text.trim();
    if (number.isNotEmpty && Fmt.validatePhone(number) != null) {
      showSnack(context, 'Check the payment number', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AdRepository>().saveSettings(AdSettings(
            enabled: _enabled,
            packages: pk,
            payNumber: number.isEmpty ? '' : Fmt.e164(number),
            payName: _name.text,
            instructions: _instructions.text,
            reminderHours: _hours,
          ));
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Ad settings saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, "Couldn't save ($e)", error: true);
    }
  }

  String _label(int d) => AdPackage(d, 0).label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ad prices & payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Ads are on'),
                  subtitle: const Text('Turn off to pause new ads and reminders'),
                ),
                const SizedBox(height: 8),
                const Text('Prices (Le) — leave empty to hide an option', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final d in _durations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(_label(d), style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(
                          child: TextField(
                            controller: _prices[d],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: 'Le ', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Where sellers pay', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _number,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Orange Money / Afrimoney number', hintText: '076 123456'),
                ),
                const SizedBox(height: 10),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name on the account')),
                const SizedBox(height: 10),
                TextField(
                  controller: _instructions,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Extra instructions (optional)', hintText: 'e.g. Use your phone number as the reference'),
                ),
                const SizedBox(height: 16),
                const Text('Reminder notifications', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final h in const [1, 2, 3, 4, 6])
                      ChoiceChip(
                        label: Text(h == 1 ? 'Every hour' : 'Every $h hours'),
                        selected: _hours == h,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: _hours == h ? Colors.white : context.ink, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _hours = h),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Between 8am and 9pm only. Users can turn ad reminders off.',
                    style: TextStyle(color: context.muted, fontSize: 12)),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}
