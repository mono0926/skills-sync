---
name: skills-sync
description: Provides usage instructions and best practices for the skills_sync CLI tool. Use this to understand how to manage, sync, and configure AI agent skills based on the user's config file.
---

# Skills Sync

A skill for using the `skills_sync` CLI tool, which is used to manage and sync AI agent skills.

## Context

The `skills_sync` tool reads a configuration file and synchronizes the user's local skills directory (typically `~/.agents/skills`) with remote repositories.

**Configuration Precedence**:

1. Project-specific: `./skills.yaml`
2. Global: `~/.config/skills_sync/skills.yaml`

**Crucial Note**: When another skill (like `skills-optimizer`) modifies the `skills.yaml` configuration, those changes are NOT automatically applied. You MUST run `skills_sync sync` to download new skills, remove deleted ones, and apply exclusions.

## Commands

Here are the primary commands for `skills_sync`:

### `skills_sync sync`

Synchronizes the skills based on the configuration file.

- **When to use**: Immediately after any modifications to `~/.config/skills_sync/skills.yaml` or when the user requests to update their skills.
- **Action**: It fetches repositories, applies includes/excludes, and ensures locally installed skills match the configuration.

### `skills_sync list`

Lists the current configuration and locally installed skills.

- **When to use**: To verify what is currently configured vs. what is actually installed, or to show the user their current setup.

### `skills_sync config`

Opens the `skills.yaml` configuration file in the user's default editor (or the editor specified by `$EDITOR`).

- **When to use**: When the user wants to manually edit their configuration rather than having the AI do it.

### `skills_sync init`

Generates the default global configuration file (`~/.config/skills_sync/skills.yaml`) if it does not exist.

- **When to use**: Usually only necessary for first-time setup if the file is missing.

## Workflow Integration (e.g., with `skills-optimizer`)

If you are modifying the user's `skills.yaml` (e.g., adding or removing skills):

1. **Identify the config file**: Check if a project-local `skills.yaml` exists. If not, use the global `~/.config/skills_sync/skills.yaml`.
2. **Modify the configuration**: Edit the identified `skills.yaml` file according to the user's instructions or your optimization logic.
3. **Apply the changes**: Execute `skills_sync sync` via the command line to ensure the changes take effect.
4. **Verify**: Optionally, run `skills_sync list` to confirm the installation matches expectations.

## Best Practices

- **Do not execute `sync` automatically**: NEVER run `skills_sync sync` without explicit user permission. Always ask the user if they want to apply the changes after you have modified the configuration.
- **Transparency in Configuration**: Do not modify `skills.yaml` silently. Clearly explain which skills you are adding or removing and why, ensuring the user maintains full awareness of their installed skills at all times.
- **Do not guess file paths**: Always rely on the `skills_sync` tool to handle the installation logic, cloning, and copying. Don't try to manually download zip files or clone repos with `git` to `~/.agents/skills` unless specifically requested to bypass the tool.
- **Wait for completion**: `skills_sync sync` might take a moment if it needs to download large repositories. Allow the command to finish.
- **Dry runs are not currently supported**: If you change the yaml and run sync, it will make destructive changes (deleting unlisted skills). Be sure of the user's intent before syncing after a configuration removal.
