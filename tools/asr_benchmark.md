# 文字起こし精度・速度の評価スクリプト

## 目的

`tools/asr_benchmark.py` で、複数の whisper.cpp サーバーを同じ音声・同じ条件で測り、モデルの選定に使う。測るのは次の3つ。

- CER（文字誤り率。小さいほど良い）
- 1発話あたりのリクエスト時間（クライアントから見た時間。音声の送信と応答の受信を含む）
- GPU のメモリ使用量

## 評価データ

HuggingFace で公開されている日本語の評価セットを使う。正解テキストが付いているため、自前で音声を用意する必要はない。

| 指定名 | データセット | 内容 |
|---|---|---|
| `jsut` | `japanese-asr/ja_asr.jsut_basic5000` | 読み上げ音声、クリーン |
| `common_voice` | `japanese-asr/ja_asr.common_voice_8_0` | 読み上げ、話者と環境が多様 |
| `reazonspeech` | `japanese-asr/ja_asr.reazonspeech_test` | テレビ音声、実際の話し言葉 |

ストリーミングで先頭から必要な件数だけ取得する。データセット全体（JSUT は約2.3GB）をダウンロードはしない。取得した音声は 16kHz モノラルの WAV に変換して `--audio-cache` の下に残り、2回目以降は再利用する。正解文と音声のハッシュも一緒に記録しておき、データセットが更新されて中身が変わった場合は WAV を作り直す。

`--dataset` には任意の HuggingFace のデータセットIDを渡せるが、`audio` 列に音声が直接埋め込まれているか、ローカルに実在するパスを指している必要がある。リモートのファイルを参照するデータセットは読めない。組み込みの3つは parquet に埋め込まれているため、そのまま使える。

評価に使うのは先頭から N 件で、無作為抽出ではない。モデル間では同じ発話を使うため比較には使えるが、データセット全体を代表する値ではない。

一般的な話題の日本語音声なので、人名や地名はある程度含まれるが、このプロジェクト固有の語彙は含まれない。モデルの優劣を比べる用途には使えるが、自分が使う専門用語の誤変換は測れない。

## 依存関係

Python 3.11 以上を想定する。

```bash
python -m pip install datasets soundfile soxr httpx numpy
```

サーバー本体の依存とは無関係なので、使い捨ての venv に入れればよい。

```bash
python3 -m venv ~/bench-venv
~/bench-venv/bin/pip install datasets soundfile soxr httpx numpy
```

## 測定対象のサーバーを起動する

本番のコンテナには触れず、モデルを変えた使い捨てのコンテナを別ポートで立てる。イメージは本番と同じ `voxtype-whisper-gpu:local` を使う。

```bash
docker run --rm -d --name bench-turbo-q8 --gpus all -p 8090:8080 \
  -v ~/voxtype/whisper/models:/app/models:ro \
  -e WHISPER_MODEL=/app/models/ggml-large-v3-turbo-q8_0.bin \
  -e ENABLE_VAD=false \
  voxtype-whisper-gpu:local
```

GPU メモリをモデルごとに知りたい場合は、1つずつ起動して測る。スクリプトが読むのは GPU 全体の使用量なので、複数のコンテナを同時に立てているとどのモデルを測っても同じ値になる。起動前の `nvidia-smi` の値との差が、そのモデルの使用量になる。

```bash
nvidia-smi --query-gpu=memory.used --format=csv,noheader
```

`--out` に前回の結果が残っていれば、後から測った分と合わせて表が出る。発話の集合（`corpus_fingerprint`）や正規化の条件が食い違う行が混ざると警告が出る。同じラベルで別のモデルを測ると前の結果を上書きするため、ラベルはモデルごとに変える。

測定が終わったら停止する。

```bash
docker stop bench-turbo-q8
```

## 実行方法

```bash
~/bench-venv/bin/python tools/asr_benchmark.py \
  --target medium=http://localhost:8080 \
  --target turbo-q8=http://localhost:8090 \
  --dataset jsut \
  --limit 100
```

| オプション | 既定値 | 説明 |
|---|---|---|
| `--target LABEL=URL` | 必須 | 測定対象。複数指定できる |
| `--dataset` | `jsut` | 上の表の指定名、または HuggingFace のデータセットID。複数指定できる |
| `--limit` | 100 | 使う発話数 |
| `--timeout` | 300 | 1リクエストの上限秒数 |
| `--gpu-index` | 0 | メモリ使用量を読む GPU |
| `--worst` | 5 | 誤りの大きい発話を何件表示するか |
| `--audio-cache` | `tools/.asr_audio` | WAV の保存先 |
| `--out` | `tools/asr_results.json` | 結果の保存先 |

本番で動いているモデルをそのまま測る場合は、`docker compose` のネットワークに入るか、一時的にポートを公開する必要がある。使い捨てコンテナを別に立てるほうが本番への影響がない。

## 出力

```
jsut
model                        CER   median      p95     RTF      GPU
-------------------------------------------------------------------
turbo-q8                   8.10%    0.22s    0.25s   0.056   4184MB
medium                    10.18%    0.28s    0.39s   0.075   4948MB

turbo-q8: worst 3 utterances
  CER 41.2%
    ref: むかしむかし1人の老人が住んでいた
    hyp: 昔昔一人の老人が住んでいた
```

誤りの大きい発話が並ぶので、漢字の誤変換がどこで起きているかを目で確認できる。全発話の結果は `--out` の JSON に残る。

接続できない、タイムアウトする、想定外の応答が返るといった場合、そのモデルだけを失敗として記録し、残りのモデルの計測は続ける。結果はモデル1つを測り終えるたびに保存する。

## 数値の読み方

- CER は全発話の編集距離の合計を正解文字数の合計で割った値
- 比較の前に NFKC 正規化、空白の除去、Unicode の句読点カテゴリに属する文字とチルダの除去を行う。長音記号は modifier letter なので残る
- 英字の大文字と小文字は区別する。正解文にラテン文字が含まれる場合、表記の違いは誤りとして数える
- RTF はリクエスト時間の合計を音声の長さの合計で割った値。1より小さければ実時間より速い
- 発話ごとの `elapsed_s` と `duration_s` も JSON に残るため、保存後に集計をやり直せる
- p95 は nearest-rank。100件なら95番目の値
- GPU は GPU 全体のメモリ使用量で、同じ GPU で動いている他のコンテナの分も含む。プロセス別の内訳は JSON の `gpu_processes` に残る
- 正規化の条件が変われば絶対値も変わる。公開されているベンチマークの数値と直接は比較できない。比較はこのスクリプトの出力どうしで行う
- モデルは whisper-server の起動時にロードされるため、1回目のリクエストに含まれるのは初回推論と GPU の初期化。これは計測から除外して `first_inference_s` として JSON に記録する
- 空の文字起こしが返った件数は `empty_hypotheses` に記録する。無音と判定されやすいモデルの確認に使う
