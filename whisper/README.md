# whisper.cpp Server

whisper.cpp を使用した音声認識サーバー。

## モデルのダウンロード

モデルファイルは約6GBと大きいため、手動でダウンロードする必要がある。

### ダウンロード手順

```bash
cd whisper/whisper.cpp/models
./download-ggml-model.sh large-v3-q8_0
```

ダウンロード後、モデルファイルを `whisper/models/` に移動する。

```bash
mv ggml-large-v3-q8_0.bin ../../models/
```

### 確認

```bash
ls -lh whisper/models/
# ggml-large-v3-q8_0.bin (約6GB) が存在すること
```

## Docker でのビルドと起動

```bash
# イメージをビルド
docker compose build whisper

# 起動
docker compose up whisper
```

## ヘルスチェック

```bash
curl http://localhost:8080/health
```

## 音声認識テスト

```bash
curl -X POST http://localhost:8080/inference \
  -F "file=@test.wav" \
  -F "response_format=json"
```
