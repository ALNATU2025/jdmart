import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Phone-number sign-in with an SMS code (Firebase Auth). No passwords.
class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  ConfirmationResult? _webConfirmation;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Sends the SMS code. On Android the code can be read automatically, in
  /// which case [onAutoVerified] fires and the user is signed in directly.
  Future<void> sendCode({
    required String phoneE164,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
    int? resendToken,
  }) async {
    if (kIsWeb) {
      try {
        _webConfirmation = await _auth.signInWithPhoneNumber(phoneE164);
        onCodeSent('web', null);
      } on FirebaseAuthException catch (e) {
        onError(_message(e));
      }
      return;
    }
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          onAutoVerified?.call();
        } on FirebaseAuthException catch (e) {
          onError(_message(e));
        }
      },
      verificationFailed: (e) => onError(_message(e)),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Returns an error message, or null on success.
  Future<String?> verifyCode(String verificationId, String code) async {
    try {
      if (kIsWeb) {
        final c = _webConfirmation;
        if (c == null) return 'Please request a new code.';
        await c.confirm(code);
      } else {
        await _auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' => 'That phone number is not valid.',
        'invalid-verification-code' => 'The code is incorrect. Please check the SMS and try again.',
        'session-expired' || 'code-expired' => 'The code has expired. Please request a new one.',
        'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
        'quota-exceeded' => 'SMS limit reached for today. Please try again later.',
        'network-request-failed' => 'No internet connection. Please check your data or Wi-Fi.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };
}
