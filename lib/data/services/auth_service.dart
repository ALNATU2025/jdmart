import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/config/app_config.dart';

/// Email + password sign-in using Firebase Authentication's built-in emails
/// (verification and password reset). Works without Cloud Functions, Gmail or
/// billing.
///
/// People who signed up with the old 6-digit email code have no password yet:
/// "Forgot password?" emails them a link to set one.
class AuthService {
  AuthService(this._auth, this._functions, this._db);
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  static const _offline = 'No internet connection. Please check your data or Wi-Fi.';

  /// Returns an error message, or null when signed in.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e, signingUp: false);
    } catch (_) {
      return _offline;
    }
  }

  /// Creates the account and emails a verification link. Returns an error
  /// message, or null when signed in.
  Future<String?> signUp(String email, String password) async {
    try {
      final cred =
          await _auth.createUserWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {} // not essential to start using the app
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e, signingUp: true);
    } catch (_) {
      return _offline;
    }
  }

  /// Emails a link to set a new password. Returns an error message, or null.
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e, signingUp: false);
    } catch (_) {
      return _offline;
    }
  }

  Future<String?> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e, signingUp: false);
    } catch (_) {
      return _offline;
    }
  }

  /// Asks the server to put admin roles on the sign-in token (used by Cloud
  /// Functions). Optional: if the server is unreachable the security rules
  /// still recognise admins by their verified email.
  Future<void> refreshRoles() async {
    try {
      await _functions.httpsCallable('refreshClaims').call<dynamic>().timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  /// Admin role straight from the database: the super admin's email, or an
  /// email listed in /admins. Requires a verified email, like the rules.
  Future<({bool admin, bool superAdmin})> rolesFromDatabase(User user) async {
    final email = (user.email ?? '').toLowerCase();
    if (email.isEmpty || !user.emailVerified) return (admin: false, superAdmin: false);
    if (email == AppConfig.superAdminEmail.toLowerCase()) return (admin: true, superAdmin: true);
    try {
      final d = await _db.collection('admins').doc(email).get();
      return (admin: d.exists, superAdmin: false);
    } catch (_) {
      return (admin: false, superAdmin: false);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e, {required bool signingUp}) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' =>
          'Wrong email or password. If you used to sign in with an email code, tap "Forgot password?" to set a password.',
        'email-already-in-use' =>
          'This email already has an account. Sign in instead — or tap "Forgot password?" if you never set a password.',
        'weak-password' => 'Choose a stronger password (at least 6 characters).',
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been suspended. Please contact JDMart support.',
        'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
        'network-request-failed' => _offline,
        'operation-not-allowed' =>
          'Email sign-in is not switched on yet. (Firebase console → Authentication → Sign-in method → Email/Password.)',
        _ => e.message ?? (signingUp ? 'Sign-up failed (${e.code}).' : 'Sign-in failed (${e.code}).'),
      };
}
