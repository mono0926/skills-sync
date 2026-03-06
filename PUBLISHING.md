# Automated Release Procedure (GitHub Actions)

Releasing `skills_sync` to `pub.dev` is automated using GitHub Actions.
It uses OIDC (OpenID Connect), so password or secret key management is not required and it is secure.

## Preparation (One-time only)

To enable automated publishing, you need to perform the following settings on `pub.dev`.

1.  Access **[pub.dev/packages/skills_sync/admin](https://pub.dev/packages/skills_sync/admin)**.
2.  Find the **Automated publishing** section.
3.  Click **Enable publishing from GitHub Actions**.
4.  Enter the following values and save.
    - **Repository**: `mono0926/skills-sync`
    - **Tag pattern**: `v{{version}}`

## Release Workflow

To release a new version to pub.dev, we use the `release-pub` skill which automates the process safely.

Simply ask the AI Assistant:

> /release-pub

The skill will specifically handle:

1. Pre-release checks (`git status`, code formatting, analysis, and `pub publish --dry-run`).
2. Determining the correct version bump (major/minor/patch) based on commit history.
3. Automatically generating and updating the `CHANGELOG.md`.
4. Updating `pubspec.yaml`.
5. Committing, tagging, and creating a GitHub release.

After the AI completes the skill and pushes the tag, GitHub Actions will trigger and automatically upload to `pub.dev`. ✨

1.  Open the **Actions** tab on GitHub.
2.  Verify that the workflow named **Publish to pub.dev** has started.
3.  Once finished, the new version will be reflected on `pub.dev` within a few minutes.
