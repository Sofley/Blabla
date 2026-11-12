import 'dart:io';

import 'package:nexus_release/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
