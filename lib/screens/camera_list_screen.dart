import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/onvif_discovery.dart';
import '../services/detection_service.dart';
import 'stream_screen.dart';

class CameraListScreen extends StatefulWidget {
  const CameraListScreen({super.key});

  @override
  State<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends State<CameraListScreen> {
  final _storage = const FlutterSecureStorage();
  List<DiscoveredDevice> _cameras = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanNetwork();
  }

  Future<void> _scanNetwork() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final discovered = await OnvifDiscovery.discover();
      setState(() {
        _cameras = discovered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Scan failed: $e';
        _loading = false;
      });
    }
  }

  Future<void> _connectToCamera(DiscoveredDevice device) async {
    // Check if we have saved credentials for this camera
    final savedUser = await _storage.read(key: 'cam_user_${device.ip}');
    final savedPass = await _storage.read(key: 'cam_pass_${device.ip}');

    if (savedUser != null && savedPass != null) {
      // Already have credentials — connect directly
      _openStream(device, savedUser, savedPass);
    } else {
      // Ask for credentials
      _showCredentialsDialog(device);
    }
  }

  void _showCredentialsDialog(DiscoveredDevice device) {
    final userController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool obscure = true;
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text(device.name ?? 'Camera'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final user = userController.text.trim();
                    final pass = passController.text;
                    if (user.isEmpty || pass.isEmpty) return;

                    // Save credentials for next time
                    await _storage.write(key: 'cam_user_${device.ip}', value: user);
                    await _storage.write(key: 'cam_pass_${device.ip}', value: pass);

                    if (ctx.mounted) Navigator.pop(ctx);
                    _openStream(device, user, pass);
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openStream(DiscoveredDevice device, String user, String pass) async {
    // Start background detection service
    await DetectionService.instance.start(
      ip: device.ip,
      port: device.rtspPort,
      username: user,
      password: pass,
      cameraName: device.name ?? device.ip,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StreamScreen()),
    );
  }

  void _showAddManuallyDialog() {
    final ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Camera by IP'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: 'e.g. 192.168.1.17',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isEmpty) return;
              Navigator.pop(ctx);
              _connectToCamera(DiscoveredDevice(ip: ip));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cameras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanNetwork,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddManuallyDialog,
        tooltip: 'Add by IP',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning network for cameras...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _scanNetwork, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_cameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No cameras found on this network'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _scanNetwork, child: const Text('Scan Again')),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cameras.length,
      itemBuilder: (context, index) {
        final cam = _cameras[index];
        return ListTile(
          leading: const Icon(Icons.videocam, size: 40, color: Colors.green),
          title: Text(cam.name ?? 'Unknown Camera'),
          subtitle: Text(cam.ip),
          trailing: const Icon(Icons.wifi, color: Colors.green),
          onTap: () => _connectToCamera(cam),
        );
      },
    );
  }
}
