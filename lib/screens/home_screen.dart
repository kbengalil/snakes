import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
import 'camera_list_screen.dart';
import 'detections_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _goToLiveStream(BuildContext context) async {
    // Enable WiFi if off
    final enabled = await WiFiForIoTPlugin.isEnabled();
    if (!enabled) {
      await WiFiForIoTPlugin.setEnabled(true);
      await Future.delayed(const Duration(seconds: 2));
    }

    final isConnected = await WiFiForIoTPlugin.isConnected();

    if (!isConnected) {
      // Open WiFi settings panel so user can connect in one tap
      AppSettings.openAppSettings(type: AppSettingsType.wifi);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to your home WiFi then come back'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snake Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pest_control, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user?.displayName ?? 'User'}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Live Stream', style: TextStyle(fontSize: 18)),
                onPressed: () => _goToLiveStream(context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Detections', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetectionsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
