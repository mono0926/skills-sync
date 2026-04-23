import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skills_sync/src/audit_cache.dart';
import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';
import 'package:yaml/yaml.dart';

/// The command that synchronizes skills based on the configuration file.
class SyncCommand extends SkillsSyncCommand {
  /// Creates a new [SyncCommand].
  SyncCommand() {
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
        help: 'Skip confirmation prompt and proceed with syncing.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output result in JSON format for AI parsing.',
      )
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'Specify the agent name to install skills for.',
        defaultsTo: 'antigravity',
      )
      ..addFlag(
        'clean',
        help: 'Delete all existing skills before syncing.',
        defaultsTo: true,
      );
  }

  @override
  String get description => 'Syncs skills based on the configuration file.';

  @override
  String get name => 'sync';

  @override
  Future<int> run() async {
    if (!await checkGh()) {
      logger
        ..err('gh command or skill extension not found.')
        ..info(
          '\nPlease install GitHub CLI and the skill extension:\n'
          'https://cli.github.com/\n'
          'gh extension install mono0926/gh-skill',
        );
      return 1;
    }

    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final configPath = argResults?['config'] as String?;
    final agent = argResults?['agent'] as String? ?? 'antigravity';
    final clean = argResults?['clean'] as bool? ?? false;
    final configFile = findConfigFile(configPath);

    if (configFile == null) {
      logger.err('Configuration file not found.');
      return 1;
    }

    final yamlString = await configFile.readAsString();
    final yaml = loadYaml(yamlString) as YamlMap;
    final entries = parseSkillEntries(yaml);
    final auditCache = await AuditCache.load();

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
          ? expandPath('~/.gemini/antigravity/.skill-lock.json')
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
          ? expandPath('~/.gemini/antigravity/.skill-lock.json')
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

    final yes = argResults?['yes'] as bool? ?? false;

    if (!yes && clean) {
      final targetDirs = validPaths.map((p) => p ?? 'global').join('\n  - ');
      logger
        ..warn(
          '⚠️  WARNING: This command will DELETE all existing skills in the '
          'target directories before syncing.',
        )
        ..info('Target locations:\n  - $targetDirs\n');

      if (!dryRun) {
        final confirmed = logger.confirm('Do you want to proceed?');
        if (!confirmed) {
          return 0;
        }
        logger.info('');
      } else {
        logger.info('=== Dry Run: Skipping confirmation prompt ===\n');
      }
    }

    final diffs = <String?, Map<String, dynamic>>{};

    if (clean) {
      if (dryRun) {
        logger.info(
          '=== Dry Run: The following removal commands would be executed ===',
        );
      } else {
        logger.info('=== Removing existing skills ===');
      }

      for (final path in validPaths) {
        final targetName = path ?? 'global';
        final targetDir = path == null
            ? expandPath('~/.gemini/antigravity/skills')
            : '${expandPath(path)}/.agents/skills';

        if (dryRun) {
          logger.info('rm -rf $targetDir');
          continue;
        }

        final progress = logger.progress('Removing skills for $targetName...');
        final dir = Directory(targetDir);
        if (dir.existsSync()) {
          try {
            dir.deleteSync(recursive: true);
            progress.complete('Removed skills for $targetName.');
          } on Exception catch (e) {
            progress.fail('Failed to remove skills for $targetName: $e');
            hasError = true;
          }
        } else {
          progress.complete('No skills found for $targetName (already clean).');
        }
      }
      logger.success('Existing skills removed.\n');
    } else if (!dryRun && !clean) {
      logger.info('=== Updating skills (clean mode disabled) ===');
    }

    // --- Resolve Patterns ---
    final resolvedEntries = <SkillEntry>[];
    for (final entry in entries) {
      final targetName = entry.targetPath ?? 'global';
      final progress = logger.progress(
        'Checking available skills for $targetName (${entry.source})...',
      );

      final isLocal =
          entry.source.startsWith('/') || entry.source.startsWith('~');
      ProcessResult? listResult;
      var availableSkills = <String>[];

      if (isLocal) {
        final sourcePath = expandPath(entry.source);
        final sourceDir = Directory(sourcePath);
        if (sourceDir.existsSync()) {
          final skillFiles = sourceDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => p.basename(f.path).toLowerCase() == 'skill.md');

          for (final file in skillFiles) {
            final skillDir = file.parent;
            if (p.equals(skillDir.path, sourcePath)) {
              availableSkills.add(''); // Root skill
              continue;
            }
            final relativePath = p.relative(skillDir.path, from: sourcePath);
            final segments = p.split(relativePath);
            
            // Handle standard container directories
            if (segments.length >= 2 && 
                (segments[0] == 'skills' || 
                 (segments[0] == '.gemini' && segments[1] == 'skills') ||
                 (segments[0] == '.agent' && segments[1] == 'skills'))) {
              availableSkills.add(segments.last);
            } else if (segments.length >= 4 && segments[0] == 'plugins' && segments[2] == 'skills') {
              availableSkills.add(segments.last);
            } else if (segments.length == 1) {
              availableSkills.add(segments[0]); // Root level sub-dir
            } else {
              availableSkills.add(relativePath); // Deeply nested, use full path
            }
          }
        }
      } else {
        // Detect default branch
        final repoInfo = await Process.run('gh', [
          'api',
          'repos/${entry.source}',
          '--jq',
          '.default_branch',
        ], runInShell: true);
        final branch = repoInfo.exitCode == 0
            ? (repoInfo.stdout as String).trim()
            : 'main';

        // Use Git Trees API (recursive) to find all SKILL.md files in one call
        final response = await Process.run('gh', [
          'api',
          'repos/${entry.source}/git/trees/$branch?recursive=1',
          '--jq',
          '.tree[] | select(.path | endswith("/SKILL.md") or . == "SKILL.md") | .path',
        ], runInShell: true);

        if (response.exitCode == 0) {
          final paths = response.stdout
              .toString()
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);

          for (final path in paths) {
            if (path == 'SKILL.md') {
              availableSkills.add(''); // Root skill
              continue;
            }
            final relativePath = p.dirname(path);
            final segments = p.split(relativePath);
            
            // Handle standard container directories
            if (segments.length >= 2 && 
                (segments[0] == 'skills' || 
                 (segments[0] == '.gemini' && segments[1] == 'skills') ||
                 (segments[0] == '.agent' && segments[1] == 'skills'))) {
              availableSkills.add(segments.last);
            } else if (segments.length >= 4 && segments[0] == 'plugins' && segments[2] == 'skills') {
              availableSkills.add(segments.last);
            } else if (segments.length == 1) {
              availableSkills.add(segments[0]); // Root level sub-dir
            } else {
              availableSkills.add(relativePath); // Deeply nested, use full path
            }
          }
        } else {
          listResult = response;
        }
      }

      availableSkills = availableSkills.toSet().toList(); // De-duplicate

      if (availableSkills.isEmpty && !isLocal && listResult != null) {
        progress.fail('Failed to get skill list: ${entry.source}');
        resolvedEntries.add(entry);
        hasError = true;
        continue;
      }

      final matchedSkills = <String>{};

      if (entry.skills.isEmpty &&
          entry.patterns.isEmpty &&
          entry.excludes.isEmpty &&
          entry.excludePatterns.isEmpty) {
        // Case: No specific skills or patterns, install everything discovered
        matchedSkills.addAll(availableSkills);
      } else {
        // Add explicit skills if they exist in availableSkills
        for (final skill in entry.skills) {
          if (availableSkills.contains(skill)) {
            matchedSkills.add(skill);
          } else if (skill.isEmpty && availableSkills.contains('')) {
            matchedSkills.add('');
          }
        }

        // Add skills matching patterns
        for (final pattern in entry.patterns) {
          final regExp = patternToRegExp(pattern);
          for (final skill in availableSkills) {
            if (regExp.hasMatch(skill)) {
              matchedSkills.add(skill);
            }
          }
        }

        // Remove excluded skills
        entry.excludes.forEach(matchedSkills.remove);

        // Remove skills matching exclude patterns
        for (final pattern in entry.excludePatterns) {
          final regExp = patternToRegExp(pattern);
          matchedSkills.removeWhere(regExp.hasMatch);
        }
      }

      if (matchedSkills.isEmpty) {
        progress.fail(
          'No skills matched for ${entry.source}.',
        );
        resolvedEntries.add(entry.copyWith(skills: []));
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

    // --- Sequential Install ---
    final activeEntries = <SkillEntry>[];
    final results = <ProcessResult>[];

    for (final entry in resolvedEntries) {
      if (entry.targetPath != null && skippedPaths.contains(entry.targetPath)) {
        continue;
      }
      activeEntries.add(entry);

      final workingDirectory = entry.targetPath != null
          ? expandPath(entry.targetPath!)
          : null;
      final targetName = entry.targetPath ?? 'global';

      final skillsToInstall = entry.skills.isEmpty ? [''] : entry.skills;
      final installed = <String>[];
      var entryHasError = false;

      if (dryRun) {
        for (final skill in skillsToInstall) {
          final command = _buildCommand(
            entry.source,
            skill,
            agent: agent,
            isGlobal: entry.targetPath == null,
          );
          final wdStr = workingDirectory != null
              ? ' (in $workingDirectory)'
              : '';
          logger.info('${command.join(' ')}$wdStr');
        }
        continue;
      }

      final installProgress = logger.progress(
        'Installing skills from ${entry.source} to $targetName...',
      );

      for (final skill in skillsToInstall) {
        final command = _buildCommand(
          entry.source,
          skill,
          agent: agent,
          isGlobal: entry.targetPath == null,
        );

        final result =
            await Process.start(
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

        if (result.exitCode == 0) {
          if (skill.isEmpty) {
            // All skills were installed (if gh skill supported it, but
            // it's interactive)
            // For now, we assume pattern resolution filled entry.skills
          } else {
            installed.add(skill);
          }
          results.add(result);
        } else {
          logger.err(
            'Failed to install skill "$skill" from ${entry.source} '
            '(exit code: ${result.exitCode})',
          );
          entryHasError = true;
          hasError = true;
        }
      }

      if (!dryRun) {
        if (!entryHasError) {
          installProgress.complete('Installed skills from ${entry.source}.');
        } else {
          installProgress.fail(
            'Some skills failed to install from ${entry.source}.',
          );
        }

        final updatedEntry = SkillEntry(
          source: entry.source,
          skills: entry.skills,
          patterns: entry.patterns,
          excludes: entry.excludes,
          excludePatterns: entry.excludePatterns,
          targetPath: entry.targetPath,
          installedSkills: installed,
        );
        activeEntries[activeEntries.length - 1] = updatedEntry;
      }
    }

    if (!dryRun) {
      final afterLocks = <String?, Map<String, dynamic>>{};
      for (final path in validPaths) {
        afterLocks[path] = readLock(path);
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

          // Calculate hashes using Git
          final skillHashes = <String, String>{};
          for (final skill in extractedSkills) {
            final skillPath = path == null
                ? expandPath('~/.gemini/antigravity/skills/$skill')
                : '${expandPath(path)}/.agents/skills/$skill';

            final skillDir = Directory(skillPath);
            if (skillDir.existsSync()) {
              try {
                final gitInit = await Process.run('git', [
                  'init',
                ], workingDirectory: skillPath);
                if (gitInit.exitCode == 0) {
                  await Process.run('git', [
                    'add',
                    '.',
                  ], workingDirectory: skillPath);
                  final writeTree = await Process.run('git', [
                    'write-tree',
                  ], workingDirectory: skillPath);
                  if (writeTree.exitCode == 0) {
                    skillHashes[skill] = writeTree.stdout.toString().trim();
                  }
                  final dotGit = Directory('$skillPath/.git');
                  if (dotGit.existsSync()) {
                    dotGit.deleteSync(recursive: true);
                  }
                }
              } on Exception catch (e) {
                logger.detail('Failed to calculate hash for $skill: $e');
              }
            }
          }

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
                  ? expandPath('~/.gemini/antigravity/skills')
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
            final hash = skillHashes[skill];
            mergedSkills[skill] = <String, dynamic>{
              if (existing != null) ...existing,
              'source': entry.source,
              'skillFolderHash': ?hash,
            };
          }
        }

        final addedSkills = <String, String>{};
        final removedSkills = <String, String>{};
        final updatedSkills = <String, Map<String, String>>{};

        final beforeSkills = before['skills'] as Map<String, dynamic>? ?? {};

        for (final skill in mergedSkills.keys) {
          final afterData = mergedSkills[skill] as Map<String, dynamic>;
          final afterSource = afterData['source'] as String? ?? 'unknown';
          final afterHash = afterData['skillFolderHash'] as String?;

          if (!beforeSkills.containsKey(skill)) {
            addedSkills[skill] = afterSource;
          } else {
            final beforeData = beforeSkills[skill] as Map<String, dynamic>;
            final beforeHash = beforeData['skillFolderHash'] as String?;
            if (beforeHash != null &&
                afterHash != null &&
                beforeHash != afterHash) {
              updatedSkills[skill] = {
                'source': afterSource,
                'oldHash': beforeHash,
                'newHash': afterHash,
              };
            }
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

        diffs[path] = {
          'added': addedSkills,
          'removed': removedSkills,
          'updated': updatedSkills,
        };

        final finalLock = <String, dynamic>{
          'version': before['version'] ?? 3,
          'skills': mergedSkills,
          'dismissed': <String, dynamic>{},
        };
        writeLock(path, finalLock);
      }

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

        final skillsPerSource = <String, List<String>>{};
        final lockfilePath = path == null
            ? expandPath('~/.agents/.skill-lock.json')
            : '${expandPath(path)}/skills-lock.json';
        final lockfile = File(lockfilePath);

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
        final added = (pathDiff['added'] as Map?)?.cast<String, String>() ?? {};
        final removed =
            (pathDiff['removed'] as Map?)?.cast<String, String>() ?? {};
        final updated =
            (pathDiff['updated'] as Map?)
                ?.cast<String, Map<String, String>>() ??
            {};

        if (added.isNotEmpty || removed.isNotEmpty || updated.isNotEmpty) {
          logger.info('\n    [Changes from previous sync]');
          if (added.isNotEmpty) {
            final sortedAdded = added.keys.toList()..sort();
            for (final skill in sortedAdded) {
              logger.info('    ✨ Added: $skill (${added[skill]})');
            }
          }
          if (updated.isNotEmpty) {
            final sortedUpdated = updated.keys.toList()..sort();
            for (final skill in sortedUpdated) {
              final data = updated[skill]!;
              final oldHash = data['oldHash']?.substring(0, 7);
              final newHash = data['newHash']?.substring(0, 7);
              final source = data['source'];
              final fullHash = data['newHash'];
              final audit = fullHash != null
                  ? auditCache.getAudit(fullHash)
                  : null;

              if (audit != null) {
                final status = audit['securityStatus'] as String? ?? 'unknown';
                final summary = audit['summary'] as String? ?? '';
                final icon = status == 'safe'
                    ? '✅'
                    : status == 'caution'
                    ? '⚠️'
                    : '🚨';
                logger.info(
                  '    🔄 Updated: $skill ($oldHash -> $newHash, $source)\n'
                  '       $icon Audit: $status\n'
                  '       📝 Summary: $summary',
                );
                final details = audit['details'] as String?;
                if (details != null && details.isNotEmpty) {
                  logger.info('       🔒 Details: $details');
                }
              } else {
                logger.info(
                  '    🔄 Updated: $skill ($oldHash -> $newHash, $source) '
                  '[Not Audited]',
                );
              }
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

  List<String> _buildCommand(
    String source,
    String skill, {
    required String agent,
    required bool isGlobal,
  }) {
    final isLocal = source.startsWith('/') || source.startsWith('~');
    return [
      'gh',
      'skill',
      'install',
      if (isLocal) expandPath(source) else source,
      if (skill.isNotEmpty) skill,
      '--allow-hidden-dirs',
      if (isLocal) '--from-local',
      if (isGlobal) ...['--scope', 'user'],
      '--agent',
      agent,
      '--force',
    ];
  }

  void _deleteSkillDir(SkillEntry entry, String skillName) {
    final excludePath = entry.targetPath == null
        ? expandPath('~/.gemini/antigravity/skills/$skillName')
        : '${expandPath(entry.targetPath!)}/.agents/skills/$skillName';
    final excludeDir = Directory(excludePath);
    if (excludeDir.existsSync()) {
      excludeDir.deleteSync(recursive: true);
    }
  }
}
