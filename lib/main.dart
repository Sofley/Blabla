import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/storage/attachment_store.dart';
import 'data/storage/data_migration.dart';
import 'data/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting();
  final store = await LocalStore.open();
  // v2.x → v3.0: snapshot of the old records first, then the upgrade.
  await DataMigration.run(store);
  final attachments = await FileAttachmentStore.open();
  runApp(NexusTradeApp(store: store, attachments: attachments));
}
