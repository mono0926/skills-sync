# Skills Sync CLI

[AI Agent Skills](https://agentskills.io/home) を過不足なく一括同期するためのDart CLIツールです。

## 特徴

- **Skillsの簡単インストール**: `skills.yaml` に記述されたSkills定義に従って、過不足なく一括でインストール・同期します。
- **ワイルドカード/除外サポート**: Skills名にワイルドカード（`*`）や除外（`!`）を使用して、柔軟に構成を管理できます。
- **並列インストール**: 複数のリポジトリからのSkillsインストールを並列で実行し、高速にセットアップを完了します。
- **Skills Optimizer による継続的な最適化**: `skills.yaml` に `mono0926/skills-sync` を追加することで、専用の Skills が利用可能になります。
  - **メリット**:
    - 💡 **コンテキストの節約**: 不要な Skills を整理し、AI が本来の作業に集中できる環境を作ります。
    - 🛡️ **セキュリティ監査**: 新しく追加する Skills を AI が事前に読み取って安全性を確認します。
    - 🚀 **スタック最適化**: ユーザーの技術スタックに合わせた最適な Skills を AI が自ら提案します。

## インストール

Dart SDKがインストールされている環境で、以下のコマンドを実行してください。

```bash
dart pub global activate skills_sync
```

## 使い方

### 2. 初期セットアップ

プロジェクトのルートディレクトリで実行します：

```bash
skills-sync init
```

これにより、`~/.config/skills_sync/config.yaml`（初回のみ）と、プロジェクトごとの `skills.yaml` が生成されます。デフォルトで `skills-optimizer` を含む `mono0926/skills-sync` リポジトリが設定に含まれます。

### 3. 同期

`skills.yaml` に基づいて Skills を同期します：

```bash
skills-sync sync
```

### 4. Skills Optimizer の活用

同期完了後、AI アシスタントに対して以下のように依頼してください：

「Skillsを最適化して」
「新しい技術スタックに合わせたSkillsを提案して」

AI が `skills.yaml` の内容を分析し、最適な設定への更新をサポートします。自分で `skills.yaml` に追記する場合は以下のように記述します。

```yaml
global:
  mono0926/skills-sync: # 全Skills（Skills Optimizerを含む）をインストール
  ~/Git/skills-sync/skills/skills-optimizer: # ローカルパス指定の例
```

> [!NOTE]
>
> - 値を空（`:` の後に何も書かない）にするか空リスト `[]` を指定すると、そのリポジトリに含まれるすべての Skills をインストールします。
> - **ローカルパス指定の注意**: `npx skills add` は、指定したディレクトリの直下に `SKILL.md` があることを期待します。そのため、リポジトリのルートではなく、`skills/xxx` のように個別の Skill ディレクトリを指定してください。

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
skills-sync sync --config my-skills.yaml
```

### 設定ファイルの例

リポジトリ内の [examples/mono/skills.yaml](https://github.com/mono0926/skills-sync/blob/main/examples/mono/skills.yaml) も参考にしてください。

```yaml
global:
  mono0926/skills-sync: # Skills Optimizer を含む
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
