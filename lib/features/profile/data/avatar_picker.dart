import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a photo and returns it cropped to a 1:1 square JPEG (adjacent_systems/02 §2.1:
/// "photo library integration with interactive 1:1 circular crop tool"). Null when the
/// user cancels either step. FE-608.
abstract interface class AvatarPicker {
  Future<Uint8List?> pickSquareAvatar();
}

/// [ImagePicker] (photo library) → [ImageCropper] (locked 1:1, circular guide) → bytes.
class DeviceAvatarPicker implements AvatarPicker {
  DeviceAvatarPicker({ImagePicker? picker, ImageCropper? cropper})
      : _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  final ImagePicker _picker;
  final ImageCropper _cropper;

  /// Avatars render at most ~92 logical px; 512 px covers 3x displays with room to spare.
  static const _outputSize = 512;

  @override
  Future<Uint8List?> pickSquareAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048);
    if (picked == null) return null;
    final cropped = await _cropper.cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: _outputSize,
      maxHeight: _outputSize,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop avatar', lockAspectRatio: true, cropStyle: CropStyle.circle),
        IOSUiSettings(
          title: 'Crop avatar',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    return cropped?.readAsBytes();
  }
}

final avatarPickerProvider = Provider<AvatarPicker>((ref) => DeviceAvatarPicker());
