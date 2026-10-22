"""HTTP wrapper around NeMo's parakeet ASR model.

The endpoints mirror whisper-server so that both the application and
tools/asr_benchmark.py can talk to either backend without changes.
"""

import asyncio
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
DECODERS = ("tdt", "ctc")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("parakeet")

state: dict = {}


class UnknownResultShape(Exception):
    """NeMo returned something this wrapper cannot read a transcript out of."""


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Fail at startup rather than silently transcribing with the wrong decoder.
    if DECODER not in DECODERS:
        raise ValueError(f"PARAKEET_DECODER must be one of {DECODERS}, got {DECODER!r}")

    # Load before the server starts listening, the way whisper-server does.
    # A request that arrives first must not pay for the model load, or the
    # benchmark's first_inference_s would measure something else.
    logger.info("loading model %s (decoder=%s)", MODEL_NAME, DECODER)
    model = nemo_asr.models.ASRModel.from_pretrained(model_name=MODEL_NAME)
    if DECODER == "ctc":
        model.change_decoding_strategy(decoder_type="ctc")
    model.eval()
    state["model"] = model
    # One model on one GPU: concurrent transcribe() calls would race over the
    # same weights, so requests queue here instead.
    state["lock"] = asyncio.Lock()
    logger.info("model ready")
    yield
    state.clear()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health() -> dict:
    # Uvicorn only starts accepting connections once lifespan has yielded, so
    # anything that reaches this point is talking to a loaded model.
    return {"status": "ok"}


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
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as handle:
            temp_path = handle.name
            handle.write(audio)
        # transcribe() is synchronous and takes hundreds of milliseconds, which
        # would block the event loop and stall the health check along with
        # every other request. Hand it to a thread, one caller at a time.
        async with state["lock"]:
            results = await asyncio.to_thread(model.transcribe, [temp_path], verbose=False)
        text = extract_text(results)
    except UnknownResultShape:
        logger.exception("unreadable transcription result")
        return JSONResponse({"error": "unreadable transcription result"}, status_code=500)
    except Exception:
        logger.exception("transcription failed")
        return JSONResponse({"error": "transcription failed"}, status_code=500)
    finally:
        if temp_path is not None:
            try:
                Path(temp_path).unlink(missing_ok=True)
            except OSError:
                # Losing a temp file is not worth masking the real outcome.
                logger.warning("could not remove %s", temp_path)

    return JSONResponse({"text": text})


def extract_text(results) -> str:
    """Pull the transcript out of what NeMo returned.

    NeMo's transcribe() contract (GenericTranscriptionType) allows a list, a
    list of lists, a tuple, or a dict of lists. The hybrid TDT-CTC model
    answers with a (best_hypotheses, all_hypotheses) tuple for the decoder in
    use, so the first element is the one to read -- the tuple is not one entry
    per decoder. Items are either strings or objects carrying .text.

    Raises:
        UnknownResultShape: when the nesting bottoms out on something with no
            readable transcript. Returning "" there would hand the caller a
            successful-looking empty result.
    """
    value = results
    while isinstance(value, (tuple, list)):
        if not value:
            return ""
        value = value[0]

    if isinstance(value, str):
        return value

    text = getattr(value, "text", None)
    if isinstance(text, str):
        return text

    raise UnknownResultShape(f"no transcript in {type(value).__name__}: {value!r:.200}")
