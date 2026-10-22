# VoxType

whisper.cpp を使用した音声認識サーバーと Mac クライアントで構成される音声入力システム。

## 概要

- whisper.cpp (large-v3 モデル) による日本語音声認識
- GitHub OAuth による認証と whitelist によるアクセス制御
- Mac メニューバーアプリでホットキー録音、テキスト挿入
- React 管理画面でユーザーと辞書を管理

## ドキュメント

| 文書 | 内容 |
|---|---|
| [docs/server-setup.md](docs/server-setup.md) | サーバーの構築手順（Ubuntu Server、GPU、Docker、Cloudflare Tunnel） |
| [docs/operations.md](docs/operations.md) | 運用手順（バックアップ、更新、障害時の確認） |

## 変更履歴

### v1.6.0

本番環境を GPU 対応にし、サーバー構成を整理した。

- whisper の推論を GPU で実行するようにした。`whisper/Dockerfile.gpu`（CUDA 12.2）でビルドし、NVIDIA Container Toolkit 経由で GPU を割り当てる
- whisper のイメージを1つに統合した。fast と smart は同じイメージをモデル違いで起動する。コンパイルの並列数は `BUILD_JOBS` で指定する
- OAuth のコールバック先を許可リストで検証するようにした。検証していなかったため、細工されたログイン URL で JWT が外部へ渡る経路があった
- CORS の許可オリジンを設定可能にし、本番では管理画面のオリジンのみを許可するようにした
- nginx のレート制限を実クライアント単位にした。Cloudflare Tunnel 経由では全利用者が同じ制限枠を共有していた
- 必須の環境変数が未設定のときに compose が停止するようにした
- データベース全体のバックアップスクリプト（`scripts/pg-backup.sh`）を追加した
- サーバーの構築手順と運用手順を `docs/` に整理した

### v1.5.5

- 長尺録音で発話しているのに空の結果が返る問題を修正した。RMS の無音判定を、音声全体の平均から20msフレームの上位10%平均へ変更した
- 無音チェックが一つも走らない経路を塞いだ。VAD が判定できない音声形式では RMS へフォールバックする
- 設定キー `RMS_CHECK_ENABLED` を廃止した

### v1.5.4

- 録音の60秒自動停止と、停止後の自動文字起こしを追加した
- 録音方式を3択（キー長押し / 右Shiftダブルタップ / マウスホイール長押し）に再構成した
- キー長押しモードで停止を取りこぼす問題を修正した

## システム構成

```mermaid
flowchart LR
    subgraph Client["クライアント"]
        MC[Mac Client<br/>SwiftUI]
        AW[Admin Web<br/>React]
    end

    subgraph Server["サーバー"]
        API[FastAPI<br/>認証・API]
        WS[whisper.cpp<br/>音声認識]
        DB[(PostgreSQL)]
    end

    MC -->|音声データ| API
    AW -->|管理操作| API
    API <-->|認識リクエスト| WS
    API <-->|データ永続化| DB
```

## ディレクトリ構成

```
voxtype/
├── server/        # FastAPI サーバー
├── whisper/       # whisper.cpp サーバー
├── admin-web/     # React 管理画面
├── client/        # Mac クライアント
├── docs/          # 構築・運用ドキュメント
├── scripts/       # 運用スクリプト
└── plan/          # 計画ドキュメント
```

### 未使用のファイル

| ファイル | 状態 |
|----------|------|
| `docker-compose.yml` | 未使用。2026-01-31 以降メンテナンスされておらず、現在の構成と一致しない。ローカル開発は Makefile、本番は `docker-compose.prod.yml` を使う |

## セットアップ

### 必要環境

- Docker
- GNU Make
- Python 3.11+ / uv
- Node.js 18+
- Xcode 15+ (Mac クライアントビルド用)

### 環境変数

| 変数名 | 必須 | 説明 | 例 |
|--------|------|------|-----|
| `DATABASE_URL` | Yes | データベース接続URL | `postgresql+asyncpg://voice:password@localhost:5434/voice_server` |
| `JWT_SECRET` | Yes | JWT署名用シークレットキー | ランダムな文字列 |
| `GITHUB_CLIENT_ID` | Yes | GitHub OAuth App Client ID | `Iv1.xxxxxxxxxx` |
| `GITHUB_CLIENT_SECRET` | Yes | GitHub OAuth App Client Secret | `xxxxxxxxxxxxxxxx` |
| `WHISPER_SERVER_URL_FAST` | No | whisper.cppサーバーURL（fast） | `http://localhost:8080` |
| `WHISPER_SERVER_URL_SMART` | No | 音声認識サーバーURL（smart） | `http://localhost:8081` |
| `VOICE_LANGUAGE` | No | 認識言語 | `ja` / `en` / `auto` |
| `VAD_ENABLED` | No | VADによる無音判定 | `true` / `false` |
| `VAD_SPEECH_THRESHOLD` | No | VADの発話判定しきい値 | `0.3` |
| `RMS_SILENCE_THRESHOLD` | No | RMSの無音判定しきい値（VADが無効なときに使用） | `0.005` |
| `APP_NAME` | No | アプリケーション名 | `VoxType` |
| `DEBUG` | No | デバッグモード | `true` / `false` |

無音判定はVADとRMSのどちらか一方が必ず動く。`VAD_ENABLED` が `true` でクライアントから届く発話判定しきい値が0より大きいときはVADを使い、それ以外ではRMSを使う。RMSは音声を20msのフレームに分け、音量上位10%のフレームの平均値を `RMS_SILENCE_THRESHOLD` と比較する。

### ローカル開発環境の起動

ローカル開発では Makefile を使います。`docker-compose.yml` は未使用のため参照しないでください。

```bash
# 環境変数を設定
cp .env.example .env
# .env を編集して GitHub OAuth 情報を設定

# whisper モデルをダウンロード (初回のみ)
make download-models

# PostgreSQL と whisper サーバーを起動し、マイグレーションを実行
make up

# バックエンドを起動 (別ターミナル)
make backend
```

`make up` が起動するものは次のとおりです。

| サービス | 起動方法 | ポート | 備考 |
|----------|----------|--------|------|
| PostgreSQL | `voice-postgres` コンテナ | 5434 | postgres:15 |
| whisper-fast | `whisper-fast` コンテナ | 8080 | large-v3-turbo-q8_0 モデル |
| whisper-smart | `whisper-smart` コンテナ | 8081 | large-v3-turbo モデル |

バックエンドはコンテナではなくホスト上で uvicorn として動きます。そのため `.env` の `DATABASE_URL` と `WHISPER_SERVER_URL` は `localhost` を指します。

主な Makefile ターゲットは次のとおりです。

| コマンド | 内容 |
|----------|------|
| `make up` | db と whisper を起動してマイグレーションを実行 |
| `make backend` | バックエンドを 8000 で起動 |
| `make admin` | 管理画面を 5173 で起動 |
| `make status` | 各サービスの起動状態を確認 |
| `make down` | コンテナを停止 |
| `make clean` | コンテナを停止して削除 |
| `make test` | サーバーのテストを実行 |
| `make help` | 全ターゲットの一覧 |

### 開発環境

```bash
# サーバーの依存関係を同期
cd server
uv sync

# テスト実行
uv run pytest

# Admin Web開発
cd admin-web
npm install
npm run dev
```

### Mac クライアント

1. GitHub Releases から .app をダウンロード
2. Applications フォルダに配置
3. 初回起動時に「システム設定 > プライバシーとセキュリティ」で許可

## 本番環境デプロイ

本番は Ubuntu Server 上の Docker Compose で動かす。外部公開は Cloudflare Tunnel 経由で、SSL は Cloudflare が終端する。サーバー側でポートを開けず、証明書も管理しない。

```
[インターネット] → [Cloudflare] → (Tunnel) → [サーバー]
                                                ├─ cloudflared
                                                ├─ nginx（サブドメイン振り分け）
                                                ├─ server (API)
                                                ├─ admin-web
                                                ├─ whisper-fast / parakeet（GPU）
                                                └─ db (PostgreSQL)
```

| サブドメイン | 向き先 | 認証 |
|--------------|--------|------|
| `voxtype.oshiruko.dev` | server:8000 | API の JWT（GitHub OAuth） |
| `voxtype-admin.oshiruko.dev` | admin-web:80 | Cloudflare Zero Trust（GitHub） |

どちらも NVIDIA Container Toolkit 経由で GPU を割り当てる。fast は CUDA でビルドした whisper.cpp（large-v3-turbo-q8_0 モデル）、smart は NeMo の parakeet-tdt_ctc-0.6b-ja を使う。parakeet は whisper-server と同じ HTTP 契約を持つため、サーバー側からは接続先の違いでしかない。

ローカル開発環境（`make up`）は fast / smart とも whisper のまま。parakeet は NVIDIA GPU が要るため。

構築手順は [docs/server-setup.md](docs/server-setup.md)、運用手順は [docs/operations.md](docs/operations.md) を参照。

## トラブルシューティング

### Mac クライアントが起動しない

1. 「システム設定 > プライバシーとセキュリティ」で「このまま開く」を選択
2. マイクのアクセス許可を確認
3. アクセシビリティ権限を確認（ホットキー機能に必要）

### 認証エラー (403 Forbidden)

- Whitelist に登録されているか確認
- JWT トークンの有効期限（7日間）を確認
- 管理画面からユーザーを再追加

### 音声認識が遅い

- whisper.cpp サーバーが起動しているか確認
- モデルファイル（large-v3-q8_0）がダウンロードされているか確認
- サーバーリソース（CPU/メモリ）を確認

### docker compose up でエラー

```bash
# ログを確認
docker compose logs -f

# コンテナを再ビルド
docker compose build --no-cache
docker compose up -d
```

## ライセンス

このプロジェクトは以下のオープンソースソフトウェアを使用しています。

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - MIT License
- [Whisper](https://github.com/openai/whisper) - MIT License
- [FastAPI](https://fastapi.tiangolo.com/) - MIT License
- [SQLAlchemy](https://www.sqlalchemy.org/) - MIT License
- [PostgreSQL](https://www.postgresql.org/) - PostgreSQL License
- [Authlib](https://authlib.org/) - BSD-3-Clause License
- [React](https://reactjs.org/) - MIT License
- [shadcn/ui](https://ui.shadcn.com/) - MIT License
- [Tailwind CSS](https://tailwindcss.com/) - MIT License
