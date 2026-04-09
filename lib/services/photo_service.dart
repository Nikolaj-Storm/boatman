import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Handles photo capture, storage, and visual analysis for repair assistance.
///
/// Photos are stored locally on-device. In mock mode, uses keyword-based
/// visual description. When NobodyWho vision models are available, will use
/// on-device multimodal inference (Qwen3-VL or similar).
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
    return _saveAndAnalyze(image);
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
    return _saveAndAnalyze(image);
  }

  /// Save the image locally and generate analysis
  Future<CapturedPhoto> _saveAndAnalyze(XFile image) async {
    // Save to app documents for persistence
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'chat_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final photoId = _uuid.v4();
    final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
    final savedPath = p.join(photosDir.path, '$photoId$ext');
    await File(image.path).copy(savedPath);

    // Analyze the image
    final analysis = await analyzeImage(savedPath);

    return CapturedPhoto(
      id: photoId,
      path: savedPath,
      analysis: analysis,
      timestamp: DateTime.now(),
    );
  }

  /// Analyze an image for marine repair context.
  ///
  /// In mock mode: returns a prompt asking the user to describe what's in the photo.
  /// With NobodyWho vision: will use on-device multimodal model (Qwen3-VL + mmproj).
  Future<ImageAnalysis> analyzeImage(String imagePath) async {
    // TODO: When NobodyWho vision is available (Qwen3-VL + mmproj.gguf):
    // final model = await Model.load(
    //   modelPath: './qwen3vl-2b.gguf',
    //   imageIngestion: './mmproj-qwen3vl.gguf',
    // );
    // final chat = Chat(model: model, systemPrompt: _visionSystemPrompt);
    // final response = await chat.askWithPrompt(Prompt([
    //   TextPart(_visionPrompt),
    //   ImagePart(imagePath),
    // ])).completed();
    // return ImageAnalysis.fromVisionResponse(response);

    // Mock mode: guide the user to describe what they're showing
    return ImageAnalysis(
      description: 'Photo attached for visual inspection.',
      detectedComponents: [],
      suggestedCategory: null,
      confidence: 0.0,
      isVisionAvailable: false,
    );
  }

  // ignore: unused_field
  static const _visionSystemPrompt =
      'You are a marine equipment visual inspector. Analyze photos of boat '
      'components and identify: 1) What the component/part is, 2) Its current '
      'condition (good/worn/damaged/failed), 3) Any visible problems (corrosion, '
      'cracks, leaks, wear, discoloration), 4) What system it belongs to '
      '(engine, electrical, plumbing, rigging, hull). Be specific and practical.';
}

class CapturedPhoto {
  final String id;
  final String path;
  final ImageAnalysis analysis;
  final DateTime timestamp;

  const CapturedPhoto({
    required this.id,
    required this.path,
    required this.analysis,
    required this.timestamp,
  });
}

class ImageAnalysis {
  final String description;
  final List<String> detectedComponents;
  final String? suggestedCategory;
  final double confidence;
  final bool isVisionAvailable;

  const ImageAnalysis({
    required this.description,
    this.detectedComponents = const [],
    this.suggestedCategory,
    this.confidence = 0.0,
    this.isVisionAvailable = false,
  });

  /// Build context string for the AI prompt
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('[USER ATTACHED PHOTO]');
    if (isVisionAvailable) {
      buffer.writeln('Visual analysis: $description');
      if (detectedComponents.isNotEmpty) {
        buffer.writeln('Detected components: ${detectedComponents.join(", ")}');
      }
      if (suggestedCategory != null) {
        buffer.writeln('Category: $suggestedCategory');
      }
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
