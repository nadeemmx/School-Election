import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      return file?.path;
    } catch (e) {
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      return file?.path;
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasCameraSupport() async {
    try {
      return _picker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return true;
    }
  }

  Future<void> showImagePickerSheet(
    BuildContext context, {
    required void Function(String path) onImageSelected,
  }) async {
    final hasCamera = await hasCameraSupport();

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              if (hasCamera)
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                  ),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Use camera to capture'),
                  onTap: () => Navigator.pop(ctx, true),
                ),
              if (hasCamera)
                const Divider(indent: 72, endIndent: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.green),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick from photo library'),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    if (!context.mounted) return;

    final String? path;
    if (result) {
      path = await pickFromCamera();
    } else {
      path = await pickFromGallery();
    }
    if (path != null && context.mounted) {
      onImageSelected(path);
    }
  }

  static bool isImageFileValid(String? path) {
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    return file.existsSync();
  }
}
