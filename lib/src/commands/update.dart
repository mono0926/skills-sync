import 'dart:io';

import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';
import 'package:yaml/yaml.dart';

/// The command that updates all installed skills.
class UpdateCommand extends SkillsSyncCommand {
  /// Creates a new [UpdateCommand].
  UpdateCommand() {
    argParser
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Only show what would be done without making any changes.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Skip confirmation prompt and proceed with updating.',
      )
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'Specify the agent name to update skills for.',
        defaultsTo: 'antigravity',
      );
  }

  @override
  String get description =>
      'Updates all installed skills to their latest versions.';

  @override
  String get name => 'update';

  @override
  Future<int> run() async {
    if (!await checkGh()) {
      logger
        ..err('gh skill command not found.')
        ..info(
          '\nPlease install or update the latest GitHub CLI:\n'
          'https://cli.github.com/',
        );
      return 1;
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final configPath = argResults?['config'] as String?;
    final agent = argResults?['agent'] as String? ?? 'antigravity';
    final configFile = findConfigFile(configPath);

    if (configFile == null) {
      logger.err('Configuration file not found.');
      return 1;
    }

    final yamlString = await configFile.readAsString();
    final yaml = loadYaml(yamlString) as YamlMap;
    final entries = parseSkillEntries(yaml);

    final paths = entries.map((e) => e.targetPath).toSet().toList();
    if (!paths.contains(null)) {
      paths.add(null);
    }

    var hasError = false;

    if (dryRun) {
      logger.info(
        '=== Dry Run: The following commands would be executed ===\n',
      );
    }

    for (final path in paths) {
      final workingDirectory = path != null ? expandPath(path) : null;
      final targetName = path ?? 'global';

      final command = [
        'gh',
        'skill',
        'update',
        '--all',
        '--agent',
        agent,
        '--allow-hidden-dirs',
      ];

      if (dryRun) {
        final dirInfo = workingDirectory != null ? ' (in $path)' : '';
        logger.info('${command.join(' ')}$dirInfo');
        continue;
      }

      final progress = logger.progress('Updating skills for $targetName...');
      final result = await Process.run(
        command.first,
        command.sublist(1),
        runInShell: true,
        workingDirectory: workingDirectory,
      );

      if (result.exitCode == 0) {
        progress.complete('Updated skills for $targetName.');
      } else {
        progress.fail(
          'Failed to update skills for $targetName:\n${result.stderr}',
        );
        hasError = true;
      }
    }

    if (!dryRun) {
      logger.success('\nAll skills have been checked for updates.');
    }

    return hasError ? 1 : 0;
  }
}
