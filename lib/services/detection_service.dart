import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'yolo_detector.dart';
import 'monitoring_service.dart';

/// Singleton that owns the Player, YoloDetector, and detection loop.
/// Runs independently of any screen — survives navigation.
class DetectionService {
  DetectionService._();
  static final DetectionService instance = DetectionService._();

  Player? _player;
  YoloDetector? _detector;
  Timer? _timer;
  bool _detecting = false;
  bool _running = false;

  String _cameraName = '';
  String _ip = '';
  static const double _assumedFps = 25.0;
  int detectEveryNFrames = 10;

  DateTime? _lastNotification;
  final _notifications = FlutterLocalNotificationsPlugin();

  // Screens subscribe to this to get live bbox updates
  final _boxesController = StreamController<List<DetectionBox>>.broadcast();
  Stream<List<DetectionBox>> get boxesStream => _boxesController.stream;

  Player? get player => _player;
  bool get isRunning => _running;
  String get cameraName => _cameraName;
  String get ip => _ip;

  Future<void> start({
    required String ip,
    required String username,
    required String password,
    required String cameraName,
    int port = 554,
    String rtspPath = '/stream1',
  }) async {
    await stop();

    _ip = ip;
    _cameraName = cameraName;
    _running = true;

    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _detector = YoloDetector();
    await _detector!.initialize();

    _player = Player();
    final u = Uri.encodeComponent(username);
    final p = Uri.encodeComponent(password);
    await _player!.open(Media('rtsp://$u:$p@$ip:$port$rtspPath'));

    // Remember this camera so the WiFi watcher can reconnect automatically
    const storage = FlutterSecureStorage();
    await storage.write(key: 'cam_last_ip', value: ip);

    startMonitoring();
    _restartTimer();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    stopMonitoring();
    _player?.dispose();
    _player = null;
    // Wait for any in-flight compute() to finish before closing interpreter
    while (_detecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _detector?.dispose();
    _detector = null;
    _boxesController.add([]);
  }

  void updateFrameInterval(int n) {
    detectEveryNFrames = n;
    if (_running) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final ms = (detectEveryNFrames / _assumedFps * 1000).round().clamp(100, 30000);
    _timer = Timer.periodic(Duration(milliseconds: ms), _onTick);
  }

  Future<void> _onTick(Timer timer) async {
    if (!_running) { timer.cancel(); return; }
    if (_detecting) return;

    _detecting = true;
    try {
      final bytes = await _player?.screenshot()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (!_running || bytes == null) return;

      final result = await _detector!.detect(bytes);
      if (!_running) return;

      _boxesController.add(result.boxes);

      if (result.detected) {
        await _sendNotification(bytes, result.boxes);
      }
    } catch (_) {
      // ignore errors from player disposed or network issues
    } finally {
      _detecting = false;
    }
  }

  Future<void> _sendNotification(Uint8List bytes, List<DetectionBox> boxes) async {
    final now = DateTime.now();
    if (_lastNotification != null &&
        now.difference(_lastNotification!) < const Duration(seconds: 10)) return;
    _lastNotification = now;

    final imagePath = await _saveImage(bytes, boxes);

    await _notifications.show(
      0,
      'Detection Alert',
      '$_cameraName detected something',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'detection_channel',
          'Detections',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            hideExpandedLargeIcon: true,
          ),
        ),
      ),
    );
  }

  Future<String> _saveImage(Uint8List bytes, List<DetectionBox> boxes) async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    await detectionsDir.create(recursive: true);
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final name = 'detection_'
        '${now.year}${pad(now.month)}${pad(now.day)}_'
        '${pad(now.hour)}${pad(now.minute)}${pad(now.second)}.jpg';
    final file = File('${detectionsDir.path}/$name');

    final annotated = await Future(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || boxes.isEmpty) return bytes;
      for (final box in boxes) {
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
}
