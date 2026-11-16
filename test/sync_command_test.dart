import 'package:skills_sync/src/commands/sync.dart';
import 'package:test/test.dart';

void main() {
  late SyncCommand command;

  setUp(() {
    command = SyncCommand();
  });

  group('SyncCommand', () {
    test('extractTrackedSkills returns sorted skill names from lock data', () {
      final lockData = <String, dynamic>{
        'version': 3,
        'skills': <String, dynamic>{
          'skill-b': <String, dynamic>{'source': 'owner/repo'},
          'skill-a': <String, dynamic>{'source': 'owner/repo'},
        },
      };

      expect(command.extractTrackedSkills(lockData), ['skill-a', 'skill-b']);
    });

    test('extractTrackedSkills returns empty list when skills is missing', () {
      expect(command.extractTrackedSkills(<String, dynamic>{}), isEmpty);
      expect(
        command.extractTrackedSkills(<String, dynamic>{'skills': null}),
        isEmpty,
      );
    });

    test('buildRemoveCommand builds project-scoped command without --all', () {
      final cmd = command.buildRemoveCommand([
        'skill-a',
        'skill-b',
      ], isGlobal: false);

      expect(cmd, ['npx', 'skills', 'remove', 'skill-a', 'skill-b', '-y']);
      expect(cmd, isNot(contains('--all')));
      expect(cmd, isNot(contains('--global')));
    });

    test('buildRemoveCommand includes --global when isGlobal is true', () {
      final cmd = command.buildRemoveCommand(['skill-a'], isGlobal: true);

      expect(cmd, ['npx', 'skills', 'remove', 'skill-a', '--global', '-y']);
      expect(cmd, isNot(contains('--all')));
    });
  });
}
