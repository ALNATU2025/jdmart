import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// One place for every upload in the app (listing photos, avatars, rider
/// photos, banners, CVs).
///
/// When a Cloudinary account is set in [AppConfig] files go there: it has a
/// free plan and needs no billing on the Firebase project. Otherwise they go
/// to Firebase Storage as before.
class UploadService {
  UploadService(this._storage);
  final FirebaseStorage _storage;

  static bool get usesCloudinary =>
      AppConfig.cloudinaryCloudName.isNotEmpty && AppConfig.cloudinaryUploadPreset.isNotEmpty;

  /// Uploads [bytes] and returns a public URL.
  /// [path] is like `products/uid/productId/123.jpg`; [document] is true for
  /// CVs (PDF/Word) rather than images.
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    bool document = false,
  }) async {
    if (usesCloudinary) return _cloudinary(path, bytes, document);
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public,max-age=604800'));
    return ref.getDownloadURL();
  }

  Future<String> _cloudinary(String path, Uint8List bytes, bool document) async {
    final slash = path.lastIndexOf('/');
    final folder = 'jdmart/${slash > 0 ? path.substring(0, slash) : ''}';
    final fileName = slash >= 0 ? path.substring(slash + 1) : path;
    final type = document ? 'raw' : 'image';
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/$type/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    } catch (_) {
      throw Exception('Upload failed — check your internet connection and try again.');
    }
    final body = _json(res.body);
    if (res.statusCode != 200) {
      final msg = (body['error'] is Map ? (body['error'] as Map)['message'] : null) ?? 'HTTP ${res.statusCode}';
      throw Exception('Upload failed ($msg)');
    }
    final url = body['secure_url'] as String;
    // Let Cloudinary pick the smallest format/quality for each phone: saves data.
    return document ? url : url.replaceFirst('/image/upload/', '/image/upload/f_auto,q_auto/');
  }

  Map<String, dynamic> _json(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Best effort. Cloudinary files can only be deleted with the secret API key,
  /// so those are left (and can be cleared from the Cloudinary dashboard).
  Future<void> deleteByUrl(String url) async {
    if (!url.contains('firebasestorage')) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
