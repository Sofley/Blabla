// Manual tool (skipped in normal runs): writes a real encrypted backup with
// the app's own code, or verifies one downloaded back (e.g. from Google Drive).
//   NT_MODE=write  NT_OUT=/path/file.ntb  flutter test test/tools/...
//   NT_MODE=verify NT_IN=/path/file.ntb   flutter test test/tools/...
import 'dart:io';
import 'dart:typed_data';

import 'package:b2b_contracts/data/models/currency.dart';
import 'package:b2b_contracts/data/models/deal.dart';
import 'package:b2b_contracts/data/models/trade_contract.dart';
import 'package:b2b_contracts/data/repositories/auth_repository.dart';
import 'package:b2b_contracts/data/repositories/deal_repository.dart';
import 'package:b2b_contracts/data/repositories/quote_repository.dart';
import 'package:b2b_contracts/data/repositories/settings_repository.dart';
import 'package:b2b_contracts/data/storage/attachment_store.dart';
import 'package:b2b_contracts/domain/finance_calculator.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:b2b_contracts/state/backup_controller.dart';
import 'package:b2b_contracts/state/chat_controller.dart';
import 'package:b2b_contracts/state/clients_controller.dart';
import 'package:b2b_contracts/state/deals_controller.dart';
import 'package:b2b_contracts/state/quotes_controller.dart';
import 'package:b2b_contracts/state/rates_controller.dart';
import 'package:b2b_contracts/state/routes_controller.dart';
import 'package:b2b_contracts/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../test_helpers.dart';

const password = 'DriveTest2026';

Uint8List docBytes() =>
    Uint8List.fromList(List<int>.generate(1500000, (i) => (i * 7 + 3) & 0xFF));

Future<(BackupController, DealsController)> setup(String name) async {
  final dir = await Directory.systemTemp.createTemp(name);
  Hive.init(dir.path);
  final settingsBox = await Hive.openBox('s');
  final deals = DealsController(
    DealRepository(await Hive.openBox<Map>('d')),
    attachments: MemoryAttachmentStore(),
  );
  final ctl = BackupController(
    settingsBox: settingsBox,
    auth: AuthController(
      AuthRepository(await Hive.openBox('a')),
      hasher: const FastHasher(),
    ),
    deals: deals,
    quotes: QuotesController(QuoteRepository(await Hive.openBox<Map>('q'))),
    settings: SettingsController(SettingsRepository(settingsBox)),
    rates: RatesController(settingsBox),
    routes: RoutesController(await Hive.openBox<Map>('r')),
    chat: ChatController(await Hive.openBox<Map>('c')),
    clients: ClientsController(await Hive.openBox<Map>('cl')),
    vault: MemoryBackupKeyVault(),
    directory: () async => dir,
  );
  return (ctl, deals);
}

void main() {
  final mode = Platform.environment['NT_MODE'];

  test('write', () async {
    final (ctl, deals) = await setup('w');
    final now = DateTime(2026, 11, 12);
    await deals.upsert(
      Deal(
        id: 'drive-test',
        buyerContract: TradeContract(
          side: ContractSide.buyer,
          number: 'S-DRIVE',
          date: now,
          counterpartyName: 'Test Buyer LLC',
          currency: Currency.usd,
          unitPrice: 2.30,
          quantity: 22000,
          unit: 'kg',
          goodsRatePerUsd: 1,
          agencyFeePercent: 0,
          vatEnabled: false,
        ),
        sellerContract: TradeContract(
          side: ContractSide.seller,
          number: 'P-DRIVE',
          date: now,
          counterpartyName: 'Test Factory',
          currency: Currency.usd,
          unitPrice: 1600,
          quantity: 22,
          unit: 't',
          goodsRatePerUsd: 1,
          freightCost: 5400,
          logisticsRatePerUsd: 1,
          agencyFeePercent: 8,
          vatEnabled: false,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await deals.addDocument(
      'drive-test',
      category: DocCategory.mainContract,
      fileName: 'contract-test.pdf',
      bytes: docBytes(),
      number: 'DOG-TEST-1',
    );
    await ctl.rememberPassword(password);
    final f = await ctl.createFile();
    await f.copy(Platform.environment['NT_OUT']!);
    // ignore: avoid_print
    print('WROTE ${f.lengthSync()} bytes');
  }, skip: mode != 'write');

  test('verify', () async {
    final (ctl, deals) = await setup('v');
    final p = await ctl.openFile(
      File(Platform.environment['NT_IN']!),
      password: password,
    );
    await ctl.applyPending(p);
    final d = deals.deals.single;
    expect(d.dealNumber, startsWith('NT-2026-'));
    expect(DealProfit.of(d).netProfitUsd, closeTo(7184, 1e-6));
    final doc = d.documents.single;
    expect(doc.number, 'DOG-TEST-1');
    expect(await deals.readFile(d.id, doc.current!.fileId), docBytes());
    // ignore: avoid_print
    print(
      'VERIFIED deal ${d.dealNumber}, profit 7184, document ${doc.current!.size} bytes identical',
    );
  }, skip: mode != 'verify');
}
