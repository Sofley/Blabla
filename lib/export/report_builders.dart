import 'package:intl/intl.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/formatters.dart';
import '../data/models/currency.dart';
import '../data/models/deal.dart';
import '../data/models/price_quote.dart';
import '../data/models/trade_contract.dart';
import '../domain/finance_calculator.dart';
import '../domain/price_calculator.dart';
import 'report.dart';

/// Builds [Report]s for deals, deal registries and price quotes.
/// Only characters available in the bundled PDF font are used.
class ReportBuilders {
  ReportBuilders(this.s, this.fmt);

  final AppStrings s;
  final Fmt fmt;

  late final _num = NumberFormat('#,##0.00', fmt.locale);
  late final _precise = NumberFormat('#,##0.00##', fmt.locale);

  ReportCell _money(
    double v, [
    Currency c = kReportingCurrency,
    bool bold = false,
  ]) => ReportCell('${_num.format(v)} ${c.code}', number: v, bold: bold);

  ReportCell _price(double v, Currency c) =>
      ReportCell('${_precise.format(v)} ${c.code}', number: v);

  ReportCell _text(String v, {bool bold = false}) =>
      ReportCell(v.trim().isEmpty ? '-' : v, bold: bold);

  ReportCell _pct(double v) => ReportCell(fmt.percent(v), number: v);

  String _stamp() => '${s.generatedOn} ${fmt.dateTime(DateTime.now())}';

  static String safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
    return cleaned.isEmpty ? 'report' : cleaned;
  }

  // ---------------- Deal ----------------

  Report deal(Deal d) {
    final p = DealProfit.of(d);
    return Report(
      title: '${s.dealDetails} ${d.displayTitle}',
      subtitle: '${s.status}: ${s.stage(d.stage)} · ${_stamp()}',
      fileBaseName: safeName('deal_${d.displayTitle}'),
      blocks: [
        ReportHeading(s.profitCalculator),
        ReportKeyValues([
          if (d.isThreeParty) (s.companyStatus, _text(s.roleTitle(d.role))),
          (s.revenueFromBuyer, _money(p.revenueExVatUsd)),
          if (p.outputVatUsd > 0) (s.buyerVatExcluded, _money(p.outputVatUsd)),
          (s.paymentToFactory, _money(-p.purchase.goodsUsd)),
          if (p.purchase.vatUsd > 0) (s.factoryVat, _money(-p.purchase.vatUsd)),
          (s.logistics, _money(-p.purchase.logisticsUsd)),
          (s.agentFeeInternal, _money(-p.purchase.agencyFeeUsd)),
          (s.profitBeforeBonus, _money(p.markupUsd)),
          if (p.vatRefundUsd > 0) ...[
            (s.vatRefundAmount, _money(p.vatRefundUsd)),
            (
              '${s.vatBonus} (${fmt.percent(d.sellerContract.vatBonusShare)})',
              _money(p.vatBonusUsd),
            ),
            (
              s.addVatBonusToProfit,
              _text(p.vatBonusInProfitUsd > 0 ? s.yes : s.no),
            ),
            (s.vatRefundReceived, _text(d.vatRefundReceived ? s.yes : s.no)),
          ],
          (s.netProfit, _money(p.netProfitUsd, kReportingCurrency, true)),
          (s.margin, _pct(p.marginPercent)),
        ]),
        ReportHeading(s.statusTracker),
        ReportKeyValues([
          for (final e in d.stageDates.entries)
            (s.stage(e.key), _text(fmt.date(e.value))),
        ]),
        ..._contract(d.buyerContract),
        ..._contract(d.sellerContract),
        ReportParagraph(s.profitFormula),
      ],
    );
  }

  /// Document for the buyer: contract price only — no factory amount,
  /// logistics, agent fee or margin.
  Report buyerContract(Deal d) {
    final c = d.buyerContract;
    final f = ContractFinancials.of(c);
    final unit = c.unit.isEmpty ? '' : ' ${c.unit}';
    final title = d.isThreeParty ? s.singleContract : s.contractTitle(c.side);
    return Report(
      title: '$title № ${c.number.trim().isEmpty ? '-' : c.number}',
      subtitle: fmt.date(c.date),
      fileBaseName: safeName('contract_${c.number}'),
      blocks: [
        ReportHeading(s.parties),
        ReportKeyValues([
          (s.buyerShort, _text(c.counterpartyName)),
          if (d.isThreeParty) ...[
            (s.sellerShort, _text(d.sellerContract.counterpartyName)),
            (s.payerTrader, _text(c.intermediaryName)),
          ] else
            (s.sellerShort, _text(c.intermediaryName)),
        ]),
        ReportHeading(s.contractSubject),
        ReportKeyValues([
          (s.productName, _text(c.productName)),
          (
            s.quantity,
            ReportCell(
              '${_precise.format(c.quantity)}$unit',
              number: c.quantity,
            ),
          ),
          (s.unitPrice, _price(c.unitPrice, c.currency)),
          (s.contractPriceForBuyer, _money(c.goodsCost, c.currency, true)),
          if (f.vatUsd > 0) ...[
            (
              '${s.vat} ${fmt.percent(c.vatPercent)}',
              _money(f.vatUsd * c.goodsRatePerUsd, c.currency),
            ),
            (
              s.totalWithVat,
              _money(f.totalInContractCurrency, c.currency, true),
            ),
          ],
        ]),
      ],
    );
  }

  List<ReportBlock> _contract(TradeContract c) {
    final f = ContractFinancials.of(c);
    final unit = c.unit.isEmpty ? '' : ' ${c.unit}';
    return [
      ReportHeading(
        '${s.contractTitle(c.side)}: ${s.contractPartiesPlain(c.side)}',
      ),
      ReportKeyValues([
        (s.contractNumber, _text(c.number)),
        (s.contractDate, _text(fmt.date(c.date))),
        (s.counterpartyLabel(c.side), _text(c.counterpartyName)),
        (s.intermediary, _text(c.intermediaryName)),
        (s.productName, _text(c.productName)),
        (s.unitPrice, _price(c.unitPrice, c.currency)),
        (
          s.quantity,
          ReportCell('${_precise.format(c.quantity)}$unit', number: c.quantity),
        ),
        (s.goodsCost, _money(c.goodsCost, c.currency)),
        if (c.currency != Currency.usd)
          (
            s.ratePerUsd(c.currency.code),
            ReportCell(
              _precise.format(c.goodsRatePerUsd),
              number: c.goodsRatePerUsd,
            ),
          ),
        (s.transport, _money(c.transportCost, c.logisticsCurrency)),
        (s.freight, _money(c.freightCost, c.logisticsCurrency)),
        (s.portFees, _money(c.portFees, c.logisticsCurrency)),
        (s.agencyFee, _pct(c.agencyFeePercent)),
        (s.vatPercent, _pct(c.effectiveVatPercent)),
        if (c.vatRefundEnabled) ('${s.vatRefund}, %', _pct(c.vatRefundPercent)),
      ]),
      ReportHeading('${s.calculator} (${kReportingCurrency.code})'),
      ReportKeyValues([
        (s.goods, _money(f.goodsUsd)),
        (s.logistics, _money(f.logisticsUsd)),
        (s.agency, _money(f.agencyFeeUsd)),
        (s.netAmount, _money(f.netUsd)),
        (s.vat, _money(f.vatUsd)),
        (s.contractTotal, _money(f.totalUsd, kReportingCurrency, true)),
        if (c.currency != Currency.usd)
          (s.inContractCurrency, _money(f.totalInContractCurrency, c.currency)),
        if (f.vatRefundUsd > 0) ...[
          (s.vatRefundAmount, _money(f.vatRefundUsd)),
          (s.vatBonus, _money(f.vatBonusUsd)),
        ],
      ]),
      if (c.notes.trim().isNotEmpty) ...[
        ReportHeading(s.notesSection),
        ReportParagraph(c.notes.trim()),
      ],
    ];
  }

  // ---------------- Registry ----------------

  Report registry(List<Deal> deals, String period) {
    var turnover = 0.0, refund = 0.0, profit = 0.0, revenue = 0.0;
    final rows = <List<ReportCell>>[];
    for (final d in deals) {
      final p = DealProfit.of(d);
      turnover += p.turnoverUsd;
      refund += p.vatBonusUsd;
      profit += p.netProfitUsd;
      revenue += p.revenueExVatUsd;
      rows.add([
        _text(d.buyerContract.number),
        _text(d.sellerContract.number),
        _text(fmt.date(d.reportingDate)),
        _text(d.buyerContract.counterpartyName),
        _text(d.sellerContract.counterpartyName),
        _text(s.stage(d.stage)),
        _money(p.turnoverUsd),
        _money(p.vatBonusUsd),
        _money(p.netProfitUsd),
        _pct(p.marginPercent),
      ]);
    }
    final margin = revenue > 0 ? profit / revenue * 100 : 0.0;
    rows.add([
      _text(s.total, bold: true),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _money(turnover, kReportingCurrency, true),
      _money(refund, kReportingCurrency, true),
      _money(profit, kReportingCurrency, true),
      _pct(margin),
    ]);
    return Report(
      title: '${s.dealsRegistry}: $period',
      subtitle: '${s.allValuesInUsd} · ${_stamp()}',
      fileBaseName: safeName('registry_$period'),
      blocks: [
        ReportKeyValues([
          (
            s.contractsCount,
            ReportCell('${deals.length}', number: deals.length.toDouble()),
          ),
          (s.turnover, _money(turnover)),
          (s.vatBonus, _money(refund)),
          (s.netProfit, _money(profit, kReportingCurrency, true)),
          (s.margin, _pct(margin)),
        ]),
        ReportHeading(s.navDeals),
        ReportTable(
          headers: [
            s.contractShort(ContractSide.buyer),
            s.contractShort(ContractSide.seller),
            s.contractDate,
            s.buyerShort,
            s.sellerShort,
            s.status,
            s.turnover,
            s.vatBonus,
            s.netProfit,
            s.margin,
          ],
          rows: rows,
        ),
      ],
    );
  }

  // ---------------- Quote ----------------

  Report quote(PriceQuote q) {
    final b = PriceBreakdown(q);
    final c = q.currency;
    final unit = q.unit.isEmpty ? '' : ' ${q.unit}';
    return Report(
      title:
          '${s.priceCalculator}: ${q.productName.isEmpty ? '-' : q.productName}',
      subtitle: _stamp(),
      fileBaseName: safeName('price_${q.productName}'),
      blocks: [
        ReportKeyValues([
          (s.productName, _text(q.productName)),
          (s.buyerShort, _text(q.buyerName)),
          (
            s.quantity,
            ReportCell(
              '${_precise.format(q.quantity)}$unit',
              number: q.quantity,
            ),
          ),
          (s.incoterms, _text(q.incoterms)),
          if (c != Currency.usd)
            (
              s.ratePerUsd(c.code),
              ReportCell(_precise.format(q.ratePerUsd), number: q.ratePerUsd),
            ),
        ]),
        ReportHeading(s.pricePerUnitStructure),
        ReportTable(
          headers: [s.component, s.perUnit, s.share],
          rows: [
            [
              _text('1. ${s.exwPrice} (${q.incoterms})'),
              _price(b.goodsPerUnit, c),
              _pct(b.share(b.goodsPerUnit) * 100),
            ],
            [
              _text('2. ${s.quantityVolume}'),
              ReportCell(
                '${_precise.format(q.quantity)}$unit',
                number: q.quantity,
              ),
              _text(''),
            ],
            [
              _text('3. ${s.logisticsPerUnit}'),
              _price(b.logisticsPerUnit, c),
              _pct(b.share(b.logisticsPerUnit) * 100),
            ],
            [
              _text('4. ${s.stepAgent} ${fmt.percent(q.agentPercent)}'),
              _price(b.agentPerUnit, c),
              _pct(b.share(b.agentPerUnit) * 100),
            ],
            [
              _text(
                '5. ${s.vat} ${fmt.percent(q.vatEnabled ? q.vatPercent : 0)}',
              ),
              _price(b.vatPerUnit, c),
              _pct(b.share(b.vatPerUnit) * 100),
            ],
            [
              _text(
                q.profitIsPercent
                    ? '6. ${s.stepMyProfit} ${fmt.percent(q.profitValue)}'
                    : '6. ${s.stepMyProfit}',
              ),
              _price(b.profitPerUnit, c),
              _pct(b.share(b.profitPerUnit) * 100),
            ],
            [
              _text(s.salePrice, bold: true),
              _price(b.salePricePerUnit, c),
              _pct(100),
            ],
          ],
        ),
        ReportHeading(
          '${s.forWholeBatch} (${_precise.format(q.quantity)}$unit)',
        ),
        ReportKeyValues([
          (s.saleAmount, _money(b.saleTotal, c)),
          (s.purchaseAmount, _money(-b.purchaseTotal, c)),
          (s.logistics, _money(-b.logisticsTotal, c)),
          (s.agentFee, _money(-b.agentTotal, c)),
          if (q.vatEnabled)
            ('${s.vat} ${fmt.percent(q.vatPercent)}', _money(-b.vatTotal, c)),
          (s.myProfit, _money(b.markupTotal, c)),
          if (q.vatRefundEnabled) ...[
            (
              '${s.vatRefundAmount} ${fmt.percent(q.vatRefundPercent)}',
              _money(b.vatRefundTotal, c),
            ),
            (
              '${s.vatBonus} ${fmt.percent(q.vatBonusShare)}',
              _money(b.vatBonusTotal, c),
            ),
            (s.addVatBonusToProfit, _text(q.vatBonusInProfit ? s.yes : s.no)),
          ],
          (s.totalProfit, _money(b.totalProfit, c, true)),
          (s.profitPerUnit, _price(b.totalProfitPerUnit, c)),
          (s.margin, _pct(b.marginPercent)),
          if (c != Currency.usd)
            ('${s.totalProfit} (USD)', _money(b.toUsd(b.totalProfit))),
        ]),
        if (q.notes.trim().isNotEmpty) ...[
          ReportHeading(s.notesSection),
          ReportParagraph(q.notes.trim()),
        ],
      ],
    );
  }
}
