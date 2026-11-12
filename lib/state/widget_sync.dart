// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/formatters.dart';
import '../data/models/contract_stage.dart';
import '../data/models/deal.dart';
import '../domain/access_policy.dart';
import '../domain/finance_calculator.dart';

/// What the home-screen widget shows. Everything is prepared (and
/// translated) here, so the native widget only places the texts.
class WidgetSnapshot {
  const WidgetSnapshot(this.values);

  final Map<String, Object> values;

  /// Number of stages after the first one (progress bar maximum).
  static final maxProgress = ContractStage.values.length - 1;

  /// [deals] are already filtered and redacted for the signed-in user.
  /// [selectedId] is the deal chosen for the widget; when it is missing or
  /// not visible, the latest active deal is shown.
  static WidgetSnapshot build({
    required List<Deal> deals,
    required String? selectedId,
    required AccessPolicy policy,
    required AppStrings s,
    required Fmt fmt,
    required bool hideAmounts,
  }) {
    final active = [
      for (final d in deals)
        if (!d.isDeleted && !d.stage.isClosed) d,
    ];
    Deal? deal;
    for (final d in deals) {
      if (d.id == selectedId && !d.isDeleted) deal = d;
    }
    deal ??= active.isNotEmpty ? active.first : null;
    deal ??= deals.isNotEmpty ? deals.first : null;

    final showSum = deal != null && policy.seesContractSums && !hideAmounts;
    final showProfit = deal != null && policy.seesFinance && !hideAmounts;
    final profit = deal == null ? null : DealProfit.of(deal);
    final c = deal?.buyerContract;

    return WidgetSnapshot({
      'w_count_label': s.widgetActiveContracts,
      'w_count': '${active.length}',
      'w_deal': deal == null ? s.widgetNoDeals : deal.displayTitle,
      'w_client': c == null || c.counterpartyName.trim().isEmpty
          ? ''
          : c.counterpartyName.trim(),
      'w_stage': deal == null
          ? ''
          : '${s.stage(deal.stage)} · ${deal.stage.index + 1}/${ContractStage.values.length}',
      'w_progress': deal?.stage.index ?? 0,
      'w_progress_max': maxProgress,
      'w_sum_label': s.widgetContractSum,
      'w_sum': showSum ? fmt.money(c!.goodsCost, c.currency) : '•••',
      'w_profit_label': s.netProfit,
      'w_profit': showProfit ? fmt.money(profit!.netProfitUsd) : '•••',
      'w_profit_negative': showProfit && profit!.netProfitUsd < 0,
      'w_updated': fmt.dateTime(DateTime.now()),
    });
  }
}

/// Writes data for the native widget. Replaced by a fake in tests.
abstract class WidgetBridge {
  Future<void> publish(Map<String, Object> values);
}

class HomeWidgetBridge implements WidgetBridge {
  const HomeWidgetBridge();

  /// Must match the Android provider class and the iOS widget kind.
  static const androidName = 'NexusWidgetProvider';
  static const iOSName = 'NexusWidget';
  static const appGroupId = 'group.uz.nexustrade.app';

  @override
  Future<void> publish(Map<String, Object> values) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      for (final e in values.entries) {
        await HomeWidget.saveWidgetData(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: androidName, iOSName: iOSName);
    } catch (e) {
      // No widget support on this platform (tests, desktop): ignore.
      debugPrint('home widget: $e');
    }
  }
}

class FakeWidgetBridge implements WidgetBridge {
  Map<String, Object> last = {};
  int calls = 0;

  @override
  Future<void> publish(Map<String, Object> values) async {
    last = values;
    calls++;
  }
}

/// Settings of the widget (stored in the encrypted settings box) and the
/// refresh of its data whenever deals or the user change.
class WidgetSync extends ChangeNotifier {
  WidgetSync(this._box, {WidgetBridge bridge = const HomeWidgetBridge()})
    : _bridge = bridge;

  final Box _box;
  final WidgetBridge _bridge;

  String? get selectedDealId => _box.get('widgetDealId') as String?;

  /// Hide the contract amount and the profit on the home screen
  /// (the widget is visible without unlocking the phone).
  bool get hideAmounts => _box.get('widgetHideAmounts') as bool? ?? false;

  Future<void> select(String? dealId) async {
    dealId == null
        ? await _box.delete('widgetDealId')
        : await _box.put('widgetDealId', dealId);
    notifyListeners();
  }

  Future<void> setHideAmounts(bool v) async {
    await _box.put('widgetHideAmounts', v);
    notifyListeners();
  }

  Future<void> refresh({
    required List<Deal> deals,
    required AccessPolicy policy,
    required AppStrings s,
    required Fmt fmt,
  }) => _bridge.publish(
    WidgetSnapshot.build(
      deals: deals,
      selectedId: selectedDealId,
      policy: policy,
      s: s,
      fmt: fmt,
      hideAmounts: hideAmounts,
    ).values,
  );
}
