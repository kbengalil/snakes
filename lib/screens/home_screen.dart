import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';
import 'video_picker_screen.dart';
import 'guide_screen.dart';
import '../services/detection_service.dart';
import '../services/wifi_watcher_service.dart';
import 'camera_list_screen.dart';
import '../screens/detections_screen.dart';
import 'login_screen.dart';
import 'test_detection_screen.dart';
import 'stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

int detectionIntervalMs = 1000;

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _autoMonitor = false;
  String? _homeSsid;
  int _detectionCount = 0;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  Future<void> _loadDetectionCount() async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    if (!await detectionsDir.exists()) { if (mounted) setState(() => _detectionCount = 0); return; }
    final count = detectionsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).length;
    if (mounted) setState(() => _detectionCount = count);
  }

  @override
  void initState() {
    super.initState();
    _loadAutoMonitorState();
    _loadDetectionCount();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }


  Future<void> _loadAutoMonitorState() async {
    final running = await WifiWatcherService.isRunning;
    final ssid = await WifiWatcherService.savedSsid;
    if (mounted) setState(() { _autoMonitor = running; _homeSsid = ssid; });
  }

  Future<void> _toggleAutoMonitor(bool enable) async {
    if (enable) {
      final ssid = await WiFiForIoTPlugin.getSSID();
      final cleanSsid = ssid?.replaceAll('"', '').trim();
      if (cleanSsid == null || cleanSsid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect to your home WiFi first')),
          );
        }
        return;
      }
      await WifiWatcherService.enable(cleanSsid);
      if (mounted) setState(() { _autoMonitor = true; _homeSsid = cleanSsid; });
    } else {
      await WifiWatcherService.disable();
      if (mounted) setState(() { _autoMonitor = false; });
    }
  }

  Future<void> _pickAndTestVideo() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoPickerScreen()),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _goToLiveStream() async {
    final enabled = await WiFiForIoTPlugin.isEnabled();
    if (!enabled) {
      await WiFiForIoTPlugin.setEnabled(true);
      await Future.delayed(const Duration(seconds: 2));
    }

    final isConnected = await WiFiForIoTPlugin.isConnected();

    if (!isConnected) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('No WiFi', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: const Text(
              'Please connect to your home WiFi first, then press Start again.',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraListScreen()),
      );
      if (mounted) setState(() {}); // refresh monitoring status on return
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.ranchoTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/home_bg.png', fit: BoxFit.cover),
          Container(color: Colors.white.withOpacity(0.25)),
          SafeArea(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuideScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  'Press to view guide',
                  style: GoogleFonts.rancho(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: DetectionService.instance.isRunning
                        ? () async {
                            await DetectionService.instance.stop();
                            setState(() {});
                          }
                        : _goToLiveStream,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DetectionService.instance.isRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(side: BorderSide(color: Colors.black, width: 2)),
                      padding: const EdgeInsets.all(28),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(DetectionService.instance.isRunning ? Icons.stop : Icons.play_arrow, size: 32),
                        const SizedBox(height: 4),
                        Text(DetectionService.instance.isRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                  // Auto button hidden — re-enable when splash bug is resolved
                  if (DetectionService.instance.isRunning) ...[
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StreamScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Text('Active',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!DetectionService.instance.isRunning) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 168,
                      height: 67,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          side: const BorderSide(color: Colors.black, width: 2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _pickAndTestVideo,
                        child: const Text('Test my app', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                setState(() => _detectionCount = 0);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetectionsScreen()),
                );
                _loadDetectionCount();
              },
              child: SizedBox(
                width: 160,
                height: 140,
                child: Stack(
                  children: [
                    ClipPath(
                      clipper: _TriangleClipper(),
                      child: Container(color: Colors.white),
                    ),
                    CustomPaint(
                      painter: _TriangleBorderPainter(),
                      child: const SizedBox(width: 160, height: 140),
                    ),
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: const [
                          Icon(Icons.warning_amber_rounded, size: 36, color: Colors.red),
                          Text('Alerts', style: TextStyle(fontSize: 26, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (_detectionCount > 0)
                      Positioned(
                        top: 8,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_detectionCount',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
        ],
      ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_TriangleClipper _) => false;
}

class _TriangleBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TriangleBorderPainter _) => false;
}
