import 'package:flutter/material.dart';
import '../services/tapo_service.dart';
import '../services/onvif_discovery.dart';
import 'stream_screen.dart';

class CameraListScreen extends StatefulWidget {
  final TapoService tapoService;

  const CameraListScreen({super.key, required this.tapoService});

  @override
  State<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends State<CameraListScreen> {
  List<TapoCamera>? _cameras;
  Map<String, String> _cameraIps = {};
  bool _loading = true;
  String _status = 'Loading your cameras...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Fetching cameras from your account...';
    });

    try {
      final cameras = await widget.tapoService.getDevices();

      setState(() => _status = 'Scanning local network for cameras...');

      final discovered = await OnvifDiscovery.discover();

      final ipMap = <String, String>{};
      for (final cam in cameras) {
        for (final device in discovered) {
          final nameMatch = device.name != null &&
              (device.name!.toLowerCase().contains(cam.deviceModel.toLowerCase()) ||
               cam.deviceName.toLowerCase().contains(device.name!.toLowerCase()));
          if (nameMatch) {
            ipMap[cam.deviceId] = device.ip;
            break;
          }
        }
        if (!ipMap.containsKey(cam.deviceId) && discovered.isNotEmpty) {
          ipMap[cam.deviceId] = discovered.first.ip;
        }
      }

      setState(() {
        _cameras = cameras;
        _cameraIps = ipMap;
        _loading = false;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _connectToCamera(TapoCamera cam, String ip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamScreen(
          cameraName: cam.deviceName,
          ip: ip,
          username: 'kbengalil',
          password: 'dardas100',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cameras')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
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
            ElevatedButton(onPressed: _loadCameras, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_cameras == null || _cameras!.isEmpty) {
      return const Center(child: Text('No cameras found on your account.'));
    }

    return ListView.builder(
      itemCount: _cameras!.length,
      itemBuilder: (context, index) {
        final cam = _cameras![index];
        final ip = _cameraIps[cam.deviceId];

        return ListTile(
          leading: const Icon(Icons.videocam, size: 40, color: Colors.green),
          title: Text(cam.deviceName),
          subtitle: Text(ip != null ? '${cam.deviceModel} • $ip' : cam.deviceModel),
          trailing: ip != null
              ? const Icon(Icons.wifi, color: Colors.green)
              : const Icon(Icons.wifi_off, color: Colors.grey),
          onTap: () {
            if (ip != null) {
              _connectToCamera(cam, ip);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera not found on local network')),
              );
            }
          },
        );
      },
    );
  }
}
