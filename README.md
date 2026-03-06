# Skills Sync CLI

[AI Agent Skills](https://agentskills.io/home) を過不足なく一括同期するためのDart CLIツールです。

## 特徴

- **Skillsの簡単インストール**: `skills.yaml` に記述されたSkills定義に従って、過不足なく一括でインストール・同期します。
- **ワイルドカード/除外サポート**: Skills名にワイルドカード（`*`）や除外（`!`）を使用して、柔軟に構成を管理できます。
- **並列インストール**: 複数のリポジトリからのSkillsインストールを並列で実行し、高速にセットアップを完了します。
- **Skills Optimizerの同梱**: 本ツールに同梱の `skills-optimizer` をインストールすれば、対話を通じて `skills.yaml` の最適化・クリーンアップもサポートします。

## インストール

Dart SDKがインストールされている環境で、以下のコマンドを実行してください。

```bash
dart pub global activate skills_sync
```

## 使い方

初めて使用する場合は、まず `init` コマンドで設定ファイルの雛形を生成します。

```bash
skills_sync init
```

次に設定ファイルを編集します（デフォルトのエディタで開きます）。

```bash
skills_sync config
```

設定が完了したら、`sync` コマンドでSkillsを同期（インストール／不要なものの削除）します。

```bash
skills_sync sync
```

### サブコマンド一覧

- `init`: `~/.config/skills_sync/config.yaml` を生成します。
- `config`: 設定ファイルをエディタで開きます。
- `sync`: 設定に基づいてSkillsを過不足なくインストール・同期します。
- `list`: 現在の設定内容とインストール状況を表示します。

### 環境要件

- **Node.js**: `npx` コマンドを使用するため、Node.js がインストールされている必要があります。
- **Git**: 外部リポジトリからSkillsを取得する場合に必要です。

### 設定ファイルの場所

デフォルトで以下の場所を探索します：

- `~/.config/skills_sync/config.yaml`

また、`-c` または `--config` オプションを使用して、明示的にパスを指定することも可能です。

```bash
skills_sync sync --config my-skills.yaml
```

### 設定ファイルの例

```yaml
global:
  anthropics/skills:
    - '*' # 全Skills
    - '!recipe-*' # recipeで始まるSkillsを除外

./path/to/project:
  mono0926/skills:
    - flutter-* # flutter関連のSkillsのみ
```

### オプション

- `--dry-run`: 実際にインストールを行わず、実行されるコマンドの確認のみ行います。

## ライセンス

MIT
