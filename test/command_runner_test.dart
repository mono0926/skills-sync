import 'package:skills_sync/src/command_runner.dart';
import 'package:test/test.dart';

void main() {
  late SkillsSyncCommandRunner runner;

  setUp(() {
    runner = SkillsSyncCommandRunner();
  });

  group('SkillsSyncCommandRunner', () {
    test('has correct name and description', () {
      expect(runner.executableName, 'skills_sync');
      expect(
        runner.description,
        'A CLI tool to keep AI Agent Skills in sync.',
      );
    });

    test('has all required commands registered', () {
      expect(runner.commands.containsKey('sync'), isTrue);
      expect(runner.commands.containsKey('list'), isTrue);
      expect(runner.commands.containsKey('init'), isTrue);
      expect(runner.commands.containsKey('config'), isTrue);
    });
  });
}
