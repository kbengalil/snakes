import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/yolo_detector.dart';

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
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  int _frameCount = 0;
  bool _detecting = false;
  String _status = 'Starting...';
  DateTime? _lastNotification;

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
    _initNotifications();
    _initDetector();
    _startStream();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
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

      final found = await Future(() => _detector.detectPerson(bytes));
      if (!mounted) return;

      if (found) {
        setState(() => _status = 'Person detected!');
        _sendNotification();
      } else {
        setState(() => _status = 'Watching...');
      }
    } finally {
      _detecting = false;
    }
  }

  Future<void> _sendNotification() async {
    final now = DateTime.now();
    if (_lastNotification != null &&
        now.difference(_lastNotification!) < const Duration(seconds: 10)) {
      return; // cooldown
    }
    _lastNotification = now;

    await _notifications.show(
      0,
      'Person Detected',
      '${widget.cameraName} detected a person',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'detection_channel',
          'Detections',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detector.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cameraName)),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Video(
              controller: _controller,
              controls: NoVideoControls,
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
                    color: _status.contains('detected') ? Colors.red : Colors.green,
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
