import 'package:intl/intl.dart';

/// Sierra Leone uses the redenominated Leone (SLE), written "Le".
class Fmt {
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _moneyShort = NumberFormat('#,##0', 'en_US');

  static String price(double v) =>
      v == v.roundToDouble() ? 'Le ${_moneyShort.format(v)}' : 'Le ${_money.format(v)}';

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  /// Sierra Leone numbers: +232 followed by 8 digits (e.g. 076 123456 -> +232 76 123456).
  static String? validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your phone number';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('232') ? digits.substring(3) : digits.replaceFirst(RegExp(r'^0'), '');
    if (local.length != 8) return 'Enter a valid Sierra Leone number';
    return null;
  }

  static String normalizePhone(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('232') ? digits.substring(3) : digits.replaceFirst(RegExp(r'^0'), '');
    return '+232 ${local.substring(0, 2)} ${local.substring(2)}';
  }
}
