import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloDetector {
  static const int inputSize = 320;
  static const int numAnchors = 2100;
  static const double confidenceThreshold = 0.5;

  late Interpreter _interpreter;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/models/yolo11n_float32.tflite');
    _interpreter.allocateTensors();
    debugPrint('YOLO input shape: ${_interpreter.getInputTensor(0).shape}');
    debugPrint('YOLO output shape: ${_interpreter.getOutputTensor(0).shape}');
  }

  bool detectPerson(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return false;

    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // Build flat Float32List then reshape to [1, inputSize, inputSize, 3]
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

    // Output shape: [1, 84, 2100]
    final output = [
      List.generate(84, (_) => List<double>.filled(numAnchors, 0.0)),
    ];

    _interpreter.run(input, output);

    // Check each anchor for person (class 0 = index 4)
    final detections = output[0];
    for (int i = 0; i < numAnchors; i++) {
      if (detections[4][i] > confidenceThreshold) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _interpreter.close();
  }
}
