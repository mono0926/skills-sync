# skills_sync 🚀

[![pub package](https://img.shields.io/pub/v/skills_sync.svg)](https://pub.dev/packages/skills_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A CLI tool to keep [AI Agent Skills](https://agentskills.io/home) (`SKILL.md`) in sync across your projects based on a central `skills.yaml` configuration file.

## Key Features

- 📦 **Batch Sync**: Install and sync multiple skills from various repositories or local folders.
- ⚡ **Wildcard Support**: Use `*` for batch selection and `!` for exclusions in your configuration.
- 🧐 **Optimization**: Save AI context window pressure by organizing skills and using security-audited skills.

---

## Installation

```bash
dart pub global activate skills_sync
```

## Quick Start

1. **Initialize**: Run `skills_sync init` to generate the default global configuration at `~/.config/skills_sync/skills.yaml`.
2. **Configure**: Edit the global configuration to add your favorite skill sources.
3. **Sync**: Run `skills_sync sync` to install and update skills in your project.

---

---

## Installation

```bash
dart pub global activate skills_sync
```

## Quick Start

## Detailed Usage

### 1. Initialization

Run this in your project root:

```bash
skills_sync init
```

This generates `~/.config/skills_sync/skills.yaml`. By default, `skills_sync` uses this global configuration to manage skills across all your projects.

> [!NOTE]
> You can also place a `skills.yaml` in your project root for project-specific settings. If present, it will take precedence over the global configuration.

### 2. Synchronization

Sync your skills based on `skills.yaml`:

```bash
skills_sync sync
```

---

## Configuration Example

```yaml
global:
  mono0926/skills_sync: # Includes Skills Optimizer
  anthropics/skills:
    - '*' # All skills
    - '!recipe-*' # Exclude skills starting with 'recipe-'

./path/to/project:
  mono0926/skills:
    - flutter-* # Only flutter-related skills
```

---

## Subcommands

- `init`: Generates configuration files.
- `config`: Opens configuration in your default editor.
- `sync`: Installs and syncs skills.
- `list`: Shows current configuration and installation status.

## Environment Requirements

- **Node.js**: Required for `npx` command.
- **Git**: Required for fetching remote repositories.

## Developer Note

To run locally for development:

```bash
dart pub get
dart run skills_sync sync
```

## License

MIT
