/// 麻雀牌1枚を表すモデル
///
/// suit: 'm'=萬子, 'p'=筒子, 's'=索子, 'z'=字牌(1-4:東南西北, 5-7:白發中)
/// number: 1-9 (数牌) / 1-7 (字牌)
/// isRed: 赤ドラかどうか(5m/5p/5sのみ有効)
class Tile implements Comparable<Tile> {
  final String suit;
  final int number;
  final bool isRed;

  const Tile(this.suit, this.number, {this.isRed = false});

  /// "5m" "1z" のような文字列表記からTileを生成
  /// 赤ドラは "0m" "0p" "0s" と表記する慣習に対応
  factory Tile.fromString(String code) {
    final suit = code.substring(code.length - 1);
    var numStr = code.substring(0, code.length - 1);
    int number = int.parse(numStr);
    bool red = false;
    if (number == 0) {
      red = true;
      number = 5;
    }
    return Tile(suit, number, isRed: red);
  }

  bool get isHonor => suit == 'z';
  bool get isTerminal => !isHonor && (number == 1 || number == 9);
  bool get isTerminalOrHonor => isHonor || isTerminal;

  /// 字牌の種別: 1-4=風牌(東南西北), 5-7=三元牌(白發中)
  bool get isWindTile => isHonor && number >= 1 && number <= 4;
  bool get isDragonTile => isHonor && number >= 5 && number <= 7;

  String get code => '$number$suit';

  /// ソート・比較用のキー (萬子 < 筒子 < 索子 < 字牌 の順)
  int get sortKey {
    const suitOrder = {'m': 0, 'p': 1, 's': 2, 'z': 3};
    return suitOrder[suit]! * 10 + number;
  }

  @override
  int compareTo(Tile other) => sortKey.compareTo(other.sortKey);

  @override
  bool operator ==(Object other) =>
      other is Tile && other.suit == suit && other.number == number;

  @override
  int get hashCode => Object.hash(suit, number);

  @override
  String toString() => isRed ? '0$suit(赤$number)' : code;
}

/// 面子(メンツ)の種類
enum MeldType { shuntsu, kotsu, kantsu }

/// 副露(鳴き)の種類。closedは暗刻・暗槓・手牌内の順子
enum MeldSource { closed, chi, pon, minkan, ankan, shouminkan }

/// 面子(3枚 or 4枚のまとまり)
class Meld {
  final MeldType type;
  final MeldSource source;
  final List<Tile> tiles; // 構成牌(ソート済み)

  Meld(this.type, this.source, this.tiles);

  bool get isOpen =>
      source == MeldSource.chi ||
      source == MeldSource.pon ||
      source == MeldSource.minkan ||
      source == MeldSource.shouminkan;

  bool get isConcealedTriplet =>
      type == MeldType.kotsu && source == MeldSource.closed;
  bool get isConcealedKan => source == MeldSource.ankan;

  bool get isTriplet =>
      type == MeldType.kotsu || type == MeldType.kantsu;
  bool get isSequence => type == MeldType.shuntsu;
  bool get isKan =>
      type == MeldType.kantsu;

  Tile get first => tiles.first;
}
