import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloDetector {
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.5;
  static const int personClassIndex = 0;

  late Interpreter _interpreter;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/models/yolo11n_float32.tflite');
  }

  bool detectPerson(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return false;

    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // Build input tensor [1, 640, 640, 3]
    final input = List.generate(
      1, (_) => List.generate(
        inputSize, (y) => List.generate(
          inputSize, (x) => [
            resized.getPixel(x, y).r / 255.0,
            resized.getPixel(x, y).g / 255.0,
            resized.getPixel(x, y).b / 255.0,
          ],
        ),
      ),
    );

    // Output tensor [1, 84, 8400]
    final output = List.generate(1, (_) =>
      List.generate(84, (_) => List.filled(8400, 0.0)),
    );

    _interpreter.run(input, output);

    // Check each of the 8400 anchors for person (class 0)
    final detections = output[0];
    for (int i = 0; i < 8400; i++) {
      final personScore = detections[4][i]; // class 0 score is at index 4
      if (personScore > confidenceThreshold) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _interpreter.close();
  }
}
