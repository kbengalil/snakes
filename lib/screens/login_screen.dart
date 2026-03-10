import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/tapo_service.dart';
import 'camera_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tapoService = TapoService();
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final email = await _storage.read(key: 'tapo_email');
    final password = await _storage.read(key: 'tapo_password');

    if (email != null && password != null) {
      _emailController.text = email;
      _passwordController.text = password;
      await _login(auto: true);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _login({bool auto = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await _tapoService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        // Save credentials for next time
        await _storage.write(key: 'tapo_email', value: _emailController.text.trim());
        await _storage.write(key: 'tapo_password', value: _passwordController.text);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CameraListScreen(tapoService: _tapoService),
            ),
          );
        }
      } else {
        // Clear saved credentials if login failed
        await _storage.deleteAll();
        setState(() => _error = 'Login failed. Check your credentials.');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Snakes & Rats')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Sign in with your Tapo account',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
