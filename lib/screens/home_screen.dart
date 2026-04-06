import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  bool _autoMonitor = false;
  String? _homeSsid;

  @override
  void initState() {
    super.initState();
    _loadAutoMonitorState();
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
      AppSettings.openAppSettings(type: AppSettingsType.wifi);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect to your home WiFi then come back'),
            duration: Duration(seconds: 4),
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
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Monitoring: ${DetectionService.instance.cameraName}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('View Live Stream'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StreamScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 180,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  label: const Text('Stop Monitoring', style: TextStyle(color: Colors.red)),
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestDetectionScreen()),
                ),
                child: const Text('Test my app', style: TextStyle(fontSize: 30)),
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
