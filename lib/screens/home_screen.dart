import 'package:flutter/material.dart';
import '../services/tapo_service.dart';
import 'camera_list_screen.dart';
import 'detections_screen.dart';

class HomeScreen extends StatelessWidget {
  final TapoService tapoService;

  const HomeScreen({super.key, required this.tapoService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snakes & Rats')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pest_control, size: 80, color: Colors.green),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Live Stream', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraListScreen(tapoService: tapoService),
                  ),
                ),
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
