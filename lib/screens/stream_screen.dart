import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/detection_service.dart';
import '../services/yolo_detector.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late final VideoController _controller;
  StreamSubscription? _boxesSub;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;
  StreamSubscription? _errorSub;
  Timer? _connectTimer;

  List<DetectionBox> _boxes = [];
  double _videoWidth = 1920;
  double _videoHeight = 1080;
  String _status = 'Please wait for live stream...';
  bool _connectionFailed = false;

  @override
  void initState() {
    super.initState();
    final player = DetectionService.instance.player!;
    _controller = VideoController(player);

    _widthSub = player.stream.width.listen((w) {
      if (w != null && w > 0 && mounted) {
        setState(() {
          _videoWidth = w.toDouble();
          if (_status == 'Please wait for live stream...' || _status == 'Connecting...') {
            _status = 'Watching...';
          }
        });
      }
    });
    _heightSub = player.stream.height.listen((h) {
      if (h != null && h > 0 && mounted) setState(() => _videoHeight = h.toDouble());
    });

    _boxesSub = DetectionService.instance.boxesStream.listen((boxes) {
      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _status = boxes.isNotEmpty ? 'Detected!' : 'Watching...';
      });
    });

    // Catch player errors (e.g. auth failure, bad URL)
    _errorSub = player.stream.error.listen((err) {
      if (err.isNotEmpty && mounted && !_connectionFailed) {
        _onConnectionFailed();
      }
    });

    // Fallback: if still connecting after 12s, assume failure
    _connectTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _status == 'Connecting...' && !_connectionFailed) {
        _onConnectionFailed();
      }
    });
  }

  Future<void> _onConnectionFailed() async {
    if (_connectionFailed) return;
    _connectionFailed = true;
    setState(() => _status = 'Connection failed');

    // Clear saved credentials so user is prompted again next time
    final ip = DetectionService.instance.ip;
    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    await storage.delete(key: 'cam_user_$ip');
    await storage.delete(key: 'cam_pass_$ip');

    await DetectionService.instance.stop();

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Connection Failed'),
        content: const Text(
            'Could not connect to the camera.\nPlease check your username and password.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context); // back to camera list
  }

  @override
  void dispose() {
    _boxesSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _errorSub?.cancel();
    _connectTimer?.cancel();
    // Do NOT dispose the player — DetectionService owns it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DetectionService.instance.cameraName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
              ),
              child: const Text('Home page'),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _controller, controls: NoVideoControls),
          if (_boxes.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: _BoxPainter(_boxes,
                    videoWidth: _videoWidth, videoHeight: _videoHeight),
              ),
            ),
          if (_status == 'Please wait for live stream...' || _status.contains('failed'))
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: _status.contains('Detected')
                        ? Colors.red
                        : _status.contains('failed') || _status.contains('Please wait')
                            ? Colors.orange
                            : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOUNDING BOX PAINTER
// ============================================================================

class _BoxPainter extends CustomPainter {
  final List<DetectionBox> boxes;
  final double videoWidth;
  final double videoHeight;

  _BoxPainter(this.boxes, {required this.videoWidth, required this.videoHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final videoAspect = videoWidth / videoHeight;
    final canvasAspect = size.width / size.height;

    final Rect videoRect;
    if (videoAspect > canvasAspect) {
      final h = size.width / videoAspect;
      videoRect = Rect.fromLTWH(0, (size.height - h) / 2, size.width, h);
    } else {
      final w = size.height * videoAspect;
      videoRect = Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
    }

    final boxPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const labelStyle = TextStyle(
        color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold);

    for (final box in boxes) {
      final left   = videoRect.left + (box.cx - box.w / 2) * videoRect.width;
      final top    = videoRect.top  + (box.cy - box.h / 2) * videoRect.height;
      final right  = videoRect.left + (box.cx + box.w / 2) * videoRect.width;
      final bottom = videoRect.top  + (box.cy + box.h / 2) * videoRect.height;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), boxPaint);

      final tp = TextPainter(
        text: TextSpan(text: box.label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final lx = left.clamp(videoRect.left, videoRect.right - tp.width);
      final ly = (top - tp.height - 2).clamp(videoRect.top, videoRect.bottom - tp.height);

      canvas.drawRect(
        Rect.fromLTWH(lx - 2, ly - 1, tp.width + 4, tp.height + 2),
        Paint()..color = Colors.black54,
      );
      tp.paint(canvas, Offset(lx, ly));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.boxes != boxes ||
      old.videoWidth != videoWidth ||
      old.videoHeight != videoHeight;
}
