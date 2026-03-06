import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

abstract class SkillsSyncCommand extends Command<int> {
  SkillsSyncCommand() {
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'skills.yaml のパスを指定します',
    );
  }

  Future<bool> checkNpx() async {
    try {
      final result = await Process.run('npx', ['--version'], runInShell: true);
      return result.exitCode == 0;
    } on Exception catch (_) {
      return false;
    }
  }

  File? findConfigFile(String? explicitPath) {
    if (explicitPath != null) {
      final file = File(explicitPath);
      return file.existsSync() ? file : null;
    }

    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) {
      return null;
    }

    final file = File(
      p.join(home, '.config', 'skills_sync', 'config.yaml'),
    );
    return file.existsSync() ? file : null;
  }

  String expandPath(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
      return path.replaceFirst('~/', '$home/');
    }
    return path;
  }

  List<SkillEntry> parseSkillEntries(YamlMap yaml) {
    final entries = <SkillEntry>[];

    if (yaml['global'] is YamlMap) {
      entries.addAll(_parseSourceMap(yaml['global'] as YamlMap, null));
    }

    for (final MapEntry(key: pathStr, value: pathValue) in yaml.entries) {
      if (pathStr == 'global') {
        continue;
      }
      if (pathStr is! String || pathValue is! YamlMap) {
        continue;
      }
      entries.addAll(_parseSourceMap(pathValue, pathStr));
    }

    return entries;
  }

  Iterable<SkillEntry> _parseSourceMap(YamlMap map, String? targetPath) sync* {
    for (final MapEntry(:key, :value) in map.entries) {
      if (key is! String) {
        continue;
      }

      final source = key;
      final skills = <String>[];
      final patterns = <String>[];
      final excludes = <String>[];
      final excludePatterns = <String>[];

      void processValue(dynamic v) {
        if (v is String) {
          if (v.startsWith('!')) {
            final p = v.substring(1);
            if (p.contains('*')) {
              excludePatterns.add(p);
            } else {
              excludes.add(p);
            }
          } else if (v.contains('*')) {
            patterns.add(v);
          } else {
            skills.add(v);
          }
        }
      }

      if (value is YamlList) {
        value.forEach(processValue);
      } else if (value != null) {
        continue;
      }

      yield SkillEntry(
        source: source,
        skills: skills,
        patterns: patterns,
        excludes: excludes,
        excludePatterns: excludePatterns,
        targetPath: targetPath,
      );
    }
  }

  RegExp patternToRegExp(String pattern) {
    final escaped = pattern
        .replaceAll('.', r'\.')
        .replaceAll('+', r'\+')
        .replaceAll('?', r'\?')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('^', r'\^')
        .replaceAll(r'$', r'\$')
        .replaceAll('|', r'\|')
        .replaceAll('*', '.*');
    return RegExp('^$escaped\$', caseSensitive: false);
  }
}

class SkillEntry {
  SkillEntry({
    required this.source,
    this.skills = const [],
    this.patterns = const [],
    this.excludes = const [],
    this.excludePatterns = const [],
    this.targetPath,
  });

  final String source;
  final List<String> skills;
  final List<String> patterns;
  final List<String> excludes;
  final List<String> excludePatterns;
  final String? targetPath;
}
