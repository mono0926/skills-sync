import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skills_sync/src/command_base.dart';
import 'package:skills_sync/src/logger.dart';

/// The command that initializes the skills_sync configuration.
class InitCommand extends SkillsSyncCommand {
  /// Initializes a new instance of the [InitCommand].
  InitCommand();
  @override
  String get description =>
      'Generates the default global configuration file (~/.config/skills_sync/skills.yaml).';

  @override
  String get name => 'init';

  @override
  Future<int> run() async {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) {
      logger.err('Could not identify the HOME directory.');
      return 1;
    }

    final configDir = Directory(p.join(home, '.config', 'skills_sync'));
    final configFile = File(p.join(configDir.path, 'skills.yaml'));

    if (configFile.existsSync()) {
      logger.warn('Configuration file already exists: ${configFile.path}');
      return 0;
    }

    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    const template = r'''# skills_sync global configuration file
#
# Location: ~/.config/skills_sync/skills.yaml
#
# Examples:
# global:
#   # Install skills globally to ~/.agents/skills/
#   # source: [skill1, skill2, ...]
#   mono0926/skills-sync: # Sync all skills
#
# ~/Git/my-project:
#   # Install skills to a specific project directory
#   mono0926/skills-sync:
#     - skills-optimizer
#     - "!recipe-*" # Exclude skills starting with 'recipe-'
#   anthropics/skills:
#     - "flutter-*" # Wildcard match

global:
  mono0926/skills-sync: # Essential skills including Skills Optimizer
''';

    configFile.writeAsStringSync(template);
    logger
      ..success('Generated configuration file: ${configFile.path}')
      ..info('\nNext, run `skills_sync sync` to install skills.');

    return 0;
  }
}
