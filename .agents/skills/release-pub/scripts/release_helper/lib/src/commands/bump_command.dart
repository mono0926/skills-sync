import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:release_helper/src/logger.dart';
import 'package:yaml_edit/yaml_edit.dart';

class BumpCommand extends Command<int> {
  BumpCommand() {
    argParser.addOption(
      'file',
      abbr: 'f',
      help: 'The path to pubspec.yaml',
      defaultsTo: 'pubspec.yaml',
    );
  }

  @override
  String get description => 'Bumps the version in pubspec.yaml';

  @override
  String get name => 'bump';

  @override
  Future<int> run() async {
    final args = argResults?.rest ?? [];
    if (args.isEmpty) {
      logger.err(
        'Please specify a bump type (major | minor | patch) '
        'or an exact version.',
      );
      return 1;
    }

    final bumpTypeOrVersion = args.first;
    final filePath = argResults?['file'] as String;
    final file = File(filePath);

    if (!file.existsSync()) {
      logger.err('pubspec.yaml not found at $filePath');
      return 1;
    }

    final content = file.readAsStringSync();
    final editor = YamlEditor(content);

    final currentVersionNode = editor.parseAt(['version']);
    final currentVersion = currentVersionNode.value as String;

    String nextVersion;
    if (bumpTypeOrVersion == 'major') {
      nextVersion = _bumpMajor(currentVersion);
    } else if (bumpTypeOrVersion == 'minor') {
      nextVersion = _bumpMinor(currentVersion);
    } else if (bumpTypeOrVersion == 'patch') {
      nextVersion = _bumpPatch(currentVersion);
    } else {
      nextVersion = bumpTypeOrVersion;
    }

    editor.update(['version'], nextVersion);
    file.writeAsStringSync(editor.toString());

    logger.success('Bumped version from $currentVersion to $nextVersion');
    return 0;
  }

  String _bumpMajor(String version) {
    final parts = _parseVersion(version);
    return '${parts[0] + 1}.0.0';
  }

  String _bumpMinor(String version) {
    final parts = _parseVersion(version);
    return '${parts[0]}.${parts[1] + 1}.0';
  }

  String _bumpPatch(String version) {
    final parts = _parseVersion(version);
    return '${parts[0]}.${parts[1]}.${parts[2] + 1}';
  }

  List<int> _parseVersion(String version) {
    final basicPart = version.split('+').first.split('-').first;
    final parts = basicPart.split('.');
    return parts.map(int.parse).toList();
  }
}
