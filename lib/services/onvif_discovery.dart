import 'dart:async';
import 'dart:io';
import 'dart:convert';

class DiscoveredDevice {
  final String ip;
  final String? name;

  DiscoveredDevice({required this.ip, this.name});
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
    final completer = Completer<List<DiscoveredDevice>>();

    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 4;
      socket.broadcastEnabled = true;

      final probeBytes = utf8.encode(_probeMessage);
      socket.send(probeBytes, InternetAddress(_multicastAddress), _multicastPort);

      // Also send directly to common Tapo subnet broadcast
      socket.send(probeBytes, InternetAddress('255.255.255.255'), _multicastPort);

      final timer = Timer(const Duration(seconds: 6), () {
        socket?.close();
        if (!completer.isCompleted) completer.complete(devices);
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
          if (!completer.isCompleted) completer.complete(devices);
        },
        onError: (_) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete(devices);
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.complete(devices);
    }

    return completer.future;
  }

  static String? _extractName(String xml) {
    final patterns = [
      RegExp(r'<.*?FriendlyName[^>]*>([^<]+)<'),
      RegExp(r'<.*?Name[^>]*>([^<]+)<'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(xml);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
