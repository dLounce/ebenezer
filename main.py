# main.py — Ebenezer backend
#
# Ebenezer turns real moments in a Roblox world into Scripture left standing in
# the ground where they happened.
#
# Two APIs do the work, and the split between them is deliberate:
#   Gloo AI       — reads the emotional shape of a gameplay event and SELECTS a
#                   passage reference from a curated pool. It never writes text.
#   YouVersion    — supplies every actual word, in the player's own language,
#                   from a licensed translation.
#
# Net effect: no generated prose ever reaches a player. See README.md.

import os, re, json, uuid, base64, time, threading, pathlib
import datetime as dt
import requests
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# ---------- config ----------
GLOO_CLIENT_ID     = os.environ["GLOO_CLIENT_ID"]
GLOO_CLIENT_SECRET = os.environ["GLOO_CLIENT_SECRET"]
YVP_APP_KEY        = os.environ["YVP_APP_KEY"]
SHARED_SECRET      = os.environ.get("EBENEZER_SECRET", "dev")

YV         = "https://api.youversion.com/v1"
GLOO_AUTH  = "https://platform.ai.gloo.com/oauth2/token"
GLOO_CHAT  = "https://platform.ai.gloo.com/ai/v1/chat/completions"
GLOO_MODEL = "gloo-google-gemini-2.5-flash-lite"

YV_HEADERS = {"X-YVP-App-Key": YVP_APP_KEY, "accept": "application/json"}

HERE       = pathlib.Path(__file__).parent
STORE_PATH = HERE / "stones.json"

# Entitlement-verified against a live key on 2026-07-28: every id below returned
# HTTP 200 for a real passage fetch. ru and ko are deliberately absent — see README.
BIBLES = {
    "en": 1932,  # FBV    — plain modern English, chosen for young readers
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
    """YouVersion returns passage content as HTML. It is licensed text from a
    trusted origin, so a tag strip is sufficient here."""
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html)).strip()


def get_passage(bible_id: int, usfm_ref: str) -> dict:
    # Range syntax must be BOOK.CH.V-V. The full form BOOK.CH.V-BOOK.CH.V 404s.
    r = requests.get(f"{YV}/bibles/{bible_id}/passages/{usfm_ref}",
                     headers=YV_HEADERS, timeout=20)
    r.raise_for_status()
    d = r.json()
    return {"ref": d.get("reference"), "text": _strip(d.get("content", ""))}


# ---------- verse pool ----------
# The model NEVER writes Scripture. It picks one reference out of this pool and
# YouVersion serves every word. An off-pool answer is discarded, not shown.
POOL = {
    "fear":         ["ISA.41.10", "PSA.56.3", "JOS.1.9", "PSA.27.1", "2TI.1.7"],
    "loss":         ["PSA.34.18", "MAT.5.4", "PSA.147.3", "ROM.8.28", "PSA.30.5"],
    "perseverance": ["GAL.6.9", "JAS.1.12", "ROM.5.3-5", "HEB.12.1", "ISA.40.31"],
    "loneliness":   ["DEU.31.6", "PSA.139.7-10", "MAT.28.20", "HEB.13.5", "PSA.25.16"],
    "awe":          ["PSA.19.1", "PSA.8.3-4", "JOB.12.7-9", "PSA.104.24", "ROM.1.20"],
    "celebration":  ["PSA.126.3", "ZEP.3.17", "PSA.118.24", "1TH.5.16-18", "PSA.100.1-2"],
    "provision":    ["MAT.6.26", "PHP.4.19", "PSA.23.1", "MAT.6.34", "PSA.34.10"],
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


# ---------- passage cache ----------
_passage_cache: dict = {}
_cache_lock = threading.Lock()


def passage_for(ref: str, locale: str) -> dict:
    loc = (locale or "en").split("-")[0].lower()
    key = (ref, loc)
    with _cache_lock:
        hit = _passage_cache.get(key)
    if hit:
        return hit
    try:
        p = get_passage(BIBLES.get(loc, BIBLES["en"]), ref)
    except Exception:
        p = get_passage(BIBLES["en"], ref)          # locale failed -> English
        loc = "en"
    with _cache_lock:
        _passage_cache[key] = p
    return p


# ---------- store ----------
# Roblox DataStore is the authoritative long-term record (see EbenezerServer.lua).
# This list is a mirror so the web map can render without entering the game, and
# so a fresh server can repopulate a world it has never seen.
STONES: list = []
_stones_lock = threading.Lock()


def _load_disk():
    try:
        if STORE_PATH.exists():
            with _stones_lock:
                STONES.extend(json.loads(STORE_PATH.read_text("utf-8")))
    except Exception:
        pass


def _save_disk():
    try:
        with _stones_lock:
            snapshot = list(STONES)
        STORE_PATH.write_text(json.dumps(snapshot, ensure_ascii=False), "utf-8")
    except Exception:
        pass      # ephemeral filesystem on free hosting; DataStore is the real record


_load_disk()

# ---------- seeded world ----------
# Fixed landmarks so the world is never empty for a first-time visitor. Each one
# is a real Gloo theme paired with a real pooled reference, and the text is
# fetched live from YouVersion on first request — nothing here is hardcoded prose.
# Flagged `seeded: true` in the API so nothing is passed off as emergent.
SEED_SPECS = [
    (-118.0, 146.0, "loneliness",   "PSA.139.7-10", "en"),
    (232.0, -74.0,  "fear",         "ISA.41.10",    "pt"),
    (-286.0, -198.0, "perseverance", "GAL.6.9",     "es"),
    (96.0,  318.0,  "loss",         "PSA.34.18",    "en"),
    (348.0, 122.0,  "awe",          "PSA.19.1",     "ja"),
    (-204.0, 62.0,  "provision",    "MAT.6.26",     "hi"),
    (24.0,  -336.0, "celebration",  "PSA.126.3",    "fr"),
    (-72.0, -128.0, "fear",         "PSA.56.3",     "de"),
]
_seeds: list = []
_seed_lock = threading.Lock()


def seeds() -> list:
    with _seed_lock:
        if _seeds:
            return _seeds
        for i, (x, z, theme, ref, loc) in enumerate(SEED_SPECS):
            try:
                p = passage_for(ref, loc)
            except Exception:
                continue
            _seeds.append({
                "stone_id": f"seed{i:02d}",
                "pos": {"x": x, "y": 0.0, "z": z},
                "theme": theme, "usfm": ref,
                "reference": p["ref"], "text": p["text"],
                "locale": loc, "bible_id": BIBLES.get(loc, BIBLES["en"]),
                "left_by": "unknown", "seeded": True,
                "at": "2026-07-28T00:00:00Z",
            })
        return _seeds


# ---------- api ----------
app = FastAPI(title="Ebenezer",
              description="Scripture becomes geography. YouVersion + Gloo AI.")
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
    return {"ok": True, "languages": len(BIBLES),
            "stones": len(STONES), "seeded": len(SEED_SPECS)}


@app.post("/stone")
def stone(req: StoneRequest, x_ebenezer_key: str = Header(default="")):
    """A moment happened. Choose Scripture for it and return a stone."""
    if x_ebenezer_key != SHARED_SECRET:
        raise HTTPException(401, "bad key")
    pick = choose_verse(req.event)
    loc = (req.locale or "en").split("-")[0].lower()
    if loc not in BIBLES:
        loc = "en"
    p = passage_for(pick["ref"], loc)
    s = {
        "stone_id": str(uuid.uuid4())[:8],
        "pos": {"x": round(req.x, 1), "y": round(req.y, 1), "z": round(req.z, 1)},
        "theme": pick["theme"], "usfm": pick["ref"], "why": pick.get("why"),
        "reference": p["ref"], "text": p["text"],
        "locale": loc, "bible_id": BIBLES.get(loc, BIBLES["en"]),
        "left_by": req.player, "event": req.event, "seeded": False,
        "at": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    with _stones_lock:
        STONES.append(s)
    _save_disk()
    return s


@app.get("/stones")
def stones(limit: int = 500, include_seeds: bool = True):
    """Every stone standing in the world. The game calls this on server start;
    the web map calls it to draw."""
    with _stones_lock:
        live = list(STONES[-limit:])
    out = (seeds() if include_seeds else []) + live
    return {"count": len(out), "live": len(live), "stones": out}


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


@app.get("/map", response_class=HTMLResponse)
def world_map():
    """Live map of every stone ever left. Judges can see the world filling up
    without installing anything."""
    f = HERE / "web" / "map.html"
    if not f.exists():
        raise HTTPException(404, "map.html missing")
    return HTMLResponse(f.read_text("utf-8"))


@app.get("/", response_class=HTMLResponse)
def root():
    return HTMLResponse(
        '<meta http-equiv="refresh" content="0; url=/map">'
        '<p style="font:14px system-ui">Ebenezer &rarr; <a href="/map">world map</a> '
        '&middot; <a href="/docs">API</a></p>')
