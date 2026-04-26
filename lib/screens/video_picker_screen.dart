import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'test_detection_screen.dart';

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  State<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen> {
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Open the native video picker immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v', 'ts', 'mpg', 'mpeg',
  };

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (!mounted) return;

    if (file == null) {
      Navigator.pop(context);
      return;
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!_videoExtensions.contains(ext)) {
      setState(() => _picking = false);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Not a video'),
          content: const Text('Please select a video file, not an image or other file.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
      if (mounted) _pick(); // re-open picker
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => VideoTestScreen(filePath: file.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
