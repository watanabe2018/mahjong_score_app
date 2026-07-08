import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MahjongScoreApp());
}

class MahjongScoreApp extends StatelessWidget {
  const MahjongScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '麻雀符計算アプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
