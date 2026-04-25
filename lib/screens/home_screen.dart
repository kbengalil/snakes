import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
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
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _loadAutoMonitorState();
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
            title: const Text('No WiFi'),
            content: const Text('Please connect to your home WiFi first, then press Start again.'),
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
                        const Icon(Icons.videocam, size: 32),
                        const SizedBox(height: 4),
                        Text(DetectionService.instance.isRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                  // Auto button hidden — re-enable when splash bug is resolved
                  if (!DetectionService.instance.isRunning) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 140,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(color: Colors.black, width: 2),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _pickAndTestVideo,
                        child: const Text('Test my app', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ],
              ),
            if (DetectionService.instance.isRunning) ...[
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _blinkAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 12),
                      SizedBox(width: 8),
                      Text('Live — monitoring active',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DetectionsScreen()),
              ),
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
