import 'package:image_picker/image_picker.dart';

/// Shared camera capture settings for Attendance, Store Visit, and OSA --
/// this is the third screen to need "take a photo," which is the point at
/// which this project's own convention says to extract it instead of
/// duplicating a fourth time.
///
/// PERFORMANCE: this is also the actual fix for "heavy internet/device
/// load," not just a UI tweak. A raw camera photo is typically 3-8MB;
/// image_picker compresses it at the platform layer (native code, before
/// Dart ever holds the bytes) when given maxWidth/imageQuality, verified
/// against the installed image_picker 1.2.3 source rather than assumed.
/// 1280px wide / 70% JPEG quality is a guess -- good enough to verify a
/// face or a shelf, small enough to not hurt on field mobile data --
/// typically landing in the 150-400KB range instead of several MB.
/// Not measured against real field bandwidth; revisit if photos still
/// feel slow to upload once this runs on a real device.
class PhotoCapture {
  static const _maxWidth = 1280.0;
  static const _imageQuality = 70;

  static Future<XFile?> capture({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      maxWidth: _maxWidth,
      imageQuality: _imageQuality,
    );
  }
}
