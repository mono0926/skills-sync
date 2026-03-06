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

Follow these steps to release a new version.

### 1. Pre-release Checks

Before running the release script, ensure that the code is formatted and there are no analysis issues.

```bash
dart format .
dart analyze
```

### 2. Run the Release Script

Run the following command in the project root directory.

```bash
# To bump the patch version (0.0.x) (default)
dart run scripts/release.dart

# To bump the minor version (0.x.0)
dart run scripts/release.dart --minor

# To bump the major version (x.0.0)
dart run scripts/release.dart --major
```

This script automatically performs the following tasks:

1.  Updates the version in `pubspec.yaml`.
2.  Inserts a version header into `CHANGELOG.md`.
3.  Staging, committing, and tagging (`vx.y.z`) in Git.
4.  Creating a GitHub Release with the latest changelog entries.
5.  Final confirmation before pushing.

### 2. Adjust CHANGELOG.md (Optional)

The script pauses before committing, so we recommend writing specific changes in `CHANGELOG.md` at that time.

### 3. Confirm Push and Automated Execution

When you approve the push (`y`) as instructed by the script, GitHub Actions will trigger and automatically upload to `pub.dev`. ✨

1.  Open the **Actions** tab on GitHub.
2.  Verify that the workflow named **Publish to pub.dev** has started.
3.  Once finished, the new version will be reflected on `pub.dev` within a few minutes.

---

> [!TIP]
> We recommend running `dart pub publish --dry-run` locally before pushing tags to final-check the package contents. ✨
