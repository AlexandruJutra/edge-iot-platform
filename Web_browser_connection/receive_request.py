import subprocess
from fastapi import FastAPI, HTTPException, Request

app = FastAPI()

# Calea absolută către binarul claude instalat pe sistem
CLAUDE_BIN = "/home/alex/.local/bin/claude"


@app.post("/mcp")
async def handle_mcp_post(request: Request):
  try:
    body_data = await request.json()
  except Exception as e:
    raise HTTPException(
        status_code=400, detail=f"Invalid JSON payload: {str(e)}"
    )

  # Extrage mesajul din payload (suportă atât 'message' cât și 'prompt')
  user_message = body_data.get("message", body_data.get("prompt", ""))

  if not user_message:
    raise HTTPException(
        status_code=400,
        detail="Lipsește câmpul 'message' sau 'prompt' din corpul cererii.",
    )

  try:
    # Folosește calea absolută pentru a evita eroarea de tip PATH
    result = subprocess.run(
        [CLAUDE_BIN, "-p", "--model", "claude-haiku-5-5", user_message],
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )

    return {"status": "success", "claude_response": result.stdout.strip()}

  except subprocess.CalledProcessError as e:
    error_msg = e.stderr.strip() if e.stderr else str(e)
    raise HTTPException(
        status_code=500, detail=f"Eroare de execuție Claude: {error_msg}"
    )
  except subprocess.TimeoutExpired:
    raise HTTPException(
        status_code=504, detail="Cererea către Claude a expirat (Timeout)."
    )