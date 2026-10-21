import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_screen.dart';
import '../../core/theme/palette.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String checkoutId;
  final List<String> orderIds;
  final double total;
  final bool paidOnline;
  const OrderSuccessScreen({
    super.key,
    required this.checkoutId,
    required this.orderIds,
    required this.total,
    required this.paidOnline,
  });

  @override
  Widget build(BuildContext context) {
    final multiple = orderIds.length > 1;
    return Scaffold(
      backgroundColor: context.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 72, color: AppColors.success),
                ),
              ),
              const SizedBox(height: 28),
              Text(paidOnline ? 'Payment received!' : 'Order placed!',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '${Fmt.price(total)} • ${paidOnline ? 'Paid' : 'Pay in cash when it arrives'}\n'
                '${multiple ? 'Your items come from ${orderIds.length} sellers, so you have ${orderIds.length} orders. ' : ''}'
                'The seller will contact you to arrange delivery. We will notify you when the status changes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.muted, height: 1.6),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => multiple || orderIds.isEmpty
                        ? const OrdersScreen()
                        : OrderDetailScreen(orderId: orderIds.first),
                  ),
                ),
                child: Text(multiple ? 'View my orders' : 'Track order'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
