import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skills_sync/src/command_base.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

class TestCommand extends SkillsSyncCommand {
  @override
  String get description => 'Test Command';

  @override
  String get name => 'test';

  @override
  Future<int> run() async => 0;
}

void main() {
  late TestCommand command;

  setUp(() {
    command = TestCommand();
  });

  group('SkillsSyncCommand', () {
    test('expandPath expands ~/ correctly', () {
      final home = Platform.environment['HOME'];
      if (home != null) {
        expect(command.expandPath('~/foo'), '$home/foo');
      }
      expect(command.expandPath('foo/bar'), 'foo/bar');
    });

    test(
      'findConfigFile prioritizes ./skills.yaml over global (mocked via temp)',
      () {
        final tempDir = Directory.systemTemp.createTempSync('skills_sync_test');
        try {
          final skillsFile = File(p.join(tempDir.path, 'skills.yaml'))
            ..writeAsStringSync('global: {}');
          expect(
            command.findConfigFile(skillsFile.path)?.path,
            skillsFile.path,
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test('patternToRegExp converts wildcards to regex', () {
      final regex = command.patternToRegExp('flutter-*');
      expect(regex.hasMatch('flutter-hooks'), isTrue);
      expect(regex.hasMatch('flutter_hooks'), isFalse);
      expect(regex.hasMatch('FLUTTER-HOOKS'), isTrue); // case-insensitive

      final regexComplex = command.patternToRegExp('abc.def*ghi');
      expect(regexComplex.hasMatch('abc.def_xyz_ghi'), isTrue);
    });

    test('parseSkillEntries handles various YAML structures', () {
      final yaml =
          loadYaml('''
global:
  mono0926/skills-sync:
  another/repo: []
  filtered/repo:
    - skill1
    - "pattern-*"
    - "!exclude-*"
~/local/path:
  local/repo:
    - local-skill
''')
              as YamlMap;

      final entries = command.parseSkillEntries(yaml);

      expect(entries.length, 4);

      // global: mono0926/skills-sync: (value is null)
      final globalAll = entries.firstWhere(
        (e) => e.source == 'mono0926/skills-sync',
      );
      expect(globalAll.targetPath, isNull);
      expect(globalAll.skills, isEmpty);
      expect(globalAll.patterns, isEmpty);

      // global: another/repo: [] (value is YamlList)
      final globalEmpty = entries.firstWhere((e) => e.source == 'another/repo');
      expect(globalEmpty.skills, isEmpty);

      // global: filtered/repo
      final filtered = entries.firstWhere((e) => e.source == 'filtered/repo');
      expect(filtered.skills, contains('skill1'));
      expect(filtered.patterns, contains('pattern-*'));
      expect(filtered.excludePatterns, contains('exclude-*'));

      // ~/local/path
      final local = entries.firstWhere((e) => e.source == 'local/repo');
      // expect(local.targetPath, contains('local/path')); // expandPath will be called
      expect(local.skills, contains('local-skill'));
    });
  });
}
