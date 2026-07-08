import 'package:flutter/material.dart';
import '../models/tile.dart';
import '../models/called_meld_draft.dart';
import '../logic/hand_parser.dart';
import '../logic/yaku_checker.dart';
import '../logic/score_calculator.dart';
import '../logic/dora_calculator.dart';
import 'result_screen.dart';
import 'widgets/tile_picker_dialog.dart';
import 'widgets/tile_style.dart';

class InputScreen extends StatefulWidget {
  final List<String> tileCodes; // 面前部分(鳴き分を除いた残りの手牌)
  final List<CalledMeldDraft> calledMelds;
  final List<String> doraIndicators; // 牌確認画面で選んだドラ表示牌
  final int akaDoraCount; // 牌確認画面で入力した赤ドラ枚数
  const InputScreen({
    super.key,
    required this.tileCodes,
    this.calledMelds = const [],
    this.doraIndicators = const [],
    this.akaDoraCount = 0,
  });

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  late String _winningTileCode = widget.tileCodes.first;
  bool _isDealer = true;
  int _honba = 0;
  bool _isTsumo = true;
  bool _riichi = false;
  bool _doubleRiichi = false;
  bool _ippatsu = false;
  int _roundWind = 1;
  int _seatWind = 1;
  final List<String> _uraDoraIndicators = [];

  bool get _isMenzen => widget.calledMelds.every(
        (m) => m.kind == CalledMeldKind.ankan,
      ); // 暗槓のみなら面前扱い

  String _label(String code) {
    const honorNames = {
      '1z': '東', '2z': '南', '3z': '西', '4z': '北',
      '5z': '白', '6z': '發', '7z': '中',
    };
    if (honorNames.containsKey(code)) return honorNames[code]!;
    if (code.startsWith('0')) return '赤5${code.substring(1)}';
    return code;
  }

  Future<void> _addDoraIndicator(List<String> target) async {
    final code = await TilePickerDialog.show(context);
    if (code == null) return;
    setState(() => target.add(code));
  }

  void _submit() {
    try {
      final concealed = widget.tileCodes.map((c) => Tile.fromString(c)).toList();
      final calledMelds = widget.calledMelds.map((d) => d.toMeld()).toList();
      final winTile = Tile.fromString(_winningTileCode);

      final hand = HandInput(
        concealedTiles: concealed,
        calledMelds: calledMelds,
        winningTile: winTile,
        isTsumo: _isTsumo,
      );

      // ドラ計算: 手牌全体(面前+鳴き)から表示牌に対応する牌の枚数を数える
      final allHandTiles = [...concealed, ...calledMelds.expand((m) => m.tiles)];
      final doraIndicatorTiles = widget.doraIndicators.map((c) => Tile.fromString(c)).toList();
      final uraDoraIndicatorTiles = _uraDoraIndicators.map((c) => Tile.fromString(c)).toList();
      final doraCount = DoraCalculator.countDora(doraIndicatorTiles, allHandTiles);
      final uraDoraCount = (_riichi || _doubleRiichi)
          ? DoraCalculator.countDora(uraDoraIndicatorTiles, allHandTiles)
          : 0;
      final akaDoraCount = widget.akaDoraCount;

      final ctx = GameContext(
        roundWind: _roundWind,
        seatWind: _seatWind,
        isDealer: _isDealer,
        isTsumo: _isTsumo,
        riichi: _riichi,
        doubleRiichi: _doubleRiichi,
        ippatsu: _ippatsu,
        doraCount: doraCount,
        uraDoraCount: uraDoraCount,
        akaDoraCount: akaDoraCount,
        honba: _honba,
      );
      final result = ScoreCalculator.calculate(hand, ctx);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('計算できませんでした'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
          ],
        ),
      );
    }
  }

  Widget _windSelector(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('東')),
              ButtonSegment(value: 2, label: Text('南')),
              ButtonSegment(value: 3, label: Text('西')),
              ButtonSegment(value: 4, label: Text('北')),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }

  Widget _doraIndicatorSection(String title, List<String> indicators) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addDoraIndicator(indicators),
              icon: const Icon(Icons.add),
              label: const Text('表示牌を追加'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: List.generate(indicators.length, (i) {
            final indicator = Tile.fromString(indicators[i]);
            final doraTile = DoraCalculator.doraTileFor(indicator);
            return InputChip(
              label: Text('${_label(indicators[i])} → ${_label(doraTile.code)}がドラ',
                  style: TextStyle(color: TileStyle.textColor(indicators[i]))),
              backgroundColor: TileStyle.backgroundColor(indicators[i]),
              side: BorderSide(color: TileStyle.borderColor(indicators[i])),
              onDeleted: () => setState(() => indicators.removeAt(i)),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('和了条件を入力')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.calledMelds.isNotEmpty) ...[
            const Text('鳴き', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: widget.calledMelds.map((m) => Chip(
                label: Text(m.label, style: TextStyle(color: TileStyle.textColor(m.baseTileCode))),
                backgroundColor: TileStyle.backgroundColor(m.baseTileCode),
                side: BorderSide(color: TileStyle.borderColor(m.baseTileCode)),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],

          const Text('和了牌はどれですか?', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: widget.tileCodes.toSet().map((code) {
              return ChoiceChip(
                label: Text(_label(code), style: TextStyle(color: TileStyle.textColor(code))),
                selected: _winningTileCode == code,
                backgroundColor: TileStyle.backgroundColor(code),
                selectedColor: TileStyle.borderColor(code),
                side: BorderSide(color: TileStyle.borderColor(code)),
                onSelected: (_) => setState(() => _winningTileCode = code),
              );
            }).toList(),
          ),
          const Divider(height: 32),

          const Text('親 / 子', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('親')),
              ButtonSegment(value: false, label: Text('子')),
            ],
            selected: {_isDealer},
            onSelectionChanged: (s) => setState(() => _isDealer = s.first),
          ),
          const SizedBox(height: 16),

          const Text('ツモ / ロン', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('ツモ')),
              ButtonSegment(value: false, label: Text('ロン')),
            ],
            selected: {_isTsumo},
            onSelectionChanged: (s) => setState(() => _isTsumo = s.first),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Text('何本場', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => setState(() => _honba = (_honba - 1).clamp(0, 99)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_honba 本場', style: const TextStyle(fontSize: 16)),
              IconButton(
                onPressed: () => setState(() => _honba++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(height: 32),

          _windSelector('場風', _roundWind, (v) => setState(() => _roundWind = v)),
          const SizedBox(height: 8),
          _windSelector('自風', _seatWind, (v) => setState(() => _seatWind = v)),
          const Divider(height: 32),

          if (_isMenzen) ...[
            SwitchListTile(
              title: const Text('立直'),
              value: _riichi,
              onChanged: (v) => setState(() {
                _riichi = v;
                if (!v) {
                  _doubleRiichi = false;
                  _ippatsu = false;
                  _uraDoraIndicators.clear();
                }
              }),
            ),
            if (_riichi)
              SwitchListTile(
                title: const Text('ダブル立直'),
                value: _doubleRiichi,
                onChanged: (v) => setState(() => _doubleRiichi = v),
              ),
            if (_riichi)
              SwitchListTile(
                title: const Text('一発'),
                value: _ippatsu,
                onChanged: (v) => setState(() => _ippatsu = v),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('鳴きがあるため立直は選択できません', style: TextStyle(color: Colors.grey)),
            ),
          const Divider(height: 32),

          if (widget.doraIndicators.isNotEmpty) ...[
            const Text('ドラ表示牌(牌確認画面で選択済み)', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.doraIndicators.map((code) {
                final doraTile = DoraCalculator.doraTileFor(Tile.fromString(code));
                return Chip(
                  label: Text('${_label(code)} → ${_label(doraTile.code)}がドラ',
                      style: TextStyle(color: TileStyle.textColor(code))),
                  backgroundColor: TileStyle.backgroundColor(code),
                  side: BorderSide(color: TileStyle.borderColor(code)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (_riichi || _doubleRiichi) ...[
            _doraIndicatorSection('裏ドラ表示牌', _uraDoraIndicators),
          ],
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('赤ドラ: ${widget.akaDoraCount}枚(牌確認画面で入力済み)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('計算する', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
