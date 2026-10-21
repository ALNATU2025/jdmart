import 'package:intl/intl.dart';

/// Sierra Leone uses the redenominated Leone (SLE), written "Le".
class Fmt {
  static final _money = NumberFormat('#,##0.00', 'en_US');
  static final _moneyShort = NumberFormat('#,##0', 'en_US');

  static String price(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? 'Le ${_moneyShort.format(d)}' : 'Le ${_money.format(d)}';
  }

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

  /// The 8-digit national number, e.g. "076 123456" -> "76123456". Null if invalid.
  static String? _local(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('232') ? digits.substring(3) : digits.replaceFirst(RegExp(r'^0'), '');
    return local.length == 8 ? local : null;
  }

  /// Sierra Leone numbers: +232 followed by 8 digits.
  static String? validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your phone number';
    return _local(v) == null ? 'Enter a valid Sierra Leone number' : null;
  }

  /// E.164 format for Firebase Auth / SMS, e.g. +23276123456.
  static String e164(String v) => '+232${_local(v)!}';

  /// Display format, e.g. +232 76 123456.
  static String display(String v) {
    final l = _local(v);
    if (l == null) return v;
    return '+232 ${l.substring(0, 2)} ${l.substring(2)}';
  }
}
