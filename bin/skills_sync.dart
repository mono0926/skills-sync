import 'dart:io';

import 'package:skills_sync/src/command_runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await SkillsSyncCommandRunner().run(args) ?? 0;
}
