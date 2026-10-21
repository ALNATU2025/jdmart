import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

Future<void> openLink(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// "I agree to the Terms and Privacy Policy" with tappable links.
class LegalAgreementText extends StatefulWidget {
  const LegalAgreementText({super.key});

  @override
  State<LegalAgreementText> createState() => _LegalAgreementTextState();
}

class _LegalAgreementTextState extends State<LegalAgreementText> {
  final _terms = TapGestureRecognizer()..onTap = () => openLink(AppConfig.termsUrl);
  final _privacy = TapGestureRecognizer()..onTap = () => openLink(AppConfig.privacyPolicyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: AppColors.navy),
        children: [
          const TextSpan(text: 'I agree to the JDMart '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
        ],
      ),
    );
  }
}
