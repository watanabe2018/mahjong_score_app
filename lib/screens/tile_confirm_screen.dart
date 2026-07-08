import 'package:flutter/material.dart';
import '../models/called_meld_draft.dart';
import '../models/tile.dart';
import '../logic/dora_calculator.dart';
import 'input_screen.dart';
import 'widgets/tile_picker_dialog.dart';
import 'widgets/tile_style.dart';

class TileConfirmScreen extends StatefulWidget {
  final List<String> initialTileCodes;
  final String recognitionNotes;
  const TileConfirmScreen({
    super.key,
    required this.initialTileCodes,
    required this.recognitionNotes,
  });

  @override
  State<TileConfirmScreen> createState() => _TileConfirmScreenState();
}

class _TileConfirmScreenState extends State<TileConfirmScreen> {
  late List<String> _tiles;
  final List<CalledMeldDraft> _melds = [];
  final List<String> _doraIndicators = [];
  int _akaDoraCount = 0;

  @override
  void initState() {
    super.initState();
    _tiles = List.from(widget.initialTileCodes);
    // 認識結果や手動選択で既に赤5として入力されている枚数を初期値にする
    _akaDoraCount = _tiles.where((c) => c.startsWith('0')).length;
  }

  /// 面前(手の中)で必要な残り牌数。鳴き1つにつき3枚分減る。
  int get _requiredConcealedCount => 14 - _melds.length * 3;

  void _removeAt(int index) => setState(() => _tiles.removeAt(index));

  void _add(String code) {
    if (_tiles.length >= _requiredConcealedCount) return;
    setState(() => _tiles.add(code));
  }

  Future<void> _addMeld(CalledMeldKind kind) async {
    final isChi = kind == CalledMeldKind.chi;
    final code = await TilePickerDialog.show(context, allowRed: true, chiOnly: isChi);
    if (code == null) return;
    final hasRed = code.startsWith('0');
    final normalizedCode = hasRed ? '5${code.substring(1)}' : code;
    setState(() {
      _melds.add(CalledMeldDraft(kind: kind, baseTileCode: normalizedCode, hasRedFive: hasRed));
      while (_tiles.length > _requiredConcealedCount) {
        _tiles.removeLast();
      }
    });
  }

  void _removeMeld(int index) => setState(() => _melds.removeAt(index));

  Future<void> _addDoraIndicator() async {
    final code = await TilePickerDialog.show(context);
    if (code == null) return;
    setState(() => _doraIndicators.add(code));
  }

  List<String> _allTileCodes() {
    final list = <String>[];
    for (final suit in ['m', 'p', 's']) {
      for (int n = 1; n <= 9; n++) {
        list.add('$n$suit');
      }
    }
    for (int n = 1; n <= 7; n++) {
      list.add('${n}z');
    }
    return list;
  }

  String _label(String code) {
    const honorNames = {
      '1z': '東', '2z': '南', '3z': '西', '4z': '北',
      '5z': '白', '6z': '發', '7z': '中',
    };
    if (honorNames.containsKey(code)) return honorNames[code]!;
    if (code == '0m') return '赤5m';
    if (code == '0p') return '赤5p';
    if (code == '0s') return '赤5s';
    return code;
  }

  bool get _canProceed => _tiles.length == _requiredConcealedCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('牌を確認・修正')),
      body: Column(
        children: [
          if (widget.recognitionNotes.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: Text('認識メモ: ${widget.recognitionNotes}'),
            ),

          // --- 鳴き(ポン・チー・カン)セクション ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('鳴き', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                PopupMenuButton<CalledMeldKind>(
                  onSelected: _addMeld,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: CalledMeldKind.pon, child: Text('ポンを追加')),
                    PopupMenuItem(value: CalledMeldKind.chi, child: Text('チーを追加')),
                    PopupMenuItem(value: CalledMeldKind.minkan, child: Text('明槓を追加')),
                    PopupMenuItem(value: CalledMeldKind.ankan, child: Text('暗槓を追加')),
                    PopupMenuItem(value: CalledMeldKind.shouminkan, child: Text('加槓を追加')),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.add, size: 18),
                    label: Text('鳴きを追加'),
                  ),
                ),
              ],
            ),
          ),
          if (_melds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_melds.length, (i) {
                  return InputChip(
                    label: Text(_melds[i].label),
                    onDeleted: () => _removeMeld(i),
                  );
                }),
              ),
            ),
          const Divider(),

          // --- 手牌(面前部分)セクション ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('手牌 (${_tiles.length}/$_requiredConcealedCount枚) — タップで削除',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 130,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_tiles.length, (i) {
                    final code = _tiles[i];
                    return InputChip(
                      label: Text(_label(code), style: TextStyle(fontSize: 16, color: TileStyle.textColor(code))),
                      backgroundColor: TileStyle.backgroundColor(code),
                      side: BorderSide(color: TileStyle.borderColor(code)),
                      deleteIconColor: TileStyle.textColor(code),
                      onDeleted: () => _removeAt(i),
                    );
                  }),
                ),
              ),
            ),
          ),
          const Divider(),

          // --- ドラ表示牌セクション ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text('ドラ表示牌', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addDoraIndicator,
                  icon: const Icon(Icons.add),
                  label: const Text('表示牌を追加'),
                ),
              ],
            ),
          ),
          if (_doraIndicators.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_doraIndicators.length, (i) {
                  final indicator = Tile.fromString(_doraIndicators[i]);
                  final doraTile = DoraCalculator.doraTileFor(indicator);
                  return InputChip(
                    label: Text('${_label(_doraIndicators[i])} → ${_label(doraTile.code)}がドラ',
                        style: TextStyle(color: TileStyle.textColor(_doraIndicators[i]))),
                    backgroundColor: TileStyle.backgroundColor(_doraIndicators[i]),
                    side: BorderSide(color: TileStyle.borderColor(_doraIndicators[i])),
                    onDeleted: () => setState(() => _doraIndicators.removeAt(i)),
                  );
                }),
              ),
            ),
          const Divider(),

          // --- 赤ドラ枚数セクション ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text('赤ドラ枚数', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => setState(() => _akaDoraCount = (_akaDoraCount - 1).clamp(0, 4)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_akaDoraCount 枚', style: const TextStyle(fontSize: 16)),
                IconButton(
                  onPressed: () => setState(() => _akaDoraCount = (_akaDoraCount + 1).clamp(0, 4)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('※ 手牌で「赤5m」等を選んでいれば自動で反映されますが、ここで調整もできます',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
                childAspectRatio: 1,
              ),
              itemCount: _allTileCodes().length,
              itemBuilder: (context, i) {
                final code = _allTileCodes()[i];
                return GestureDetector(
                  onTap: () => _add(code),
                  onLongPress: () {
                    if (code == '5m' || code == '5p' || code == '5s') {
                      _add('0${code.substring(1)}');
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.all(2),
                    color: TileStyle.backgroundColor(code),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: TileStyle.borderColor(code)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(_label(code), style: TextStyle(color: TileStyle.textColor(code), fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canProceed
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => InputScreen(
                              tileCodes: _tiles,
                              calledMelds: _melds,
                              doraIndicators: _doraIndicators,
                              akaDoraCount: _akaDoraCount,
                            ),
                          ),
                        )
                    : null,
                child: Text(_canProceed
                    ? '次へ進む'
                    : 'あと${_requiredConcealedCount - _tiles.length}枚必要です'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
