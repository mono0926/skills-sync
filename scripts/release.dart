import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
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

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print('Usage: dart run scripts/release.dart [options]');
    print(parser.usage);
    return;
  }

  final isDryRun = results['dry-run'] as bool;
  final bumpMajor = results['major'] as bool;
  final bumpMinor = results['minor'] as bool;
  // If major or minor is specified, don't use the patch default unless explicitly specified.
  final bumpPatch = results['patch'] as bool && !bumpMajor && !bumpMinor;

  // Read current version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found.');
    exit(1);
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspecYaml = loadYaml(pubspecContent) as YamlMap;
  final currentVersionStr = pubspecYaml['version'] as String;

  final parts = currentVersionStr.split('.').map(int.parse).toList();
  var (major, minor, patch) = (parts[0], parts[1], parts[2]);

  if (bumpMajor) {
    major++;
    minor = 0;
    patch = 0;
  } else if (bumpMinor) {
    minor++;
    patch = 0;
  } else if (bumpPatch || results['patch'] as bool) {
    patch++;
  }

  final nextVersion = '$major.$minor.$patch';
  final nextTag = 'v$nextVersion';

  print('Current version: $currentVersionStr');
  print('Next version:    $nextVersion');
  print('Next tag:        $nextTag');

  if (isDryRun) {
    print('\n--- DRY RUN ---');
    print('Would update pubspec.yaml to version: $nextVersion');
    print('Would prepend version header to CHANGELOG.md');
    print('Would run: git add pubspec.yaml CHANGELOG.md');
    print('Would run: git commit -m "chore: bump version to $nextVersion"');
    print('Would run: git tag $nextTag');
    print('Would ask for confirmation before: git push origin main $nextTag');
    return;
  }

  // Confirm
  stdout.write('\nProceed with these changes? (y/N): ');
  final response = stdin.readLineSync()?.toLowerCase();
  if (response != 'y') {
    print('Aborted.');
    return;
  }

  // 1. Update pubspec.yaml
  final newPubspecContent = pubspecContent.replaceFirst(
    RegExp(r'version: \d+\.\d+\.\d+'),
    'version: $nextVersion',
  );
  await pubspecFile.writeAsString(newPubspecContent);

  // 2. Update CHANGELOG.md
  final changelogFile = File('CHANGELOG.md');
  if (await changelogFile.exists()) {
    final changelogContent = await changelogFile.readAsString();
    final newChangelogContent =
        '## $nextVersion\n\n- (Add changes here)\n\n$changelogContent';
    await changelogFile.writeAsString(newChangelogContent);
    print('Updated CHANGELOG.md. Please edit it before pushing.');
  }

  // 3. Git commands
  await _run('git', ['add', 'pubspec.yaml', 'CHANGELOG.md']);

  print('\nChanges committed locally. Please review CHANGELOG.md.');
  stdout.write('Ready to commit and tag? (y/N): ');
  if (stdin.readLineSync()?.toLowerCase() != 'y') {
    print('Stopped before commit. Please finish manually.');
    return;
  }

  await _run('git', ['commit', '-m', 'chore: bump version to $nextVersion']);
  await _run('git', ['tag', nextTag]);

  // 4. Final Push Confirmation
  print('\nVersion $nextVersion is ready to be pushed.');
  stdout.write('Push commit and tag to origin? (y/N): ');
  if (stdin.readLineSync()?.toLowerCase() == 'y') {
    await _run('git', ['push', 'origin', 'main', nextTag]);
    print('\nSuccessfully released $nextVersion! 🚀');
  } else {
    print(
      '\nPush aborted. You can push manually with: git push origin main $nextTag',
    );
  }
}

Future<void> _run(String command, List<String> args) async {
  print('Running: $command ${args.join(' ')}');
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    print('Error: ${result.stderr}');
    exit(result.exitCode);
  }
}
