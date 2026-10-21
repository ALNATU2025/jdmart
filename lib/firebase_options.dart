// PLACEHOLDER — this file is replaced when you connect your Firebase project.
//
// Run from the project folder:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project-id>
//
// That command overwrites this file with your real keys (they are safe to
// commit — Firebase security comes from the rules in firestore.rules and
// storage.rules, not from hiding these values).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured yet. Run `flutterfire configure` — see docs/GO_LIVE.md, step 2.',
      );
}
