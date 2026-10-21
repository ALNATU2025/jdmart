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
    if (old.file.path != widget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (_, s) => s.hasData
            ? Image.memory(s.data!, width: widget.width, height: widget.height, fit: BoxFit.cover)
            : Container(width: widget.width, height: widget.height, color: context.skeleton),
      );
}
