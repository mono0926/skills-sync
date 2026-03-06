import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:skills_sync/src/commands/config.dart';
import 'package:skills_sync/src/commands/init.dart';
import 'package:skills_sync/src/commands/list.dart';
import 'package:skills_sync/src/commands/sync.dart';
import 'package:skills_sync/src/exceptions.dart';
import 'package:skills_sync/src/logger.dart';

class SkillsSyncCommandRunner extends CompletionCommandRunner<int> {
  SkillsSyncCommandRunner()
    : super('skills_sync', 'AI Agent Skillsを過不足なく同期するCLIツール') {
    addCommand(SyncCommand());
    addCommand(ListCommand());
    addCommand(InitCommand());
    addCommand(ConfigCommand());
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    try {
      return await super.run(args);
    } on FormatException catch (e) {
      logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return 64; // usage error
    } on UsageException catch (e) {
      logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return 64; // EX_USAGE
    } on AppException catch (e) {
      logger.err(e.message);
      return 1;
    } on Exception catch (e, stackTrace) {
      logger
        ..err('An unexpected error occurred: $e')
        ..err(stackTrace.toString());
      return 1;
    }
  }
}
