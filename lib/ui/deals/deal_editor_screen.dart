import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/deal.dart';
import '../../data/models/trade_contract.dart';
import '../../domain/finance_calculator.dart';
import '../../state/deals_controller.dart';
import '../../state/settings_controller.dart';
import '../common/widgets.dart';
import 'widgets/contract_form.dart';
import 'widgets/finance_cards.dart';
import 'widgets/status_tracker.dart';

/// Create / edit a deal. Contract #1 and Contract #2 live on separate tabs
/// with independent forms; the third tab shows the combined profit.
class DealEditorScreen extends StatefulWidget {
  const DealEditorScreen({super.key, this.dealId});

  /// `null` creates a new deal.
  final String? dealId;

  static Future<void> open(BuildContext context, {String? dealId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: dealId == null,
          builder: (_) => DealEditorScreen(dealId: dealId),
        ),
      );

  @override
  State<DealEditorScreen> createState() => _DealEditorScreenState();
}

class _DealEditorScreenState extends State<DealEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Deal _draft;
  late final bool _isNew;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final deals = context.read<DealsController>();
    final settings = context.read<SettingsController>();
    final existing = widget.dealId == null ? null : deals.byId(widget.dealId!);
    _isNew = existing == null;
    _draft =
        existing ??
        deals.createDraft(
          companyName: settings.companyName,
          agencyFee: settings.defaultAgencyFee,
          vat: settings.defaultVat,
        );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onContractChanged(TradeContract c) {
    setState(() {
      _dirty = true;
      _draft = c.side == ContractSide.buyer
          ? _draft.copyWith(buyerContract: c)
          : _draft.copyWith(sellerContract: c);
    });
  }

  String? _validate() {
    final s = context.s;
    final checks = [(_draft.buyerContract, 0), (_draft.sellerContract, 1)];
    for (final (c, tab) in checks) {
      final title = s.contractTitle(c.side);
      if (c.number.trim().isEmpty) {
        _tabs.animateTo(tab);
        return s.fillContractNumber(title);
      }
      if (c.goodsRatePerUsd <= 0 || c.logisticsRatePerUsd <= 0) {
        _tabs.animateTo(tab);
        return '$title: ${s.invalidNumber}';
      }
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final error = _validate();
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await context.read<DealsController>().upsert(_draft);
    if (!mounted) return;
    _dirty = false;
    messenger.showSnackBar(SnackBar(content: Text(context.s.dealSaved)));
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final s = context.s;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.discardChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.discard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = context.watch<SettingsController>();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? s.newDeal : s.editDeal),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: Text(s.save),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.contractTitle(ContractSide.buyer)),
              Tab(text: s.contractTitle(ContractSide.seller)),
              Tab(text: s.summary),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: TabBarView(
            controller: _tabs,
            children: [
              ContractForm(
                key: const ValueKey('contract-buyer'),
                initial: _draft.buyerContract,
                onChanged: _onContractChanged,
                defaultAgencyFee: settings.defaultAgencyFee,
                defaultVat: settings.defaultVat,
              ),
              ContractForm(
                key: const ValueKey('contract-seller'),
                initial: _draft.sellerContract,
                onChanged: _onContractChanged,
                defaultAgencyFee: settings.defaultAgencyFee,
                defaultVat: settings.defaultVat,
              ),
              _SummaryTab(
                deal: _draft,
                onStageSelected: (stage) => setState(() {
                  _dirty = true;
                  _draft = _draft.withStage(stage);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.deal, required this.onStageSelected});

  final Deal deal;
  final ValueChanged<ContractStage> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        ProfitCard(profit: DealProfit.of(deal)),
        const SizedBox(height: 12),
        SectionCard(
          title: s.statusTracker,
          child: StatusTracker(
            stage: deal.stage,
            stageDates: deal.stageDates,
            onStageSelected: onStageSelected,
          ),
        ),
      ],
    );
  }
}
