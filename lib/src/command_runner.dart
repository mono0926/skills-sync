import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:skills_sync/src/commands/config.dart';
import 'package:skills_sync/src/commands/init.dart';
import 'package:skills_sync/src/commands/list.dart';
import 'package:skills_sync/src/commands/sync.dart';
import 'package:skills_sync/src/exceptions.dart';
import 'package:skills_sync/src/logger.dart';

/// The command runner for the skills_sync CLI tool.
class SkillsSyncCommandRunner extends CompletionCommandRunner<int> {
  /// Initializes the runner with all available commands.
  SkillsSyncCommandRunner()
    : super('skills_sync', 'A CLI tool to keep AI Agent Skills in sync.') {
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
