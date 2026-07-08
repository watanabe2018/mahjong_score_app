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
      // 保存済みパスワードがあれば直接カメラ画面へ
      // (実際の正当性はバックエンド呼び出し時に401で検証される)
      if (mounted) _goNext(saved);
      return;
    }
    setState(() => _checking = false);
  }

  void _goNext(String password) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CameraScreen(password: password)),
    );
  }

  Future<void> _onSubmit() async {
    final pw = _controller.text.trim();
    if (pw.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.passwordStorageKey, pw);
    if (mounted) _goNext(pw);
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
            const Text('合言葉を入力してください', style: TextStyle(fontSize: 16)),
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
