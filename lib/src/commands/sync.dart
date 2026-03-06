import 'dart:convert';
import 'dart:io';

import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';
import 'package:yaml/yaml.dart';

/// The command that synchronizes skills based on the configuration file.
class SyncCommand extends SkillsSyncCommand {
  /// Creates a new [SyncCommand].
  SyncCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Only show what would be done without making any changes.',
    );
  }

  @override
  String get description => 'Syncs skills based on the configuration file.';

  @override
  String get name => 'sync';

  @override
  Future<int> run() async {
    if (!await checkNpx()) {
      logger
        ..err('npx command not found.')
        ..info('\nPlease install Node.js and npm: https://nodejs.org/');
      return 1;
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final configPath = argResults?['config'] as String?;
    final configFile = findConfigFile(configPath);

    if (configFile == null) {
      logger.err('Configuration file not found.');
      return 1;
    }

    final yamlString = await configFile.readAsString();
    final yaml = loadYaml(yamlString) as YamlMap;
    final entries = parseSkillEntries(yaml);

    if (dryRun) {
      logger.info(
        '=== Dry Run: The following commands would be executed ===\n',
      );
    }

    var hasError = false;
    final skippedPaths = <String>[];
    final validPaths = <String?>{null}; // null represents global

    for (final entry in entries) {
      if (entry.targetPath != null) {
        final expandedPath = expandPath(entry.targetPath!);
        if (Directory(expandedPath).existsSync()) {
          validPaths.add(entry.targetPath);
        } else {
          if (!skippedPaths.contains(entry.targetPath)) {
            skippedPaths.add(entry.targetPath!);
          }
        }
      }
    }

    // --- Helper Functions ---
    Map<String, dynamic> readLock(String? path) {
      final lockPath = path == null
          ? expandPath('~/.agents/.skill-lock.json')
          : '${expandPath(path)}/skills-lock.json';
      final file = File(lockPath);
      if (!file.existsSync()) {
        return {
          'version': 3,
          'skills': <String, dynamic>{},
          'dismissed': <String, dynamic>{},
        };
      }
      try {
        return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } on Exception catch (_) {
        return {
          'version': 3,
          'skills': <String, dynamic>{},
          'dismissed': <String, dynamic>{},
        };
      }
    }

    void writeLock(String? path, Map<String, dynamic> data) {
      final lockPath = path == null
          ? expandPath('~/.agents/.skill-lock.json')
          : '${expandPath(path)}/skills-lock.json';
      final file = File(lockPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    }

    // --- Before State ---
    final beforeLocks = <String?, Map<String, dynamic>>{};
    for (final path in validPaths) {
      beforeLocks[path] = readLock(path);
    }

    final diffs = <String?, Map<String, Map<String, String>>>{};

    if (!dryRun) {
      logger.info('=== Removing existing skills ===');
      for (final path in validPaths) {
        final workingDirectory = path != null ? expandPath(path) : null;
        final targetName = path ?? 'global';
        final progress = logger.progress('Removing skills for $targetName...');

        final command = [
          'npx',
          'skills',
          'remove',
          '--all',
          if (path == null) '--global',
          '-y',
        ];

        final result = await Process.run(
          command.first,
          command.sublist(1),
          runInShell: true,
          workingDirectory: workingDirectory,
        );

        if (result.exitCode == 0) {
          progress.complete('Removed skills for $targetName.');
        } else {
          progress.fail(
            'Failed to remove skills for $targetName:\n${result.stderr}',
          );
          hasError = true;
        }
      }
      logger.success('Existing skills removed.\n');
    }

    // --- Resolve Patterns ---
    final resolvedEntries = <SkillEntry>[];
    for (final entry in entries) {
      if (entry.patterns.isEmpty) {
        resolvedEntries.add(entry);
        continue;
      }

      final targetName = entry.targetPath ?? 'global';
      final progress = logger.progress(
        'Checking available skills for $targetName (${entry.source})...',
      );

      final listResult = await Process.run('npx', [
        'skills',
        'add',
        entry.source,
        '--list',
      ], runInShell: true);

      if (listResult.exitCode != 0) {
        progress.fail('Failed to get skill list: ${entry.source}');
        resolvedEntries.add(entry);
        continue;
      }

      final availableSkills = _extractSkillNames(listResult.stdout.toString());
      final matchedSkills = <String>{...entry.skills};

      for (final pattern in entry.patterns) {
        final regExp = patternToRegExp(pattern);
        for (final skill in availableSkills) {
          if (regExp.hasMatch(skill)) {
            matchedSkills.add(skill);
          }
        }
      }

      for (final pattern in entry.excludePatterns) {
        final regExp = patternToRegExp(pattern);
        matchedSkills.removeWhere(regExp.hasMatch);
      }

      entry.excludes.forEach(matchedSkills.remove);

      if (matchedSkills.isEmpty) {
        progress.fail(
          'No skills matched the patterns: ${entry.patterns.join(', ')}',
        );
        continue;
      }

      progress.complete(
        'Found ${matchedSkills.length} skills for $targetName '
        '(${entry.source}).',
      );

      resolvedEntries.add(
        SkillEntry(
          source: entry.source,
          skills: matchedSkills.toList(),
          excludes: entry.excludes,
          excludePatterns: entry.excludePatterns,
          targetPath: entry.targetPath,
        ),
      );
    }

    final progress = dryRun
        ? null
        : logger.progress('Executing installation (parallel)...');

    // --- Parallel Install ---
    final activeEntries = <SkillEntry>[];
    final resultFutures = <Future<ProcessResult>>[];
    for (final entry in resolvedEntries) {
      if (entry.targetPath != null && skippedPaths.contains(entry.targetPath)) {
        continue;
      }
      activeEntries.add(entry);
      final workingDirectory = entry.targetPath != null
          ? expandPath(entry.targetPath!)
          : null;
      final command = _buildCommand(entry);

      if (dryRun) {
        final wdStr = workingDirectory != null ? ' (in $workingDirectory)' : '';
        logger.info('${command.join(' ')}$wdStr');
        continue;
      }

      final targetName = entry.targetPath ?? 'global';

      final futureResult =
          Process.start(
            command.first,
            command.sublist(1),
            runInShell: true,
            workingDirectory: workingDirectory,
          ).then((p) async {
            final stdoutLines = <String>[];
            final stderrLines = <String>[];

            final stdoutFuture = p.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen((line) {
                  if (line.trim().isEmpty) {
                    return;
                  }
                  stdoutLines.add(line);
                  logger.detail('[$targetName] $line');
                })
                .asFuture<void>();

            final stderrFuture = p.stderr
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen((line) {
                  if (line.trim().isEmpty) {
                    return;
                  }
                  stderrLines.add(line);
                  logger.warn('[$targetName:stderr] $line');
                })
                .asFuture<void>();

            final exitCode = await p.exitCode;
            await Future.wait([stdoutFuture, stderrFuture]);

            return ProcessResult(
              p.pid,
              exitCode,
              stdoutLines.join('\n'),
              stderrLines.join('\n'),
            );
          });

      resultFutures.add(futureResult);
    }

    if (!dryRun) {
      final results = await Future.wait(resultFutures);

      final afterLocks = <String?, Map<String, dynamic>>{};
      for (final path in validPaths) {
        afterLocks[path] = readLock(path);
      }

      for (final result in results) {
        final stdoutStr = result.stdout.toString();
        final stderrStr = result.stderr.toString();
        if (stdoutStr.isNotEmpty) {
          logger.info(stdoutStr.trim());
        }
        if (stderrStr.isNotEmpty) {
          logger.warn(stderrStr.trim());
        }
        if (result.exitCode != 0) {
          logger.warn('⚠️  Exit code: ${result.exitCode}');
          hasError = true;
        }
      }

      for (final path in validPaths) {
        final before = beforeLocks[path]!;
        final after = afterLocks[path]!;

        final allPossible = <String, dynamic>{
          ...(before['skills'] as Map<String, dynamic>? ?? <String, dynamic>{}),
          ...(after['skills'] as Map<String, dynamic>? ?? <String, dynamic>{}),
        };

        final mergedSkills = <String, dynamic>{};

        for (var i = 0; i < activeEntries.length; i++) {
          final entry = activeEntries[i];
          if (entry.targetPath != path) {
            continue;
          }

          final result = results[i];
          if (result.exitCode != 0) {
            continue;
          }

          final stdoutStr = result.stdout.toString();
          final regex = RegExp(r'\.agents/skills/([\w\-]+)');
          final matches = regex.allMatches(stdoutStr);
          var extractedSkills = matches.map((m) => m.group(1)!).toSet()
            ..addAll(entry.skills);

          if (entry.excludes.isNotEmpty || entry.excludePatterns.isNotEmpty) {
            final allExcludeRegExps = [
              ...entry.excludePatterns.map(patternToRegExp),
            ];

            extractedSkills = extractedSkills.where((skill) {
              if (entry.excludes.contains(skill)) {
                return false;
              }
              for (final regex in allExcludeRegExps) {
                if (regex.hasMatch(skill)) {
                  return false;
                }
              }
              return true;
            }).toSet();

            for (final exclude in entry.excludes) {
              _deleteSkillDir(entry, exclude);
            }
            final regexes = entry.excludePatterns.map(patternToRegExp).toList();
            if (regexes.isNotEmpty) {
              final skillDir = entry.targetPath == null
                  ? expandPath('~/.agents/skills')
                  : '${expandPath(entry.targetPath!)}/.agents/skills';
              final dir = Directory(skillDir);
              if (dir.existsSync()) {
                for (final entity in dir.listSync()) {
                  if (entity is Directory) {
                    final skillName = entity.uri.pathSegments
                        .where((s) => s.isNotEmpty)
                        .last;
                    for (final regex in regexes) {
                      if (regex.hasMatch(skillName)) {
                        entity.deleteSync(recursive: true);
                        break;
                      }
                    }
                  }
                }
              }
            }
          }

          for (final skill in extractedSkills) {
            final existing = allPossible[skill] as Map<String, dynamic>?;
            mergedSkills[skill] = <String, dynamic>{
              'source': entry.source,
              'sourceType': existing?['sourceType'] ?? 'github',
              'computedHash': existing?['computedHash'] ?? '',
            };
          }
        }

        final addedSkills = <String, String>{};
        final removedSkills = <String, String>{};

        final beforeSkills = before['skills'] as Map<String, dynamic>? ?? {};

        for (final skill in mergedSkills.keys) {
          final afterSource =
              (mergedSkills[skill] as Map<String, dynamic>)['source']
                  as String? ??
              'unknown';
          if (!beforeSkills.containsKey(skill)) {
            addedSkills[skill] = afterSource;
          }
        }
        for (final skill in beforeSkills.keys) {
          if (!mergedSkills.containsKey(skill)) {
            removedSkills[skill] =
                (beforeSkills[skill] as Map<String, dynamic>)['source']
                    as String? ??
                'unknown';
          }
        }

        diffs[path] = {'added': addedSkills, 'removed': removedSkills};

        final finalLock = <String, dynamic>{
          'version': before['version'] ?? 3,
          'skills': mergedSkills,
          'dismissed': <String, dynamic>{},
        };
        writeLock(path, finalLock);
      }
      progress?.complete('Installation process completed.');

      if (hasError) {
        logger.warn('\n⚠️  Errors occurred while syncing some skills.');
      } else {
        logger.success('\nAll skills have been successfully synced/verified.');
      }
    }

    if (!dryRun) {
      logger.info('\n=== Installation Summary ===');

      for (final path in validPaths) {
        final targetName = path ?? 'global';
        logger.info('📍 $targetName:');

        final lockfilePath = path == null
            ? expandPath('~/.agents/.skill-lock.json')
            : '${expandPath(path)}/skills-lock.json';
        final lockfile = File(lockfilePath);
        final skillsPerSource = <String, List<String>>{};

        if (lockfile.existsSync()) {
          try {
            final content = lockfile.readAsStringSync();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final skills = json['skills'] as Map<String, dynamic>? ?? {};

            for (final entry in skills.entries) {
              final skillName = entry.key;
              final skillData = entry.value as Map<String, dynamic>;
              final source = skillData['source'] as String? ?? 'unknown';

              skillsPerSource.putIfAbsent(source, () => []).add(skillName);
            }
          } on FormatException catch (e) {
            logger.warn('    ⚠️  Failed to parse lockfile: $lockfilePath ($e)');
          }
        }

        if (skillsPerSource.isEmpty) {
          logger.info('  - (No skills installed)');
        } else {
          final sources = skillsPerSource.keys.toList()..sort();
          for (final source in sources) {
            logger.info('  - $source');
            final skills = skillsPerSource[source]!..sort();
            for (final skill in skills) {
              logger.info('    - $skill');
            }
          }
        }

        final pathDiff = diffs[path] ?? {};
        final added = pathDiff['added'] ?? {};
        final removed = pathDiff['removed'] ?? {};

        if (added.isNotEmpty || removed.isNotEmpty) {
          logger.info('\n    [Changes from previous sync]');
          if (added.isNotEmpty) {
            final sortedAdded = added.keys.toList()..sort();
            for (final skill in sortedAdded) {
              logger.info('    ✨ Added: $skill (${added[skill]})');
            }
          }
          if (removed.isNotEmpty) {
            final sortedRemoved = removed.keys.toList()..sort();
            for (final skill in sortedRemoved) {
              logger.info('    🗑️  Removed: $skill (${removed[skill]})');
            }
          }
        } else {
          logger
            ..info('\n    [Changes]')
            ..info('    🔄 All skills are up to date (no changes).');
        }
      }
    }

    if (skippedPaths.isNotEmpty) {
      logger.info(
        '\n⏭️  The following paths were skipped as they do not exist:',
      );
      for (final path in skippedPaths) {
        logger.info('  - $path');
      }
    }

    return hasError ? 1 : 0;
  }

  List<String> _buildCommand(SkillEntry entry) {
    return [
      'npx',
      'skills',
      'add',
      entry.source,
      if (entry.targetPath == null) '--global',
      '--agent',
      'antigravity',
      '-y',
      if (entry.skills.isNotEmpty) ...['--skill', ...entry.skills],
    ];
  }

  List<String> _extractSkillNames(String output) {
    final cleanOutput = output.replaceAll(
      RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'),
      '',
    );
    final names = <String>{};
    final regex = RegExp(r'(?:│\s{4}|-\s+|│\s+-\s+)([\w\d\-]+)(?:\s|$)');
    for (final match in regex.allMatches(cleanOutput)) {
      final name = match.group(1)!;
      if (name.length > 2 && !name.contains(' ')) {
        names.add(name);
      }
    }
    return names.toList();
  }

  void _deleteSkillDir(SkillEntry entry, String skillName) {
    final excludePath = entry.targetPath == null
        ? expandPath('~/.agents/skills/$skillName')
        : '${expandPath(entry.targetPath!)}/.agents/skills/$skillName';
    final excludeDir = Directory(excludePath);
    if (excludeDir.existsSync()) {
      excludeDir.deleteSync(recursive: true);
    }
  }
}
