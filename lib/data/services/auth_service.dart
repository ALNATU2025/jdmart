import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Email sign-in with a 6-digit code. The code is emailed from JDMart's Gmail
/// account by the `requestLoginCode` Cloud Function; `verifyLoginCode` checks
/// it and returns a token that signs the user in. No passwords, no SMS.
class AuthService {
  AuthService(this._auth, this._functions);
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Returns an error message, or null when the email was sent.
  Future<String?> sendCode(String email) async {
    try {
      await _functions.httpsCallable('requestLoginCode').call<dynamic>({'email': email.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionsMessage(e);
    } catch (_) {
      return 'No internet connection. Please check your data or Wi-Fi.';
    }
  }

  /// Returns an error message, or null when signed in.
  Future<String?> verifyCode(String email, String code) async {
    try {
      final r = await _functions
          .httpsCallable('verifyLoginCode')
          .call<dynamic>({'email': email.trim(), 'code': code.trim()});
      final token = (r.data as Map)['token'] as String;
      await _auth.signInWithCustomToken(token);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionsMessage(e);
    } on FirebaseAuthException catch (e) {
      return e.code == 'network-request-failed'
          ? 'No internet connection. Please check your data or Wi-Fi.'
          : (e.message ?? 'Sign-in failed (${e.code}).');
    } catch (_) {
      return 'Sign-in failed. Please try again.';
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _functionsMessage(FirebaseFunctionsException e) => switch (e.code) {
        'unavailable' when e.message == null => 'No internet connection. Please check your data or Wi-Fi.',
        _ => e.message ?? 'Something went wrong (${e.code}). Please try again.',
      };
}
