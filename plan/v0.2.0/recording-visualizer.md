# v0.2.0 - 録音中ビジュアライザー機能

## 概要

録音中に音声レベルを視覚的に表示するフローティングウィンドウを追加する。
Aqua Voice のような縦バーが音声に合わせて動くUIを実装する。

## 目標

- 録音中であることが視覚的に明確にわかる
- 音声が認識されているかリアルタイムでフィードバック
- 邪魔にならないミニマルなデザイン

## デザイン仕様

### ビジュアライザーウィンドウ

```
┌─────────────────────────────────────────────────┐
│  ▁ ▂ ▃ ▅ ▇ █ ▇ ▅ ▃ ▂ ▁ ▂ ▃ ▅ ▇ █ ▇ ▅ ▃ ▂ ▁   │
└─────────────────────────────────────────────────┘
```

### 仕様詳細

| 項目 | 値 |
|------|-----|
| バー数 | 20〜30本 |
| バーの幅 | 3〜4px |
| バーの間隔 | 2px |
| バーの最大高さ | 30px |
| ウィンドウ高さ | 約50px |
| ウィンドウ幅 | 約300px |
| 背景 | 半透明ダーク or ライト（システム設定に合わせる） |
| 角丸 | 8〜12px |
| 表示位置 | 画面上部中央（メニューバー下） |

### アニメーション

- 音声レベルに応じてバーの高さが変化
- スムーズなアニメーション（0.05秒程度の遷移）
- 無音時は低い状態で微妙に揺れる（録音中であることを示す）

## 技術設計

### 必要なコンポーネント

```
VoiceClient/
├── Views/
│   ├── RecordingOverlayWindow.swift    # 新規: フローティングウィンドウ
│   └── AudioVisualizerView.swift       # 新規: バービジュアライザー
├── Services/
│   └── AudioRecorder.swift             # 既存: 音声レベル取得（実装済み）
└── AppState.swift                      # 既存: audioLevel（実装済み）
```

### データフロー

```
AudioRecorder.getCurrentLevel()
    ↓
AppState.audioLevel (0.0 ~ 1.0)
    ↓
AudioVisualizerView (SwiftUI)
    ↓
バーの高さに反映
```

### ウィンドウ表示制御

1. 録音開始時 → ウィンドウ表示（フェードイン）
2. 録音中 → 音声レベルでバー更新
3. 録音終了時 → ウィンドウ非表示（フェードアウト）

## 実装タスク

### Phase 1: 基本実装

- [ ] AudioVisualizerView.swift 作成
  - [ ] バーを描画するSwiftUI View
  - [ ] audioLevelを複数バーに分散表示
  - [ ] アニメーション実装

- [ ] RecordingOverlayWindow.swift 作成
  - [ ] NSPanel でフローティングウィンドウ作成
  - [ ] 常に最前面に表示
  - [ ] ドラッグ不可、クリック透過

- [ ] AppState / VoiceClientApp 統合
  - [ ] 録音開始時にウィンドウ表示
  - [ ] 録音終了時にウィンドウ非表示

### Phase 2: 改善

- [ ] ウィンドウ位置の設定オプション
- [ ] バーの色カスタマイズ
- [ ] ダークモード対応
- [ ] ウィンドウサイズの調整オプション

## 参考実装

### AudioVisualizerView 概要

```swift
struct AudioVisualizerView: View {
    let audioLevel: Float
    let barCount: Int = 25

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(level: calculateBarLevel(for: index))
            }
        }
    }

    private func calculateBarLevel(for index: Int) -> CGFloat {
        // 中央が高く、端が低くなるような計算
        // + ランダム性を加えて自然な動きに
    }
}
```

### NSPanel (フローティングウィンドウ)

```swift
class RecordingOverlayWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
    }
}
```

## テスト計画

1. 録音開始でウィンドウが表示されるか
2. 音声レベルに応じてバーが動くか
3. 録音終了でウィンドウが消えるか
4. 長時間録音（60秒）で問題ないか
5. 複数ディスプレイ環境での表示位置

## リリースノート案

### v0.2.0 - Recording Visualizer

新機能:
- 録音中に音声レベルを表示するビジュアライザーを追加
- 画面上部に表示されるフローティングウィンドウ
- 音声入力をリアルタイムで視覚化

---

## 進捗管理

| タスク | 状態 | 備考 |
|--------|------|------|
| AudioVisualizerView | [ ] 未着手 | |
| RecordingOverlayWindow | [ ] 未着手 | |
| 統合・テスト | [ ] 未着手 | |
| ドキュメント更新 | [ ] 未着手 | |

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026-01-31 | 初版作成 |
