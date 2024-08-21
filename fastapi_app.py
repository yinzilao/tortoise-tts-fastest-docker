from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import Response
from pydantic import BaseModel
from tortoise.api import TextToSpeech, MODELS_DIR
from tortoise.utils.audio import load_voices
from tortoise.utils.diffusion import SAMPLERS
import torch
import io
import os
from typing import Optional

app = FastAPI()

# Initialize the TTS model once at startup
tts = TextToSpeech()

# Define the request model for the TTS endpoint
class TTSRequest(BaseModel):
    text: str
    voice: str = "random"
    preset: str = "fast"
    seed: Optional[int] = None
    num_autoregressive_samples: Optional[int] = None
    temperature: Optional[float] = None
    length_penalty: Optional[float] = None
    repetition_penalty: Optional[float] = None
    top_p: Optional[float] = None
    max_mel_tokens: Optional[int] = None
    cvvp_amount: Optional[float] = None
    diffusion_iterations: Optional[int] = None
    cond_free: Optional[bool] = None
    cond_free_k: Optional[float] = None
    diffusion_temperature: Optional[float] = None
    sampler: Optional[str] = None

@app.post("/tts")
async def text_to_speech(request: TTSRequest, background_tasks: BackgroundTasks):
    try:
        # Load voice samples if a specific voice is requested
        voice_samples, conditioning_latents = None, None
        if request.voice != "random":
            voice_samples, conditioning_latents = load_voices([request.voice])

        # Prepare generation settings, adding optional parameters if provided
        gen_settings = {
            "preset": request.preset,
            "use_deterministic_seed": request.seed,
        }

        optional_params = [
            "num_autoregressive_samples", "temperature", "length_penalty",
            "repetition_penalty", "top_p", "max_mel_tokens", "cvvp_amount",
            "diffusion_iterations", "cond_free", "cond_free_k",
            "diffusion_temperature", "sampler"
        ]

        for param in optional_params:
            value = getattr(request, param)
            if value is not None:
                gen_settings[param] = value

        # Generate speech using the TTS model
        gen = tts.tts_with_preset(
            request.text,
            voice_samples=voice_samples,
            conditioning_latents=conditioning_latents,
            **gen_settings
        )

        # Convert the generated speech to a WAV file format
        audio_buffer = io.BytesIO()
        torch.save(gen, audio_buffer)

        # Schedule background task to clean up CUDA memory
        background_tasks.add_task(torch.cuda.empty_cache)

        return Response(content=audio_buffer.getvalue(), media_type="audio/wav")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/voices")
async def list_voices():
    try:
        voices = os.listdir(os.path.join(MODELS_DIR, "voices"))
        return {"voices": voices}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing voices: {e}")

@app.get("/presets")
async def list_presets():
    try:
        presets = [
            "single_sample", "ultra_fast", "very_fast",
            "ultra_fast_old", "fast", "standard", "high_quality"
        ]
        return {"presets": presets}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing presets: {e}")

@app.get("/samplers")
async def list_samplers():
    try:
        return {"samplers": SAMPLERS}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing samplers: {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
