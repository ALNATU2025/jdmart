#!/usr/bin/env bash
# One-time setup for JDMart. Run from the project folder:  bash setup.sh
# Windows users: follow docs/GO_LIVE.md step by step instead.
set -e

echo "▶ Generating Android and iOS project folders…"
flutter create --project-name jdmart --org sl.jdmart --platforms=android,ios .

if [ -f config/google-services.json ] && [ -d android/app ]; then
  echo "▶ Android: copying Firebase config (google-services.json)…"
  cp config/google-services.json android/app/google-services.json
fi

echo "▶ Installing packages…"
flutter pub get

echo "▶ App icon and splash screen from the JDMart logo…"
dart run flutter_launcher_icons
dart run flutter_native_splash:create

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  echo "▶ Android: internet permission…"
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi
if ! grep -q "<queries>" "$MANIFEST"; then
  echo "▶ Android: allow opening payment pages, phone dialer and WhatsApp…"
  perl -0pi -e 's#</manifest>#    <queries>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n    </queries>\n</manifest>#' "$MANIFEST"
fi
perl -pi -e 's#android:label="jdmart"#android:label="JDMart"#' "$MANIFEST"
if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
  echo "▶ Android: location permission for live delivery tracking…"
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>#' "$MANIFEST"
fi
if ! grep -q "com.google.android.geo.API_KEY" "$MANIFEST"; then
  echo "▶ Android: Google Maps key placeholder (replace YOUR_MAPS_KEY)…"
  perl -0pi -e 's#(<application[^>]*>)#$1\n        <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_KEY"/>#' "$MANIFEST"
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSCameraUsageDescription "$PLIST"; then
  echo "▶ iOS: camera and photo permissions…"
  perl -0pi -e 's#<dict>#<dict>\n\t<key>NSCameraUsageDescription</key>\n\t<string>JDMart uses the camera so you can photograph items you sell.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>JDMart needs your photos so you can add pictures to your listings.</string>#' "$PLIST"
fi

echo "▶ Running tests…"
flutter test

cat <<'MSG'

✅ App setup done.

Firebase project jdmart-sl is already connected (lib/firebase_options.dart).
Next: deploy the backend (docs/GO_LIVE.md, step 3), then run the app on a phone:
    flutter run
MSG
