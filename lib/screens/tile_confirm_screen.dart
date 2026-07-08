import 'package:flutter/material.dart';
import '../models/called_meld_draft.dart';
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

  @override
  void initState() {
    super.initState();
    _tiles = List.from(widget.initialTileCodes);
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
