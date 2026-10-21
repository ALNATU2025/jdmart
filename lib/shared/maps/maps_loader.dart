// Loads the Google Maps JavaScript API on the web (no need to edit
// web/index.html). On Android/iOS the key comes from the native project.
export 'maps_loader_stub.dart' if (dart.library.js_interop) 'maps_loader_web.dart';
