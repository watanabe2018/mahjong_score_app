import 'package:flutter/material.dart';
import '../logic/score_calculator.dart';

class ResultScreen extends StatelessWidget {
  final ScoreResult result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isYakuman = result.limitName.contains('役満');
    return Scaffold(
      appBar: AppBar(title: const Text('計算結果')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                if (!isYakuman)
                  Text(
                    '${result.han}翻 ${result.fu}符',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                if (result.limitName.isNotEmpty)
                  Text(
                    result.limitName,
                    style: const TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${result.totalPoints}点',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          const Text('役', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.yakuNames
                .map((y) => Chip(label: Text(y)))
                .toList(),
          ),
          const Divider(height: 40),
          const Text('支払い内訳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...result.payments.entries.map(
            (e) => ListTile(
              dense: true,
              title: Text(_paymentLabel(e.key)),
              trailing: Text('${e.value}点'),
            ),
          ),
          if (result.fuBreakdown.isNotEmpty) ...[
            const Divider(height: 40),
            const Text('符の内訳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...result.fuBreakdown.map((b) => Text('・$b')),
          ],
        ],
      ),
    );
  }

  String _paymentLabel(String key) {
    switch (key) {
      case 'ronPayer':
        return '放銃者の支払い';
      case 'dealer':
        return '親の支払い';
      case 'nonDealerEach(x2)':
        return '子2人 各々の支払い';
      case 'nonDealerEach(x3)':
        return '子3人 各々の支払い';
      default:
        return key;
    }
  }
}
