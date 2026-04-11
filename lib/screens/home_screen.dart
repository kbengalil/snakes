import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
import 'video_picker_screen.dart';
import '../services/detection_service.dart';
import '../services/wifi_watcher_service.dart';
import 'camera_list_screen.dart';
import 'notifications_screen.dart';
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
              onTap: () {
                // TODO: open guide screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guide coming soon!')),
                );
              },
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
            // Monitoring status banner
            if (DetectionService.instance.isRunning) ...[
              Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FadeTransition(
                  opacity: _blinkAnimation,
                  child: Text(
                    'Running Snakes Detection',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                height: 120,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  label: const Text('Stop', style: TextStyle(fontSize: 30)),
                  style: ElevatedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 2),
                    foregroundColor: Colors.red,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () async {
                    await DetectionService.instance.stop();
                    setState(() {});
                  },
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _goToLiveStream,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(side: BorderSide(color: Colors.black, width: 2)),
                      padding: const EdgeInsets.all(28),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, size: 32),
                        SizedBox(height: 4),
                        Text('Start', style: TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.black, width: 2),
                      color: _autoMonitor ? Colors.green : Colors.red,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Auto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                        Switch(
                          value: _autoMonitor,
                          onChanged: _toggleAutoMonitor,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.green.shade800,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.red.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications),
                label: const Text('Notifications', style: TextStyle(fontSize: 30)),
                style: ElevatedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 2),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ),
            if (!DetectionService.instance.isRunning) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 2),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _pickAndTestVideo,
                  child: const Text('Test my app', style: TextStyle(fontSize: 30)),
                ),
              ),
            ],
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
