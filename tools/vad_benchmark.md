# VAD 速度評価スクリプト

## 目的

`tools/vad_benchmark.py` で silero の推論時間を測る。

## 前提

- 16kHz / mono / 16-bit PCM の WAV を用意する
- Python 3.10 以上を想定する

## 依存関係

- `numpy`
- `silero-vad-lite`
- `torch`

インストール例は次の通り。

```bash
python -m pip install numpy silero-vad-lite torch
```

`silero-vad` は `torch.hub` でモデルを取得するため、初回はネットワークが必要になる。

## 実行方法

```bash
python tools/vad_benchmark.py path/to/audio.wav
```

フレーム長を変える場合は `--frame-ms` を指定する。

```bash
python tools/vad_benchmark.py path/to/audio.wav --frame-ms 32
```

`silero-vad` を省略したい場合は `--skip-silero` を指定する。

```bash
python tools/vad_benchmark.py path/to/audio.wav --skip-silero
```

## 出力例

```
silero-vad-lite: 12.34 ms total (500 frames, 0.025 ms/frame)
silero-vad: 98.76 ms total (500 frames, 0.198 ms/frame)
```
