import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/deal.dart';
import '../../data/models/trade_contract.dart';
import '../../domain/finance_calculator.dart';
import '../../state/clients_controller.dart';
import '../../state/deals_controller.dart';
import '../../state/settings_controller.dart';
import '../common/widgets.dart';
import 'widgets/contract_form.dart';
import 'widgets/deal_kind_widgets.dart';
import 'widgets/finance_cards.dart';
import 'widgets/status_tracker.dart';

/// Create / edit a deal. Contract #1 and Contract #2 live on separate tabs
/// with independent forms; the third tab shows the combined profit.
class DealEditorScreen extends StatefulWidget {
  const DealEditorScreen({super.key, this.dealId, this.draft});

  /// `null` creates a new deal.
  final String? dealId;

  /// Prefilled new deal (e.g. created from a price calculation).
  final Deal? draft;

  static Future<void> open(
    BuildContext context, {
    String? dealId,
    Deal? draft,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: dealId == null,
      builder: (_) => DealEditorScreen(dealId: dealId, draft: draft),
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
    _dirty = widget.draft != null;
    _draft =
        existing ??
        widget.draft ??
        deals.createDraft(
          companyName: settings.companyName,
          agencyFee: settings.defaultAgencyFee,
          agentVat: settings.defaultAgentVat,
          vat: settings.defaultVat,
          vatRefund: settings.defaultVatRefund,
          vatShare: settings.defaultVatShare,
          profitPerUnit: settings.defaultProfitPerUnit,
          unit: settings.defaultUnit,
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
      _normalize();
    });
  }

  void _changeDeal(Deal d) => setState(() {
    _dirty = true;
    _draft = d;
    _normalize();
  });

  /// Keeps derived values consistent: one number/date in a three-party
  /// contract, and the buyer price calculated from the margin.
  void _normalize() {
    var d = _draft;
    if (d.isSingleContract) {
      final b = d.buyerContract, sc = d.sellerContract;
      if (sc.number != b.number ||
          sc.date != b.date ||
          sc.intermediaryName != b.intermediaryName) {
        d = d.copyWith(
          sellerContract: sc.copyWith(
            number: b.number,
            date: b.date,
            intermediaryName: b.intermediaryName,
          ),
        );
      }
    }
    final price = computedBuyerUnitPrice(d);
    if (price != null && (price - d.buyerContract.unitPrice).abs() > 1e-9) {
      d = d.copyWith(buyerContract: d.buyerContract.copyWith(unitPrice: price));
    }
    _draft = d;
  }

  String _singleTitle(AppStrings s) =>
      _draft.isTwoParty ? s.twoPartyContract : s.singleContract;

  String? _validate() {
    final s = context.s;
    if (_draft.dealNumber.isNotEmpty &&
        context.read<DealsController>().isNumberTaken(
          _draft.dealNumber,
          exceptId: _draft.id,
        )) {
      _tabs.animateTo(2);
      return s.dealNumberTaken;
    }
    final checks = [(_draft.buyerContract, 0), (_draft.sellerContract, 1)];
    for (final (c, tab) in checks) {
      final title = _draft.isSingleContract
          ? (tab == 0 ? _singleTitle(s) : s.internalCalc)
          : s.contractTitle(c.side);
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
    // Keep the clients directory in step with the buyer of Contract #1.
    var deal = _draft;
    if (deal.clientId == null) {
      final client = await context.read<ClientsController>().ensure(
        deal.buyerContract.counterpartyName,
      );
      if (client != null) deal = deal.copyWith(clientId: client.id);
    }
    if (!mounted) return;
    await context.read<DealsController>().upsert(deal);
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48 + 52),
            child: Column(
              children: [
                // Mode switcher: Back-to-Back / single three-party contract.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<DealKind>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: DealKind.backToBack,
                          label: Text(s.kindBackToBack),
                        ),
                        ButtonSegment(
                          value: DealKind.threeParty,
                          label: Text(s.kindThreeParty),
                        ),
                        ButtonSegment(
                          value: DealKind.twoParty,
                          label: Text(s.kindTwoParty),
                        ),
                      ],
                      selected: {_draft.kind},
                      onSelectionChanged: (v) =>
                          _changeDeal(_draft.copyWith(kind: v.first)),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _draft.isSingleContract
                      ? [
                          Tab(text: _singleTitle(s)),
                          Tab(text: s.internalCalc),
                          Tab(text: s.summary),
                        ]
                      : [
                          Tab(text: s.contractTitle(ContractSide.buyer)),
                          Tab(text: s.contractTitle(ContractSide.seller)),
                          Tab(text: s.summary),
                        ],
                ),
              ],
            ),
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
                kind: _draft.kind,
                header: _draft.isSingleContract
                    ? ThreePartyHeader(
                        internal: false,
                        twoParty: _draft.isTwoParty,
                      )
                    : null,
                partiesExtra: _draft.isSingleContract
                    ? ThreePartyExtras(deal: _draft, onChanged: _changeDeal)
                    : null,
                pricingControl: PricingControl(
                  deal: _draft,
                  onChanged: _changeDeal,
                ),
                computedUnitPrice: computedBuyerUnitPrice(_draft),
              ),
              ContractForm(
                key: const ValueKey('contract-seller'),
                initial: _draft.sellerContract,
                onChanged: _onContractChanged,
                defaultAgencyFee: settings.defaultAgencyFee,
                defaultVat: settings.defaultVat,
                kind: _draft.kind,
                header: _draft.isSingleContract
                    ? const ThreePartyHeader(internal: true)
                    : null,
                showRequisites: !_draft.isSingleContract,
              ),
              _SummaryTab(
                deal: _draft,
                onNumber: (v) => setState(() {
                  _dirty = true;
                  _draft = _draft.copyWith(dealNumber: v.trim());
                }),
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
  const _SummaryTab({
    required this.deal,
    required this.onStageSelected,
    required this.onNumber,
  });

  final Deal deal;
  final ValueChanged<ContractStage> onStageSelected;
  final ValueChanged<String> onNumber;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        SectionCard(
          title: s.dealNumberTitle,
          child: TextFormField(
            initialValue: deal.dealNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: s.dealNumberTitle,
              hintText: s.dealNumberAuto,
              helperText: s.dealNumberHint,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
            ),
            onChanged: onNumber,
          ),
        ),
        const SizedBox(height: 12),
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
