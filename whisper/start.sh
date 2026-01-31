#!/bin/bash
exec /app/whisper-server \
    --model /app/models/ggml-large-v3-turbo-q8_0.bin \
    --host 0.0.0.0 \
    --port 8080 \
    --language ja
