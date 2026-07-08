import '../models/tile.dart';
import 'hand_parser.dart';

/// 局の状況やその他の条件をまとめたコンテキスト
class GameContext {
  final int roundWind; // 場風 1=東 2=南 3=西 4=北
  final int seatWind; // 自風 1=東 2=南 3=西 4=北
  final bool isDealer; // 親かどうか(点数計算にも使う)
  final bool isTsumo; // ツモかロンか(点数の支払い方法に影響)
  final bool riichi;
  final bool doubleRiichi;
  final bool ippatsu;
  final bool haitei; // 海底摸月
  final bool houtei; // 河底撈魚
  final bool rinshan; // 嶺上開花
  final bool chankan; // 槍槓
  final int doraCount;
  final int uraDoraCount;
  final int akaDoraCount;
  final int honba;

  GameContext({
    required this.roundWind,
    required this.seatWind,
    required this.isDealer,
    required this.isTsumo,
    this.riichi = false,
    this.doubleRiichi = false,
    this.ippatsu = false,
    this.haitei = false,
    this.houtei = false,
    this.rinshan = false,
    this.chankan = false,
    this.doraCount = 0,
    this.uraDoraCount = 0,
    this.akaDoraCount = 0,
    this.honba = 0,
  });
}

class YakuResult {
  final String name;
  final int han; // 面前時の翻数(食い下がりは呼び出し側で調整)
  final bool isYakuman;
  YakuResult(this.name, this.han, {this.isYakuman = false});
}

class YakuChecker {
  /// 通常形(4面子+雀頭)の役をチェックする
  static List<YakuResult> check(
    HandInput hand,
    Decomposition decomp,
    GameContext ctx,
  ) {
    final results = <YakuResult>[];
    final melds = decomp.melds;
    final pair = decomp.pair;
    final menzen = hand.isMenzen;
    final allTiles = [...melds.expand((m) => m.tiles), ...pair];

    bool allSequence = melds.every((m) => m.isSequence);
    bool allTriplet = melds.every((m) => m.isTriplet);

    // --- 役満 ---
    final yakumanList = <YakuResult>[];
    // 大三元
    final dragonTriplets =
        melds.where((m) => m.isTriplet && m.first.isDragonTile).length;
    if (dragonTriplets == 3) {
      yakumanList.add(YakuResult('大三元', 0, isYakuman: true));
    }
    // 四暗刻
    final concealedTriplets =
        melds.where((m) => m.isConcealedTriplet || m.isConcealedKan).length;
    if (concealedTriplets == 4) {
      yakumanList.add(YakuResult('四暗刻', 0, isYakuman: true));
    }
    // 字一色
    if (allTiles.every((t) => t.isHonor)) {
      yakumanList.add(YakuResult('字一色', 0, isYakuman: true));
    }
    // 清老頭
    if (allTiles.every((t) => t.isTerminal)) {
      yakumanList.add(YakuResult('清老頭', 0, isYakuman: true));
    }
    // 緑一色 (索子の2,3,4,6,8と發のみ)
    const greenAllowed = {'2s', '3s', '4s', '6s', '8s', '6z'};
    if (allTiles.every((t) => greenAllowed.contains(t.code))) {
      yakumanList.add(YakuResult('緑一色', 0, isYakuman: true));
    }
    // 小四喜/大四喜
    final windTriplets =
        melds.where((m) => m.isTriplet && m.first.isWindTile).length;
    if (windTriplets == 4) {
      yakumanList.add(YakuResult('大四喜', 0, isYakuman: true));
    } else if (windTriplets == 3 && pair.first.isWindTile) {
      yakumanList.add(YakuResult('小四喜', 0, isYakuman: true));
    }
    if (yakumanList.isNotEmpty) return yakumanList; // 役満成立時は他の役は数えない

    // --- 通常役 ---
    // 立直/ダブル立直
    if (ctx.doubleRiichi) {
      results.add(YakuResult('ダブル立直', 2));
    } else if (ctx.riichi) {
      results.add(YakuResult('立直', 1));
    }
    if (ctx.ippatsu && (ctx.riichi || ctx.doubleRiichi)) {
      results.add(YakuResult('一発', 1));
    }
    // 門前清自摸和
    if (menzen && hand.isTsumo) {
      results.add(YakuResult('門前清自摸和', 1));
    }
    // 平和 (面前・全て順子・雀頭が役牌以外・両面待ち)
    if (menzen &&
        allSequence &&
        !_isYakuhaiTile(pair.first, ctx)) {
      // 待ちの形の厳密判定は簡略化し、ここでは順子構成+雀頭条件のみチェック
      results.add(YakuResult('平和', 1));
    }
    // 断么九
    if (allTiles.every((t) => !t.isTerminalOrHonor)) {
      results.add(YakuResult('断么九', 1));
    }
    // 一盃口(面前限定)
    if (menzen) {
      final seqs = melds.where((m) => m.isSequence).map((m) => m.tiles.map((t) => t.code).join()).toList();
      final seqCounts = <String, int>{};
      for (final s in seqs) {
        seqCounts[s] = (seqCounts[s] ?? 0) + 1;
      }
      final pairs = seqCounts.values.where((c) => c >= 2).length;
      if (pairs >= 1) {
        results.add(YakuResult('一盃口', 1));
      }
    }
    // 役牌(風牌・三元牌)
    for (final m in melds.where((m) => m.isTriplet)) {
      if (m.first.isDragonTile) {
        results.add(YakuResult('役牌(三元牌)', 1));
      } else if (m.first.isWindTile) {
        if (m.first.number == ctx.roundWind) {
          results.add(YakuResult('役牌(場風)', 1));
        }
        if (m.first.number == ctx.seatWind) {
          results.add(YakuResult('役牌(自風)', 1));
        }
      }
    }
    // 三色同順
    if (_hasSanshokuDoujun(melds)) {
      results.add(YakuResult('三色同順', menzen ? 2 : 1));
    }
    // 一気通貫
    if (_hasIttsuu(melds)) {
      results.add(YakuResult('一気通貫', menzen ? 2 : 1));
    }
    // 全帯幺/純全帯幺
    if (_allSetsContainTerminalOrHonor(melds, pair)) {
      final hasHonor = allTiles.any((t) => t.isHonor);
      if (hasHonor) {
        results.add(YakuResult('混全帯幺九', menzen ? 2 : 1));
      } else {
        results.add(YakuResult('純全帯幺九', menzen ? 3 : 2));
      }
    }
    // 対々和
    if (allTriplet) {
      results.add(YakuResult('対々和', 2));
    }
    // 三暗刻
    if (concealedTriplets == 3) {
      results.add(YakuResult('三暗刻', 2));
    }
    // 混老頭
    if (allTiles.every((t) => t.isTerminalOrHonor) && !allTiles.every((t) => t.isHonor)) {
      results.add(YakuResult('混老頭', 2));
    }
    // 三色同刻
    if (_hasSanshokuDoukou(melds)) {
      results.add(YakuResult('三色同刻', 2));
    }
    // 混一色/清一色
    final suitsUsed = allTiles.map((t) => t.suit).toSet();
    final nonHonorSuits = suitsUsed.where((s) => s != 'z').toSet();
    if (nonHonorSuits.length == 1) {
      if (suitsUsed.contains('z')) {
        results.add(YakuResult('混一色', menzen ? 3 : 2));
      } else {
        results.add(YakuResult('清一色', menzen ? 6 : 5));
      }
    }
    // 状況役
    if (ctx.haitei) results.add(YakuResult('海底摸月', 1));
    if (ctx.houtei) results.add(YakuResult('河底撈魚', 1));
    if (ctx.rinshan) results.add(YakuResult('嶺上開花', 1));
    if (ctx.chankan) results.add(YakuResult('槍槓', 1));

    return results;
  }

  /// 七対子の役チェック
  static List<YakuResult> checkChiitoitsu(HandInput hand, GameContext ctx) {
    final results = <YakuResult>[YakuResult('七対子', 2)];
    final tiles = hand.concealedTiles.toSet();
    if (ctx.riichi || ctx.doubleRiichi) {
      results.add(ctx.doubleRiichi ? YakuResult('ダブル立直', 2) : YakuResult('立直', 1));
    }
    if (hand.isTsumo) results.add(YakuResult('門前清自摸和', 1));
    if (tiles.every((t) => !t.isTerminalOrHonor)) {
      results.add(YakuResult('断么九', 1));
    }
    final suits = tiles.map((t) => t.suit).toSet();
    final nonHonor = suits.where((s) => s != 'z').toSet();
    if (nonHonor.length == 1) {
      results.add(suits.contains('z') ? YakuResult('混一色', 3) : YakuResult('清一色', 6));
    }
    if (tiles.every((t) => t.isTerminalOrHonor) && !tiles.every((t) => t.isHonor)) {
      results.add(YakuResult('混老頭', 2));
    }
    return results;
  }

  static bool _isYakuhaiTile(Tile t, GameContext ctx) {
    if (t.isDragonTile) return true;
    if (t.isWindTile && (t.number == ctx.roundWind || t.number == ctx.seatWind)) return true;
    return false;
  }

  static bool _hasSanshokuDoujun(List<Meld> melds) {
    final seqs = melds.where((m) => m.isSequence);
    final byStart = <int, Set<String>>{};
    for (final m in seqs) {
      byStart.putIfAbsent(m.first.number, () => {}).add(m.first.suit);
    }
    return byStart.values.any((suits) => suits.containsAll({'m', 'p', 's'}));
  }

  static bool _hasSanshokuDoukou(List<Meld> melds) {
    final triplets = melds.where((m) => m.isTriplet);
    final byNumber = <int, Set<String>>{};
    for (final m in triplets) {
      byNumber.putIfAbsent(m.first.number, () => {}).add(m.first.suit);
    }
    return byNumber.values.any((suits) => suits.containsAll({'m', 'p', 's'}));
  }

  static bool _hasIttsuu(List<Meld> melds) {
    final seqs = melds.where((m) => m.isSequence).toList();
    for (final suit in ['m', 'p', 's']) {
      final starts = seqs
          .where((m) => m.first.suit == suit)
          .map((m) => m.first.number)
          .toSet();
      if (starts.containsAll({1, 4, 7})) return true;
    }
    return false;
  }

  static bool _allSetsContainTerminalOrHonor(List<Meld> melds, List<Tile> pair) {
    if (!pair.first.isTerminalOrHonor) return false;
    for (final m in melds) {
      if (m.isSequence) {
        if (!m.tiles.any((t) => t.isTerminal)) return false;
      } else {
        if (!m.first.isTerminalOrHonor) return false;
      }
    }
    return true;
  }
}
