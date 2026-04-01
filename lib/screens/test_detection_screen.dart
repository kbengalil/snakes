import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import '../services/yolo_detector.dart';
import 'detections_screen.dart';

class TestDetectionScreen extends StatefulWidget {
  const TestDetectionScreen({super.key});

  @override
  State<TestDetectionScreen> createState() => _TestDetectionScreenState();
}

class _TestDetectionScreenState extends State<TestDetectionScreen> {
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Detection')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science, size: 64, color: Colors.green),
            const SizedBox(height: 24),
            const Text('Pick a file to test snake detection',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Pick Image', style: TextStyle(fontSize: 18)),
                onPressed: _pickImage,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Pick Video', style: TextStyle(fontSize: 18)),
                onPressed: _pickVideo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageTestScreen(filePath: file.path),
      ),
    );
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoTestScreen(filePath: file.path),
      ),
    );
  }
}

// ─── Image Test ──────────────────────────────────────────────────────────────

class _ImageTestScreen extends StatefulWidget {
  final String filePath;
  const _ImageTestScreen({required this.filePath});

  @override
  State<_ImageTestScreen> createState() => _ImageTestScreenState();
}

class _ImageTestScreenState extends State<_ImageTestScreen> {
  Uint8List? _imageBytes;
  List<DetectionBox> _boxes = [];
  double _imgW = 1;
  double _imgH = 1;
  bool _loading = true;
  String _status = 'Running detection...';

  @override
  void initState() {
    super.initState();
    _runDetection();
  }

  Future<void> _runDetection() async {
    final detector = YoloDetector();
    try {
      await detector.initialize();
      final bytes = await File(widget.filePath).readAsBytes();
      final result = await detector.detect(bytes);
      final decoded = img.decodeImage(bytes);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _boxes = result.boxes;
          _imgW = decoded?.width.toDouble() ?? 1;
          _imgH = decoded?.height.toDouble() ?? 1;
          _loading = false;
          _status = result.detected
              ? '${result.boxes.length} detection(s) found!'
              : 'No snakes detected';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _status = 'Error: $e'; });
    } finally {
      detector.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Detection')),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Running YOLO...', style: TextStyle(color: Colors.white)),
              ],
            ))
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_imageBytes != null)
                  InteractiveViewer(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_imageBytes!, fit: BoxFit.contain),
                        if (_boxes.isNotEmpty)
                          CustomPaint(
                            painter: _BoxPainter(_boxes, videoWidth: _imgW, videoHeight: _imgH),
                          ),
                      ],
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
                          color: _status.contains('found') ? Colors.red : Colors.green,
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

// ─── Video Test ───────────────────────────────────────────────────────────────

class _VideoTestScreen extends StatefulWidget {
  final String filePath;
  const _VideoTestScreen({required this.filePath});

  @override
  State<_VideoTestScreen> createState() => _VideoTestScreenState();
}

class _VideoTestScreenState extends State<_VideoTestScreen> {
  late final Player _player;
  late final VideoController _controller;
  YoloDetector? _detector;
  Timer? _timer;
  bool _detecting = false;
  bool _done = false;
  Duration _lastPosition = Duration.zero;

  int _framesScanned = 0;
  int _detectionsFound = 0;
  String _status = 'Loading...';
  DateTime? _lastSaved;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _player = Player();
    _controller = VideoController(_player);
    _detector = YoloDetector();
    await _detector!.initialize();
    await _player.open(Media('file://${widget.filePath}'));
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _status = 'Scanning...');
    _timer = Timer.periodic(const Duration(milliseconds: 1000), _onTick);

    _player.stream.completed.listen((completed) {
      if (completed && _framesScanned > 0) _finish();
    });
  }

  Future<void> _onTick(Timer t) async {
    if (_detecting || _done) return;
    _detecting = true;
    try {
      final bytes = await _player.screenshot()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (!mounted) return;
      if (bytes == null) {
        if (mounted) setState(() => _status = 'screenshot null (frame $_framesScanned)');
        return;
      }
      // skip if position hasn't advanced
      final pos = _player.state.position;
      if (pos == _lastPosition) return;
      _lastPosition = pos;
      _framesScanned++;
      final result = await _detector!.detect(bytes);
      if (result.detected) {
        final now = DateTime.now();
        if (_lastSaved == null || now.difference(_lastSaved!) >= const Duration(seconds: 3)) {
          _lastSaved = now;
          _detectionsFound++;
          await _saveDetection(bytes, result.boxes);
        }
      }
      if (mounted) setState(() => _status = 'frame $_framesScanned | found $_detectionsFound');
    } catch (_) {
    } finally {
      _detecting = false;
    }
  }

  Future<void> _saveDetection(Uint8List bytes, List<DetectionBox> boxes) async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    await detectionsDir.create(recursive: true);

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    for (final box in boxes) {
      final x1 = ((box.cx - box.w / 2) * decoded.width).round().clamp(0, decoded.width - 1);
      final y1 = ((box.cy - box.h / 2) * decoded.height).round().clamp(0, decoded.height - 1);
      final x2 = ((box.cx + box.w / 2) * decoded.width).round().clamp(0, decoded.width - 1);
      final y2 = ((box.cy + box.h / 2) * decoded.height).round().clamp(0, decoded.height - 1);
      img.drawRect(decoded, x1: x1, y1: y1, x2: x2, y2: y2,
          color: img.ColorRgb8(255, 0, 0), thickness: 12);
    }

    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    final name = 'detection_${now.year}${p(now.month)}${p(now.day)}_${p(now.hour)}${p(now.minute)}${p(now.second)}_${now.millisecond}.jpg';
    await File('${detectionsDir.path}/$name')
        .writeAsBytes(img.encodeJpg(decoded, quality: 90));
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _player.dispose();
    _detector?.dispose();
    _detector = null;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Done'),
        content: Text('Scanned $_framesScanned frames\nSaved $_detectionsFound detection(s)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const DetectionsScreen()));
            },
            child: const Text('View detections'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_done) { _player.dispose(); }
    _detector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Scan')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _controller, controls: NoVideoControls),
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Please wait until video ends',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Box Painter (same as StreamScreen) ──────────────────────────────────────

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

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    const labelStyle = TextStyle(
        color: Colors.red, fontSize: 26, fontWeight: FontWeight.bold);

    for (final box in boxes) {
      final left   = videoRect.left + (box.cx - box.w / 2) * videoRect.width;
      final top    = videoRect.top  + (box.cy - box.h / 2) * videoRect.height;
      final right  = videoRect.left + (box.cx + box.w / 2) * videoRect.width;
      final bottom = videoRect.top  + (box.cy + box.h / 2) * videoRect.height;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);

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
