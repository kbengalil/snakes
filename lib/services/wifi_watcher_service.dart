import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wifi_iot/wifi_iot.dart';

const _channelId   = 'snake_wifi_watcher_v2';
const _channelName = 'WiFi Camera Monitor';
const _fgNotifId   = 900;   // foreground service notification
const _alertId     = 901;   // "tap to start" alert
const _noCamId     = 902;   // "no camera" alert

// ─── Public API ──────────────────────────────────────────────────────────────

class WifiWatcherService {
  static final _svc = FlutterBackgroundService();

  /// Call once at app startup (before runApp).
  static Future<void> configure() async {
    // Create notification channel before configuring the service so Android 8+
    // can post the mandatory foreground notification without crashing.
    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      ));
    }

    await _svc.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _bgEntry,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId, // must match _channelId const
        initialNotificationTitle: 'Snake Monitor',
        initialNotificationContent: 'Watching for home WiFi…',
        foregroundServiceNotificationId: _fgNotifId,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  /// Enable auto-monitoring for [ssid]. Starts the background service.
  static Future<void> enable(String ssid) async {
    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    await storage.write(key: 'home_wifi_ssid', value: ssid);
    await storage.write(key: 'auto_monitor_enabled', value: 'true');
    await _svc.startService();
  }

  /// Disable auto-monitoring and stop the background service.
  static Future<void> disable() async {
    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    await storage.write(key: 'auto_monitor_enabled', value: 'false');
    _svc.invoke('stop');
  }

  static Future<bool> get isRunning => _svc.isRunning();

  static Future<String?> get savedSsid async =>
      const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)).read(key: 'home_wifi_ssid');

  /// Listen for start_detection events from the background service.
  static Stream<Map<String, dynamic>?> get onStartDetection =>
      _svc.on('start_detection');
}

// ─── Background entry point ──────────────────────────────────────────────────

@pragma('vm:entry-point')
void _bgEntry(ServiceInstance service) async {
  const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  if (service is AndroidServiceInstance) {
    service.on('stop').listen((_) => service.stopSelf());
  }

  bool ticking = false;

  // Check immediately, then every 30 seconds
  await _tick(service, storage, notifications);
  Timer.periodic(const Duration(seconds: 30), (_) async {
    if (ticking) return;
    ticking = true;
    try {
      await _tick(service, storage, notifications);
    } finally {
      ticking = false;
    }
  });
}

Future<void> _tick(
  ServiceInstance service,
  FlutterSecureStorage storage,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final homeSsid = await storage.read(key: 'home_wifi_ssid');
  print('[WifiWatcher] tick — homeSsid=$homeSsid');
  if (homeSsid == null) return;

  // Get current WiFi SSID (requires location permission on Android)
  String? currentSsid;
  try {
    currentSsid = (await WiFiForIoTPlugin.getSSID()
            .timeout(const Duration(seconds: 4), onTimeout: () => null))
        ?.replaceAll('"', '')
        .trim();
  } catch (e) {
    print('[WifiWatcher] getSSID error: $e');
  }

  print('[WifiWatcher] currentSsid=$currentSsid homeSsid=$homeSsid');
  if (currentSsid == null || currentSsid != homeSsid) return;

  // ── Home WiFi matched ────────────────────────────────────────────────────
  final lastIp  = await storage.read(key: 'cam_last_ip');
  print('[WifiWatcher] WiFi matched! lastIp=$lastIp');
  if (lastIp == null) return; // no camera ever connected — nothing to do

  final portStr  = await storage.read(key: 'cam_port_$lastIp');
  final port     = int.tryParse(portStr ?? '554') ?? 554;
  final reachable = await _isReachable(lastIp, port);

  print('[WifiWatcher] reachable=$reachable');
  if (!reachable) {
    // Clear the "already notified" flag so we notify again next time camera comes back
    await storage.delete(key: 'cam_found_notified');
    await _saveEvent('no_camera', lastIp);
    print('[WifiWatcher] sending no-camera notification...');
    try {
      await _notify(notifications, _noCamId,
          'Snake Monitor', 'Home WiFi detected but no camera found');
      print('[WifiWatcher] notification sent OK');
    } catch (e) {
      print('[WifiWatcher] notification error: $e');
    }
    return;
  }

  // Camera is reachable — only notify once per detection session
  final alreadyNotified = await storage.read(key: 'cam_found_notified');
  if (alreadyNotified == 'true') return;
  await storage.write(key: 'cam_found_notified', value: 'true');

  await _saveEvent('camera_found', lastIp);
  service.invoke('start_detection', {'ip': lastIp, 'port': port});

  // Also set a flag so the app auto-starts if it was closed and reopened
  await storage.write(key: 'auto_start_pending', value: 'true');

  await _notify(notifications, _alertId, 'Camera Found', 'Snake monitoring started');
}

Future<void> _saveEvent(String type, String ip) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final eventsDir = Directory('${dir.path}/events');
    await eventsDir.create(recursive: true);
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    final name = 'event_${now.year}${p(now.month)}${p(now.day)}_${p(now.hour)}${p(now.minute)}${p(now.second)}.json';
    await File('${eventsDir.path}/$name').writeAsString(jsonEncode({
      'type': type,
      'ip': ip,
      'timestamp': now.toIso8601String(),
    }));
  } catch (e) {
    print('[WifiWatcher] saveEvent error: $e');
  }
}

Future<bool> _isReachable(String ip, int port) async {
  try {
    final s = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 3));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _notify(
  FlutterLocalNotificationsPlugin n,
  int id,
  String title,
  String body,
) async {
  await n.show(
    id, title, body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
