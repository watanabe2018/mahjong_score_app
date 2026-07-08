import 'package:flutter/material.dart';

/// 汎用の牌選択ダイアログ。選ばれた牌コード(例: "3p")を返す。
/// [allowRed] が true の場合、5の牌は長押しで赤ドラとして選べる("0p"等を返す)。
/// [chiOnly] が true の場合、チー用に1-7の数牌(順子の起点)のみ表示する。
class TilePickerDialog extends StatelessWidget {
  final bool allowRed;
  final bool chiOnly;
  const TilePickerDialog({super.key, this.allowRed = false, this.chiOnly = false});

  static Future<String?> show(BuildContext context, {bool allowRed = false, bool chiOnly = false}) {
    return showDialog<String>(
      context: context,
      builder: (_) => TilePickerDialog(allowRed: allowRed, chiOnly: chiOnly),
    );
  }

  List<String> _codes() {
    final list = <String>[];
    for (final suit in ['m', 'p', 's']) {
      final maxN = chiOnly ? 7 : 9;
      for (int n = 1; n <= maxN; n++) {
        list.add('$n$suit');
      }
    }
    if (!chiOnly) {
      for (int n = 1; n <= 7; n++) {
        list.add('${n}z');
      }
    }
    return list;
  }

  String _label(String code) {
    const honorNames = {
      '1z': '東', '2z': '南', '3z': '西', '4z': '北',
      '5z': '白', '6z': '發', '7z': '中',
    };
    return honorNames[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final codes = _codes();
    return AlertDialog(
      title: Text(chiOnly ? 'チーの最小牌を選択' : '牌を選択'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, childAspectRatio: 1),
          itemCount: codes.length,
          itemBuilder: (context, i) {
            final code = codes[i];
            final isFive = code == '5m' || code == '5p' || code == '5s';
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(code),
              onLongPress: (allowRed && isFive)
                  ? () => Navigator.of(context).pop('0${code.substring(1)}')
                  : null,
              child: Card(
                margin: const EdgeInsets.all(2),
                child: Center(child: Text(_label(code))),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
      ],
    );
  }
}
