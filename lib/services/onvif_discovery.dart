import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DiscoveredDevice {
  final String ip;
  final String? name;
  final int rtspPort;

  DiscoveredDevice({required this.ip, this.name, this.rtspPort = 554});
}

class OnvifDiscovery {
  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 3702;

  static const _probeMessage = '''<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
            xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
            xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
            xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
  <e:Header>
    <w:MessageID>uuid:discover-tapo-cameras</w:MessageID>
    <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
    <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
  </e:Header>
  <e:Body>
    <d:Probe>
      <d:Types>dn:NetworkVideoTransmitter</d:Types>
    </d:Probe>
  </e:Body>
</e:Envelope>''';

  static Future<List<DiscoveredDevice>> discover() async {
    final devices = <DiscoveredDevice>[];
    final seenIps = <String>{};

    // Step 1: ONVIF multicast — finds cameras that support WS-Discovery (e.g. Tapo)
    await _onvifProbe(devices, seenIps);

    // Step 2: Port scan — finds cameras that don't support ONVIF (e.g. ProVision)
    await _rtspPortScan(devices, seenIps);

    return devices;
  }

  static Future<void> _onvifProbe(
      List<DiscoveredDevice> devices, Set<String> seenIps) async {
    final completer = Completer<void>();

    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 4;
      socket.broadcastEnabled = true;

      final probeBytes = utf8.encode(_probeMessage);
      socket.send(probeBytes, InternetAddress(_multicastAddress), _multicastPort);

      // Also send directly to common Tapo subnet broadcast
      socket.send(probeBytes, InternetAddress('255.255.255.255'), _multicastPort);

      final timer = Timer(const Duration(seconds: 4), () {
        socket?.close();
        if (!completer.isCompleted) completer.complete();
      });

      socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket?.receive();
            if (datagram != null) {
              final ip = datagram.address.address;
              if (!seenIps.contains(ip)) {
                seenIps.add(ip);
                final response = utf8.decode(datagram.data, allowMalformed: true);
                final name = _extractName(response);
                devices.add(DiscoveredDevice(ip: ip, name: name));
              }
            }
          }
        },
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (_) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  // Scans all local /24 subnets for RTSP ports.
  // Only the two common RTSP ports — keeps the scan fast (~5s total).
  static const _rtspPorts = [554, 8554];

  static Future<void> _rtspPortScan(
      List<DiscoveredDevice> devices, Set<String> seenIps) async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

    final subnets = <String>{};
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length == 4 && parts[0] != '127') {
          subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    }
    if (subnets.isEmpty) return;

    for (final subnet in subnets) {
      const batchSize = 50;
      for (int base = 1; base <= 254; base += batchSize) {
        final futures = <Future>[];
        for (int i = base; i < base + batchSize && i <= 254; i++) {
          final ip = '$subnet.$i';
          if (seenIps.contains(ip)) continue;
          futures.add(_probeRtspPort(ip).then((port) async {
            if (port != null && !seenIps.contains(ip)) {
              seenIps.add(ip);
              final name = await _fetchOnvifName(ip);
              devices.add(DiscoveredDevice(ip: ip, rtspPort: port, name: name));
            }
          }));
        }
        await Future.wait(futures);
      }
    }
  }

  static Future<int?> _probeRtspPort(String ip) async {
    for (final port in _rtspPorts) {
      try {
        final socket = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 300));
        socket.destroy();
        return port;
      } catch (_) {}
    }
    return null;
  }

  static const _onvifBody =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">'
      '<s:Body>'
      '<tds:GetDeviceInformation xmlns:tds="http://www.onvif.org/ver10/device/wsdl"/>'
      '</s:Body>'
      '</s:Envelope>';

  static Future<String?> _fetchOnvifName(String ip) async {
    for (final httpPort in [80, 8080]) {
      // 1. Try ONVIF GetDeviceInformation on common paths and content-types
      for (final path in ['/onvif/device_service', '/onvif/device', '/onvif/Device']) {
        for (final ct in ['application/soap+xml; charset=utf-8', 'text/xml; charset=utf-8']) {
          try {
            final response = await http.post(
              Uri.parse('http://$ip:$httpPort$path'),
              headers: {'Content-Type': ct},
              body: _onvifBody,
            ).timeout(const Duration(seconds: 2));

            final body = response.body;
            final manufacturer = RegExp(r'<[^:>]*:?Manufacturer>([^<]+)<')
                .firstMatch(body)?.group(1)?.trim();
            final model = RegExp(r'<[^:>]*:?Model>([^<]+)<')
                .firstMatch(body)?.group(1)?.trim();
            if (manufacturer != null || model != null) {
              return [manufacturer, model]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' ');
            }
          } catch (_) {}
        }
      }

      // 2. HTTP GET — read page <title> (camera web UIs show the model there)
      try {
        final response = await http.get(
          Uri.parse('http://$ip:$httpPort/'),
        ).timeout(const Duration(seconds: 2));

        final title = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
            .firstMatch(response.body)?.group(1)?.trim();
        // Only use if it looks like a device name, not a generic server page
        if (title != null && title.isNotEmpty &&
            !RegExp(r'nginx|apache|index|welcome|router|login',
                    caseSensitive: false)
                .hasMatch(title)) {
          return title;
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _extractName(String xml) {
    // 1. XML element: <FriendlyName>...</FriendlyName>
    // 2. XML element: <Name>...</Name>
    final elementPatterns = [
      RegExp(r'<[^>]*FriendlyName[^>]*>([^<]+)<'),
      RegExp(r'<[^>]*Name[^>]*>([^<]+)<'),
    ];
    for (final p in elementPatterns) {
      final m = p.firstMatch(xml);
      if (m != null) return m.group(1)!.trim();
    }

    // 3. ONVIF scope URI: onvif://www.onvif.org/name/<value>
    //    Tapo cameras put their model here, e.g. "C200" or "TP-Link%20Tapo%20C200"
    final scopeMatch =
        RegExp(r'onvif://www\.onvif\.org/name/([^\s<&]+)').firstMatch(xml);
    if (scopeMatch != null) {
      final raw = scopeMatch.group(1)!;
      return Uri.decodeComponent(raw.replaceAll('+', ' ')).trim();
    }

    return null;
  }
}
