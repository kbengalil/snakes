import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'test_detection_screen.dart';

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  State<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen> {
  List<AssetEntity> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final videos = await albums.first.getAssetListRange(start: 0, end: 500);
    if (mounted) setState(() { _videos = videos; _loading = false; });
  }

  Future<void> _onTap(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => VideoTestScreen(filePath: file.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a video')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No videos found'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final asset = _videos[index];
                    return GestureDetector(
                      onTap: () => _onTap(asset),
                      child: _Thumbnail(asset: asset),
                    );
                  },
                ),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  final AssetEntity asset;
  const _Thumbnail({required this.asset});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    widget.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)).then((data) {
      if (mounted) setState(() => _thumb = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.asset.videoDuration;
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        _thumb != null
            ? Image.memory(_thumb!, fit: BoxFit.cover)
            : const ColoredBox(color: Colors.black12),
        const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
        Positioned(
          bottom: 4,
          right: 6,
          child: Text('$mins:$secs',
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black)])),
        ),
      ],
    );
  }
}
