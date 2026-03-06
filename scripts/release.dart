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
  } on FormatException catch (e) {
    logger
      ..err(e.message)
      ..info(parser.usage);
    exit(64);
  }

  if (results['help'] as bool) {
    logger
      ..info('Usage: dart run scripts/release.dart [options]')
      ..info(parser.usage);
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

  logger
    ..info(
      'Current version: ${lightCyan.wrap(currentVersion) ?? currentVersion}',
    )
    ..info('Bumping type:    ${lightYellow.wrap(bumpType) ?? bumpType}');

  if (isDryRun) {
    logger
      ..info('\n--- DRY RUN ---')
      ..info('Would run: dart run cider bump $bumpType')
      ..info('Would run: dart run cider release')
      ..info('Would commit, tag and push.');
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

      // 6. GitHub Release
      final createRelease = logger.confirm('Create GitHub Release?');
      if (createRelease) {
        // Extract release notes from CHANGELOG.md
        final changelog = File('CHANGELOG.md').readAsStringSync();
        final releaseNotes = _extractReleaseNotes(changelog, nextVersion);

        if (releaseNotes != null) {
          final tempFile = File('.release_notes.md')
            ..writeAsStringSync(releaseNotes);

          try {
            await _run(
              'gh',
              [
                'release',
                'create',
                nextTag,
                '--title',
                'v$nextVersion',
                '--notes-file',
                tempFile.path,
              ],
              logger,
            );
            logger.success('Successfully created GitHub release $nextTag! 🎁');
          } finally {
            if (tempFile.existsSync()) {
              tempFile.deleteSync();
            }
          }
        } else {
          logger.warn('Could not extract release notes for $nextVersion.');
        }
      }

      logger.success('Successfully released $nextVersion! 🚀');
    }
  } else {
    logger.info('Commit aborted. Please handle git commands manually.');
  }
}

String? _extractReleaseNotes(String changelog, String version) {
  final lines = changelog.split('\n');
  final startIndex = lines.indexWhere(
    (l) => l.startsWith('## $version') || l.startsWith('## [$version]'),
  );
  if (startIndex == -1) {
    return null;
  }

  final notes = <String>[];
  for (var i = startIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('## ')) {
      break;
    }
    notes.add(line);
  }
  return notes.join('\n').trim();
}

Future<void> _run(String command, List<String> args, Logger logger) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    logger
      ..err('Error running $command ${args.join(' ')}:')
      ..err(result.stderr.toString());
    exit(result.exitCode);
  }
}
