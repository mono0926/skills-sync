import 'dart:io';

import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';

class ConfigCommand extends SkillsSyncCommand {
  @override
  String get description => '設定ファイルをエディタで開きます。';

  @override
  String get name => 'config';

  @override
  Future<int> run() async {
    final configPath = argResults?['config'] as String?;
    final configFile = findConfigFile(configPath);

    if (configFile == null || !configFile.existsSync()) {
      logger.err('設定ファイルが見つかりません。先に `skills_sync init` を実行してください。');
      return 1;
    }

    final editor = Platform.environment['EDITOR'];
    if (editor != null && editor.isNotEmpty) {
      logger.info('エディタで開いています: $editor ${configFile.path}');
      final process = await Process.start(editor, [
        configFile.path,
      ], runInShell: true);
      final exitCode = await process.exitCode;
      return exitCode;
    }

    if (Platform.isMacOS) {
      logger.info('システム標準のエディタで開いています: ${configFile.path}');
      final process = await Process.run('open', [configFile.path]);
      return process.exitCode;
    }

    logger.info('設定ファイルのパス: ${configFile.path}');
    return 0;
  }
}
