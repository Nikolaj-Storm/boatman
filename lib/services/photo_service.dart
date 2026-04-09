import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:boatman/services/ai_service.dart';

/// Handles photo capture, storage, and visual analysis for repair assistance.
///
/// Photos are stored locally on-device. When a vision model (Qwen3-VL + mmproj)
/// is available, uses NobodyWho for on-device image analysis.
class PhotoService {
  static const _uuid = Uuid();
  final _picker = ImagePicker();

  /// Take a photo with the camera
  Future<CapturedPhoto?> takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return null;
    return _savePhoto(image);
  }

  /// Pick a photo from the gallery
  Future<CapturedPhoto?> pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return null;
    return _savePhoto(image);
  }

  /// Save the image locally
  Future<CapturedPhoto> _savePhoto(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'chat_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final photoId = _uuid.v4();
    final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
    final savedPath = p.join(photosDir.path, '$photoId$ext');
    await File(image.path).copy(savedPath);

    return CapturedPhoto(
      id: photoId,
      path: savedPath,
      timestamp: DateTime.now(),
    );
  }

  /// Analyze an image using NobodyWho vision model
  /// Returns the analysis text, or null if vision is not available
  Future<String?> analyzeWithVision({
    required String imagePath,
    required AiService aiService,
    String question = '',
    String? visionModelPath,
    String? mmprojPath,
  }) async {
    if (visionModelPath == null || mmprojPath == null) return null;

    try {
      final response = await aiService.askAboutPhoto(
        imagePath: imagePath,
        question: question,
        visionModelPath: visionModelPath,
        mmprojPath: mmprojPath,
      );
      return response;
    } catch (e) {
      return 'Vision analysis failed: $e';
    }
  }

  /// Build context string for the AI prompt when vision is not available
  static String buildPhotoPromptContext({bool visionAvailable = false, String? visionAnalysis}) {
    final buffer = StringBuffer();
    buffer.writeln('[USER ATTACHED PHOTO]');
    if (visionAvailable && visionAnalysis != null) {
      buffer.writeln('Visual analysis: $visionAnalysis');
    } else {
      buffer.writeln('Photo attached but vision model not loaded.');
      buffer.writeln('Ask the user to describe what they see in the photo.');
      buffer.writeln('Guide them through visual identification:');
      buffer.writeln('- What part/component is shown?');
      buffer.writeln('- What does the damage/problem look like?');
      buffer.writeln('- What color is the fluid/residue/corrosion?');
      buffer.writeln('- Where on the boat is this located?');
    }
    return buffer.toString();
  }
}

class CapturedPhoto {
  final String id;
  final String path;
  final DateTime timestamp;

  const CapturedPhoto({
    required this.id,
    required this.path,
    required this.timestamp,
  });
}
