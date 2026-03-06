import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  final logger = Logger();
  final parser = ArgParser()
    ..addFlag('major', negatable: false, help: 'Bump the major version')
    ..addFlag('minor', negatable: false, help: 'Bump the minor version')
    ..addFlag(
      'patch',
      negatable: false,
      defaultsTo: true,
      help: 'Bump the patch version (default)',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Show what would be done without making changes',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  final ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    logger.err(e.toString());
    print(parser.usage);
    exit(64);
  }

  if (results['help'] as bool) {
    logger.info('Usage: dart run scripts/release.dart [options]');
    logger.info(parser.usage);
    return;
  }

  final isDryRun = results['dry-run'] as bool;
  final bumpMajor = results['major'] as bool;
  final bumpMinor = results['minor'] as bool;
  final bumpType = bumpMajor ? 'major' : (bumpMinor ? 'minor' : 'patch');

  // 1. Get current version
  final pubspecYaml =
      loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final currentVersion = pubspecYaml['version'] as String;

  logger.info(
    'Current version: ${lightCyan.wrap(currentVersion) ?? currentVersion}',
  );
  logger.info('Bumping type:    ${lightYellow.wrap(bumpType) ?? bumpType}');

  if (isDryRun) {
    logger.info('\n--- DRY RUN ---');
    logger.info('Would run: dart run cider bump $bumpType');
    logger.info('Would run: dart run cider release');
    logger.info('Would commit, tag and push.');
    return;
  }

  // Confirm
  final proceed = logger.confirm('\nProceed with release?');
  if (!proceed) {
    logger.info('Aborted.');
    return;
  }

  // 2. Bump version using cider
  logger.info('Bumping version...');
  await _run('dart', ['run', 'cider', 'bump', bumpType], logger);

  // 3. Release using cider (updates CHANGELOG.md)
  logger.info('Updating CHANGELOG.md...');
  await _run('dart', ['run', 'cider', 'release'], logger);

  // 4. Get new version
  final newPubspecYaml =
      loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final nextVersion = newPubspecYaml['version'] as String;
  final nextTag = 'v$nextVersion';

  logger.info('Next version: ${lightGreen.wrap(nextVersion) ?? nextVersion}');

  // 5. Git actions
  await _run('git', ['add', 'pubspec.yaml', 'CHANGELOG.md'], logger);

  final commit = logger.confirm('Commit and tag $nextTag?');
  if (commit) {
    await _run('git', [
      'commit',
      '-m',
      'chore: bump version to $nextVersion',
    ], logger);
    await _run('git', ['tag', nextTag], logger);

    final push = logger.confirm('Push to origin?');
    if (push) {
      await _run('git', ['push', 'origin', 'main', nextTag], logger);
      logger.success('Successfully released $nextVersion! 🚀');
    }
  } else {
    logger.info('Commit aborted. Please handle git commands manually.');
  }
}

Future<void> _run(String command, List<String> args, Logger logger) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    logger.err('Error running $command ${args.join(' ')}:');
    logger.err(result.stderr);
    exit(result.exitCode);
  }
}
