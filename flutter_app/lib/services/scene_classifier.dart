import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of scene classification: waypoint id and confidence.
class SceneClassificationResult {
  final String locationId;
  final double confidence;

  const SceneClassificationResult({
    required this.locationId,
    required this.confidence,
  });
}

/// On-device Scene CNN for waypoint confirmation (AnchorStep).
/// Loads TFLite model from assets; expects model input [1, height, width, 3] and output [1, numClasses].
/// [labelIds] must match the order of model output indices (e.g. [main_entrance, junction_1, ...]).
class SceneClassifier {
  static const String _defaultAsset = 'assets/models/scene_classifier.tflite';
  static const int _inputSize = 224; // MobileNetV2 typical input

  Interpreter? _interpreter;
  final List<String> labelIds;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// [labelIds] must match the order of the model's output logits (recommended: sorted node ids).
  SceneClassifier({
    List<String>? labelIds,
    this.assetPath = _defaultAsset,
  }) : labelIds = labelIds ?? [];

  final String assetPath;

  /// Load the TFLite model from assets. Call once before [predict].
  Future<bool> load() async {
    if (_isLoaded) return true;
    try {
      final bundlePath =
          assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
      _interpreter = await Interpreter.fromAsset(
        bundlePath,
        options: InterpreterOptions()..threads = 2,
      );
      _isLoaded = true;
      return true;
    } catch (e) {
      // Model file may not exist yet (Phase 1.1–1.2 pending)
      assert(() {
        // ignore: avoid_print
        print('SceneClassifier load failed: $e');
        return true;
      }());
      return false;
    }
  }

  /// Preprocess image bytes to input tensor [1, H, W, 3] normalized 0..1.
  List<List<List<List<double>>>> _preprocess(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('SceneClassifier: failed to decode image');

    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [
              (p.r.toDouble() / 255.0),
              (p.g.toDouble() / 255.0),
              (p.b.toDouble() / 255.0),
            ];
          },
        ),
      ),
    );
    return input;
  }

  /// Run inference. Returns (locationId, confidence) or null if not loaded or inference fails.
  /// [imageBytes] should be JPEG or PNG bytes.
  Future<SceneClassificationResult?> predict(Uint8List imageBytes) async {
    if (!_isLoaded || _interpreter == null || labelIds.isEmpty) return null;

    try {
      final input = _preprocess(imageBytes);
      final numClasses = _interpreter!.getOutputTensor(0).shape.last;
      final output = List.generate(1, (_) => List.filled(numClasses, 0.0));

      _interpreter!.run(input, output);

      final raw = (output[0] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      var scores = raw;
      final maxRaw = raw.isEmpty ? 0.0 : raw.reduce((a, b) => a > b ? a : b);
      if (maxRaw > 1.05 || raw.any((s) => s < 0)) {
        double sum = 0;
        scores = raw.map((s) {
          final v = exp(s.clamp(-40.0, 40.0));
          sum += v;
          return v;
        }).map((v) => sum > 0 ? v / sum : 0.0).toList();
      }

      int maxIdx = 0;
      double maxScore = 0.0;
      for (int i = 0; i < scores.length; i++) {
        final s = scores[i];
        if (s > maxScore) {
          maxScore = s;
          maxIdx = i;
        }
      }

      if (maxIdx >= labelIds.length) return null;
      return SceneClassificationResult(
        locationId: labelIds[maxIdx],
        confidence: maxScore.clamp(0.0, 1.0),
      );
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('SceneClassifier predict error: $e');
        return true;
      }());
      return null;
    }
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
