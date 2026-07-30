# Ebenezer

**Scripture becomes geography.**

> Then Samuel took a stone and set it up... and called its name Ebenezer, saying,
> "Till now the Lord has helped us." — 1 Samuel 7:12

Ebenezer is a Roblox world where meaningful moments leave something behind. Die
repeatedly in the same place, survive your first night with no one else online,
or come back after a long stretch of failing at something, and a stone rises out
of the ground at those exact coordinates with a verse cut into it — chosen for
the moment you just had, and shown in your own language.

The stones stay, and they are public. Walk far enough and you will find one a
stranger left, standing where they had a hard night. You will not know who. You
will only know that someone was here, and that this is what they needed to read.

That is the whole product. Not a Bible app inside a game — Scripture as terrain,
discovered the same way Roblox and Minecraft have already trained a hundred
million people to read found text in a world.

---

## Why Roblox

Roblox has ~80M daily users and skews to exactly the age YouVersion has the
hardest time reaching. It is also free to enter: a judge clicks a link and walks
into the world. No account purchase, no server to stand up.

Genre is Adventure, not Education, on purpose. The thesis is that Scripture
belongs where people already are, and filing this under Education would
contradict that in one click.

---

## How the two APIs split the work

This split is the architectural decision the whole project rests on.

| | responsibility | never does |
|---|---|---|
| **Gloo AI** | Reads the emotional shape of a gameplay event and **selects** one passage reference from a curated pool of 35 | Never writes text |
| **YouVersion Platform** | Supplies **every actual word**, from a licensed translation, in the player's own language | Never decides what is relevant |

```
gameplay moment
   -> Gloo AI (gemini-2.5-flash-lite)  theme + reference, JSON only
   -> validated against the pool       off-pool answers are discarded
   -> YouVersion /passages             the words, localized
   -> a stone rises at those coordinates
```

**No generated prose ever reaches a player.** The model's entire output surface
is one of 35 references and a theme label. If it returns anything outside the
pool, the response is thrown away and a fallback reference is used instead. A
player cannot be shown a hallucinated verse, a misattributed verse, or a verse
that does not exist, because the model is never the source of text.

That is also the answer to the question a Roblox moderator asks after you
disclose generative AI, and it is why the disclosure answers below are what they
are.

### Roblox generative-AI disclosure

- **Does your experience allow users to interact with Generative AI? — Yes.**
  Players never type at a model, but their gameplay state is sent to Gloo and the
  model's response determines what they see. That is an interaction that triggers
  a response, so it is disclosed.
- **What type of interactions? — Limited.** Every Gloo call is stateless: it
  contains the current event and the fixed pool, and nothing from any prior
  session. No user context is ever loaded back into the model. There is no bot,
  character, or chat surface. And nothing the model writes is ever stored,
  because the model never writes anything — what persists on a stone is licensed
  Scripture plus a theme label.

### Language coverage

Twelve languages, each one verified against a live key rather than taken from the
catalogue: **en** (FBV), **es**, **pt**, **fr**, **de**, **ja**, **zh**, **hi**,
**tl**, **id**, **th**, **ar**.

`Player.LocaleId` routes each player automatically — nobody picks a language, the
stone simply *is* in their tongue. YouVersion also returns the reference already
localized, so a Japanese player reads 詩篇 139:7-10, not "Psalms".

Two deliberate exclusions, both discovered by probing rather than assuming:

- **Russian** — the only entitled Russian text is Church Slavonic, a liturgical
  language that reads like ritual text from another century to a Russian
  twelve-year-old. Better to omit it than to hand a kid the wrong register.
- **Korean** — appears in the catalogue, returns 403 on fetch. `all_available=true`
  lists what exists, not what a key can read.

English is **FBV** (Free Bible Version, id 1932), chosen over KJV/ASV because the
audience is nine to sixteen. NIrV would have been the ideal reading level but is
Biblica-licensed and not entitled.

---

## Architecture

```
Roblox place (Lua)
  EbenezerWorld.lua    procedural world: pre-dawn light, fog, chasm, scatter
  EbenezerServer.lua   moment detection, HTTP, stone construction, persistence
  EbenezerConfig.lua   server-only; the shared secret is never replicated

      | HttpService, X-Ebenezer-Key
      v
FastAPI backend (main.py)
  POST /stone     moment -> Gloo selection -> YouVersion text -> stone record
  GET  /stones    every stone standing; the game calls this on server start
  GET  /map       live web map, so judges can see the world without entering it
  GET  /selftest  verifies all 35 pooled references resolve
  GET  /health    liveness + language count
```

### Persistence

Roblox `DataStore` is the long-lived record. The backend keeps a mirror so a
freshly booted server can repopulate a world it has never seen, and so the web
map can render without anyone being in the game. Both are wrapped so that if
either is unavailable the game still works — a stone always appears.

### Moment detection

| moment | trigger |
|---|---|
| first death | `Humanoid.Died`, death #1 — alone, carrying nothing |
| repeated death | deaths #2 and up, escalating description |
| alone in the dark | only player in the server for 90s |
| came back from it | 7 minutes without dying after having died |

Death is the primary trigger because deaths never fail to fire. The world
includes one chasm near spawn for exactly this reason.

### Seeded landmark stones

Eight stones exist at fixed coordinates so a first-time visitor never walks into
an empty world. Their text is fetched **live from YouVersion on first request** —
nothing is hardcoded prose — and every one is flagged `"seeded": true` in the API
and labelled as a landmark on the map. They are level design, not fabricated
telemetry.

---

## Run it

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

`.env` in the same folder:

```
GLOO_CLIENT_ID=...
GLOO_CLIENT_SECRET=...
YVP_APP_KEY=...
EBENEZER_SECRET=any_random_string
```

Then `GET /selftest` — it should return `{"total":35,"broken":[]}`.

Deploy anywhere that gives you HTTPS (Roblox `HttpService` cannot reach
localhost). Then in Roblox Studio:

1. `ServerScriptService` needs three children: `EbenezerConfig` (ModuleScript),
   `EbenezerWorld` (Script), `EbenezerServer` (Script) — sources in `roblox/`.
2. Set `BASE` and `SECRET` in `EbenezerConfig`.
3. **File → Game/Experience Settings → Security**: enable *Allow HTTP Requests*
   and *Enable Studio Access to API Services*.
4. Press Play. Walk into the chasm.

### Notes for anyone reproducing this

Four things cost real time and are worth writing down:

- The YouVersion auth header is `X-YVP-App-Key`, not a bearer token.
- `/v1/bibles` returns 422 unless you pass `language_ranges[]` with the literal
  brackets.
- Passage range syntax is `BOOK.CH.V-V`. The full form `BOOK.CH.V-BOOK.CH.V`
  returns 404. `+` joins non-contiguous verses.
- `all_available=true` shows the whole catalogue, not what your key is entitled
  to. Probe with a real fetch before you design around a translation.

---

## Repo

```
main.py                     backend
requirements.txt
web/map.html                live world map (served at /map)
roblox/EbenezerConfig.lua   server-only config
roblox/EbenezerWorld.lua    procedural world
roblox/EbenezerServer.lua   the product
WRITEUP.md                  submission writeup
```

Credentials live in `.env`, which is gitignored. Never committed.
