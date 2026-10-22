"""HTTP wrapper around NeMo's parakeet ASR model.

The endpoints mirror whisper-server so that both the application and
tools/asr_benchmark.py can talk to either backend without changes.
"""

import logging
import os
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path

import nemo.collections.asr as nemo_asr
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse

MODEL_NAME = os.environ.get("PARAKEET_MODEL", "nvidia/parakeet-tdt_ctc-0.6b-ja")
# The model ships both decoders. TDT is the default and the one the model card
# reports its headline numbers with; CTC is marginally faster but less accurate.
DECODER = os.environ.get("PARAKEET_DECODER", "tdt")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("parakeet")

state: dict = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load before the server starts listening, the way whisper-server does.
    # A request that arrives first must not pay for the model load, or the
    # benchmark's first_inference_s would measure something else.
    logger.info("loading model %s (decoder=%s)", MODEL_NAME, DECODER)
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=MODEL_NAME)
    if DECODER == "ctc":
        model.change_decoding_strategy(decoder_type="ctc")
    model.eval()
    state["model"] = model
    logger.info("model ready")
    yield
    state.clear()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok" if "model" in state else "loading"}


@app.post("/inference")
async def inference(file: UploadFile = File(...)) -> JSONResponse:
    """Transcribe one audio file.

    Mirrors whisper-server: multipart upload in, {"text": ...} out. The
    response_format field that callers send is accepted and ignored, since
    JSON is the only format this wrapper produces.
    """
    model = state.get("model")
    if model is None:
        return JSONResponse({"error": "model is not loaded"}, status_code=503)

    audio = await file.read()
    if not audio:
        return JSONResponse({"error": "empty upload"}, status_code=400)

    # NeMo transcribes from a path, so the upload has to land on disk first.
    suffix = Path(file.filename or "audio.wav").suffix or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as handle:
        handle.write(audio)
        temp_path = handle.name

    try:
        results = model.transcribe([temp_path], verbose=False)
    except Exception:
        logger.exception("transcription failed")
        return JSONResponse({"error": "transcription failed"}, status_code=500)
    finally:
        os.unlink(temp_path)

    return JSONResponse({"text": extract_text(results)})


def extract_text(results) -> str:
    """Pull the transcript out of whatever shape NeMo returned.

    The hybrid TDT-CTC model answers with a tuple of two hypothesis lists,
    one per decoder, and the first holds the active decoder's output. Other
    NeMo models answer with a single list, whose items are either strings or
    objects carrying .text. Walk the nesting instead of pinning a shape.
    """
    value = results
    while isinstance(value, (tuple, list)):
        if not value:
            return ""
        value = value[0]
    return value if isinstance(value, str) else getattr(value, "text", "")
