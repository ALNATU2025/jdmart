import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Opens a link in the browser / external app. Returns false if it couldn't.
Future<bool> openExternal(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Call / WhatsApp / Email buttons for a person. Hidden when a channel is empty.
class ContactActions extends StatelessWidget {
  final String? phone; // E.164 (+232...) or empty
  final String? email;
  final String whatsAppText;
  const ContactActions({super.key, this.phone, this.email, this.whatsAppText = ''});

  @override
  Widget build(BuildContext context) {
    final p = (phone ?? '').trim();
    final e = (email ?? '').trim();
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (p.isNotEmpty)
          _ActionChip(icon: Icons.call_rounded, label: 'Call', color: AppColors.blue, onTap: () => openExternal('tel:$p')),
        if (digits.isNotEmpty)
          _ActionChip(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => openExternal('https://wa.me/$digits?text=${Uri.encodeComponent(whatsAppText)}'),
          ),
        if (e.isNotEmpty)
          _ActionChip(
            icon: Icons.email_rounded,
            label: 'Email',
            color: AppColors.orange,
            onTap: () => openExternal('mailto:$e'),
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.93,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ),
        ),
      );
}

/// A file the user picked from their device.
class PickedDoc {
  final String name;
  final Uint8List bytes;
  const PickedDoc(this.name, this.bytes);
}

/// Lets the user choose a CV (PDF or Word, max 5 MB). Returns null if cancelled.
/// Throws an [Exception] with a friendly message if the file can't be used.
Future<PickedDoc?> pickCvFile() async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'doc', 'docx'],
    withData: true,
  );
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  final bytes = f.bytes;
  if (bytes == null) throw Exception("Couldn't read that file. Please try another one.");
  if (bytes.lengthInBytes > 5 * 1024 * 1024) throw Exception('That file is over 5 MB. Please choose a smaller CV.');
  return PickedDoc(f.name, bytes);
}
