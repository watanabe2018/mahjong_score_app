import '../models/tile.dart';
import 'hand_parser.dart';
import 'yaku_checker.dart';

enum WaitType { ryanmen, kanchan, penchan, tanki, shanpo }

class FuResult {
  final int fu;
  final WaitType waitType;
  final List<String> breakdown; // 内訳(表示用)
  FuResult(this.fu, this.waitType, this.breakdown);
}

class FuCalculator {
  static FuResult calculate(
    HandInput hand,
    Decomposition decomp,
    GameContext ctx,
  ) {
    final breakdown = <String>[];
    int fu = 20;
    breakdown.add('副底 20符');

    final waitType = _detectWaitType(hand, decomp);

    // 待ちによる符
    switch (waitType) {
      case WaitType.kanchan:
        fu += 2;
        breakdown.add('嵌張待ち +2符');
        break;
      case WaitType.penchan:
        fu += 2;
        breakdown.add('辺張待ち +2符');
        break;
      case WaitType.tanki:
        fu += 2;
        breakdown.add('単騎待ち +2符');
        break;
      case WaitType.ryanmen:
      case WaitType.shanpo:
        break; // 0符
    }

    // 面前ロン加符
    final menzen = hand.isMenzen;
    if (menzen && !hand.isTsumo) {
      fu += 10;
      breakdown.add('門前加符(ロン) +10符');
    }

    // ツモ符(平和ツモは例外的に加算しないが、最終的に丸めた結果20符になるため
    // ここでは加算しておき、平和ツモは別途チェックして20符固定にする)
    bool isPinfu = menzen &&
        decomp.melds.every((m) => m.isSequence) &&
        waitType == WaitType.ryanmen;
    if (hand.isTsumo && !isPinfu) {
      fu += 2;
      breakdown.add('自摸符 +2符');
    }

    // 面子ごとの符
    for (final m in decomp.melds) {
      if (m.isSequence) continue;
      final isTerminalHonor = m.first.isTerminalOrHonor;
      int meldFu;
      String label;
      if (m.source == MeldSource.ankan) {
        meldFu = isTerminalHonor ? 32 : 16;
        label = '暗槓(${m.first})';
      } else if (m.source == MeldSource.minkan || m.source == MeldSource.shouminkan) {
        meldFu = isTerminalHonor ? 16 : 8;
        label = '明槓(${m.first})';
      } else if (m.source == MeldSource.closed) {
        // 手牌内の刻子: 和了牌がこの刻子を完成させた場合(ロン)は明刻扱い
        final isWinningTriplet =
            waitType == WaitType.shanpo && m.tiles.contains(hand.winningTile);
        final treatAsOpen = isWinningTriplet && !hand.isTsumo;
        meldFu = treatAsOpen
            ? (isTerminalHonor ? 4 : 2)
            : (isTerminalHonor ? 8 : 4);
        label = treatAsOpen ? '明刻(${m.first})' : '暗刻(${m.first})';
      } else {
        // pon
        meldFu = isTerminalHonor ? 4 : 2;
        label = '明刻(${m.first})';
      }
      fu += meldFu;
      breakdown.add('$label +$meldFu符');
    }

    // 雀頭の符(役牌の場合)
    final pairTile = decomp.pair.first;
    int pairFu = 0;
    if (pairTile.isDragonTile) {
      pairFu = 2;
    } else if (pairTile.isWindTile) {
      if (pairTile.number == ctx.roundWind) pairFu += 2;
      if (pairTile.number == ctx.seatWind) pairFu += 2;
    }
    if (pairFu > 0) {
      fu += pairFu;
      breakdown.add('雀頭(役牌) +$pairFu符');
    }

    // 平和ツモは20符固定、平和ロンは自動的に30符(20+10門前ロン)
    if (isPinfu && hand.isTsumo) {
      return FuResult(20, waitType, ['平和自摸: 20符固定']);
    }

    // 10符単位に切り上げ
    final rounded = ((fu + 9) ~/ 10) * 10;
    if (rounded != fu) {
      breakdown.add('切り上げ: $fu符 → $rounded符');
    }
    return FuResult(rounded, waitType, breakdown);
  }

  /// 七対子は常に25符固定
  static FuResult chiitoitsuFu() {
    return FuResult(25, WaitType.tanki, ['七対子: 25符固定']);
  }

  static WaitType _detectWaitType(HandInput hand, Decomposition decomp) {
    final winTile = hand.winningTile;

    // 雀頭で和了 → 単騎
    if (decomp.pair.contains(winTile) &&
        !decomp.melds.any((m) => m.tiles.contains(winTile))) {
      return WaitType.tanki;
    }

    for (final m in decomp.melds) {
      if (!m.tiles.contains(winTile)) continue;
      if (m.isTriplet) {
        return WaitType.shanpo;
      }
      if (m.isSequence) {
        final sorted = List<Tile>.from(m.tiles)..sort();
        final numbers = sorted.map((t) => t.number).toList();
        final winIndex = sorted.indexWhere((t) => t == winTile);
        // 123待ちで3、789待ちで7 → 辺張
        if ((numbers[0] == 1 && winIndex == 2) ||
            (numbers[2] == 9 && winIndex == 0)) {
          return WaitType.penchan;
        }
        // 真ん中の牌で和了 → 嵌張
        if (winIndex == 1) {
          return WaitType.kanchan;
        }
        return WaitType.ryanmen;
      }
    }
    return WaitType.ryanmen;
  }
}
