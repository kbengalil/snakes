import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Probes a camera's RTSP port to find the correct stream path.
/// Sends a DESCRIBE request with Basic auth for each candidate path.
///
/// Result priority:
///   1. 200 OK + Content-Type: application/sdp  → confirmed correct path
///   2. 401 Unauthorized                         → path may exist, auth format mismatch
///      (first 401 path is returned as fallback if no confirmed path found)
class RtspProber {
  // Common RTSP paths ordered by popularity
  static const _paths = [
    '/stream1',                                    // TP-Link Tapo, generic
    '/stream0',                                    // ProVision ISR, generic main
    '/stream',                                     // Generic
    '/cam/realmonitor?channel=1&subtype=0',        // Dahua / Imou / ProVision (Dahua OEM)
    '/Streaming/Channels/101',                     // Hikvision main
    '/Streaming/Channels/1',                       // Hikvision alt
    '/h264Preview_01_main',                        // Reolink
    '/live/ch0',                                   // Generic / some ProVision
    '/live/main',                                  // Generic
    '/video1',                                     // Generic
    '/ch0_0.264',                                  // Some OEM brands
    '/ch0.h264',                                   // Some ProVision / Longse
    '/live',                                       // Generic
    '/stream2',                                    // Generic sub-stream
    '/1/h264major',                                // Some brands
    '/videoMain',                                  // Some brands
    '/onvif1',                                     // ONVIF-based stream
  ];

  /// Returns the first working RTSP path, or null if none found.
  /// Prefers a path confirmed by 200 OK + SDP; falls back to the first
  /// path that returned 401 (camera wants auth but path is valid).
  static Future<String?> probe(
    String ip,
    String username,
    String password, {
    int port = 554,
    void Function(String path)? onProgress,
  }) async {
    final u = Uri.encodeComponent(username);
    final p = Uri.encodeComponent(password);
    final basicCreds = base64.encode(utf8.encode('$username:$password'));

    String? authFallback; // first path that returned 401 (might still be valid)

    for (final path in _paths) {
      onProgress?.call(path);
      final url = 'rtsp://$u:$p@$ip:$port$path';
      final result = await _tryPath(ip, port, url, basicCreds);
      if (result == _ProbeResult.confirmed) return path;
      if (result == _ProbeResult.authNeeded && authFallback == null) {
        authFallback = path;
      }
    }

    return authFallback;
  }

  static Future<_ProbeResult> _tryPath(
      String ip, int port, String url, String basicCreds) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));

      // Send credentials both in URL and as Basic auth header.
      // URL creds: some cameras parse them from the DESCRIBE URI.
      // Basic header: cameras that ignore URL creds but accept Basic auth.
      final request =
          'DESCRIBE $url RTSP/1.0\r\n'
          'CSeq: 1\r\n'
          'User-Agent: SnakeDetector/1.0\r\n'
          'Accept: application/sdp\r\n'
          'Authorization: Basic $basicCreds\r\n'
          '\r\n';
      socket.write(request);

      final completer = Completer<_ProbeResult>();
      final buffer = StringBuffer();

      socket.listen(
        (data) {
          buffer.write(String.fromCharCodes(data));
          final response = buffer.toString();
          if (response.contains('RTSP/1.0') && !completer.isCompleted) {
            if (response.contains('200 OK') &&
                response.contains('application/sdp')) {
              // Full SDP response — path is confirmed correct
              completer.complete(_ProbeResult.confirmed);
            } else if (response.contains('401')) {
              // Camera wants Digest auth or different scheme — path may exist
              completer.complete(_ProbeResult.authNeeded);
            } else {
              // 404, 415, empty 200 (fake accept-all), etc.
              completer.complete(_ProbeResult.notFound);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(_ProbeResult.notFound);
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(_ProbeResult.notFound);
        },
        cancelOnError: true,
      );

      return await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () => _ProbeResult.notFound);
    } catch (_) {
      return _ProbeResult.notFound;
    } finally {
      socket?.destroy();
    }
  }
}

enum _ProbeResult { confirmed, authNeeded, notFound }
