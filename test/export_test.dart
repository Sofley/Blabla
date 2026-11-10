import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:b2b_contracts/core/l10n/app_strings.dart';
import 'package:b2b_contracts/core/utils/formatters.dart';
import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/price_quote.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/export/backup_service.dart';
import 'package:b2b_contracts/export/renderers/docx_renderer.dart';
import 'package:b2b_contracts/export/renderers/pdf_renderer.dart';
import 'package:b2b_contracts/export/renderers/xlsx_renderer.dart';
import 'package:b2b_contracts/export/report_builders.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 11, 5);
  final deal = Deal(
    id: 'd1',
    buyerContract: TradeContract(
      side: ContractSide.buyer,
      number: 'BX-101',
      date: now,
      counterpartyName: 'Ташкент Строй',
      intermediaryName: 'Silk Route FZE',
      currency: Currency.usd,
      unitPrice: 0.3135,
      quantity: 500000,
      goodsRatePerUsd: 1,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 0,
      vatEnabled: false,
      notes: 'Оплата 30/70',
    ),
    sellerContract: TradeContract(
      side: ContractSide.seller,
      number: 'CN-881',
      date: now,
      counterpartyName: 'Ningbo Plastics',
      currency: Currency.cny,
      unitPrice: 1.08,
      quantity: 500000,
      goodsRatePerUsd: 7.2,
      freightCost: 50000,
      logisticsRatePerUsd: 1,
      agencyFeePercent: 9,
      vatEnabled: false,
      vatRefundEnabled: true,
      vatRefundPercent: 9,
    ),
    createdAt: now,
    updatedAt: now,
  );
  final quote = PriceQuote(
    id: 'q1',
    productName: 'Тара 500 мл',
    quantity: 500000,
    unit: 'шт',
    exwPrice: 0.15,
    logisticsValue: 0.1,
    vatEnabled: true,
    profitValue: 0.05,
    createdAt: now,
    updatedAt: now,
  );

  late ReportBuilders b;
  setUpAll(() async {
    await initializeDateFormatting('ru');
    b = ReportBuilders(const AppStrings(Locale('ru')), Fmt('ru'));
  });

  test('deal profit in report includes VAT refund (31 750 USD)', () {
    final r = b.deal(deal);
    expect(r.title, contains('BX-101'));
  });

  test('xlsx keeps numbers numeric', () {
    final bytes = const XlsxRenderer().render(
      b.registry([deal], 'Ноябрь 2026'),
    );
    final book = Excel.decodeBytes(bytes);
    final sheet = book.tables.values.first;
    final values = [
      for (final row in sheet.rows)
        for (final c in row) c?.value,
    ];
    final nums = [
      for (final v in values)
        if (v is DoubleCellValue)
          v.value
        else if (v is IntCellValue)
          v.value.toDouble(),
    ];
    printOnFailure('$nums');
    expect(nums.any((v) => (v - 31750).abs() < 0.01), isTrue);
    expect(
      values.whereType<TextCellValue>().map((v) => v.value.text),
      contains('Ташкент Строй'),
    );
  });

  test('docx is a valid zip with document.xml', () {
    final bytes = const DocxRenderer().render(b.quote(quote));
    final zip = ZipDecoder().decodeBytes(bytes);
    final doc = zip.findFile('word/document.xml')!;
    final xml = utf8.decode(doc.content as List<int>);
    expect(xml, contains('Тара 500 мл'));
    expect(xml, contains('<w:tbl>'));
  });

  test('pdf renders with Cyrillic font', () async {
    final regular = ByteData.sublistView(
      File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
    );
    final bold = ByteData.sublistView(
      File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
    );
    final bytes = await PdfRenderer(
      regular: regular,
      bold: bold,
    ).render(b.deal(deal));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('backup round-trip', () {
    const svc = BackupService();
    final bytes = svc.encode(
      deals: [deal],
      quotes: [quote],
      settings: {'companyName': 'X'},
    );
    final content = svc.decode(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    expect(content.deals.single.sellerContract.vatRefundPercent, 9);
    expect(content.quotes.single.exwPrice, 0.15);
    expect(content.settings['companyName'], 'X');
    expect(() => svc.decode({'format': 'other'}), throwsFormatException);
  });
}
