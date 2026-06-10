import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gallery picks with Android retries + optional [file_picker] fallback.
class PrescriptionImagePicker {
  PrescriptionImagePicker._();

  static final ImagePicker _picker = ImagePicker();

  static void _setAndroidPhotoPicker(bool enabled) {
    if (kIsWeb || !Platform.isAndroid) return;
    final impl = ImagePickerPlatform.instance;
    if (impl is ImagePickerAndroid) {
      impl.useAndroidPhotoPicker = enabled;
    }
  }

  static Future<void> _ensureGalleryAccess() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return;

    final storage = await Permission.storage.request();
    if (!storage.isGranted && !photos.isGranted && !photos.isLimited) {
      throw PlatformException(
        code: 'photo_access_denied',
        message: 'Photo library access is required to choose an image.',
      );
    }
  }

  static Future<File?> pickFromGallery({
    double maxWidth = 1920,
    double maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    await _ensureGalleryAccess();

    PlatformException? lastUriError;

    if (!kIsWeb && Platform.isAndroid) {
      for (final usePhotoPicker in [true, false]) {
        _setAndroidPhotoPicker(usePhotoPicker);
        try {
          final file = await _pickWithImagePicker(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            imageQuality: imageQuality,
          );
          if (file != null) return file;
          return null;
        } on PlatformException catch (e) {
          if (e.code == 'photo_access_denied') rethrow;
          if (e.code == 'no_valid_image_uri') {
            lastUriError = e;
            continue;
          }
          rethrow;
        }
      }
    } else {
      try {
        final file = await _pickWithImagePicker(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
        );
        if (file != null) return file;
        return null;
      } on PlatformException catch (e) {
        if (e.code == 'photo_access_denied') rethrow;
        if (e.code != 'no_valid_image_uri') rethrow;
        lastUriError = e;
      }
    }

    try {
      final fallback = await _pickFromGalleryFallback();
      if (fallback != null) return fallback;
    } on MissingPluginException {
      // Hot restart without native rebuild — ignore and use message below.
    }

    throw lastUriError ??
        PlatformException(
          code: 'gallery_pick_failed',
          message:
              'Could not read the selected image. Try Camera or fully restart the app.',
        );
  }

  static Future<File?> _pickWithImagePicker({
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return _persistPickedFile(picked);
  }

  static Future<File?> _persistPickedFile(XFile picked) async {
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final ext =
            _extensionFromName(picked.name) ?? _extensionFromPath(picked.path);
        final out = File(
          '${dir.path}/rx_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await out.writeAsBytes(bytes, flush: true);
        return out;
      }
    } catch (_) {}

    final path = picked.path;
    if (path.isNotEmpty) {
      return File(path);
    }
    return null;
  }

  static Future<File?> _pickFromGalleryFallback() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      final dir = await getTemporaryDirectory();
      final ext = _extensionFromName(picked.name) ?? 'jpg';
      final out = File(
        '${dir.path}/rx_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await out.writeAsBytes(picked.bytes!, flush: true);
      return out;
    }

    final path = picked.path;
    if (path != null && path.isNotEmpty) {
      return File(path);
    }
    return null;
  }

  static String _extensionFromPath(String path) {
    return _extensionFromName(path.split('/').last) ?? 'jpg';
  }

  static String? _extensionFromName(String? name) {
    if (name == null || !name.contains('.')) return null;
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png') return ext;
    return ext.isEmpty ? null : ext;
  }

  static Future<File?> pickFromCamera({
    double maxWidth = 1920,
    double maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return _persistPickedFile(picked);
  }
}
