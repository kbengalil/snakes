import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'services/detection_service.dart';
import 'services/wifi_watcher_service.dart';
import 'screens/login_screen.dart';
import 'screens/detections_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Top-level FCM background handler — runs in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _saveDetectionFromMessage(message);
}

/// Download and save the annotated image from a detection FCM message.
Future<void> _saveDetectionFromMessage(RemoteMessage message) async {
  final imageUrl = message.data['image_url'];
  if (imageUrl == null || (imageUrl as String).isEmpty) return;
  try {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) return;
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    await detectionsDir.create(recursive: true);
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    final name =
        'detection_${now.year}${p(now.month)}${p(now.day)}_${p(now.hour)}${p(now.minute)}${p(now.second)}.jpg';
    await File('${detectionsDir.path}/$name').writeAsBytes(response.bodyBytes);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await WifiWatcherService.configure();

  // Save image when FCM arrives while app is in foreground
  FirebaseMessaging.onMessage.listen(_saveDetectionFromMessage);

  // Background service → main isolate: start detection automatically
  WifiWatcherService.onStartDetection.listen((data) async {
    final ip = data?['ip'] as String?;
    if (ip == null || DetectionService.instance.isRunning) return;
    const storage = FlutterSecureStorage();
    final user  = await storage.read(key: 'cam_user_$ip');
    final pass  = await storage.read(key: 'cam_pass_$ip');
    final port  = int.tryParse(await storage.read(key: 'cam_port_$ip') ?? '554') ?? 554;
    final rtsp  = await storage.read(key: 'cam_rtsp_$ip') ?? '/stream1';
    if (user == null || pass == null) return;
    await DetectionService.instance.start(
      ip: ip, username: user, password: pass,
      cameraName: ip, port: port, rtspPath: rtsp,
    );
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkNotificationLaunch();
  }

  Future<void> _checkNotificationLaunch() async {
    // Local notification tap (mobile mode)
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DetectionsScreen()),
        );
      });
    }

    // Auto-start detection if WiFi watcher flagged it
    const storage = FlutterSecureStorage();
    final pending = await storage.read(key: 'auto_start_pending');
    if (pending == 'true') {
      await storage.delete(key: 'auto_start_pending');
      final ip   = await storage.read(key: 'cam_last_ip');
      final user = ip != null ? await storage.read(key: 'cam_user_$ip') : null;
      final pass = ip != null ? await storage.read(key: 'cam_pass_$ip') : null;
      if (ip != null && user != null && pass != null && !DetectionService.instance.isRunning) {
        final port = int.tryParse(await storage.read(key: 'cam_port_$ip') ?? '554') ?? 554;
        final rtsp = await storage.read(key: 'cam_rtsp_$ip') ?? '/stream1';
        await DetectionService.instance.start(
          ip: ip, username: user, password: pass,
          cameraName: ip, port: port, rtspPath: rtsp,
        );
      }
    }

    // FCM tap (cloud mode)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const DetectionsScreen()),
      );
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DetectionsScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snakes & Rats',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LoginScreen(),
    );
  }
}
