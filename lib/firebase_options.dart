// Firebase configuration for the JDMart project (jdmart-sl).
//
// These values are not secret: they identify the project to Firebase. Data is
// protected by firestore.rules and storage.rules.
//
// To add iOS or web later, register the app in the Firebase console and run
//   flutterfire configure --project=jdmart-sl
// which regenerates this file with every platform.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'JDMart is configured for Android and web (run with `flutter run -d chrome`). Register the iOS app in Firebase, '
          'then run `flutterfire configure --project=jdmart-sl`.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGggfDeeWEC0bfqqEOXF7lOSKHIrZObdw',
    appId: '1:256195288050:web:6dc2c2e98ad96f35ac696b',
    messagingSenderId: '256195288050',
    projectId: 'jdmart-sl',
    authDomain: 'jdmart-sl.firebaseapp.com',
    storageBucket: 'jdmart-sl.firebasestorage.app',
    measurementId: 'G-F5PYYF7PNY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAxF1FRGeSmvr7cl8rWwICBm-FjwDRAaQw',
    appId: '1:256195288050:android:e2079da16674787fac696b',
    messagingSenderId: '256195288050',
    projectId: 'jdmart-sl',
    storageBucket: 'jdmart-sl.firebasestorage.app',
  );
}
