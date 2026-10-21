import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../providers/order_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>().byId(orderId);
    return Scaffold(
      backgroundColor: Colors.white,
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
              const Text('Order placed!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                order == null
                    ? ''
                    : 'Order #${order.id} • ${Fmt.price(order.total)}\n'
                        '${order.paymentMethod == 'cod' ? 'Pay in cash when it arrives.' : 'Paid with ${SeedData.payment(order.paymentMethod).name}.'} '
                        'The seller will contact you on ${order.phone} to arrange delivery to ${order.city}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, height: 1.6),
              ),
              const Spacer(),
              if (order != null)
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
                  child: const Text('Track order'),
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
