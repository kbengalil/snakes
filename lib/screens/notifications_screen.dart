import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'detections_screen.dart';
import 'alerts_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/login_bg.png', fit: BoxFit.cover),
          Transform.translate(
        offset: const Offset(0, -250),
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: Text('Snake Alerts', style: GoogleFonts.rancho(fontSize: 30)),
                style: ElevatedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 2),
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetectionsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications),
                label: Text('App Notifications', style: GoogleFonts.rancho(fontSize: 30)),
                style: ElevatedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 2),
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.lightBlue,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
            ),
          ],
        ),
        ),
        ),
        ],
      ),
    );
  }
}
