import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../shared/widgets/common.dart';
import '../orders/orders_screen.dart';
import 'order_success_screen.dart';

/// Sends the buyer to Monime's secure payment page (Orange Money, Afrimoney or
/// card) and waits for the server to confirm the payment.
class PaymentScreen extends StatefulWidget {
  final String checkoutId;
  final String paymentUrl;
  final double total;
  const PaymentScreen({super.key, required this.checkoutId, required this.paymentUrl, required this.total});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with WidgetsBindingObserver {
  late final OrderRepository _orders = context.read<OrderRepository>();
  late final Stream<Checkout?> _checkout = _orders.watchCheckout(widget.checkoutId);
  StreamSubscription<Checkout?>? _sub;
  bool _checking = false;
  bool _done = false;
  String _status = 'awaiting_payment';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _checkout.listen((c) {
      if (c == null || !mounted) return;
      setState(() => _status = c.status);
      if (c.status == 'paid') _finish(c);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPaymentPage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The buyer comes back from the payment page: ask the server to check.
    if (state == AppLifecycleState.resumed && !_done) _check(quiet: true);
  }

  Future<void> _openPaymentPage() async {
    final ok = await launchUrl(Uri.parse(widget.paymentUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, "Couldn't open the payment page.", error: true);
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final s = await _orders.confirmPayment(widget.checkoutId);
      if (!mounted) return;
      setState(() => _status = s);
      if (!quiet && s == 'awaiting_payment') {
        showSnack(context, "We haven't received the payment yet. Finish paying, then check again.");
      }
    } catch (e) {
      if (mounted && !quiet) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _finish(Checkout c) {
    if (_done) return;
    _done = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(checkoutId: c.id, orderIds: c.orderIds, total: c.total, paidOnline: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failed = _status == 'expired' || _status == 'cancelled';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(failed ? Icons.timer_off_outlined : Icons.phonelink_lock_rounded,
                  size: 80, color: failed ? AppColors.danger : AppColors.orange),
              const SizedBox(height: 24),
              Text(failed ? 'Payment not completed' : 'Complete your payment',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                failed
                    ? 'This payment expired or was cancelled, so your order was not placed and nothing was charged.'
                    : 'Pay ${Fmt.price(widget.total)} on the secure Monime page with Orange Money, Afrimoney or card. '
                        "Then come back here — we'll confirm automatically.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, height: 1.5),
              ),
              const Spacer(),
              if (!failed) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                  onPressed: _openPaymentPage,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open payment page'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _checking ? null : () => _check(),
                  child: _checking
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Text("I've paid — check status"),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                child: const Text('View my orders'),
              ),
              if (!failed)
                const Text('Unpaid orders are cancelled automatically after 30 minutes.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
