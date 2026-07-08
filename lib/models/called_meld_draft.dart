import 'tile.dart';

/// UI側で鳴き(ポン・チー・カン)を組み立てるための入力用モデル
enum CalledMeldKind { pon, chi, ankan, minkan, shouminkan }

class CalledMeldDraft {
  final CalledMeldKind kind;
  final String baseTileCode; // ポン/カン: 対象牌。チー: 順子の最小牌
  final bool hasRedFive; // 5の牌を含む場合、赤ドラを含むか

  CalledMeldDraft({
    required this.kind,
    required this.baseTileCode,
    this.hasRedFive = false,
  });

  String get label {
    final base = Tile.fromString(baseTileCode);
    final prefix = switch (kind) {
      CalledMeldKind.pon => 'ポン',
      CalledMeldKind.chi => 'チー',
      CalledMeldKind.ankan => '暗槓',
      CalledMeldKind.minkan => '明槓',
      CalledMeldKind.shouminkan => '加槓',
    };
    if (kind == CalledMeldKind.chi) {
      final n = base.number;
      return '$prefix ($n-${n + 1}-${n + 2}${base.suit})';
    }
    return '$prefix (${base.code})';
  }

  /// 実際のMeldオブジェクトに変換する
  Meld toMeld() {
    final base = Tile.fromString(baseTileCode);
    switch (kind) {
      case CalledMeldKind.chi:
        final tiles = [
          base,
          Tile(base.suit, base.number + 1),
          Tile(base.suit, base.number + 2, isRed: hasRedFive && base.number + 2 == 5),
        ];
        return Meld(MeldType.shuntsu, MeldSource.chi, _applyRed(tiles, base));
      case CalledMeldKind.pon:
        return Meld(
          MeldType.kotsu,
          MeldSource.pon,
          _tripletTiles(base),
        );
      case CalledMeldKind.ankan:
        return Meld(MeldType.kantsu, MeldSource.ankan, _kanTiles(base));
      case CalledMeldKind.minkan:
        return Meld(MeldType.kantsu, MeldSource.minkan, _kanTiles(base));
      case CalledMeldKind.shouminkan:
        return Meld(MeldType.kantsu, MeldSource.shouminkan, _kanTiles(base));
    }
  }

  List<Tile> _applyRed(List<Tile> tiles, Tile base) {
    if (!hasRedFive) return tiles;
    return tiles.map((t) => t.number == 5 ? Tile(t.suit, 5, isRed: true) : t).toList();
  }

  List<Tile> _tripletTiles(Tile base) {
    if (base.number == 5 && !base.isHonor && hasRedFive) {
      return [Tile(base.suit, 5, isRed: true), Tile(base.suit, 5), Tile(base.suit, 5)];
    }
    return [base, base, base];
  }

  List<Tile> _kanTiles(Tile base) {
    if (base.number == 5 && !base.isHonor && hasRedFive) {
      return [
        Tile(base.suit, 5, isRed: true),
        Tile(base.suit, 5),
        Tile(base.suit, 5),
        Tile(base.suit, 5),
      ];
    }
    return [base, base, base, base];
  }

  /// この鳴きで消費される「概念上の面子スロット数」(常に1)
  int get slotCount => 1;
}
