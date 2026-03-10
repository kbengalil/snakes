import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Called by Android when the foreground service starts.
/// Runs in a separate Dart isolate — just keeps the service alive.
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) {
  service.on('stop').listen((_) => service.stopSelf());
}

Future<void> initMonitoringService() async {
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'monitoring_channel',
        'Camera Monitoring',
        description: 'Keeps camera monitoring running in background',
        importance: Importance.low,
      ));

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'monitoring_channel',
      initialNotificationTitle: 'Snakes & Rats',
      initialNotificationContent: 'Monitoring cameras...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<void> startMonitoring() => FlutterBackgroundService().startService();

void stopMonitoring() => FlutterBackgroundService().invoke('stop');
