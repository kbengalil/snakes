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
  try { MediaKit.ensureInitialized(); } catch (_) {}
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 5));
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_saveDetectionFromMessage);
  } catch (_) {}
  // Auto-monitor disabled — background service kept configured but stopped
  try { WifiWatcherService.configure(); } catch (_) {}
  try { WifiWatcherService.disable(); } catch (_) {}
  try {
    WifiWatcherService.onStartDetection.listen((data) async {
      final ip = data?['ip'] as String?;
      if (ip == null || DetectionService.instance.isRunning) return;
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      const t = Duration(seconds: 3);
      try {
        final user  = await storage.read(key: 'cam_user_$ip').timeout(t, onTimeout: () => null);
        final pass  = await storage.read(key: 'cam_pass_$ip').timeout(t, onTimeout: () => null);
        final port  = int.tryParse(await storage.read(key: 'cam_port_$ip').timeout(t, onTimeout: () => null) ?? '554') ?? 554;
        final rtsp  = await storage.read(key: 'cam_rtsp_$ip').timeout(t, onTimeout: () => null) ?? '/stream1';
        if (user == null || pass == null) return;
        DetectionService.instance.start(
          ip: ip, username: user, password: pass,
          cameraName: ip, port: port, rtspPath: rtsp,
        );
      } catch (_) {}
    });
  } catch (_) {}
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
    // Delay so login screen renders first before any blocking storage reads
    Future.delayed(const Duration(seconds: 2), _checkNotificationLaunch);
  }

  Future<void> _checkNotificationLaunch() async {
    const t = Duration(seconds: 3);
    // Local notification tap (mobile mode)
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android))
        .timeout(t, onTimeout: () {});
    final details = await plugin.getNotificationAppLaunchDetails()
        .timeout(t, onTimeout: () => null);
    if (details?.didNotificationLaunchApp == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DetectionsScreen()),
        );
      });
    }

    // Auto-start detection if WiFi watcher flagged it
    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      const t = Duration(seconds: 3);
      final pending = await storage.read(key: 'auto_start_pending').timeout(t, onTimeout: () => null);
      if (pending == 'true') {
        await storage.delete(key: 'auto_start_pending').timeout(t, onTimeout: () {});
        final ip   = await storage.read(key: 'cam_last_ip').timeout(t, onTimeout: () => null);
        final user = ip != null ? await storage.read(key: 'cam_user_$ip').timeout(t, onTimeout: () => null) : null;
        final pass = ip != null ? await storage.read(key: 'cam_pass_$ip').timeout(t, onTimeout: () => null) : null;
        if (ip != null && user != null && pass != null && !DetectionService.instance.isRunning) {
          final port = int.tryParse(await storage.read(key: 'cam_port_$ip').timeout(t, onTimeout: () => null) ?? '554') ?? 554;
          final rtsp = await storage.read(key: 'cam_rtsp_$ip').timeout(t, onTimeout: () => null) ?? '/stream1';
          DetectionService.instance.start(
            ip: ip, username: user, password: pass,
            cameraName: ip, port: port, rtspPath: rtsp,
          );
        }
      }
    } catch (_) {}

    // FCM tap (cloud mode)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const DetectionsScreen()),
      );
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage()
        .timeout(t, onTimeout: () => null);
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
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LoginScreen(),
    );
  }
}
