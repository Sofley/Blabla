import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/repositories/deal_repository.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting();

  final dealRepository = await DealRepository.open();
  final settingsRepository = await SettingsRepository.open();

  runApp(
    B2BLedgerApp(
      dealRepository: dealRepository,
      settingsRepository: settingsRepository,
    ),
  );
}
