import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudDetectionService {
  static const String _functionUrl =
      'https://detect-frame-bmscaobpnq-uc.a.run.app';

  /// Sends a JPEG frame to the Cloud Function.
  /// Returns annotated image bytes if something was detected, null if nothing found.
  Future<Uint8List?> detectFrame(Uint8List imageBytes) async {
    try {
      final response = await http
          .post(
            Uri.parse(_functionUrl),
            headers: {'Content-Type': 'image/jpeg'},
            body: imageBytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 204) {
        return null; // No detection
      } else {
        debugPrint('CloudDetectionService error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('CloudDetectionService exception: $e');
      return null;
    }
  }
}
