import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'camera_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConfig.passwordStorageKey);
    if (saved != null && saved.isNotEmpty) {
      if (mounted) _goNext();
      return;
    }
    setState(() => _checking = false);
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  Future<void> _onSubmit() async {
    final pw = _controller.text.trim();
    if (pw.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.passwordStorageKey, pw);
    if (mounted) _goNext();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('麻雀符計算アプリ')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text('簡易ロック(任意の文字でOK)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _onSubmit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('ログイン'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
