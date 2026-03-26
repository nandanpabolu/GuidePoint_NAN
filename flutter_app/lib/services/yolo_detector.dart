import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../screens/astar_pathfinding.dart';

/// One YOLO detection after NMS (Ultralytics YOLOv8 TFLite export).
class YoloDetection {
  final int classIndex;
  final double score;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const YoloDetection({
    required this.classIndex,
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  String get className =>
      classIndex >= 0 && classIndex < YoloDetector.ultralyticsClassNames.length
          ? YoloDetector.ultralyticsClassNames[classIndex]
          : 'unknown';
}

/// Indoor YOLO model from `models/yolo/best_saved_model/best_float32.tflite` (16 classes).
/// Expects NHWC float input [1, 640, 640, 3] with values in \[\0,1\], and a raw detect head.
class YoloDetector {
  static const String defaultAssetPath = 'assets/models/yolo_detector.tflite';
  static const int kSize = 640;

  /// Class order must match `models/yolo/best_saved_model/metadata.yaml`.
  static const List<String> ultralyticsClassNames = [
    'Board',
    'Chair',
    'Cubicle',
    'Door',
    'Doorway',
    'Fans',
    'Human',
    'Lighting',
    'Outdoors',
    'Pillar',
    'Portrait',
    'Poster',
    'Rug',
    'Table',
    'Window',
    'objects',
  ];

  Interpreter? _interpreter;
  bool _loaded = false;

  /// Pre-allocated buffers (set after load).
  List<List<List<List<double>>>>? _inputTensor;
  List? _outputBuffer;
  bool _inputIsNchw = false;

  bool get isLoaded => _loaded;

  Future<bool> load({String assetPath = defaultAssetPath}) async {
    if (_loaded) return true;
    try {
      final bundlePath =
          assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
      _interpreter = await Interpreter.fromAsset(
        bundlePath,
        options: InterpreterOptions()..threads = 2,
      );

      final inShape = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;

      if (inShape.length != 4 || inShape[0] != 1) {
        throw StateError('Unexpected YOLO input shape $inShape');
      }
      final nhwc = inShape[3] == 3 && inShape[1] == kSize && inShape[2] == kSize;
      final nchw = inShape[1] == 3 && inShape[2] == kSize && inShape[3] == kSize;
      if (!nhwc && !nchw) {
        throw StateError('Expected [1,$kSize,$kSize,3] or [1,3,$kSize,$kSize], got $inShape');
      }
      _inputIsNchw = nchw;

      _inputTensor = _allocateInput4d(inShape, nchw: nchw);
      _outputBuffer = _allocateOutput(outShape);
      _loaded = true;
      return true;
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('YoloDetector load failed: $e\n$st');
        return true;
      }());
      _interpreter?.close();
      _interpreter = null;
      _loaded = false;
      return false;
    }
  }

  List<List<List<List<double>>>> _allocateInput4d(List<int> shape, {required bool nchw}) {
    final n = shape[0];
    if (nchw) {
      return List.generate(
        n,
        (_) => List.generate(
          3,
          (_) => List.generate(
            kSize,
            (_) => List.filled(kSize, 0.0),
          ),
        ),
      );
    }
    return List.generate(
      n,
      (_) => List.generate(
        kSize,
        (_) => List.generate(kSize, (_) => List.filled(3, 0.0)),
      ),
    );
  }

  /// Build nested List matching [1, A, B] output.
  List _allocateOutput(List<int> shape) {
    if (shape.length != 3) {
      throw StateError('Expected rank-3 YOLO output, got $shape');
    }
    final a = shape[1];
    final b = shape[2];
    return List.generate(
      1,
      (_) => List.generate(
        a,
        (_) => List.filled(b, 0.0),
      ),
    );
  }

  /// Run detection on JPEG/PNG bytes from the camera.
  Future<List<YoloDetection>> detect(
    Uint8List imageBytes, {
    double confThreshold = 0.35,
    double iouThreshold = 0.45,
  }) async {
    if (!_loaded || _interpreter == null || _inputTensor == null || _outputBuffer == null) {
      return [];
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return [];

    final letter = _letterbox(decoded);
    _fillInputTensor(letter.image);
    _interpreter!.run(_inputTensor!, _outputBuffer!);

    final parse = _parseHead(_outputBuffer![0] as List);
    final dets = _decodeBoxes(
      parse.features,
      parse.numBoxes,
      parse.layout,
      confThreshold,
    );
    return _nms(dets, iouThreshold);
  }

  /// True if vision supports anchoring at [node] for the expected next waypoint.
  bool matchesWaypoint(
    List<YoloDetection> detections,
    Node node, {
    double minConfidence = 0.38,
  }) {
    if (detections.isEmpty) return false;
    final wanted = node.yoloLandmarks.map((e) => e.toLowerCase()).toSet();
    if (wanted.isEmpty) {
      // No map config: require a clear object (typical indoor clutter).
      return detections.any((d) => d.score >= minConfidence + 0.12);
    }
    for (final d in detections) {
      if (d.score < minConfidence) continue;
      if (wanted.contains(d.className.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
    _inputTensor = null;
    _outputBuffer = null;
  }

  // --- preprocessing ---

  ({img.Image image, double ratio, double padX, double padY}) _letterbox(img.Image src) {
    final w = src.width;
    final h = src.height;
    final ratio = min(kSize / w, kSize / h);
    final nw = max(1, (w * ratio).round());
    final nh = max(1, (h * ratio).round());
    final resized = img.copyResize(src, width: nw, height: nh, interpolation: img.Interpolation.linear);
    final canvas = img.Image(width: kSize, height: kSize);
    final gray = img.ColorRgb8(114, 114, 114);
    img.fill(canvas, color: gray);
    final dx = ((kSize - nw) / 2).round();
    final dy = ((kSize - nh) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
    return (image: canvas, ratio: ratio, padX: dx.toDouble(), padY: dy.toDouble());
  }

  void _fillInputTensor(img.Image im) {
    final input = _inputTensor!;
    for (var y = 0; y < kSize; y++) {
      for (var x = 0; x < kSize; x++) {
        final p = im.getPixel(x, y);
        final r = p.r / 255.0;
        final g = p.g / 255.0;
        final b = p.b / 255.0;
        if (_inputIsNchw) {
          input[0][0][y][x] = r;
          input[0][1][y][x] = g;
          input[0][2][y][x] = b;
        } else {
          input[0][y][x][0] = r;
          input[0][y][x][1] = g;
          input[0][y][x][2] = b;
        }
      }
    }
  }

  // --- decode Ultralytics YOLOv8 TFLite head [1, 4+nc, N] or [1, N, 4+nc] ---

  ({int features, int numBoxes, _Layout layout}) _parseHead(List grid) {
    final d1 = grid.length;
    if (d1 == 0) {
      return (features: 0, numBoxes: 0, layout: _layoutFeaturesFirst);
    }
    final firstRow = grid[0];
    if (firstRow is! List) {
      throw StateError('Unexpected YOLO output structure');
    }
    final d2 = firstRow.length;

    final nc = ultralyticsClassNames.length;
    final feat = 4 + nc;

    if (d1 == feat && d2 > feat) {
      return (features: feat, numBoxes: d2, layout: _layoutFeaturesFirst);
    }
    if (d2 == feat && d1 > feat) {
      return (features: feat, numBoxes: d1, layout: _layoutBoxesFirst);
    }
    // Fallback: pick the dimension that equals 4+nc
    if (d1 == feat) {
      return (features: feat, numBoxes: d2, layout: _layoutFeaturesFirst);
    }
    if (d2 == feat) {
      return (features: feat, numBoxes: d1, layout: _layoutBoxesFirst);
    }
    assert(() {
      // ignore: avoid_print
      print('YoloDetector: could not infer layout d1=$d1 d2=$d2 expected feat=$feat');
      return true;
    }());
    return (features: feat, numBoxes: min(d1, d2), layout: _layoutFeaturesFirst);
  }

  double _cell(int f, int i, int features, int numBoxes, _Layout layout, List grid) {
    if (layout == _layoutFeaturesFirst) {
      return (grid[f][i] as num).toDouble();
    }
    return (grid[i][f] as num).toDouble();
  }

  List<YoloDetection> _decodeBoxes(
    int features,
    int numBoxes,
    _Layout layout,
    double confThreshold,
  ) {
    final nc = ultralyticsClassNames.length;
    if (features != 4 + nc) return [];

    final out = <YoloDetection>[];
    final grid = (_outputBuffer![0] as List);

    double sigmoid(double x) => 1.0 / (1.0 + exp(-x.clamp(-24.0, 24.0)));

    for (var i = 0; i < numBoxes; i++) {
      double cx = _cell(0, i, features, numBoxes, layout, grid);
      double cy = _cell(1, i, features, numBoxes, layout, grid);
      double w = _cell(2, i, features, numBoxes, layout, grid);
      double h = _cell(3, i, features, numBoxes, layout, grid);

      // Heuristic: if coords look like normalized \[\0,1\], scale to 640.
      if (cx <= 1.0 && cy <= 1.0 && w <= 1.0 && h <= 1.0) {
        cx *= kSize;
        cy *= kSize;
        w *= kSize;
        h *= kSize;
      }

      var bestScore = 0.0;
      var bestCls = 0;
      for (var c = 0; c < nc; c++) {
        final raw = _cell(4 + c, i, features, numBoxes, layout, grid);
        final s = raw > 1.0 ? raw : sigmoid(raw);
        if (s > bestScore) {
          bestScore = s;
          bestCls = c;
        }
      }
      if (bestScore < confThreshold) continue;

      final halfW = w / 2;
      final halfH = h / 2;
      var x1 = cx - halfW;
      var y1 = cy - halfH;
      var x2 = cx + halfW;
      var y2 = cy + halfH;
      x1 = x1.clamp(0.0, kSize.toDouble());
      y1 = y1.clamp(0.0, kSize.toDouble());
      x2 = x2.clamp(0.0, kSize.toDouble());
      y2 = y2.clamp(0.0, kSize.toDouble());

      out.add(YoloDetection(
        classIndex: bestCls,
        score: bestScore.clamp(0.0, 1.0),
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      ));
    }
    return out;
  }

  List<YoloDetection> _nms(List<YoloDetection> boxes, double iouThreshold) {
    if (boxes.length <= 1) return boxes;
    boxes.sort((a, b) => b.score.compareTo(a.score));
    final kept = <YoloDetection>[];
    for (final b in boxes) {
      var shouldKeep = true;
      for (final k in kept) {
        if (_iou(b, k) >= iouThreshold) {
          shouldKeep = false;
          break;
        }
      }
      if (shouldKeep) kept.add(b);
    }
    return kept;
  }

  double _iou(YoloDetection a, YoloDetection b) {
    final ix1 = max(a.x1, b.x1);
    final iy1 = max(a.y1, b.y1);
    final ix2 = min(a.x2, b.x2);
    final iy2 = min(a.y2, b.y2);
    final iw = max(0.0, ix2 - ix1);
    final ih = max(0.0, iy2 - iy1);
    final inter = iw * ih;
    final areaA = max(0.0, a.x2 - a.x1) * max(0.0, a.y2 - a.y1);
    final areaB = max(0.0, b.x2 - b.x1) * max(0.0, b.y2 - b.y1);
    final union = areaA + areaB - inter;
    if (union <= 0) return 0;
    return inter / union;
  }
}

typedef _Layout = int;
const _layoutFeaturesFirst = 0;
const _layoutBoxesFirst = 1;
