# 自動リリース手順 (GitHub Actions)

`skills_sync` の `pub.dev` へのリリースは、GitHub Actions を使用して自動化されています。
OIDC (OpenID Connect) を利用しているため、パスワードや秘密鍵の管理は不要で安全です。

## 事前準備 (一回のみ)

自動リリースを有効にするには、以下の設定を `pub.dev` 上で行う必要があります。

1.  **[pub.dev/packages/skills_sync/admin](https://pub.dev/packages/skills_sync/admin)** にアクセスします。
2.  **Automated publishing** セクションを探します。
3.  **Enable publishing from GitHub Actions** をクリックします。
4.  以下の値を入力して保存します。
    - **Repository**: `mono0926/skills-sync`
    - **Tag pattern**: `v{{version}}`

## リリースの流れ

新しいバージョンをリリースする手順は以下の通りです。

### 1. リリーススクリプトの実行

プロジェクトのルートディレクトリで以下のコマンドを実行します。

```bash
# パッチバージョン (0.0.x) を上げる場合 (デフォルト)
dart run scripts/release.dart

# マイナーバージョン (0.x.0) を上げる場合
dart run scripts/release.dart --minor

# メジャーバージョン (x.0.0) を上げる場合
dart run scripts/release.dart --major
```

このスクリプトは以下の作業を自動で行います：

1.  `pubspec.yaml` のバージョン更新
2.  `CHANGELOG.md` へのバージョンヘッダー挿入
3.  Git のステージング、コミット、タグ付け (`vx.y.z`)
4.  プッシュ前の最終確認

### 2. CHANGELOG.md の調整 (任意)

スクリプトがコミットする前に一旦停止するので、そのタイミングで `CHANGELOG.md` に具体的な変更内容を記述することをお勧めします。

### 3. プッシュと自動実行の確認

スクリプトの指示に従ってプッシュを承認（`y`）すると、GitHub Actions が起動し、自動的に `pub.dev` へアップロードされます。 ✨

1.  GitHub の **Actions** タブを開きます。
2.  **Publish to pub.dev** というワークフローが開始されていることを確認します。
3.  完了すると、数分以内に `pub.dev` 上に新バージョンが反映されます。

---

> [!TIP]
> タグをプッシュする前に `dart pub publish --dry-run` をローカルで実行し、パッケージ内容に問題がないか最終確認することをお勧めします。✨
