"""Mock whisper.cpp server for testing."""

from typing import Annotated

from fastapi import FastAPI, File, UploadFile

app = FastAPI(title="Whisper Mock Server")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


@app.post("/inference")
async def mock_inference(file: Annotated[UploadFile, File(...)]):
    """Mock inference endpoint that returns a fixed response."""
    # Read file to simulate processing
    await file.read()
    return {"text": "これはテスト用の認識結果です"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
