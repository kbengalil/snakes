import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DetectionsScreen extends StatefulWidget {
  const DetectionsScreen({super.key});

  @override
  State<DetectionsScreen> createState() => _DetectionsScreenState();
}

class _DetectionsScreenState extends State<DetectionsScreen> {
  List<File> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/detections');
    if (!await detectionsDir.exists()) {
      setState(() => _images = []);
      return;
    }
    final files = detectionsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first
    setState(() => _images = files);
  }

  String _formatTimestamp(File f) {
    final name = f.uri.pathSegments.last;
    // detection_20240101_120000.jpg
    try {
      final parts = name.replaceAll('.jpg', '').split('_');
      final date = parts[1];
      final time = parts[2];
      return '${date.substring(6)}/${date.substring(4, 6)}/${date.substring(0, 4)}  '
          '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4)}';
    } catch (_) {
      return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detections')),
      body: _images.isEmpty
          ? const Center(child: Text('No detections yet.'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 16 / 9,
              ),
              itemCount: _images.length,
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: () => _openFullscreen(context, i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_images[i], fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _formatTimestamp(_images[i]),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _openFullscreen(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(_formatTimestamp(_images[index])),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(_images[index]),
            ),
          ),
        ),
      ),
    );
  }
}
