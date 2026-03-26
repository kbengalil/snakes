import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final dir = await getApplicationDocumentsDirectory();
    final eventsDir = Directory('${dir.path}/events');
    if (!await eventsDir.exists()) {
      setState(() => _events = []);
      return;
    }
    final files = eventsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first

    final events = <Map<String, dynamic>>[];
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        data['_file'] = f.path;
        events.add(data);
      } catch (_) {}
    }
    setState(() => _events = events);
  }

  Future<void> _deleteEvent(int index) async {
    final path = _events[index]['_file'] as String;
    await File(path).delete();
    setState(() => _events.removeAt(index));
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all?'),
        content: const Text('This will permanently delete all alert history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (confirm != true) return;
    for (final e in _events) {
      await File(e['_file'] as String).delete();
    }
    setState(() => _events = []);
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String p(int n) => n.toString().padLeft(2, '0');
      return '${p(dt.day)}/${p(dt.month)}/${dt.year}  ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete all',
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _events.isEmpty
          ? const Center(child: Text('No alerts yet.'))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, i) {
                final e = _events[i];
                final isCameraFound = e['type'] == 'camera_found';
                return Dismissible(
                  key: ValueKey(e['_file']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteEvent(i),
                  child: ListTile(
                    leading: Icon(
                      isCameraFound ? Icons.videocam : Icons.videocam_off,
                      color: isCameraFound ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Text(
                      isCameraFound
                          ? 'Camera found'
                          : 'No camera found',
                      style: TextStyle(
                        color: isCameraFound ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['ip'] ?? ''),
                        Text(
                          _formatTimestamp(e['timestamp'] ?? ''),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
