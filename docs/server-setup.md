# サーバー構築手順

VoxType の本番サーバーをゼロから構築する手順。Ubuntu Server 24.04 LTS と NVIDIA GPU が用意されている状態から始める。VM の作成やハイパーバイザ側の GPU パススルー設定は対象外。

構築後の運用（バックアップ、障害時の確認、更新）は [operations.md](operations.md) を参照。

## 前提

| 項目 | 内容 |
|---|---|
| OS | Ubuntu Server 24.04 LTS |
| GPU | NVIDIA 製（検証環境は GeForce RTX 3060 12GB） |
| CPU | 6コア以上 |
| メモリ | 12GB以上（ビルド時のピークで決まる） |
| ディスク | 100GB以上 |
| 外部公開 | Cloudflare Tunnel（ポート開放と証明書管理は不要） |

GPU が OS から見えていることを確認する。

```bash
lspci -nn | grep -i nvidia
```

VGA と Audio の2行が出れば正常。この時点ではドライバを入れていないため `nvidia-smi` はまだ通らない。

### ディスク容量が足りない場合

Ubuntu インストーラで LVM を選ぶと、ボリュームグループの約半分だけが論理ボリュームに割り当てられる。120GB のディスクでも `df -h /` が 58GB になることがある。

```bash
sudo vgs
```

`VFree` に空きがあれば、Docker を入れる前に広げる。`/var/lib/docker` がルートに乗るため、イメージを置く前に済ませる。

```bash
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

マウントしたまま拡張でき、停止も再起動も要らない。ファイルシステムが xfs の場合は最後を `sudo xfs_growfs /` にする。

### 容量の内訳

| 項目 | 目安 |
|---|---|
| OS と NVIDIA ドライバ | 8GB |
| CUDA devel イメージ（ビルド用） | 7GB |
| CUDA runtime と whisper イメージ | 4GB |
| ビルドキャッシュ | 10〜15GB |
| その他のイメージ | 2GB |
| Whisper モデル（small + medium） | 2GB |

## インストールするパッケージ

必要なものだけを入れる。

| パッケージ | 用途 |
|---|---|
| `nvidia-driver-595-server` | GPU ドライバ |
| `linux-headers-generic` | DKMS がカーネル更新時にモジュールを再ビルドするために必要 |
| `docker-ce` / `docker-ce-cli` / `containerd.io` | コンテナ実行 |
| `docker-buildx-plugin` | `docker compose build` が内部で使う |
| `docker-compose-plugin` | `docker compose` コマンド |
| `nvidia-container-toolkit` 一式 | コンテナへ GPU を渡す |
| `git` | リポジトリ取得（whisper.cpp はサブモジュール） |
| `curl` / `ca-certificates` / `gnupg` | リポジトリ鍵の取得 |

`-server` ブランチのドライバを選ぶため、デスクトップ向けのライブラリは入らない。

## 1. 基本パッケージ

```bash
sudo apt update
```

```bash
sudo apt install -y git curl ca-certificates gnupg
```

## 2. NVIDIA ドライバ

### 2-1. カーネルヘッダ

Ubuntu Server のイメージはカーネルヘッダを含まないことがある。DKMS がモジュールをビルドするのに必要。

```bash
sudo apt install -y linux-headers-generic
```

バージョン固定の `linux-headers-$(uname -r)` ではなくメタパッケージを使う。カーネルが更新されたときにヘッダも追従し、DKMS がモジュールを再ビルドできる。固定版だけだとカーネル更新で GPU が使えなくなる。

### 2-2. ドライバのインストール

```bash
sudo apt install -y nvidia-driver-595-server
```

```bash
sudo reboot
```

モジュールのビルドや初期化に失敗する場合は open kernel module 版へ切り替える。Turing 以降の GPU は open モジュールに対応している。

```bash
sudo apt install -y nvidia-driver-595-server-open
```

候補を一覧したい場合は `ubuntu-drivers-common` を入れて `ubuntu-drivers devices` を実行する方法もあるが、入れるドライバが決まっているなら不要。

### 2-3. 確認

```bash
nvidia-smi
```

GPU 名、ドライバ版、CUDA 版が表示されれば成功。コンテナは CUDA 12.2 でビルドされるため、ドライバが対応する CUDA 版は 12.2 以上である必要がある。ドライバは古い CUDA ランタイムに対して後方互換なので、新しいドライバであれば問題ない。

## 3. Docker

Docker 公式リポジトリから入れる。以下は Docker 公式ドキュメントの「Install using the apt repository」と同じ手順。

### 3-1. リポジトリ

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
```

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

書き込まれた内容を確認する。`Suites:` が空なら展開に失敗しているため、コードネーム（24.04 なら `noble`）を直接書く。

```bash
cat /etc/apt/sources.list.d/docker.sources
```

### 3-2. インストール

```bash
sudo apt update
```

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

```bash
sudo usermod -aG docker $USER
```

グループの変更はログインし直すまで反映されない。一度ログアウトして入り直す。

```bash
docker ps
```

`permission denied` が出なければよい。

## 4. NVIDIA Container Toolkit

ドライバを入れただけではコンテナから GPU を使えない。デバイスとドライバのライブラリをコンテナへ渡す仕組みが別に必要になる。

### 4-1. リポジトリ

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

```bash
sudo apt update
```

### 4-2. インストール

バージョンを固定する。利用可能な版は次で確認できる。

```bash
apt-cache madison nvidia-container-toolkit | head -5
```

```bash
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.20.1-1
```

```bash
sudo apt install -y \
    nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
```

4つとも同じ版で揃える。

### 4-3. Docker への登録

```bash
sudo nvidia-ctk runtime configure --runtime=docker
```

これで `/etc/docker/daemon.json` が作られる。この手順を飛ばすと `--gpus` が効かない。

### 4-4. ログの上限

既定ではコンテナのログが無制限に増える。docker を再起動する前に上限を設定する。

```bash
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
```

`runtimes` の記述を残したまま設定を追加する。

```bash
sudo python3 -c "import json;p='/etc/docker/daemon.json';c=json.load(open(p));c['log-driver']='json-file';c['log-opts']={'max-size':'10m','max-file':'3'};json.dump(c,open(p,'w'),indent=4)"
```

```bash
sudo systemctl restart docker
```

```bash
docker info --format '{{.LoggingDriver}} / {{.DefaultRuntime}} / {{range $k,$v := .Runtimes}}{{$k}} {{end}}'
```

`json-file` が出て、ランタイム一覧に `nvidia` が含まれていればよい。`DefaultRuntime` は `runc` のままで正しい。compose 側が GPU を要求する。

### 4-5. コンテナから GPU が見えるか

```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

ホストと同じ出力が出れば、コンテナから GPU を使える。この確認用イメージは本番では使わないため、確認後に消してよい。

```bash
docker rmi nvidia/cuda:12.2.0-base-ubuntu22.04
```

## 5. 外部公開の準備

### 5-1. GitHub OAuth App

1. GitHub Developer Settings で OAuth App を作成する
2. Authorization callback URL を `https://<APIのホスト名>/auth/github/callback` にする
3. Client ID と Client Secret を控える

パスは `/auth/callback` ではなく `/auth/github/callback`。

### 5-2. Cloudflare Tunnel

1. Cloudflare Zero Trust の Networks > Tunnels でトンネルを作る
2. Public hostname を2つ登録し、どちらも `http://nginx:80` へ向ける（API 用と管理画面用）
3. トークンを控える
4. 管理画面側のホスト名に Zero Trust Access のポリシー（GitHub 認証）を設定する

API 側は macOS クライアントが接続するため Zero Trust を掛けない。API 自体の JWT 認証で保護する。

## 6. リポジトリと環境変数

### 6-1. クローン

whisper.cpp はサブモジュールのため、`--recurse-submodules` を付ける。付け忘れると `whisper/whisper.cpp` が空になり、ビルドが失敗する。

```bash
git clone --recurse-submodules https://github.com/notokeisho/voxtype.git
```

```bash
cd voxtype
```

付け忘れた場合は次で回復できる。

```bash
git submodule update --init --recursive
```

### 6-2. .env.prod

```bash
cp .env.prod.example .env.prod
```

```bash
nano .env.prod
```

| 変数 | 内容 |
|---|---|
| `TUNNEL_TOKEN` | Cloudflare Tunnel のトークン |
| `POSTGRES_PASSWORD` | `openssl rand -hex 24` で生成 |
| `JWT_SECRET` | `openssl rand -hex 32` で生成 |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth App の値 |
| `INITIAL_ADMIN_GITHUB_ID` | `curl -s https://api.github.com/users/<username>` の `id` |
| `INITIAL_ADMIN_GITHUB_USERNAME` | GitHub のユーザー名 |

`DATABASE_URL` は `POSTGRES_*` を参照する形で書かれているため、そのままでよい。

必須の値（`TUNNEL_TOKEN`、`DATABASE_URL`、`JWT_SECRET`、`GITHUB_CLIENT_ID`、`GITHUB_CLIENT_SECRET`、`POSTGRES_PASSWORD`）が欠けていると、`up` だけでなく `ps` や `down` を含むすべての compose コマンドがエラーで止まる。設定漏れのまま起動させないための仕様。

アクセス制御の2つは、未設定でも compose 側の既定値が入る。開発用の URL を含めたい場合だけ `.env.prod` に書く。

| 変数 | 既定値 |
|---|---|
| `CORS_ALLOW_ORIGINS` | 管理画面の本番オリジン |
| `OAUTH_CALLBACK_ALLOWLIST` | `voxtype://callback` と管理画面の本番コールバック |

権限を絞る。

```bash
chmod 600 .env.prod
```

設定を確認する。出力には秘密値が展開されるため、ファイルへ保存しない。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod config -q
```

## 7. モデルの取得

large-v3-turbo を量子化版と f16 版の2つ取得する。合計で約2.4GB。fast が量子化版、smart が f16 版を読む。

```bash
cd whisper/whisper.cpp/models
```

```bash
./download-ggml-model.sh large-v3-turbo-q8_0 && mv ggml-large-v3-turbo-q8_0.bin ../../models/
```

```bash
./download-ggml-model.sh large-v3-turbo && mv ggml-large-v3-turbo.bin ../../models/
```

```bash
cd ~/voxtype && ls -lh whisper/models/
```

`ggml-large-v3-turbo-q8_0.bin` と `ggml-large-v3-turbo.bin` の2つがあればよい。

## 8. ビルド

whisper のイメージは `whisper-fast` が1回だけビルドし、`whisper-smart` は同じイメージを使う。CUDA のコンパイルは1回で済む。

CUDA の devel イメージが約7GB、コンパイルに10〜20分かかる。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod build whisper-fast
```

メモリや CPU が苦しい場合はコンパイルの並列数を下げる。既定は4。

```bash
BUILD_JOBS=2 docker compose -f docker-compose.prod.yml --env-file .env.prod build whisper-fast
```

残りをビルドする。こちらは軽い。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod build server admin-web
```

### 共有ライブラリの確認

CUDA バックエンドは `ggml/src/ggml-cuda/` に出力されるため、コピー漏れが起きやすい。イメージ内で解決できているか確認する。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm --no-deps --entrypoint sh whisper-fast -lc 'ldd /app/whisper-server'
```

`libcuda.so.1 => not found` が出るのは正常。このライブラリは NVIDIA ドライバが提供するもので、GPU を割り当てずに起動したときは解決されない。実行時にコンテナツールキットが注入する。それ以外に `not found` が無ければよい。

## 9. データベースの初期化

DB だけを起動する。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d db
```

10秒ほど待ってからマイグレーションを実行する。`--no-deps` を付ける。付けないと `server` の `depends_on` により両 whisper の起動まで待たされ、GPU 側の問題がマイグレーションを巻き込む。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm --no-deps server uv run alembic upgrade head
```

テーブルができたことを確認する。

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod exec db psql -U voxtype -d voxtype -c '\dt'
```

## 10. 起動

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod ps
```

`db`、`nginx`、`server`、`whisper-fast`、`whisper-smart` が healthy になる。`whisper-smart` はモデルが大きいため60秒ほどかかる。

## 11. 動作確認

### GPU を使っているか

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod logs whisper-fast | grep -i -E "cuda|device|backend"
```

次のような行が出ていれば GPU で動いている。

```
ggml_cuda_init: found 1 CUDA devices:
  Device 0: NVIDIA GeForce RTX 3060, compute capability 8.6, VMM: yes
whisper_backend_init_gpu: using CUDA0 backend
```

CPU にフォールバックしている場合は CUDA 関連の行が出ない。`whisper-smart` も同様に確認する。

### 外部からの疎通

```bash
curl -i https://<APIのホスト名>/
```

`HTTP/2 200` と `{"status":"ok","app":"VoxType"}` が返る。

管理画面はブラウザで開く。Cloudflare Zero Trust の GitHub 認証を通ると、初回ログインで初期管理者が作られる。

### 文字起こし

クライアントアプリでログインして録音する。録音中にサーバー側で GPU の使用状況を見る。

```bash
nvidia-smi
```

whisper-server のプロセスが VRAM を使っていれば GPU 推論が効いている。small と medium の両方を常駐させるため、合計2GB前後を使う。

無音判定もあわせて確認する。

- 無言のまま60秒録音して、何も挿入されないこと
- 長い無音を挟んで発話したとき、文字起こしが返ること

## 12. バックアップの設定

構築が終わったら必ず設定する。手順は [operations.md](operations.md#バックアップ) を参照。
