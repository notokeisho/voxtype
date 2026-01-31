# Voice Server - 実装タスク一覧

## 概要

本ドキュメントでは、Voice Server の実装タスクを Phase ごとに定義する。

### 開発方針

- **TDD（テスト駆動開発）**: 各機能はテストを先に書いてから実装
- **Phase 順序**: Phase 0 から順番に実装
- **完了条件**: 全 Phase 完了後にリリース

### Phase 構成

| Phase | 内容 | 依存 |
|-------|------|------|
| 0 | 環境構築 | - |
| 1 | whisper.cpp サーバー | Phase 0 |
| 2 | FastAPI 基盤 | Phase 0 |
| 3 | 音声認識 API | Phase 1, 2 |
| 4 | Mac クライアント | Phase 3 |
| 5 | 管理画面 | Phase 3 |

---

## Phase 0: 環境構築

### 0.1 リポジトリ初期設定

**タスク**:
- [x] .gitignore 作成（Python, Node.js, Swift, macOS）
- [x] README.md 作成（プロジェクト概要）
- [x] ディレクトリ構造作成

**成果物**:
```
voice-server/
├── .gitignore
├── README.md
├── plan/
├── server/
├── whisper/
├── admin-web/
└── client/
```

---

### 0.2 Docker 環境構築

**タスク**:
- [x] docker-compose.yml 作成
- [x] PostgreSQL コンテナ設定
- [x] .env.example 作成

**成果物**:
- `docker-compose.yml`
- `.env.example`

**完了条件**:
```bash
docker compose up db
# PostgreSQL が起動し、接続可能
```

---

### 0.3 Python 開発環境

**タスク**:
- [x] pyproject.toml 作成（uv または poetry）
- [x] 依存パッケージ定義
- [x] pytest 設定
- [x] ruff（リンター）設定
- [x] whisper モックサーバー設定（テスト用）

**依存パッケージ**:
```
fastapi
uvicorn
sqlalchemy
asyncpg
authlib
httpx
pydantic
pydantic-settings
python-multipart
pytest
pytest-asyncio
```

**開発環境での whisper 対応**:

| 用途 | 方法 |
|------|------|
| 単体テスト | モック API（固定レスポンス） |
| 統合テスト | ローカル whisper サーバー |

モックサーバー例:
```python
# tests/mocks/whisper_mock.py
from fastapi import FastAPI
app = FastAPI()

@app.post("/inference")
async def mock_inference():
    return {"text": "これはテスト用の認識結果です"}
```

**完了条件**:
```bash
cd server
uv sync  # または poetry install
pytest   # テストが実行可能
```

---

## Phase 1: whisper.cpp サーバー

### 1.1 whisper.cpp ビルド

**タスク**:
- [x] whisper.cpp を git submodule として追加
- [x] ビルド用 Dockerfile 作成
- [x] whisper-server バイナリをビルド

**コマンド例**:
```bash
cd whisper
git submodule add https://github.com/ggerganov/whisper.cpp.git
```

**完了条件**:
- `whisper-server` バイナリが生成される

---

### 1.2 モデルダウンロード

**タスク**:
- [x] large-v3 量子化モデル (q8_0) をダウンロード
- [x] models/ ディレクトリに配置
- [x] .gitignore にモデルファイルを追加
- [x] README にダウンロード手順を記載

**ダウンロード方針**: 手動ダウンロード（Docker イメージには含めない）

理由:
- モデルファイルは約6GB と大きい
- Docker イメージに含めるとビルド・配布が重くなる
- 初回起動時ダウンロードは不安定

**コマンド例**:
```bash
cd whisper/whisper.cpp/models
./download-ggml-model.sh large-v3-q8_0
```

**完了条件**:
- `whisper/models/ggml-large-v3-q8_0.bin` が存在

---

### 1.3 whisper.cpp サーバー起動設定

**タスク**:
- [x] start.sh 作成（起動スクリプト）
- [x] Dockerfile 作成
- [x] docker-compose.yml に whisper サービス追加

**start.sh**:
```bash
#!/bin/bash
./whisper-server \
    --model /app/models/ggml-large-v3-q8_0.bin \
    --host 0.0.0.0 \
    --port 8080 \
    --language ja
```

**完了条件**:
```bash
docker compose up whisper
curl http://localhost:8080/health
# 正常レスポンス
```

---

### 1.4 whisper.cpp サーバー動作確認

**タスク**:
- [x] テスト用音声ファイル作成（日本語）
- [x] HTTP API で認識リクエスト送信
- [x] 認識結果の確認

**テストコマンド**:
```bash
curl -X POST http://localhost:8080/inference \
  -F "file=@test.wav" \
  -F "response_format=json"
```

**完了条件**:
- 日本語音声が正しくテキストに変換される

---

## Phase 2: FastAPI 基盤

### 2.1 FastAPI プロジェクト構造

**タスク**:
- [x] app/ ディレクトリ構造作成
- [x] main.py（エントリーポイント）
- [x] config.py（設定管理）
- [x] Dockerfile 作成

**テスト**:
```python
# tests/test_main.py
def test_app_starts():
    from app.main import app
    assert app is not None
```

**完了条件**:
```bash
uvicorn app.main:app --reload
curl http://localhost:8000/
# FastAPI が起動
```

---

### 2.2 データベース接続

**タスク**:
- [x] database.py（DB接続設定）
- [x] SQLAlchemy エンジン設定
- [x] セッション管理

**テスト**:
```python
# tests/test_database.py
@pytest.mark.asyncio
async def test_db_connection():
    async with get_session() as session:
        result = await session.execute(text("SELECT 1"))
        assert result.scalar() == 1
```

**完了条件**:
- PostgreSQL に接続可能
- テスト通過

---

### 2.3 ユーザーモデル

**タスク**:
- [x] models/user.py（User モデル）
- [x] Alembic マイグレーション設定
- [x] 初期マイグレーション作成

**テスト**:
```python
# tests/test_models.py
@pytest.mark.asyncio
async def test_create_user():
    user = User(github_id="testuser", github_avatar="https://...")
    session.add(user)
    await session.commit()
    assert user.id is not None
```

**User モデル**:
```python
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    github_id: Mapped[str] = mapped_column(String(255), unique=True)
    github_avatar: Mapped[str] = mapped_column(Text, nullable=True)
    is_admin: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(default=func.now())
    last_login_at: Mapped[datetime] = mapped_column(nullable=True)
```

---

### 2.4 Whitelist モデル

**タスク**:
- [x] models/whitelist.py
- [x] マイグレーション作成

**テスト**:
```python
@pytest.mark.asyncio
async def test_whitelist_check():
    await add_to_whitelist("alloweduser")
    assert await is_whitelisted("alloweduser") is True
    assert await is_whitelisted("unknownuser") is False
```

**Whitelist モデル**:
```python
class Whitelist(Base):
    __tablename__ = "whitelist"

    id: Mapped[int] = mapped_column(primary_key=True)
    github_id: Mapped[str] = mapped_column(String(255), unique=True)
    created_at: Mapped[datetime] = mapped_column(default=func.now())
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=True)
```

---

### 2.5 Dictionary モデル（グローバル + 個人）

**タスク**:
- [x] models/global_dictionary.py（グローバル辞書）
- [x] models/user_dictionary.py（個人辞書）
- [x] マイグレーション作成

**テスト**:
```python
@pytest.mark.asyncio
async def test_global_dictionary_replace():
    await add_global_entry("くろーど", "Claude")
    result = await apply_dictionary("くろーどは便利です", user_id=1)
    assert result == "Claudeは便利です"

@pytest.mark.asyncio
async def test_user_dictionary_priority():
    # グローバル: くろーど → Claude
    await add_global_entry("くろーど", "Claude")
    # 個人: くろーど → クロード（優先される）
    await add_user_entry(user_id=1, pattern="くろーど", replacement="クロード")

    result = await apply_dictionary("くろーどは便利です", user_id=1)
    assert result == "クロードは便利です"  # 個人辞書が優先

@pytest.mark.asyncio
async def test_user_dictionary_limit():
    # 100件まで登録
    for i in range(100):
        await add_user_entry(user_id=1, pattern=f"test{i}", replacement=f"TEST{i}")

    # 101件目はエラー
    with pytest.raises(DictionaryLimitExceeded):
        await add_user_entry(user_id=1, pattern="test100", replacement="TEST100")
```

**GlobalDictionary モデル**:
```python
class GlobalDictionary(Base):
    __tablename__ = "global_dictionary"

    id: Mapped[int] = mapped_column(primary_key=True)
    pattern: Mapped[str] = mapped_column(String(255))
    replacement: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(default=func.now())
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=True)
```

**UserDictionary モデル**:
```python
class UserDictionary(Base):
    __tablename__ = "user_dictionary"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    pattern: Mapped[str] = mapped_column(String(255))
    replacement: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(default=func.now())

# 制約: 1ユーザーあたり最大100エントリ
USER_DICTIONARY_LIMIT = 100
```

---

### 2.6 GitHub OAuth 認証

**タスク**:
- [x] auth/oauth.py（OAuth設定）
- [x] auth/routes.py（/auth/login, /auth/callback）
- [x] JWT トークン発行（有効期限: 7日間）

**JWT 設定**:
| 項目 | 値 |
|------|-----|
| 有効期限 | 7日間 |
| アルゴリズム | HS256 |
| ペイロード | user_id, github_id, exp |

**テスト**:
```python
# tests/test_auth.py
def test_login_redirect():
    response = client.get("/auth/login")
    assert response.status_code == 302
    assert "github.com" in response.headers["location"]

@pytest.mark.asyncio
async def test_jwt_token():
    token = create_jwt_token(user_id=1, github_id="testuser")
    payload = verify_jwt_token(token)
    assert payload["github_id"] == "testuser"

def test_jwt_expiration():
    token = create_jwt_token(user_id=1, github_id="testuser")
    payload = verify_jwt_token(token)
    # 7日後に期限切れ
    assert payload["exp"] > time.time()
    assert payload["exp"] < time.time() + 7 * 24 * 60 * 60 + 1
```

**エンドポイント**:
- `GET /auth/login` - GitHub 認証開始
- `GET /auth/callback` - コールバック処理、JWT発行

---

### 2.7 認証ミドルウェア

**タスク**:
- [x] auth/dependencies.py
- [x] JWT 検証デコレータ
- [x] Whitelist チェックデコレータ（毎リクエスト確認）
- [x] 管理者チェックデコレータ

**Whitelist チェック仕様**:
- 毎リクエストで DB から Whitelist を確認
- ユーザー削除時に即座にアクセス拒否
- JWT が有効でも Whitelist になければ 403

**テスト**:
```python
def test_protected_endpoint_without_token():
    response = client.post("/api/transcribe")
    assert response.status_code == 401

def test_protected_endpoint_not_whitelisted():
    token = create_token_for("notwhitelisted")
    response = client.post(
        "/api/transcribe",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403

def test_whitelist_removal_immediate_effect():
    # 1. ユーザーを whitelist に追加
    await add_to_whitelist("testuser")
    token = create_token_for("testuser")

    # 2. アクセス可能
    response = client.post("/api/transcribe", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200

    # 3. whitelist から削除
    await remove_from_whitelist("testuser")

    # 4. 同じトークンでアクセス不可（即座に反映）
    response = client.post("/api/transcribe", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403
```

---

### 2.8 ヘルスチェック API

**タスク**:
- [x] api/status.py
- [x] GET /api/status エンドポイント

**テスト**:
```python
def test_status_endpoint():
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
```

**レスポンス例**:
```json
{
  "status": "ok",
  "whisper_server": "connected",
  "database": "connected"
}
```

---

## Phase 3: 音声認識 API

### 3.1 whisper.cpp クライアント

**タスク**:
- [x] services/whisper_client.py
- [x] HTTP クライアント実装
- [x] エラーハンドリング

**テスト**:
```python
@pytest.mark.asyncio
async def test_whisper_client(mock_whisper_server):
    result = await transcribe_audio("/path/to/test.wav")
    assert isinstance(result, str)
    assert len(result) > 0
```

---

### 3.2 後処理サービス

**タスク**:
- [x] services/postprocess.py
- [x] グローバル辞書置換
- [x] 個人辞書置換（優先）
- [x] 大文字小文字を区別しない置換

**置換処理フロー**:
```
1. 個人辞書から該当ユーザーのエントリ取得
2. グローバル辞書からエントリ取得
3. 個人辞書で置換（優先）
4. グローバル辞書で置換（個人辞書で未置換の部分）
5. 結果を返却
```

**テスト**:
```python
@pytest.mark.asyncio
async def test_postprocess_global():
    # グローバル辞書: "くろーど" -> "Claude"
    text = "くろーどを使っています"
    result = await postprocess(text, user_id=1)
    assert result == "Claudeを使っています"

@pytest.mark.asyncio
async def test_postprocess_user_priority():
    # グローバル: "AI" -> "人工知能"
    # 個人: "AI" -> "AI（エーアイ）"
    text = "AIは便利です"
    result = await postprocess(text, user_id=1)
    assert result == "AI（エーアイ）は便利です"  # 個人辞書優先

@pytest.mark.asyncio
async def test_postprocess_case_insensitive():
    # 辞書: "claude" -> "Claude"（大文字小文字区別なし）
    text = "CLAUDEを使っています"
    result = await postprocess(text, user_id=1)
    assert result == "Claudeを使っています"
```

---

### 3.3 音声認識エンドポイント

**タスク**:
- [x] api/transcribe.py
- [x] POST /api/transcribe 実装
- [x] ファイルアップロード処理
- [x] 一時ファイル管理（finally で必ず削除）

**一時ファイル管理**:
```python
async def transcribe_audio(audio_path: str):
    try:
        result = await whisper_client.transcribe(audio_path)
        return result
    finally:
        # 必ず削除（例外発生時も）
        if os.path.exists(audio_path):
            os.remove(audio_path)
```

**テスト**:
```python
def test_transcribe_endpoint(auth_headers, test_audio_file):
    response = client.post(
        "/api/transcribe",
        headers=auth_headers,
        files={"audio": test_audio_file}
    )
    assert response.status_code == 200
    assert "text" in response.json()

def test_temp_file_cleanup(auth_headers, test_audio_file):
    # リクエスト前の一時ファイル数
    before_count = len(os.listdir("/tmp/voice-server"))

    response = client.post(
        "/api/transcribe",
        headers=auth_headers,
        files={"audio": test_audio_file}
    )

    # リクエスト後も一時ファイルが増えていない
    after_count = len(os.listdir("/tmp/voice-server"))
    assert after_count == before_count
```

**エンドポイント仕様**:
- メソッド: POST
- パス: /api/transcribe
- 認証: 必須（JWT + Whitelist 毎回確認）
- Content-Type: multipart/form-data
- 一時ファイル: /tmp/voice-server/ に保存、処理後削除

---

### 3.4 個人辞書 API

**タスク**:
- [x] api/dictionary.py
- [x] GET /api/dictionary（一覧取得）
- [x] POST /api/dictionary（追加、上限100件チェック）
- [x] DELETE /api/dictionary/{id}（削除、自分のエントリのみ）

**テスト**:
```python
def test_get_user_dictionary(auth_headers):
    response = client.get("/api/dictionary", headers=auth_headers)
    assert response.status_code == 200
    assert "entries" in response.json()
    assert "count" in response.json()
    assert "limit" in response.json()

def test_add_user_dictionary(auth_headers):
    response = client.post(
        "/api/dictionary",
        headers=auth_headers,
        json={"pattern": "いしだけん", "replacement": "石田研"}
    )
    assert response.status_code == 201

def test_user_dictionary_limit(auth_headers):
    # 100件登録済みの状態で追加
    response = client.post(
        "/api/dictionary",
        headers=auth_headers,
        json={"pattern": "test", "replacement": "TEST"}
    )
    assert response.status_code == 400
    assert "limit" in response.json()["detail"].lower()

def test_delete_other_user_dictionary(auth_headers, other_user_entry_id):
    # 他人のエントリは削除不可
    response = client.delete(
        f"/api/dictionary/{other_user_entry_id}",
        headers=auth_headers
    )
    assert response.status_code == 404  # または 403
```

---

### 3.5 統合テスト

**タスク**:
- [x] E2E テスト作成
- [x] 認証 → 音声認識 → 後処理 の一連のフロー確認

**テスト**:
```python
@pytest.mark.integration
async def test_full_transcription_flow():
    # 1. ログイン（モック）
    token = await login_as("testuser")

    # 2. 音声認識リクエスト
    response = await transcribe_with_token(token, "test_audio.wav")

    # 3. 結果確認
    assert response["text"] is not None
```

---

## Phase 4: Mac クライアント

### 4.1 Xcode プロジェクト作成

**タスク**:
- [x] VoiceClient.xcodeproj 作成
- [x] SwiftUI App 構造
- [x] Info.plist 設定（マイク権限）

**Info.plist**:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声認識のためにマイクを使用します</string>
```

---

### 4.2 メニューバーアプリ基盤

**タスク**:
- [x] MenuBarExtra 実装
- [x] アイコン表示
- [x] 状態管理（待機中、録音中、処理中、完了、エラー）

**コード例**:
```swift
@main
struct VoiceClientApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: appState.statusIcon)
        }
    }
}
```

---

### 4.3 設定画面

**タスク**:
- [x] SettingsView 実装
- [x] サーバーURL 設定
- [x] ホットキー設定
- [x] UserDefaults で保存

---

### 4.3.1 個人辞書編集画面

**タスク**:
- [x] DictionaryView 実装（DictionarySettingsView）
- [x] 辞書一覧表示（パターン、置換後）
- [x] エントリ追加フォーム
- [x] エントリ削除機能
- [x] 登録数表示（例: 15/100）

**UI 構成**:
```
┌─────────────────────────────────────────┐
│ 個人辞書                    15/100件   │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ パターン: いしだけん                 │ │
│ │ 置換後:   石田研           [削除]   │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ パターン: たなかさん                 │ │
│ │ 置換後:   田中さん          [削除]   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ─────────── 新規追加 ───────────        │
│ パターン: [____________]               │
│ 置換後:   [____________]               │
│                           [追加]        │
└─────────────────────────────────────────┘
```

**テスト方法**:
- 手動テスト: 設定画面 → 辞書タブ → 追加/削除操作

---

### 4.4 OAuth 認証フロー

**タスク**:
- [x] ASWebAuthenticationSession 実装
- [x] KeychainHelper クラス実装
- [x] JWT トークン保存（Keychain に暗号化保存）
- [x] ログイン/ログアウト機能
- [x] トークン期限切れ検知

**Keychain 実装**:
```swift
class KeychainHelper {
    static func save(_ token: String, forKey key: String) -> Bool
    static func load(forKey key: String) -> String?
    static func delete(forKey key: String) -> Bool
}
```

**セキュリティ要件**:
- JWT は UserDefaults ではなく Keychain に保存
- ログアウト時は Keychain から削除
- アプリ削除時も Keychain から削除される設定

**テスト方法**:
- 手動テスト: ログインボタン → GitHub認証 → トークン取得
- Keychain にトークンが保存されていることを確認

---

### 4.5 音声録音

**タスク**:
- [x] AudioRecorder クラス実装
- [x] AVFoundation で録音
- [x] WAV フォーマット（16kHz, mono）で保存
- [x] 最大録音時間: 60秒（超過時は自動停止）

**録音設定**:
| 項目 | 値 |
|------|-----|
| フォーマット | WAV (Linear PCM) |
| サンプルレート | 16000 Hz |
| チャンネル | 1 (mono) |
| ビット深度 | 16bit |
| 最大時間 | 60秒 |

**コード例**:
```swift
class AudioRecorder: ObservableObject {
    private let maxDuration: TimeInterval = 60.0

    func startRecording()
    func stopRecording() -> URL  // 録音ファイルのパス
}
```

---

### 4.6 グローバルホットキー

**タスク**:
- [x] HotkeyManager 実装
- [x] CGEvent でグローバルキー監視
- [x] 押下/離す イベント検知（ホールド式）

**動作仕様**:
- ホットキー押下 → 録音開始
- ホットキー離す → 録音停止・送信
- 押している間だけ録音（ホールド式）

**デフォルトキー**: `⌘ + Shift + V`

---

### 4.7 API クライアント

**タスク**:
- [x] APIClient 実装
- [x] URLSession で音声ファイル送信
- [x] レスポンス処理

**コード例**:
```swift
class APIClient {
    func transcribe(audioURL: URL) async throws -> TranscribeResponse
}
```

---

### 4.8 クリップボード操作

**タスク**:
- [x] ClipboardManager 実装
- [x] 現在の内容を退避
- [x] テキストをコピー
- [x] Cmd+V シミュレート
- [x] 元の内容を復元

**コード例**:
```swift
class ClipboardManager {
    func pasteText(_ text: String) {
        // 1. 現在のクリップボード内容を保存
        // 2. テキストをクリップボードにコピー
        // 3. Cmd+V イベントを送信
        // 4. 元の内容を復元
    }
}
```

---

### 4.9 エラー通知

**タスク**:
- [x] NotificationManager 実装
- [x] macOS UserNotifications 連携
- [x] エラーレベルに応じた通知制御

**通知ルール**:
| エラー種別 | アイコン変化 | macOS 通知 |
|-----------|-------------|-----------|
| 認識失敗（音声不明瞭など） | ❌ | なし |
| サーバー接続エラー | ❌ | 表示 |
| 認証エラー（トークン期限切れ） | ❌ | 表示 |
| ネットワークエラー | ❌ | 表示 |

---

### 4.10 統合・動作確認

**タスク**:
- [x] 全コンポーネント統合
- [x] エラーハンドリング
- [x] 手動テスト

**テストシナリオ（正常系）**:
1. アプリ起動 → メニューバーにアイコン表示
2. ログイン → GitHub認証成功
3. ホットキー押下 → 録音開始（アイコン変化）
4. ホットキー離す → 録音停止 → 送信 → 処理中表示
5. 結果受信 → テキスト貼り付け → 完了表示

**テストシナリオ（エラー系）**:
1. サーバー停止中に録音 → アイコン ❌ + macOS 通知
2. 60秒以上録音 → 自動停止して送信
3. トークン期限切れ → アイコン ❌ + 再ログイン通知

---

### 4.11 アプリ配布

**タスク**:
- [x] アプリをビルド（Release 構成）
- [x] GitHub Releases にアップロード
- [x] インストール手順を README に記載

**配布方法**: GitHub Releases

Phase 1 では署名なしで配布。ユーザーは「システム環境設定 → セキュリティとプライバシー」で許可が必要。

**将来の改善**: Apple Developer Program に登録し、署名 + 公証 (Notarization) を行うことで「開発元不明」警告を解消可能。

**インストール手順（README に記載）**:
1. GitHub Releases から .app をダウンロード
2. Applications フォルダにドラッグ
3. 初回起動時に警告が出たら「システム環境設定 → セキュリティ」で許可
4. アプリを再度開く

---

## Phase 5: 管理画面

### 5.1 React プロジェクト作成

**タスク**:
- [x] Vite で React + TypeScript プロジェクト作成
- [x] Tailwind CSS 設定
- [x] shadcn/ui 初期化

**コマンド**:
```bash
cd admin-web
npm create vite@latest . -- --template react-ts
npx shadcn@latest init
```

---

### 5.2 API クライアント

**タスク**:
- [x] lib/api.ts 作成
- [x] fetch ラッパー
- [x] 認証ヘッダー付与

---

### 5.3 認証・ログイン画面

**タスク**:
- [x] pages/Login.tsx
- [x] GitHub OAuth リダイレクト
- [x] トークン保存

---

### 5.4 ダッシュボード

**タスク**:
- [x] pages/Dashboard.tsx
- [x] 基本レイアウト（サイドバー、ヘッダー）
- [x] ナビゲーション

---

### 5.5 ユーザー管理画面

**タスク**:
- [x] pages/Users.tsx
- [x] ユーザー一覧テーブル
- [x] ユーザー追加フォーム（Whitelist経由）
- [x] ユーザー削除機能

**コンポーネント**:
- UserTable
- AddUserDialog
- DeleteUserDialog

---

### 5.6 グローバル辞書管理画面

**タスク**:
- [x] pages/Dictionary.tsx
- [x] グローバル辞書エントリ一覧
- [x] エントリ追加/削除
- [x] 全ユーザーに適用される旨の説明表示

**コンポーネント**:
- GlobalDictionaryTable
- GlobalDictionaryForm

**画面説明**:
- グローバル辞書は全ユーザーの認識結果に適用される
- よくある認識ミスを登録（例: くろーど → Claude）
- 個人辞書は各ユーザーが Mac アプリで管理

---

### 5.7 管理者 API 実装

**タスク**:
- [x] server/app/admin/users.py
- [x] server/app/admin/whitelist.py
- [x] server/app/admin/dictionary.py
- [x] server/app/api/me.py（ユーザー情報取得）

**テスト**:
```python
def test_list_users(admin_auth_headers):
    response = client.get("/admin/api/users", headers=admin_auth_headers)
    assert response.status_code == 200

def test_add_whitelist(admin_auth_headers):
    response = client.post(
        "/admin/api/whitelist",
        headers=admin_auth_headers,
        json={"github_id": "newuser"}
    )
    assert response.status_code == 201
```

---

### 5.8 ビルド・デプロイ設定

**タスク**:
- [x] Dockerfile 作成
- [x] Nginx 設定（SPA用）
- [x] docker-compose.yml に追加

---

## Phase 6: 最終統合・リリース準備

### 6.1 統合テスト

**タスク**:
- [ ] 全コンポーネント起動確認
- [ ] E2E シナリオテスト
- [ ] パフォーマンステスト

---

### 6.2 ドキュメント整備

**タスク**:
- [ ] README.md 更新（セットアップ手順）
- [ ] 環境変数一覧
- [ ] トラブルシューティング
- [ ] ライセンス表記（使用ライブラリ一覧）

**ライセンス表記内容**:
```markdown
## Licenses

This project uses the following open source software:

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - MIT License
- [Whisper](https://github.com/openai/whisper) - MIT License
- [FastAPI](https://fastapi.tiangolo.com/) - MIT License
- [SQLAlchemy](https://www.sqlalchemy.org/) - MIT License
- [PostgreSQL](https://www.postgresql.org/) - PostgreSQL License
- [Authlib](https://authlib.org/) - BSD-3-Clause License
- [React](https://reactjs.org/) - MIT License
- [shadcn/ui](https://ui.shadcn.com/) - MIT License
- [Tailwind CSS](https://tailwindcss.com/) - MIT License
```

---

### 6.3 Mac アプリ About 画面

**タスク**:
- [ ] About 画面にバージョン情報表示
- [ ] ライセンス情報へのリンク追加

---

### 6.3 本番環境設定

**タスク**:
- [ ] HTTPS 設定
- [ ] ドメイン設定
- [ ] GitHub OAuth アプリ設定（本番用）

---

## タスク進捗管理

### ステータス凡例

| 記号 | 意味 |
|------|------|
| [ ] | 未着手 |
| [x] | 完了 |
| [~] | 進行中 |
| [!] | ブロック中 |

### 進捗サマリー

| Phase | タスク数 | 完了 | 進捗 |
|-------|---------|------|------|
| 0 | 3 | 3 | 100% |
| 1 | 4 | 4 | 100% |
| 2 | 8 | 8 | 100% |
| 3 | 5 | 5 | 100% |
| 4 | 12 | 12 | 100% |
| 5 | 8 | 8 | 100% |
| 6 | 4 | 0 | 0% |
| **合計** | **44** | **40** | **91%** |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-01-30 | 初版作成 |
| 2026-01-30 | 設計決定事項を反映（JWT 7日、WAV 16kHz、ホールド式、60秒制限、エラー通知） |
| 2026-01-30 | セキュリティ実装タスク追加（Whitelist毎回確認、Keychain保存、ファイルクリーンアップ） |
| 2026-01-30 | 追加決定事項反映（管理者Whitelist免除、手動モデルDL、Mac配布方法、開発環境モック） |
| 2026-01-30 | 辞書機能追加（グローバル辞書+個人辞書、個人辞書100件上限、Macアプリで編集） |
| 2026-01-30 | ライセンス表記タスク追加（README、Macアプリ About画面） |
| 2026-01-31 | Phase 4、Phase 5完了を記録（Task 4.11含む） |
