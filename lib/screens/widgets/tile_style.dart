import 'package:flutter/material.dart';

/// 牌コード(例: "3m", "0p", "5z")から、種類(萬子/筒子/索子/字牌)に応じた色を返す
class TileStyle {
  static String suitOf(String code) => code.substring(code.length - 1);

  static Color backgroundColor(String code) {
    switch (suitOf(code)) {
      case 'm':
        return const Color(0xFFFFE0E0); // 萬子: 赤系
      case 'p':
        return const Color(0xFFE0EEFF); // 筒子: 青系
      case 's':
        return const Color(0xFFE0F5E0); // 索子: 緑系
      case 'z':
        return const Color(0xFFF0E8FF); // 字牌: 紫系
      default:
        return const Color(0xFFEEEEEE);
    }
  }

  static Color textColor(String code) {
    switch (suitOf(code)) {
      case 'm':
        return const Color(0xFFB71C1C);
      case 'p':
        return const Color(0xFF0D47A1);
      case 's':
        return const Color(0xFF1B5E20);
      case 'z':
        return const Color(0xFF4A148C);
      default:
        return Colors.black87;
    }
  }

  static Color borderColor(String code) {
    switch (suitOf(code)) {
      case 'm':
        return const Color(0xFFEF9A9A);
      case 'p':
        return const Color(0xFF90CAF9);
      case 's':
        return const Color(0xFFA5D6A7);
      case 'z':
        return const Color(0xFFCE93D8);
      default:
        return const Color(0xFFCCCCCC);
    }
  }
}
