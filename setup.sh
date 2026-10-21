#!/usr/bin/env bash
# One-time setup for JDMart. Run from the project folder:  bash setup.sh
set -e

echo "▶ Generating platform folders (android, ios, web)…"
flutter create --project-name jdmart --org sl.jdmart --platforms=android,ios,web .

echo "▶ Installing packages…"
flutter pub get

echo "▶ Creating app icons and splash screen from the JDMart logo…"
dart run flutter_launcher_icons
dart run flutter_native_splash:create

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  echo "▶ Adding INTERNET permission to Android manifest…"
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi
perl -pi -e 's#android:label="jdmart"#android:label="JDMart"#' "$MANIFEST"

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSCameraUsageDescription "$PLIST"; then
  echo "▶ Adding camera/photo permissions to iOS Info.plist…"
  perl -0pi -e 's#<dict>#<dict>\n\t<key>NSCameraUsageDescription</key>\n\t<string>JDMart uses the camera so you can photograph items you sell.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>JDMart needs your photos so you can add pictures to your listings.</string>#' "$PLIST"
fi

echo "▶ Running tests…"
flutter test

echo "✅ Done. Start the app with:  flutter run"
