# skills_sync 🚀

[![pub package](https://img.shields.io/pub/v/skills_sync.svg)](https://pub.dev/packages/skills_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A CLI tool to keep [AI Agent Skills](https://agentskills.io/home) (`SKILL.md`) in sync across your projects based on a central `skills.yaml` configuration file.

## Key Features

- 📦 **Batch Sync**: Install and sync multiple skills from various repositories or local folders.
- ⚡ **Wildcard Support**: Use `*` for batch selection and `!` for exclusions in your configuration.
- 🧐 **Optimization**: Save AI context window pressure by organizing skills and using security-audited skills.
- 🤖 **AI-Ready**: Bundled with dedicated [AI Agent Skills](https://agentskills.io/home) to help the AI manage your configuration.

---

## Core Skills for AI Agents

This repository includes dedicated skills to help AI agents manage your development environment:

- **[skills-sync](https://github.com/mono0926/skills-sync/blob/main/skills/skills-sync/SKILL.md)**: Teaches the AI how to use this CLI tool correctly, ensuring it doesn't make accidental changes.
- **[skills-optimizer](https://github.com/mono0926/skills-sync/blob/main/skills/skills-optimizer/SKILL.md)**: Enables the AI to analyze your tech stack and propose optimizations for your `skills.yaml`, including security audits of new skills.

To use them, add `mono0926/skills-sync` to your `skills.yaml`.

---

## Installation

```bash
dart pub global activate skills_sync
```

## Quick Start

1.  **Initialize**: Run `skills_sync init` to generate the default global configuration at `~/.config/skills_sync/skills.yaml`.
2.  **Configure**: Edit the configuration to add your favorite skill sources.
3.  **Sync**: Run `skills_sync sync` in your project to thoroughly sync skills (deletes extra skills by default).
4.  **Update**: Run `skills_sync update` for a quick version update of all installed skills.

---

## Detailed Usage

### 1. Initialization

Run the following command to set up your configuration:

```bash
skills_sync init
```

This generates `~/.config/skills_sync/skills.yaml`. By default, `skills_sync` uses this global configuration.

> [!TIP]
> You can also place a `skills.yaml` in your project root for project-specific settings. If present, it will take precedence over the global configuration.

### 2. Configuration

Edit the global or project-local `skills.yaml` to specify which skills to sync. You can use wildcards (`*`) and exclusions (`!`).

### 3. Synchronization

> [!WARNING]
> By default, `sync` will **delete all existing skills** in the target directories before installing the ones defined in your configuration to ensure a clean state.
>
> Use the `-y` or `--yes` flag to skip the confirmation prompt.

Apply your configuration changes by running:

```bash
skills_sync sync
```

#### Options:

- `--clean`: (Default: `true`) Delete existing skills before syncing. Use `--no-clean` to skip this step for a faster sync.
- `--agent <name>`: Specify the target agent (default: `antigravity`). Use `*` to target all agents.

### 4. Update

For a faster update that only checks for the latest versions of your currently configured skills without reaching for a clean state, use the `update` command:

```bash
skills_sync update
```

This runs `gh skill update --all` across all configured global and local paths.

---

## Configuration Example

See [example/mono/skills.yaml](https://github.com/mono0926/skills-sync/blob/main/example/mono/skills.yaml) for a real-world example.

```yaml
global:
  mono0926/skills:
  anthropics/skills:
    - '*' # All skills
    - '!recipe-*' # Exclude skills starting with 'recipe-'

~/Git/my-project:
  mono0926/skills:
    - flutter-* # Only flutter-related skills
```

---

## Subcommands

- `init`: Generates configuration files.
- `config`: Opens configuration in your default editor.
- `sync`: Thoroughly syncs skills (re-installs).
- `update`: Quickly updates existing skills in-place.
- `list`: Shows current configuration and installation status.

## Environment Requirements

- **GitHub CLI**: Required for `gh` command.
- **gh-skill extension**: Required for managing skills (`gh extension install mono0926/gh-skill`).
- **Git**: Required for fetching remote repositories.

## Developer Note

To run locally for development:

```bash
dart pub get
dart run skills_sync sync
```

## License

MIT
