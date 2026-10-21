import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void>? _loading;

/// Adds the Google Maps script to the page once and waits for it.
Future<void> ensureGoogleMapsLoaded(String apiKey) {
  return _loading ??= _load(apiKey);
}

Future<void> _load(String apiKey) {
  if (web.document.querySelector('script[data-jdmart-maps]') != null) return Future.value();
  final done = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(apiKey)}'
    ..async = true
    ..setAttribute('data-jdmart-maps', '1');
  script.onload = ((web.Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  script.onerror = ((web.Event _) {
    _loading = null;
    if (!done.isCompleted) done.completeError(Exception('Google Maps could not load. Check the API key.'));
  }).toJS;
  web.document.head!.append(script);
  return done.future;
}
