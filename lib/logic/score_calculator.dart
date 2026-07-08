import 'hand_parser.dart';
import 'yaku_checker.dart';
import 'fu_calculator.dart';

class ScoreResult {
  final int han;
  final int fu;
  final List<String> yakuNames;
  final String limitName; // "満貫" "跳満" "倍満" "三倍満" "役満" または ""
  final int totalPoints; // 支払い合計(本場込み)
  final Map<String, int> payments; // 誰がいくら払うか("dealer"/"nonDealerEach"/"each")
  final List<String> fuBreakdown;

  ScoreResult({
    required this.han,
    required this.fu,
    required this.yakuNames,
    required this.limitName,
    required this.totalPoints,
    required this.payments,
    required this.fuBreakdown,
  });
}

class ScoreCalculator {
  /// メインエントリポイント。
  /// 役無しの場合は例外(StateError)を投げる。
  static ScoreResult calculate(HandInput hand, GameContext ctx) {
    // 国士無双
    if (HandParser.isKokushi(hand)) {
      return _buildYakumanResult(
        ['国士無双${HandParser.isKokushiJusanmen(hand) ? "(十三面待ち)" : ""}'],
        1,
        ctx,
      );
    }

    // 七対子
    if (HandParser.isChiitoitsu(hand)) {
      final yaku = YakuChecker.checkChiitoitsu(hand, ctx);
      final fuResult = FuCalculator.chiitoitsuFu();
      return _buildResult(yaku, fuResult, ctx);
    }

    // 通常形: 全ての分解パターンを試し、最も点数が高くなるものを採用
    final decomps = HandParser.parseStandard(hand);
    if (decomps.isEmpty) {
      throw StateError('手牌を4面子1雀頭に分解できません。入力牌を確認してください。');
    }

    ScoreResult? best;
    for (final decomp in decomps) {
      final yaku = YakuChecker.check(hand, decomp, ctx);
      if (yaku.isEmpty) continue; // この分解では役無し→他の分解を試す
      if (yaku.any((y) => y.isYakuman)) {
        final result = _buildYakumanResult(
          yaku.map((y) => y.name).toList(),
          yaku.length,
          ctx,
        );
        if (best == null || result.totalPoints > best.totalPoints) best = result;
        continue;
      }
      final fuResult = FuCalculator.calculate(hand, decomp, ctx);
      final result = _buildResult(yaku, fuResult, ctx);
      if (best == null || result.totalPoints > best.totalPoints) {
        best = result;
      }
    }

    if (best == null) {
      throw StateError('役がありません(役無しは和了できません)。立直の有無や条件を確認してください。');
    }
    return best;
  }

  static ScoreResult _buildResult(
    List<YakuResult> yaku,
    FuResult fuResult,
    GameContext ctx,
  ) {
    int han = yaku.fold(0, (sum, y) => sum + y.han);
    han += ctx.doraCount + ctx.uraDoraCount + ctx.akaDoraCount;

    final names = yaku.map((y) => y.name).toList();
    if (ctx.doraCount > 0) names.add('ドラ ${ctx.doraCount}');
    if (ctx.uraDoraCount > 0) names.add('裏ドラ ${ctx.uraDoraCount}');
    if (ctx.akaDoraCount > 0) names.add('赤ドラ ${ctx.akaDoraCount}');

    final fu = fuResult.fu;
    final basePoints = _basePoints(fu, han);
    final limitName = _limitName(han, basePoints);
    final payments = _paymentTable(basePoints, ctx);
    final total = payments.values.fold(0, (a, b) => a + b);

    return ScoreResult(
      han: han,
      fu: fu,
      yakuNames: names,
      limitName: limitName,
      totalPoints: total,
      payments: payments,
      fuBreakdown: fuResult.breakdown,
    );
  }

  static ScoreResult _buildYakumanResult(
    List<String> names,
    int yakumanCount,
    GameContext ctx,
  ) {
    final basePoints = 8000 * yakumanCount;
    final payments = _paymentTable(basePoints, ctx);
    final total = payments.values.fold(0, (a, b) => a + b);
    return ScoreResult(
      han: 0,
      fu: 0,
      yakuNames: names,
      limitName: yakumanCount > 1 ? 'ダブル役満' : '役満',
      totalPoints: total,
      payments: payments,
      fuBreakdown: const [],
    );
  }

  static int _basePoints(int fu, int han) {
    if (han >= 11) return 6000; // 三倍満
    if (han >= 8) return 4000; // 倍満
    if (han >= 6) return 3000; // 跳満
    if (han == 5) return 2000; // 満貫
    final base = fu * (1 << (2 + han));
    return base > 2000 ? 2000 : base;
  }

  static String _limitName(int han, int basePoints) {
    if (han >= 11) return '三倍満';
    if (han >= 8) return '倍満';
    if (han >= 6) return '跳満';
    if (han == 5 || basePoints == 2000) return '満貫';
    return '';
  }

  static int _roundUp100(int value) => ((value + 99) ~/ 100) * 100;

  /// 支払い内訳を計算する。honbaは1本場につき300点(ロン)/100点(ツモ、各家)を加算。
  static Map<String, int> _paymentTable(int basePoints, GameContext ctx) {
    final honbaRon = ctx.honba * 300;
    final honbaTsumoEach = ctx.honba * 100;

    if (ctx.isTsumo) {
      // ツモ
      if (ctx.isDealer) {
        final each = _roundUp100(basePoints * 2) + honbaTsumoEach;
        return {'nonDealerEach(x3)': each};
      } else {
        final fromDealer = _roundUp100(basePoints * 2) + honbaTsumoEach;
        final fromNonDealer = _roundUp100(basePoints * 1) + honbaTsumoEach;
        return {
          'dealer': fromDealer,
          'nonDealerEach(x2)': fromNonDealer,
        };
      }
    } else {
      // ロン
      final multiplier = ctx.isDealer ? 6 : 4;
      final payment = _roundUp100(basePoints * multiplier) + honbaRon;
      return {'ronPayer': payment};
    }
  }
}
