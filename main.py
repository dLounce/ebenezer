# main.py — Ebenezer backend
import os, re, json, uuid, base64, time, threading
import datetime as dt
import requests
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
load_dotenv()
# ---------- config ----------
GLOO_CLIENT_ID     = os.environ["GLOO_CLIENT_ID"]
GLOO_CLIENT_SECRET = os.environ["GLOO_CLIENT_SECRET"]
YVP_APP_KEY        = os.environ["YVP_APP_KEY"]
SHARED_SECRET      = os.environ.get("EBENEZER_SECRET", "dev")

YV        = "https://api.youversion.com/v1"
GLOO_AUTH = "https://platform.ai.gloo.com/oauth2/token"
GLOO_CHAT = "https://platform.ai.gloo.com/ai/v1/chat/completions"
GLOO_MODEL = "gloo-google-gemini-2.5-flash-lite"

YV_HEADERS = {"X-YVP-App-Key": YVP_APP_KEY, "accept": "application/json"}

# entitlement-verified 2026-07-28 — every id below returned 200 on a live probe
BIBLES = {
    "en": 1932,  # FBV   — plain modern English
    "es": 147,   # RVES
    "pt": 3254,  # BLT
    "fr": 62,    # FMAR
    "de": 51,    # DELUT
    "ja": 81,    # JA1955
    "zh": 43,    # CSBS
    "hi": 819,   # HHBD
    "tl": 177,   # TLAB
    "id": 320,   # TSI
    "th": 175,   # KJV(th)
    "ar": 195,   # SAT
}
# ru/ko deliberately excluded: only Church Slavonic entitled for ru, ko returns 403.

# ---------- Gloo auth (cached, auto-refresh) ----------
_tok = {"value": None, "exp": 0}
_tok_lock = threading.Lock()

def gloo_token() -> str:
    with _tok_lock:
        if _tok["value"] and time.time() < _tok["exp"] - 120:
            return _tok["value"]
        auth = base64.b64encode(
            f"{GLOO_CLIENT_ID}:{GLOO_CLIENT_SECRET}".encode()).decode()
        r = requests.post(
            GLOO_AUTH,
            headers={"Content-Type": "application/x-www-form-urlencoded",
                     "Authorization": f"Basic {auth}"},
            data={"grant_type": "client_credentials", "scope": "api/access"},
            timeout=20)
        r.raise_for_status()
        d = r.json()
        _tok["value"] = d["access_token"]
        _tok["exp"] = time.time() + int(d.get("expires_in", 3600))
        return _tok["value"]

# ---------- YouVersion ----------
def _strip(html: str) -> str:
    # YouVersion controls this content (licensed text), so a regex strip is safe here.
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html)).strip()

def get_passage(bible_id: int, usfm_ref: str) -> dict:
    # range syntax must be BOOK.CH.V-V — BOOK.CH.V-BOOK.CH.V returns 404
    r = requests.get(f"{YV}/bibles/{bible_id}/passages/{usfm_ref}",
                     headers=YV_HEADERS, timeout=20)
    r.raise_for_status()
    d = r.json()
    return {"ref": d.get("reference"), "text": _strip(d.get("content", ""))}

# ---------- verse pool ----------
# The model NEVER writes scripture. It selects a reference from this curated pool;
# every word a player reads is served by YouVersion.
POOL = {
 "fear":        ["ISA.41.10","PSA.56.3","JOS.1.9","PSA.27.1","2TI.1.7"],
 "loss":        ["PSA.34.18","MAT.5.4","PSA.147.3","ROM.8.28","PSA.30.5"],
 "perseverance":["GAL.6.9","JAS.1.12","ROM.5.3-5","HEB.12.1","ISA.40.31"],
 "loneliness":  ["DEU.31.6","PSA.139.7-10","MAT.28.20","HEB.13.5","PSA.25.16"],
 "awe":         ["PSA.19.1","PSA.8.3-4","JOB.12.7-9","PSA.104.24","ROM.1.20"],
 "celebration": ["PSA.126.3","ZEP.3.17","PSA.118.24","1TH.5.16-18","PSA.100.1-2"],
 "provision":   ["MAT.6.26","PHP.4.19","PSA.23.1","MAT.6.34","PSA.34.10"],
}
FALLBACK = {"theme": "loneliness", "ref": "DEU.31.6", "why": "fallback"}

SYSTEM = (
 "You choose Scripture for a moment in a children's video game. "
 "Given a game event, pick the theme that matches the player's emotional state, "
 "then choose ONE reference from that theme's list. "
 'Respond ONLY with JSON: {"theme":"...","ref":"...","why":"under 12 words"}. '
 "No markdown, no preamble."
)

def choose_verse(event: str) -> dict:
    try:
        r = requests.post(
            GLOO_CHAT,
            headers={"Authorization": f"Bearer {gloo_token()}",
                     "Content-Type": "application/json"},
            json={"model": GLOO_MODEL, "temperature": 0.4, "max_tokens": 120,
                  "messages": [
                    {"role": "system", "content": SYSTEM},
                    {"role": "user",
                     "content": f"POOL:\n{json.dumps(POOL)}\n\nEVENT: {event}"}]},
            timeout=25)
        r.raise_for_status()
        raw = r.json()["choices"][0]["message"]["content"].strip()
        raw = raw.replace("```json", "").replace("```", "").strip()
        out = json.loads(raw)
        if out.get("ref") not in POOL.get(out.get("theme"), []):
            return FALLBACK          # off-pool -> never reaches a player
        return out
    except Exception:
        return FALLBACK              # a stone always appears; it is never wrong

# ---------- store ----------
# Ephemeral on Render's free tier — fine for the demo. Swap for Postgres if it matters.
STONES: list = []
_passage_cache: dict = {}

# ---------- api ----------
app = FastAPI(title="Ebenezer")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])

class StoneRequest(BaseModel):
    event: str
    locale: str = "en"
    x: float
    y: float
    z: float
    player: str

@app.get("/health")
def health():
    return {"ok": True, "languages": len(BIBLES), "stones": len(STONES)}

@app.post("/stone")
def stone(req: StoneRequest, x_ebenezer_key: str = Header(default="")):
    if x_ebenezer_key != SHARED_SECRET:
        raise HTTPException(401, "bad key")
    pick = choose_verse(req.event)
    loc = req.locale.split("-")[0].lower()
    bible = BIBLES.get(loc, BIBLES["en"])
    key = (pick["ref"], loc)
    if key not in _passage_cache:
        try:
            _passage_cache[key] = get_passage(bible, pick["ref"])
        except Exception:
            _passage_cache[key] = get_passage(BIBLES["en"], pick["ref"])
    p = _passage_cache[key]
    s = {
        "stone_id": str(uuid.uuid4())[:8],
        "pos": {"x": round(req.x, 1), "y": round(req.y, 1), "z": round(req.z, 1)},
        "theme": pick["theme"], "usfm": pick["ref"],
        "reference": p["ref"], "text": p["text"],
        "locale": loc, "bible_id": bible, "left_by": req.player,
        "at": dt.datetime.utcnow().isoformat() + "Z",
    }
    STONES.append(s)
    return s

@app.get("/stones")
def stones(limit: int = 500):
    return {"count": len(STONES), "stones": STONES[-limit:]}

@app.get("/selftest")
def selftest():
    """Verifies every pooled reference resolves. Run once after deploy."""
    bad = []
    for theme, refs in POOL.items():
        for ref in refs:
            try:
                get_passage(BIBLES["en"], ref)
            except Exception as e:
                bad.append({"theme": theme, "ref": ref, "err": str(e)[:80]})
    return {"total": sum(len(v) for v in POOL.values()), "broken": bad}