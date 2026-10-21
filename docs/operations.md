# サーバー運用

構築済みの本番サーバーを運用するための手順。構築そのものは [server-setup.md](server-setup.md) を参照。

以下のコマンドはリポジトリのルート（`~/voxtype`）で実行する。compose のオプションが長いため、エイリアスを作っておくと扱いやすい。

```bash
alias dcp='docker compose -f docker-compose.prod.yml --env-file .env.prod'
```

## 日常の操作

| 操作 | コマンド |
|---|---|
| 状態確認 | `dcp ps` |
| ログ（全体） | `dcp logs -f` |
| ログ（個別） | `dcp logs -f server` |
| 再起動 | `dcp restart server` |
| 停止 | `dcp down` |
| 起動 | `dcp up -d` |

`.env.prod` に必須の値が揃っていないと、`ps` や `down` もエラーで止まる。設定漏れのまま起動させないための仕様。

### 絶対に実行しないコマンド

```bash
dcp down -v
```

`-v` を付けるとデータベースのボリューム `postgres_data` が削除され、ユーザー、ホワイトリスト、辞書をすべて失う。停止は `-v` なしで行う。

## バックアップ

### 何が守られていないか

アプリが毎日3時に出力するのはグローバル辞書の xlsx（`./data/backups`）だけで、データベース全体のバックアップではない。ユーザー、ホワイトリスト、ユーザー個別辞書、各種設定は `postgres_data` ボリュームにしか存在しない。

### スクリプト

`scripts/pg-backup.sh` が `pg_dump` を gzip して `./data/backups/postgres` へ出力する。

```bash
~/voxtype/scripts/pg-backup.sh
```

```bash
ls -lh ~/voxtype/data/backups/postgres/
```

| 設定 | 既定値 | 変更方法 |
|---|---|---|
| 出力先 | `./data/backups/postgres` | 環境変数 `PG_BACKUP_DIR` |
| 保持期間 | 14日 | 環境変数 `PG_BACKUP_RETENTION_DAYS` |

ダンプに失敗した場合は非ゼロで終了し、不完全なファイルは残さない。ファイルの権限は実行ユーザーのみに絞られる。

### cron への登録

```bash
crontab -e
```

```
0 4 * * * /home/voxtype/voxtype/scripts/pg-backup.sh >> /home/voxtype/pg-backup.log 2>&1
```

### 復元

```bash
gunzip -c ~/voxtype/data/backups/postgres/voxtype-<日時>.sql.gz | \
  docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T db \
  psql -U voxtype -d voxtype
```

### 残っている課題

バックアップは同じサーバー上にあるため、ディスクやマシンの障害には耐えられない。別ホストやオブジェクトストレージへの転送と、復元手順の実地確認が必要。

## 更新

### アプリケーションの更新

```bash
cd ~/voxtype && git pull
```

```bash
dcp build server admin-web
```

マイグレーションがある場合は先に実行する。

```bash
dcp run --rm --no-deps server uv run alembic upgrade head
```

```bash
dcp up -d
```

### whisper の更新

whisper 側の Dockerfile や whisper.cpp のサブモジュールを更新した場合のみ、再ビルドが必要になる。CUDA のコンパイルが走るため10〜20分かかる。

```bash
dcp build whisper-fast
```

メモリや CPU が苦しい場合は並列数を下げる。

```bash
BUILD_JOBS=2 dcp build whisper-fast
```

`whisper-smart` は `whisper-fast` と同じイメージを使うため、個別のビルドは不要。

### 設定だけの変更

nginx の設定はファイルをマウントしているだけなので、再ビルドは要らない。

```bash
dcp up -d --force-recreate nginx
```

### カーネル更新後

NVIDIA ドライバは DKMS でカーネルごとにビルドされる。カーネルが上がったあとは GPU が見えるか確認する。

```bash
nvidia-smi
```

通らない場合は `linux-headers-generic` が入っているかを確認する。

## 障害時の確認

### 文字起こしが失敗する

まず各サービスの状態を見る。

```bash
dcp ps
```

API の状態エンドポイントで依存先をまとめて確認できる。認証は不要。

```bash
curl -s https://<APIのホスト名>/api/status
```

```json
{"status":"ok","database":"connected","whisper_fast":"connected","whisper_smart":"connected","whisper_overall":"connected"}
```

`server` の healthcheck はデータベースへの接続だけを見ている。whisper が停止していても `server` は healthy のままになるため、文字起こしの可否はこのエンドポイントで判断する。

### GPU が使われていない

```bash
dcp logs whisper-fast | grep -i -E "cuda|device|backend"
```

`ggml_cuda_init: found 1 CUDA devices` が出ていなければ CPU で動いている。順に確認する。

1. ホストで `nvidia-smi` が通るか
2. `docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi` が通るか
3. 通らない場合は `nvidia-ctk runtime configure` の後に docker を再起動したか、`/etc/docker/daemon.json` に nvidia ランタイムがあるか

CPU で動作していると、推論が nginx のタイムアウト（120秒）を超えて 504 になることがある。

### 無音なのに文字が入る、発話したのに空が返る

無音判定は VAD と RMS のどちらか一方が必ず動く。

- `VAD_ENABLED=true` でクライアントから届く発話しきい値が0より大きいとき: VAD を使う
- VAD が無効、または VAD が判定できない音声形式のとき: RMS を使う

RMS は音声を20msのフレームに分け、音量上位10%のフレームの平均値を `RMS_SILENCE_THRESHOLD`（既定 0.005）と比較する。しきい値を変えた場合は `server` の再作成が必要。

```bash
dcp up -d --force-recreate server
```

### nginx が unhealthy

healthcheck は default server の `/healthz` を叩いている。

```bash
dcp exec nginx wget -q -O - http://127.0.0.1/healthz
```

`ok` が返らない場合は設定を確認する。

```bash
dcp exec nginx nginx -t
```

`nginx` が unhealthy のままだと `cloudflared` が起動せず、外部からアクセスできなくなる。

### 外部からアクセスできない

```bash
dcp logs cloudflared --tail 50
```

トークンのエラーが無いか、Cloudflare Zero Trust のダッシュボードでコネクタがオンラインかを確認する。Public hostname の向き先が `http://nginx:80` のままかも確認する。

### ディスクが逼迫した

```bash
df -h /
```

```bash
docker system df
```

使っていないビルドキャッシュを削除する。CUDA のビルドキャッシュは10GB以上になる。削除後の再ビルドは最初からになる。

```bash
docker builder prune
```

## ログ

Docker daemon 側で1コンテナあたり 10MB × 3ファイルに制限している。設定は `/etc/docker/daemon.json`。

```bash
docker info --format '{{.LoggingDriver}}'
```

## 監視として未整備な項目

本番運用として、次は未対応のまま残っている。

- whisper 障害の通知（`/api/status` の `whisper_overall` を外部から監視する必要がある）
- バックアップのサーバー外保管
- メトリクス収集
