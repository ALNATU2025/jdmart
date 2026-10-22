import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/palette.dart';

/// Preview of a photo picked on this device but not uploaded yet.
/// Reads bytes so it works on Android, iOS and web.
class LocalImage extends StatefulWidget {
  final XFile file;
  final double? width;
  final double? height;
  const LocalImage({super.key, required this.file, this.width, this.height});

  @override
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  void didUpdateWidget(covariant LocalImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.file, widget.file)) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (_, s) => s.hasData
            ? Image.memory(s.data!, width: widget.width, height: widget.height, fit: BoxFit.cover)
            : Container(width: widget.width, height: widget.height, color: context.skeleton),
      );
}

/// Copies a picked photo into memory right away. Android may delete the
/// picker's temporary file (e.g. when the phone clears the app cache) before
/// we upload it, which caused "PathNotFoundException ... scaled_xxx.jpg".
Future<XFile> keepInMemory(XFile x) async =>
    XFile.fromData(await x.readAsBytes(), name: x.name, mimeType: x.mimeType ?? 'image/jpeg');
