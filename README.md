# Voice Server

Aqua Voice の代替として構築する音声入力システム。whisper.cpp を使用した音声認識サーバーと Mac クライアントで構成される。

## 概要

- whisper.cpp (large-v3 モデル) による日本語音声認識
- GitHub OAuth による認証と whitelist によるアクセス制御
- Mac メニューバーアプリでホットキー録音、テキスト挿入
- React 管理画面でユーザーと辞書を管理

## システム構成

```
┌─────────────────┐     ┌─────────────────────────────────┐
│   Mac Client    │     │           Server                │
│   (SwiftUI)     │────►│  FastAPI + whisper.cpp server   │
└─────────────────┘     │  + PostgreSQL                   │
                        └─────────────────────────────────┘
┌─────────────────┐                    │
│   Admin Web     │────────────────────┘
│   (React)       │
└─────────────────┘
```

## ディレクトリ構成

```
voice-server/
├── server/        # FastAPI サーバー
├── whisper/       # whisper.cpp サーバー
├── admin-web/     # React 管理画面
├── client/        # Mac クライアント
└── plan/          # 計画ドキュメント
```

## セットアップ

### 必要環境

- Docker / Docker Compose
- Python 3.11+
- Node.js 18+
- Xcode 15+ (Mac クライアントビルド用)

### サーバー起動

```bash
# 環境変数を設定
cp .env.example .env
# .env を編集して GitHub OAuth 情報を設定

# コンテナ起動
docker compose up -d

# whisper モデルをダウンロード (初回のみ)
cd whisper/whisper.cpp/models
./download-ggml-model.sh large-v3-q8_0
```

### Mac クライアント

1. GitHub Releases から .app をダウンロード
2. Applications フォルダに配置
3. 初回起動時に「システム設定 > プライバシーとセキュリティ」で許可

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
