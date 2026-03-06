import 'dart:io';

import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';

/// The command that opens the configuration file in the default editor.
class ConfigCommand extends SkillsSyncCommand {
  @override
  String get description =>
      'Opens the skills.yaml configuration file in your default editor.';

  @override
  String get name => 'config';

  @override
  Future<int> run() async {
    final configPath = argResults?['config'] as String?;
    final configFile = findConfigFile(configPath);

    if (configFile == null) {
      logger.err('Configuration file not found.');
      return 1;
    }

    final editor =
        Platform.environment['EDITOR'] ??
        (Platform.isWindows ? 'notepad' : 'vi');

    logger.info('Opening ${configFile.path} with $editor...');

    final result = await Process.run(editor, [
      configFile.path,
    ], runInShell: true);
    if (result.exitCode != 0) {
      logger.err('Failed to open editor: ${result.stderr}');
      return result.exitCode;
    }

    return 0;
  }
}
