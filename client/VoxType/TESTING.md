# VoxType 手動テスト手順書

## 前提条件

### サーバー側の準備

1. PostgreSQL を起動
```bash
cd server
docker compose up -d db
```

2. マイグレーションを実行
```bash
cd server
uv run alembic upgrade head
```

3. GitHub OAuth アプリを作成
   - GitHub Settings > Developer settings > OAuth Apps > New OAuth App
   - Homepage URL: `http://localhost:8000`
   - Callback URL: `http://localhost:8000/auth/github/callback`
   - Client ID と Client Secret を取得

4. 環境変数を設定
```bash
cp .env.example .env
# .env を編集して以下を設定:
# GITHUB_CLIENT_ID=your_client_id
# GITHUB_CLIENT_SECRET=your_client_secret
```

5. Whitelist にユーザーを追加（初回のみ）
```bash
# psql で直接追加
docker compose exec db psql -U voice_user -d voice_db
INSERT INTO whitelist (github_id) VALUES ('your_github_username');
```

6. サーバーを起動
```bash
cd server
uv run uvicorn app.main:app --reload
```

7. whisper.cpp サーバーを起動
```bash
cd whisper
docker compose up whisper
```

### クライアント側の準備

1. Xcode プロジェクトを生成
```bash
cd client/VoxType
xcodegen generate
```

2. アプリをビルド・実行
```bash
open VoxType.xcodeproj
# Xcode で Run (Cmd+R)
```

---

## テストシナリオ（正常系）

### 1. アプリ起動テスト

- [ ] アプリ起動後、メニューバーにマイクアイコンが表示される
- [ ] アイコンをクリックするとドロップダウンメニューが表示される
- [ ] 「Not logged in」と表示される

### 2. アクセシビリティ権限テスト

- [ ] Settings > Hotkey タブを開く
- [ ] アクセシビリティ権限が未許可の場合、警告が表示される
- [ ] 「Grant Access」ボタンをクリックすると、システム設定が開く
- [ ] VoxType を許可リストに追加
- [ ] アプリを再起動して権限が有効になることを確認

### 3. ログインテスト

- [ ] メニューから「Login with GitHub」をクリック
- [ ] ブラウザで GitHub 認証画面が開く
- [ ] 認証を許可すると、アプリに戻る
- [ ] メニューに GitHub ユーザー名が表示される
- [ ] Settings > Account タブにユーザー情報が表示される

### 4. 録音テスト

- [ ] ホットキー（Cmd+Shift+V）を押す
- [ ] アイコンが赤に変わり、録音時間が表示される
- [ ] 日本語で話す（例：「今日はいい天気です」）
- [ ] ホットキーを離す
- [ ] アイコンがオレンジに変わり、処理中になる
- [ ] 数秒後、認識結果がカーソル位置にペーストされる
- [ ] アイコンが緑に変わり、完了表示
- [ ] 3秒後、アイコンが通常に戻る

### 5. 設定テスト

- [ ] Settings > General でサーバーURLを変更できる
- [ ] 「Test Connection」で接続テストができる
- [ ] Settings > Hotkey でホットキー設定を確認できる
- [ ] Settings > Hotkey でモデル変更ホットキーが Control + M になっている
- [ ] モデル変更ホットキーを変更してアプリ再起動後も維持される
- [ ] Settings > Dictionary で辞書エントリを追加/削除できる

---

## テストシナリオ（エラー系）

### 1. 未認証時のテスト

- [ ] ログアウト状態でホットキーを押す
- [ ] 「Please log in to use voice transcription」エラーが表示される

### 2. サーバー停止時のテスト

- [ ] サーバーを停止
- [ ] ログイン状態でホットキーを押して録音
- [ ] 録音停止後、サーバー接続エラーが表示される
- [ ] macOS 通知が表示される

### 3. 60秒自動停止テスト

- [ ] ホットキーを押し続けて60秒待つ
- [ ] 60秒で自動的に録音が停止する
- [ ] 処理が開始される

### 4. ネットワークエラーテスト

- [ ] ネットワークを切断
- [ ] 録音して送信を試みる
- [ ] ネットワークエラーが表示される
- [ ] macOS 通知が表示される

---

## コンポーネント統合確認

### フロー確認

```
[ホットキー押下]
    ↓
HotkeyManager.onHotkeyDown
    ↓
AppCoordinator.handleHotkeyDown
    ↓
AppState.startRecording
    ↓
AudioRecorder.startRecording
    ↓
[録音中...]
    ↓
[ホットキー離す]
    ↓
HotkeyManager.onHotkeyUp
    ↓
AppCoordinator.handleHotkeyUp
    ↓
AppState.stopRecording → AudioRecorder.stopRecording
    ↓
AppCoordinator.processRecording
    ↓
APIClient.transcribe (音声ファイル送信)
    ↓
[サーバー処理]
    ↓
ClipboardManager.pasteText (結果をペースト)
    ↓
AppState.completeTranscription
```

### サービス一覧

| サービス | 役割 | 状態管理 |
|---------|------|---------|
| AppState | アプリ状態管理 | @Published |
| AuthService | OAuth 認証 | Keychain |
| HotkeyManager | グローバルホットキー | CGEvent |
| AudioRecorder | 音声録音 | AVFoundation |
| APIClient | サーバー通信 | URLSession |
| ClipboardManager | クリップボード操作 | NSPasteboard |
| NotificationManager | 通知表示 | UserNotifications |
| DictionaryService | 辞書管理 | API 連携 |

---

## 既知の制限事項

1. **署名なしビルド**: 初回起動時に「開発元が未確認」警告が出る
2. **アクセシビリティ権限**: グローバルホットキーとペースト操作に必要
3. **マイク権限**: 初回録音時に許可ダイアログが表示される
4. **通知権限**: 初回起動時に許可ダイアログが表示される

---

## トラブルシューティング

### ホットキーが反応しない

1. システム設定 > プライバシーとセキュリティ > アクセシビリティ
2. VoxType が許可されているか確認
3. アプリを再起動

### 録音できない

1. システム設定 > プライバシーとセキュリティ > マイク
2. VoxType が許可されているか確認

### サーバーに接続できない

1. サーバーが起動しているか確認
2. Settings > General でサーバーURLを確認
3. 「Test Connection」で接続テスト
