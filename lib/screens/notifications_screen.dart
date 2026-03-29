import 'package:flutter/material.dart';
import 'detections_screen.dart';
import 'alerts_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Snake Alerts', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetectionsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications),
                label: const Text('Cam Alerts', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
