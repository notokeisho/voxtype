# parakeet ASR サーバー

NVIDIA の日本語音声認識モデル [parakeet-tdt_ctc-0.6b-ja](https://huggingface.co/nvidia/parakeet-tdt_ctc-0.6b-ja) を HTTP で呼べるようにしたラッパー。

whisper-server と同じエンドポイントを持つため、アプリケーションと `tools/asr_benchmark.py` のどちらからも、接続先を変えるだけで使える。

| エンドポイント | 内容 |
|---|---|
| `POST /inference` | multipart の `file` を受け取り、`{"text": "..."}` を返す |
| `GET /health` | モデルの読み込みが終わっていれば `{"status": "ok"}` |

`response_format` は受け取って無視する。JSON しか返さないため。

## 設定

| 環境変数 | 既定値 | 内容 |
|---|---|---|
| `PARAKEET_MODEL` | `nvidia/parakeet-tdt_ctc-0.6b-ja` | 読み込むモデル |
| `PARAKEET_DECODER` | `tdt` | `tdt` または `ctc` |

デコーダの精度差はモデルカードの値で JSUT 6.4 対 6.5。

## ビルドと起動

```bash
docker build -t voxtype-parakeet-gpu:local -f parakeet/Dockerfile.gpu parakeet/
```

```bash
docker run --rm -d --name parakeet --gpus all -p 8091:8080 \
  -v ~/parakeet-cache:/app/cache \
  voxtype-parakeet-gpu:local
```

重みは初回起動時にダウンロードされ、`/app/cache` に残る。ボリュームをマウントしておくと再起動のたびに取得し直さずに済む。

モデルの読み込みが終わるまで `/health` は `loading` を返す。初回は重みのダウンロードを含むため数分かかる。

## 動作確認

```bash
curl -s -F "file=@whisper/test.wav" http://localhost:8091/inference
```

## 計測

```bash
tools/asr_benchmark.py --target parakeet-tdt=http://127.0.0.1:8091 \
  --dataset jsut --dataset reazonspeech --limit 100
```

評価上の注意が2つある。

モデルカードの CER は句読点と非アルファベット文字を除去して測られており、このスクリプトの正規化とは条件が異なる。公称値と直接は比較できない。

このモデルは ReazonSpeech v2.0 で学習されている。ReazonSpeech のテストセットでの結果は有利に出る可能性があるため、判断は JSUT を主とする。
