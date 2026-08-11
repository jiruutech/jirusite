import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../app/theme.dart';

class ReceiptPhotoCapture extends StatefulWidget {
  const ReceiptPhotoCapture({
    super.key,
    this.onPhotoSelected,
    this.existingPhotoUrl,
  });

  final ValueChanged<String>? onPhotoSelected; // local file path
  final String? existingPhotoUrl;

  @override
  State<ReceiptPhotoCapture> createState() => _ReceiptPhotoCaptureState();
}

class _ReceiptPhotoCaptureState extends State<ReceiptPhotoCapture> {
  String? _localPath;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _localPath != null || widget.existingPhotoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt Photo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _processing ? null : _showSourcePicker,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: hasPhoto ? AppColors.primary : AppColors.divider,
                width: hasPhoto ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              color: AppColors.background,
            ),
            child: _processing
                ? const Center(child: CircularProgressIndicator())
                : hasPhoto
                    ? _buildPhotoPreview()
                    : _buildPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text('Tap to add receipt photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      );

  Widget _buildPhotoPreview() {
    if (_localPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_localPath!), fit: BoxFit.cover),
            Positioned(
              top: 6, right: 6,
              child: GestureDetector(
                onTap: () { setState(() => _localPath = null); widget.onPhotoSelected?.call(''); },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Remote URL
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(widget.existingPhotoUrl!, fit: BoxFit.cover),
    );
  }

  Future<void> _showSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickAndCompress(source);
  }

  Future<void> _pickAndCompress(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() => _processing = true);
    try {
      final dir = await getTemporaryDirectory();
      final outPath = p.join(dir.path, 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        outPath,
        quality: 75,
        minWidth: 1080,
        minHeight: 1080,
      );

      final finalPath = compressed?.path ?? picked.path;
      setState(() => _localPath = finalPath);
      widget.onPhotoSelected?.call(finalPath);
    } finally {
      setState(() => _processing = false);
    }
  }
}
