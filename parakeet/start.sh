#!/bin/bash

# Model to load. The Japanese XL model is the one this project evaluates.
export PARAKEET_MODEL=${PARAKEET_MODEL:-nvidia/parakeet-tdt_ctc-0.6b-ja}

# Decoder: tdt (default, best accuracy) or ctc (marginally faster).
export PARAKEET_DECODER=${PARAKEET_DECODER:-tdt}

# One worker only. The model lives in GPU memory, so a second worker would
# load a second copy.
exec uvicorn app:app \
    --host 0.0.0.0 \
    --port 8080 \
    --workers 1 \
    --log-level info
