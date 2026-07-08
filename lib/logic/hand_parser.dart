import '../models/tile.dart';

/// 手牌全体の入力情報
class HandInput {
  final List<Tile> concealedTiles; // 手牌の中の「面前」の牌(和了牌を含む)
  final List<Meld> calledMelds; // ポン・チー・カンなど既に確定している面子
  final Tile winningTile;
  final bool isTsumo;

  HandInput({
    required this.concealedTiles,
    required this.calledMelds,
    required this.winningTile,
    required this.isTsumo,
  });

  bool get isMenzen => calledMelds.every((m) => !m.isOpen);
}

/// 1通りの分解結果: 面子4つ(呼び出し済み含む) + 雀頭
class Decomposition {
  final List<Meld> melds; // 4面子(鳴き含む)
  final List<Tile> pair; // 雀頭(2枚)
  Decomposition(this.melds, this.pair);
}

class HandParser {
  /// 標準形(4面子+雀頭)の全ての分解パターンを返す。
  /// 分解不可能なら空リスト。
  static List<Decomposition> parseStandard(HandInput hand) {
    final results = <Decomposition>[];
    final calledCount = hand.calledMelds.length;
    final neededSets = 4 - calledCount; // 手牌側で作るべき面子数

    // 手牌(鳴き牌を除く部分)をスートごとに集計
    final tiles = List<Tile>.from(hand.concealedTiles)..sort();

    // 雀頭候補を総当たり
    final grouped = <String, List<Tile>>{};
    for (final t in tiles) {
      grouped.putIfAbsent(t.suit, () => []).add(t);
    }

    // 出現する牌の種類ごとに、雀頭にできる牌(2枚以上ある牌)を試す
    final pairCandidates = <Tile>{};
    for (final t in tiles) {
      if (tiles.where((x) => x == t).length >= 2) pairCandidates.add(t);
    }

    for (final pairTile in pairCandidates) {
      final remaining = List<Tile>.from(tiles);
      remaining.remove(pairTile);
      remaining.remove(pairTile);

      final remGrouped = <String, List<Tile>>{};
      for (final t in remaining) {
        remGrouped.putIfAbsent(t.suit, () => []).add(t);
      }

      // 各スートで面子分解を試みる(全組み合わせの直積)
      final perSuitOptions = <String, List<List<List<Tile>>>>{};
      bool possible = true;
      for (final suit in remGrouped.keys) {
        final opts = _decomposeSuit(remGrouped[suit]!, suit);
        if (opts.isEmpty) {
          possible = false;
          break;
        }
        perSuitOptions[suit] = opts;
      }
      if (!possible) continue;

      // 直積を取って、面子総数が neededSets と一致するものを採用
      final suits = perSuitOptions.keys.toList();
      void combine(int idx, List<List<Tile>> acc) {
        if (idx == suits.length) {
          if (acc.length != neededSets) return;
          final melds = <Meld>[];
          for (final group in acc) {
            melds.add(_toMeld(group));
          }
          results.add(Decomposition([...hand.calledMelds, ...melds], [pairTile, pairTile]));
          return;
        }
        for (final option in perSuitOptions[suits[idx]]!) {
          combine(idx + 1, [...acc, ...option]);
        }
      }

      combine(0, []);
    }

    return results;
  }

  static Meld _toMeld(List<Tile> group) {
    final isTriplet = group[0] == group[1];
    return Meld(
      isTriplet ? MeldType.kotsu : MeldType.shuntsu,
      MeldSource.closed,
      group,
    );
  }

  /// 1スート分の牌リストを、順子/刻子の組み合わせに分解する。
  /// 戻り値: 分解パターンのリスト。各パターンは [ [3枚組], [3枚組], ... ] の形。
  static List<List<List<Tile>>> _decomposeSuit(List<Tile> tiles, String suit) {
    if (tiles.isEmpty) return [[]];
    final sorted = List<Tile>.from(tiles)..sort();
    final results = <List<List<Tile>>>[];

    void solve(List<Tile> remaining, List<List<Tile>> acc) {
      if (remaining.isEmpty) {
        results.add(List.from(acc));
        return;
      }
      final first = remaining.first;

      // 刻子を試す
      final tripletCandidates =
          remaining.where((t) => t == first).toList();
      if (tripletCandidates.length >= 3) {
        final next = List<Tile>.from(remaining);
        for (int i = 0; i < 3; i++) {
          next.remove(first);
        }
        acc.add([first, first, first]);
        solve(next, acc);
        acc.removeLast();
      }

      // 順子を試す(字牌は順子不可)
      if (suit != 'z') {
        final second = Tile(suit, first.number + 1);
        final third = Tile(suit, first.number + 2);
        if (remaining.contains(second) && remaining.contains(third)) {
          final next = List<Tile>.from(remaining);
          next.remove(second);
          next.remove(third);
          next.remove(first);
          acc.add([first, second, third]);
          solve(next, acc);
          acc.removeLast();
        }
      }
    }

    solve(sorted, []);
    return results;
  }

  /// 七対子判定: 手牌14枚が7つの対子であるか
  static bool isChiitoitsu(HandInput hand) {
    if (hand.calledMelds.isNotEmpty) return false; // 七対子は面前限定
    final tiles = List<Tile>.from(hand.concealedTiles)..sort();
    if (tiles.length != 14) return false;
    for (int i = 0; i < 14; i += 2) {
      if (tiles[i] != tiles[i + 1]) return false;
    }
    // 同じ牌4枚(2対子分)は七対子では不可
    final counts = <Tile, int>{};
    for (final t in tiles) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts.values.every((c) => c == 2);
  }

  /// 国士無双判定: 13種類の么九牌+1枚が揃っているか
  static bool isKokushi(HandInput hand) {
    if (hand.calledMelds.isNotEmpty) return false;
    final tiles = List<Tile>.from(hand.concealedTiles);
    if (tiles.length != 14) return false;
    if (!tiles.every((t) => t.isTerminalOrHonor)) return false;
    final unique = tiles.toSet();
    // 么九牌13種類全てが最低1枚ずつ含まれている必要がある
    const requiredKinds = 13; // 1m9m1p9p1s9s+字牌7種
    return unique.length == requiredKinds;
  }

  /// 国士無双十三面待ちか(単騎待ちの牌が既に2枚あったか)
  static bool isKokushiJusanmen(HandInput hand) {
    final counts = <Tile, int>{};
    for (final t in hand.concealedTiles) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return (counts[hand.winningTile] ?? 0) == 2;
  }
}
