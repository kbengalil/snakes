import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
// VideoController is owned by DetectionService — do not create or dispose it here
import '../services/detection_service.dart';
import '../services/yolo_detector.dart';
import 'detections_screen.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  VideoController get _controller => DetectionService.instance.videoController!;
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
  bool _showingHome = false;

  @override
  void initState() {
    super.initState();
    final player = DetectionService.instance.player!;

    // If the stream is already running (user came back via Active button),
    // the width/height events won't re-fire — read current state directly.
    final currentW = player.state.width;
    final currentH = player.state.height;
    if (currentW != null && currentW > 0) {
      _videoWidth = currentW.toDouble();
      _videoHeight = (currentH ?? 1080).toDouble();
      _status = 'Watching...';
    }

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
      appBar: _showingHome
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Text(DetectionService.instance.cameraName),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showingHome = true),
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
          // Video widget always stays rendered — required for screenshot() to work
          if (DetectionService.instance.videoController != null)
            Video(controller: _controller, controls: NoVideoControls)
          else
            const ColoredBox(color: Colors.black),
          if (_boxes.isNotEmpty && !_showingHome)
            Positioned.fill(
              child: CustomPaint(
                painter: _BoxPainter(_boxes,
                    videoWidth: _videoWidth, videoHeight: _videoHeight),
              ),
            ),
          if (!_showingHome &&
              (_status == 'Please wait for live stream...' || _status.contains('failed')))
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
          // Home overlay — shown on top of the still-rendering Video widget
          if (_showingHome)
            _HomeOverlay(
              onDismiss: () => setState(() => _showingHome = false),
              onStop: () async {
                await DetectionService.instance.stop();
                if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// HOME OVERLAY — shown over the live stream when user presses "Home page"
// Video widget keeps rendering behind this, so screenshot() keeps working.
// ============================================================================

class _HomeOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Future<void> Function() onStop;

  const _HomeOverlay({required this.onDismiss, required this.onStop});

  @override
  State<_HomeOverlay> createState() => _HomeOverlayState();
}

class _HomeOverlayState extends State<_HomeOverlay> {
  int _detectionCount = 0;
  StreamSubscription? _boxesSub;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _boxesSub = DetectionService.instance.imageSavedStream.listen((_) {
      if (mounted) setState(() => _detectionCount++);
    });
  }

  @override
  void dispose() {
    _boxesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    if (!await detectionsDir.exists()) return;
    final count = detectionsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .length;
    if (mounted) setState(() => _detectionCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/home_bg.png', fit: BoxFit.cover),
        Container(color: Colors.white.withOpacity(0.25)),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Stop button
                    ElevatedButton(
                      onPressed: () async => await widget.onStop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(side: BorderSide(color: Colors.black, width: 2)),
                        padding: const EdgeInsets.all(28),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop, size: 32),
                          SizedBox(height: 4),
                          Text('Stop', style: TextStyle(fontSize: 26)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Active button — dismisses overlay, returns to stream view
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Text('Active',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Alerts triangle
                GestureDetector(
                  onTap: () async {
                    setState(() => _detectionCount = 0);
                    await FlutterLocalNotificationsPlugin().cancelAll();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DetectionsScreen()),
                    );
                  },
                  child: SizedBox(
                    width: 160,
                    height: 140,
                    child: Stack(
                      children: [
                        ClipPath(
                          clipper: _TriangleClipper(),
                          child: Container(color: Colors.white),
                        ),
                        CustomPaint(
                          painter: _TriangleBorderPainter(),
                          child: const SizedBox(width: 160, height: 140),
                        ),
                        Positioned(
                          bottom: 18,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: const [
                              Icon(Icons.warning_amber_rounded, size: 36, color: Colors.red),
                              Text('Alerts',
                                  style: TextStyle(
                                      fontSize: 26,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (_detectionCount > 0)
                          Positioned(
                            top: 4,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Text(
                                '$_detectionCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_TriangleClipper _) => false;
}

class _TriangleBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TriangleBorderPainter _) => false;
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
