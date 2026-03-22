import 'dart:convert';
import 'package:http/http.dart' as http;

class TapoCamera {
  final String deviceName;
  final String deviceModel;
  final String deviceIp;
  final String deviceId;

  TapoCamera({
    required this.deviceName,
    required this.deviceModel,
    required this.deviceIp,
    required this.deviceId,
  });

  @override
  String toString() => '$deviceName ($deviceModel) - $deviceIp';
}

class TapoService {
  String? _token;
  String? email;
  String? password;

  /// Login to Tapo cloud and return a session token.
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('https://wap.tplinkcloud.com');

    final body = jsonEncode({
      "method": "login",
      "params": {
        "appType": "Tapo_Android",
        "cloudUserName": email,
        "cloudPassword": password,
        "terminalUUID": "flutter-snakes-rats-app",
      }
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error_code'] == 0) {
        _token = data['result']['token'];
        this.email = email;
        this.password = password;
        return true;
      }
    }
    return false;
  }

  /// Get list of cameras registered to this Tapo account.
  Future<List<TapoCamera>> getDevices() async {
    if (_token == null) throw Exception('Not logged in');

    final url = Uri.parse('https://wap.tplinkcloud.com?token=$_token');

    final body = jsonEncode({
      "method": "getDeviceList",
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error_code'] == 0) {
        final deviceList = data['result']['deviceList'] as List;
        return deviceList
            .where((d) => d['deviceType'] == 'SMART.IPCAMERA')
            .map((d) => TapoCamera(
                  deviceName: d['alias'] ?? 'Unknown',
                  deviceModel: d['deviceModel'] ?? 'Unknown',
                  deviceIp: d['deviceMac'] ?? '', // IP resolved locally
                  deviceId: d['deviceId'] ?? '',
                ))
            .toList();
      }
    }
    return [];
  }

  bool get isLoggedIn => _token != null;
}
