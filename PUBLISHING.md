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

1.  **`pubspec.yaml` のバージョン更新**: `version: x.y.z` を新しい番号に書き換えます。
2.  **`CHANGELOG.md` の更新**: 今回の変更内容を追記します。
3.  **変更のコミット & プッシュ**: `main` ブランチにプッシュします。
4.  **タグの作成とプッシュ**:
    ```bash
    git tag v0.0.2  # pubspec.yaml と同じバージョン
    git push origin v0.0.2
    ```

## 実行の確認

1.  GitHub の **Actions** タブを開きます。
2.  **Publish to pub.dev** というワークフローが開始されていることを確認します。
3.  完了すると、数分以内に `pub.dev` 上に新バージョンが反映されます。

---

> [!TIP]
> タグをプッシュする前に `dart pub publish --dry-run` をローカルで実行し、パッケージ内容に問題がないか最終確認することをお勧めします。✨
