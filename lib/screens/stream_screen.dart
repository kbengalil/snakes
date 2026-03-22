import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../services/yolo_detector.dart';
import '../services/cloud_detection_service.dart';
import '../services/monitoring_service.dart';
import 'detections_screen.dart';

class StreamScreen extends StatefulWidget {
  final String cameraName;
  final String ip;
  final String username;
  final String password;

  const StreamScreen({
    super.key,
    required this.cameraName,
    required this.ip,
    required this.username,
    required this.password,
  });

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late final Player _player;
  late final VideoController _controller;
  final YoloDetector _detector = YoloDetector();
  final CloudDetectionService _cloudService = CloudDetectionService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  bool _cloudMode = false;
  int _frameCount = 0;
  bool _detecting = false;
  String _status = 'Starting...';
  DateTime? _lastNotification;
  List<DetectionBox> _boxes = [];

  // Actual video dimensions from media_kit — needed for letterbox calculation
  double _videoWidth = 1920;
  double _videoHeight = 1080;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;

  String get _rtspUrl {
    final u = Uri.encodeComponent(widget.username);
    final p = Uri.encodeComponent(widget.password);
    return 'rtsp://$u:$p@${widget.ip}:554/stream1';
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // Track video dimensions so painter can calculate letterbox rect
    _widthSub = _player.stream.width.listen((w) {
      if (w != null && w > 0 && mounted) setState(() => _videoWidth = w.toDouble());
    });
    _heightSub = _player.stream.height.listen((h) {
      if (h != null && h > 0 && mounted) setState(() => _videoHeight = h.toDouble());
    });

    _initNotifications();
    _initDetector();
    _startStream();
    startMonitoring();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetectionsScreen()),
          );
        }
      },
    );
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _initDetector() async {
    try {
      await _detector.initialize();
      setState(() => _status = 'Watching...');
      Timer.periodic(const Duration(milliseconds: 500), _onTick);
    } catch (e) {
      setState(() => _status = 'Model error: $e');
    }
  }

  Future<void> _startStream() async {
    try {
      final socket = await Socket.connect(widget.ip, 554, timeout: const Duration(seconds: 3));
      socket.destroy();
    } catch (_) {}
    await _player.open(Media(_rtspUrl));
  }

  Future<void> _onTick(Timer timer) async {
    if (!mounted) {
      timer.cancel();
      return;
    }
    _frameCount++;
    if (_frameCount % 10 != 0) return;
    if (_detecting) return;

    _detecting = true;
    try {
      final bytes = await _player.screenshot();
      if (bytes == null) return;

      if (_cloudMode) {
        if (mounted) setState(() => _status = 'Sending to cloud...');
        final annotated = await _cloudService.detectFrame(bytes);
        if (!mounted) return;
        if (annotated != null) {
          setState(() => _status = 'Detected!');
          await _sendNotification(bytes);
        } else {
          setState(() => _status = 'Watching...');
        }
      } else {
        final result = await _detector.detect(bytes);
        if (!mounted) return;
        if (result.detected) {
          setState(() {
            _status = 'Detected!';
            _boxes = result.boxes;
          });
          await _sendNotification(bytes);
        } else {
          setState(() {
            _status = 'Watching...';
            _boxes = [];
          });
        }
      }
    } finally {
      _detecting = false;
    }
  }

  Future<String> _saveImage(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    await detectionsDir.create(recursive: true);
    final now = DateTime.now();
    final name = 'detection_'
        '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.jpg';
    final file = File('${detectionsDir.path}/$name');

    // Draw bboxes onto the image before saving
    final annotated = await Future(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || _boxes.isEmpty) return bytes;
      for (final box in _boxes) {
        final x1 = ((box.cx - box.w / 2) * decoded.width).round().clamp(0, decoded.width - 1);
        final y1 = ((box.cy - box.h / 2) * decoded.height).round().clamp(0, decoded.height - 1);
        final x2 = ((box.cx + box.w / 2) * decoded.width).round().clamp(0, decoded.width - 1);
        final y2 = ((box.cy + box.h / 2) * decoded.height).round().clamp(0, decoded.height - 1);
        img.drawRect(decoded, x1: x1, y1: y1, x2: x2, y2: y2,
            color: img.ColorRgb8(255, 0, 0), thickness: 3);
      }
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    });

    await file.writeAsBytes(annotated);
    return file.path;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _sendNotification(Uint8List bytes) async {
    final now = DateTime.now();
    if (_lastNotification != null &&
        now.difference(_lastNotification!) < const Duration(seconds: 10)) {
      return;
    }
    _lastNotification = now;

    final imagePath = await _saveImage(bytes);
    final styleInfo = BigPictureStyleInformation(
      FilePathAndroidBitmap(imagePath),
      hideExpandedLargeIcon: true,
    );

    await _notifications.show(
      0,
      'Detection Alert',
      '${widget.cameraName} detected something',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'detection_channel',
          'Detections',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: styleInfo,
        ),
      ),
      payload: 'detections',
    );
  }

  @override
  void dispose() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    stopMonitoring();
    _detector.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cameraName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  _cloudMode ? 'Cloud' : 'Mobile',
                  style: const TextStyle(fontSize: 12),
                ),
                Switch(
                  value: _cloudMode,
                  onChanged: (val) {
                    setState(() {
                      _cloudMode = val;
                      _status = val ? 'Cloud mode active' : 'Watching...';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _controller,
            controls: NoVideoControls,
          ),
          if (_boxes.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: _BoxPainter(
                  _boxes,
                  videoWidth: _videoWidth,
                  videoHeight: _videoHeight,
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _status.contains('Detected') ? Colors.red : Colors.green,
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

    Rect videoRect;
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

    final labelBg = Paint()..color = Colors.black54;

    const labelStyle = TextStyle(
      color: Colors.red,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

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

      final labelX = left.clamp(videoRect.left, videoRect.right - tp.width);
      final labelY = (top - tp.height - 2).clamp(videoRect.top, videoRect.bottom - tp.height);

      canvas.drawRect(
        Rect.fromLTWH(labelX - 2, labelY - 1, tp.width + 4, tp.height + 2),
        labelBg,
      );
      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.boxes != boxes ||
      old.videoWidth != videoWidth ||
      old.videoHeight != videoHeight;
}
