import '../models/tile.dart';

class DoraCalculator {
  /// ドラ表示牌1枚から、実際のドラとなる牌を返す
  static Tile doraTileFor(Tile indicator) {
    if (indicator.isWindTile) {
      // 東(1)→南(2)→西(3)→北(4)→東(1)
      final next = indicator.number % 4 + 1;
      return Tile('z', next);
    }
    if (indicator.isDragonTile) {
      // 白(5)→發(6)→中(7)→白(5)
      final next = (indicator.number - 5 + 1) % 3 + 5;
      return Tile('z', next);
    }
    // 数牌: 9の次は1に戻る
    final next = indicator.number % 9 + 1;
    return Tile(indicator.suit, next);
  }

  /// 表示牌のリストと、実際の手牌全体(鳴き含む)から、ドラ合計本数(翻数)を計算する
  static int countDora(List<Tile> indicators, List<Tile> allHandTiles) {
    int total = 0;
    for (final indicator in indicators) {
      final doraTile = doraTileFor(indicator);
      total += allHandTiles.where((t) => t == doraTile).length;
    }
    return total;
  }

  /// 手牌の中に含まれる赤ドラ(赤5)の枚数を数える
  static int countAkaDora(List<Tile> allHandTiles) {
    return allHandTiles.where((t) => t.isRed).length;
  }
}
