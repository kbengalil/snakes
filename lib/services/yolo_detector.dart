import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectionResult {
  final bool detected;
  final Uint8List annotatedImage;
  DetectionResult({required this.detected, required this.annotatedImage});
}

class YoloDetector {
  static const int inputSize = 320;
  static const int numAnchors = 2100;
  static const double confidenceThreshold = 0.5;

  static const List<String> _classes = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
    'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
    'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
    'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
    'baseball bat', 'baseball glove', 'skateboard', 'surfboard',
    'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon',
    'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
    'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant',
    'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
    'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear',
    'hair drier', 'toothbrush',
  ];

  late Interpreter _interpreter;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/models/yolo11n_float32.tflite');
    _interpreter.allocateTensors();
    debugPrint('YOLO input shape: ${_interpreter.getInputTensor(0).shape}');
    debugPrint('YOLO output shape: ${_interpreter.getOutputTensor(0).shape}');
  }

  DetectionResult detect(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return DetectionResult(detected: false, annotatedImage: imageBytes);

    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final flat = Float32List(inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        flat[idx++] = pixel.r / 255.0;
        flat[idx++] = pixel.g / 255.0;
        flat[idx++] = pixel.b / 255.0;
      }
    }

    final input = [
      List.generate(inputSize, (row) =>
        List.generate(inputSize, (col) {
          final base = (row * inputSize + col) * 3;
          return [flat[base], flat[base + 1], flat[base + 2]];
        }))
    ];

    final output = [
      List.generate(84, (_) => List<double>.filled(numAnchors, 0.0)),
    ];

    _interpreter.run(input, output);

    final detections = output[0];
    final scaleX = image.width / inputSize;
    final scaleY = image.height / inputSize;
    final annotated = image.clone();
    bool anyFound = false;

    for (int i = 0; i < numAnchors; i++) {
      // Find best class score for this anchor
      double maxScore = 0;
      int maxClass = 0;
      for (int c = 4; c < 84; c++) {
        if (detections[c][i] > maxScore) {
          maxScore = detections[c][i];
          maxClass = c - 4;
        }
      }
      if (maxScore < confidenceThreshold) continue;

      anyFound = true;

      // Coordinates are in input image pixel space (0-320)
      final cx = detections[0][i];
      final cy = detections[1][i];
      final w = detections[2][i];
      final h = detections[3][i];

      final x1 = ((cx - w / 2) * scaleX).round().clamp(0, image.width - 1);
      final y1 = ((cy - h / 2) * scaleY).round().clamp(0, image.height - 1);
      final x2 = ((cx + w / 2) * scaleX).round().clamp(0, image.width - 1);
      final y2 = ((cy + h / 2) * scaleY).round().clamp(0, image.height - 1);

      final red = img.ColorRgb8(255, 0, 0);

      img.drawRect(annotated, x1: x1, y1: y1, x2: x2, y2: y2, color: red, thickness: 3);

      final label = maxClass < _classes.length
          ? '${_classes[maxClass]} ${(maxScore * 100).toStringAsFixed(0)}%'
          : 'class$maxClass ${(maxScore * 100).toStringAsFixed(0)}%';

      img.drawString(
        annotated,
        label,
        font: img.arial14,
        x: x1,
        y: (y1 - 16).clamp(0, image.height - 1),
        color: red,
      );
    }

    return DetectionResult(
      detected: anyFound,
      annotatedImage: Uint8List.fromList(img.encodeJpg(annotated)),
    );
  }

  void dispose() {
    _interpreter.close();
  }
}
