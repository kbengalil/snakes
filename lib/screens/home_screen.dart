import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:app_settings/app_settings.dart';
import '../services/detection_service.dart';
import '../services/wifi_watcher_service.dart';
import 'camera_list_screen.dart';
import 'detections_screen.dart';
import 'login_screen.dart';
import 'alerts_screen.dart';
import 'stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _detectEveryNFrames = DetectionService.instance.detectEveryNFrames;
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snake Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
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
            const SizedBox(height: 32),
            // Monitoring status banner
            if (DetectionService.instance.isRunning) ...[
              Container(
                width: 240,
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
                width: 240,
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
                width: 240,
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
              SizedBox(
                width: 240,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Start Monitoring', style: TextStyle(fontSize: 18)),
                  onPressed: _goToLiveStream,
                ),
              ),
            ],
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
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications),
                label: const Text('Alerts', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Auto-monitor toggle
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _autoMonitor ? Colors.green : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: _autoMonitor ? Colors.green.shade50 : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Auto-Monitor',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Switch(
                        value: _autoMonitor,
                        onChanged: _toggleAutoMonitor,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (_autoMonitor && _homeSsid != null)
                    Text('WiFi: $_homeSsid',
                        style: const TextStyle(fontSize: 12, color: Colors.green)),
                  if (!_autoMonitor)
                    const Text('Turns on when home WiFi detected',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Detection frequency setting
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detect every N frames',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _detectEveryNFrames = (_detectEveryNFrames - 1).clamp(1, 120));
                          DetectionService.instance.updateFrameInterval(_detectEveryNFrames);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_detectEveryNFrames',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _detectEveryNFrames = (_detectEveryNFrames + 1).clamp(1, 120));
                          DetectionService.instance.updateFrameInterval(_detectEveryNFrames);
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      '≈ every ${(_detectEveryNFrames / 25.0).toStringAsFixed(1)}s at 25fps',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
