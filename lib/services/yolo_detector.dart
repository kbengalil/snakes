import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// ============================================================================
// DATA TYPES
// ============================================================================

class DetectionBox {
  final double cx;         // center x, normalized 0–1
  final double cy;         // center y, normalized 0–1
  final double w;          // width, normalized 0–1
  final double h;          // height, normalized 0–1
  final double confidence;
  final String label;

  const DetectionBox({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.confidence,
    required this.label,
  });
}

class DetectionResult {
  final List<DetectionBox> boxes;
  bool get detected => boxes.isNotEmpty;

  const DetectionResult({required this.boxes});
}

// Passed to background isolate via compute()
class _InferenceInput {
  final int interpreterAddress;
  final Uint8List imageBytes;
  final double confidenceThreshold;

  const _InferenceInput({
    required this.interpreterAddress,
    required this.imageBytes,
    required this.confidenceThreshold,
  });
}

// ============================================================================
// DETECTOR
// ============================================================================

class YoloDetector {
  static const int inputSize = 320;
  static const int numAnchors = 2100;
  static const double _nmsIouThreshold = 0.45;

  static const List<String> classes = ['Snake'];

  late Interpreter _interpreter;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/models/Best-28-3_float32.tflite');
    _interpreter.allocateTensors();
    debugPrint('YOLO input shape: ${_interpreter.getInputTensor(0).shape}');
    debugPrint('YOLO output shape: ${_interpreter.getOutputTensor(0).shape}');
  }

  /// Runs detection in a background isolate — does not block the UI thread.
  Future<DetectionResult> detect(Uint8List imageBytes, {double confidenceThreshold = 0.5}) {
    return compute(_runInference, _InferenceInput(
      interpreterAddress: _interpreter.address,
      imageBytes: imageBytes,
      confidenceThreshold: confidenceThreshold,
    ));
  }

  void dispose() => _interpreter.close();
}

// ============================================================================
// ISOLATE ENTRY POINT
// ============================================================================

DetectionResult _runInference(_InferenceInput input) {
  // Reconstruct interpreter from address — no model reload needed
  final interpreter = Interpreter.fromAddress(input.interpreterAddress);

  final image = img.decodeImage(input.imageBytes);
  if (image == null) return const DetectionResult(boxes: []);

  final resized = img.copyResize(image, width: YoloDetector.inputSize, height: YoloDetector.inputSize);

  final flat = Float32List(YoloDetector.inputSize * YoloDetector.inputSize * 3);
  int idx = 0;
  for (int y = 0; y < YoloDetector.inputSize; y++) {
    for (int x = 0; x < YoloDetector.inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      flat[idx++] = pixel.r / 255.0;
      flat[idx++] = pixel.g / 255.0;
      flat[idx++] = pixel.b / 255.0;
    }
  }

  final inputTensor = [
    List.generate(YoloDetector.inputSize, (row) =>
      List.generate(YoloDetector.inputSize, (col) {
        final base = (row * YoloDetector.inputSize + col) * 3;
        return [flat[base], flat[base + 1], flat[base + 2]];
      })),
  ];

  final numClasses = YoloDetector.classes.length;
  final output = [
    List.generate(4 + numClasses, (_) => List<double>.filled(YoloDetector.numAnchors, 0.0)),
  ];

  interpreter.run(inputTensor, output);

  return _parseOutput(output[0], input.confidenceThreshold);
}

// ============================================================================
// OUTPUT PARSING + NMS
// ============================================================================

DetectionResult _parseOutput(List<List<double>> output, double confidenceThreshold) {
  final numClasses = YoloDetector.classes.length;
  final candidates = <int>[];
  final bestClass = <int, int>{};
  final bestScore = <int, double>{};

  for (int i = 0; i < YoloDetector.numAnchors; i++) {
    double maxScore = 0;
    int maxClass = 0;
    for (int c = 0; c < numClasses; c++) {
      final score = output[4 + c][i];
      if (score > maxScore) {
        maxScore = score;
        maxClass = c;
      }
    }
    if (maxScore >= confidenceThreshold) {
      candidates.add(i);
      bestClass[i] = maxClass;
      bestScore[i] = maxScore;
    }
  }

  if (candidates.isEmpty) return const DetectionResult(boxes: []);

  candidates.sort((a, b) => bestScore[b]!.compareTo(bestScore[a]!));

  final kept = <int>[];
  final suppressed = <int>{};

  for (final i in candidates) {
    if (suppressed.contains(i)) continue;
    kept.add(i);
    for (final j in candidates) {
      if (j == i || suppressed.contains(j)) continue;
      if (_iou(output, i, j) > 0.45) suppressed.add(j);
    }
  }

  final boxes = kept.map((i) {
    // Model outputs already normalized 0–1 (same as vision_bridge)
    final cx = output[0][i];
    final cy = output[1][i];
    final w  = output[2][i];
    final h  = output[3][i];
    final cls = bestClass[i]!;
    final label = cls < YoloDetector.classes.length
        ? YoloDetector.classes[cls]
        : 'cls$cls';
    return DetectionBox(cx: cx, cy: cy, w: w, h: h, confidence: bestScore[i]!, label: label);
  }).toList();

  return DetectionResult(boxes: boxes);
}

double _iou(List<List<double>> output, int a, int b) {
  final ax1 = output[0][a] - output[2][a] / 2;
  final ay1 = output[1][a] - output[3][a] / 2;
  final ax2 = output[0][a] + output[2][a] / 2;
  final ay2 = output[1][a] + output[3][a] / 2;

  final bx1 = output[0][b] - output[2][b] / 2;
  final by1 = output[1][b] - output[3][b] / 2;
  final bx2 = output[0][b] + output[2][b] / 2;
  final by2 = output[1][b] + output[3][b] / 2;

  final interX1 = max(ax1, bx1);
  final interY1 = max(ay1, by1);
  final interX2 = min(ax2, bx2);
  final interY2 = min(ay2, by2);

  final interW = max(0.0, interX2 - interX1);
  final interH = max(0.0, interY2 - interY1);
  final interArea = interW * interH;

  final aArea = (ax2 - ax1) * (ay2 - ay1);
  final bArea = (bx2 - bx1) * (by2 - by1);
  final unionArea = aArea + bArea - interArea;

  return unionArea <= 0 ? 0 : interArea / unionArea;
}
