(機械翻訳です)

# GitとGoogle DriveのLFSなし連携

このドキュメントは、GitとGoogle DriveをGit LFSを使わずに連携させる方法を紹介します。

これは、大きなファイルをGitでバージョン管理したいが、Git LFSを使いたくない場合に便利です。（特にゲームアセットや動画ファイルなど、非常に大きなファイルの場合）

注意：この方法はGoogle Driveに依存していません。Google Driveの代わりに他の（クラウド/サーバー/ローカル）ストレージも使えます。また、この方法は「Git LFSと併用」も可能です。（例：ほとんどのファイルはGit LFSで管理し、一部の非常に大きなファイルのみこの方法を使う場合）

## 制限事項

- この方法では、ファイルのコピーや転送は他の手段で行います。`list.txt`や`hash.txt`でファイルの変更は検出できますが、どのファイルをコピー・転送すべきかは自動化されません。
  - そのため、**大きなファイルの過去バージョンに頻繁に戻したい場合には不向き**です。（この場合は [git-lfs-agent-rclone](https://github.com/funatsufumiya/git-lfs-agent-rclone)、[git-lfs-agent-scp](https://github.com/funatsufumiya/git-lfs-agent-scp)、[git-lfs-php-server](https://github.com/funatsufumiya/git-lfs-php-server) など他の方法も検討してください）
- この制限と引き換えに得られる利点は、**ファイル名を通常通り扱える**ことです。これはGoogle DriveやDropboxでの管理上、望ましいと考えています。
  - この方法は、Google DriveやDropboxに昔ながらの`_v2.mp4`や`_final.mp4`のようなファイル名があり、同名ファイルが時々更新されるような状況で特に有効です。（古いファイル名がgitと本当に相性が良いかはさておき…）

## スクリプト

- [scripts/large-file-checker](scripts/large-file-checker)
- [scripts/large-file-checker.nu](scripts/large-file-checker.nu)（Nushell版）

## 仕組み（コンセプト）

1. Google Driveから大きなファイルをローカルにコピーします。
2. `.gitignore`でその大きなファイルを無視します。
3. `large-file-checker`スクリプトで無視したファイルの変更を追跡できます。
4. 大きなファイルがあるディレクトリで、`list.txt`と`hash.txt`を管理します（`large-file-checker`スクリプトで生成）。
5. 別の環境（または別のタイミング）で、Google Driveと同期していないファイルや変更を確認できます。
6. 必要に応じて、Google Driveから再度ファイルを手動または`rsync`（`rclone`やGoogle Drive公式アプリでマウント）でローカルにコピーします。

このプロセスで、GitとGoogle DriveをLFSなしで併用する際の最も一般的な問題を解決できます。特にゲーム開発や大容量ファイルを扱うプロジェクトに有効です。

## スクリプト詳細

デフォルトの`large-file-checker`スクリプトは[openFrameworks](https://openframeworks.cc/)向けに調整されています（例：`bin/data/**/from_gdrive`が大きなファイルディレクトリとみなされます）が、簡単に自分用に変更できます。（[Godot Engine](https://godotengine.org/)用の[古いバージョンのスクリプト](appendix/godot_scripts)も使っています。これがこのスクリプトの出発点です。）

現在の調整バージョンでは：

- `large-file-checker update assets`は、`bin/data/assets/from_gdrive`ディレクトリ内のファイルをチェックし、`list.txt`と`hash.txt`を更新します。
- `large-file-checker check assets`は、`bin/data/assets/from_gdrive`ディレクトリ内のファイルを、`list.txt`と`hash.txt`と比較して変更をチェックします。

このスクリプトは、同じプロジェクト・リポジトリで複数人が使えるように作られているため、`large-file-checker`の`ids`パラメータでGoogle Driveとローカルのフォルダを区別できます（各フォルダはさらにサブフォルダを含められます）。

自分用に`ids`や`dir_pattern_for_help`パラメータ、`get_large_file_dir`関数を修正してください。

## 注意事項

- スクリプトを使うには`rgh`コマンドが必要です。`cargo install rustgenhash`でインストールできます。
- `large-file-checker`はローカルファイルのみをチェックします。Google Driveとは通信しません。そのため、Google Driveの代わりにFTPやDropboxなど他の方法も使えます。
- `list.txt`と`hash.txt`を分けている理由は、時々（主に私が）ハッシュの更新を忘れることがあるためです。この場合、`large-file-checker check list assets`でリストのみをチェックできます。手動で`list.txt`を修正することも可能です（[Godot用古いスクリプト](appendix/godot_scripts)で.importファイルとlist.txtが共存していた名残でもあります）。
- Google Drive APIで直接チェックしない理由は、非常に大きなファイル（GB単位）がある場合、API制限にすぐ達してしまうためです。また、ローカルストレージやネットワーク速度の制約で一時的に小さいファイルに入れ替える必要がある場合もあります。現状の方法の方が実用的かつ柔軟だと考えています。

## 既知の問題

- 現在、`ignore_files`パターンでワイルドカード（*）はサポートされていません（[#1](https://github.com/funatsufumiya/git_gdrive_interop_without_lfs/issues/1)参照）。ただし部分一致には対応しているので、パターンから`*`を外してください（例：`*.import`→`.import`）。

## ライセンス

WTFPLまたは0BSD