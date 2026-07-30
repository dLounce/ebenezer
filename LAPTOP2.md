# Recording on the 16 GB laptop

**You need nothing local on that machine.** No Python, no uvicorn, no `.env`, no
git, no admin rights.

The backend runs on Render. The Roblox place lives on Roblox's servers with all
three scripts already saved into it. The second laptop only has to open the place
and record the screen.

Stop using the 8 GB machine. It's rebooting on its own now, and there is nothing
left on it you need.

---

## 1 · Install Roblox Studio

Go to **create.roblox.com** → sign in as **TinyTitanss** → click **Create**.

Studio installs into `AppData\Local`, per-user. **It does not need admin rights.**
This is the one install that will work without permission.

---

## 2 · Open the place

Studio start screen → the Ebenezer experience under My Experiences.

Everything is already inside it: `EbenezerConfig` (with the correct secret),
`EbenezerWorld`, `EbenezerServer`. Nothing to paste, nothing to configure.

Optional but worth ten seconds: `File` → `Experience Settings` → `Security` →
turn on **Enable Studio Access to API Services**. Skip if it argues.

---

## 3 · Get a recorder without installing anything

**Xbox Game Bar is built into Windows and needs no install and no admin.**

- Press **Win + G**
- Capture widget → the round record button, or just **Win + Alt + R** to start/stop
- Recordings land in `Videos\Captures`

It records the focused window at 1080p and uses the GPU encoder. Good enough — this
is a 90-second video, not a film.

If OBS happens to already be installed there, use it instead: NVENC, 1080p30,
Window Capture on Roblox Studio.

---

## 4 · Wake the backend

Open in a browser, wait for JSON, then close the tab:

    https://ebenezer-2c4o.onrender.com/health

You want `{"ok":true,"languages":12,"stones":0,"seeded":8}`. First load can take
~50 seconds because free hosting sleeps.

Do this **before** every recording session. A sleeping backend means no stone.

---

## 5 · Get the film script

On that laptop, open this in a browser:

    https://raw.githubusercontent.com/dLounce/ebenezer/main/roblox/EbenezerFilm.lua

**Ctrl+A, Ctrl+C.** That's your camera move.

---

## 6 · Record

1. In Studio press **Play**. Wait ~20 seconds until the Output shows
   `8 stones already standing in this world`.
2. Click the **command bar** (one-line box at the bottom), **Ctrl+A**, **Ctrl+V**.
3. Press **Ctrl+Enter**. Plain Enter only adds a newline.
4. You get an **8-second countdown** in the Output.
5. During those 8 seconds: press **F11** for fullscreen, then **Win+Alt+R** to
   start recording. Then take your hands off the keyboard.
6. About 50 seconds of camera work runs by itself. When the Output says
   `[Film] done`, press **Win+Alt+R** again.

### What it shoots

| | |
|---|---|
| 0:00 | Fog, half light, an empty world. Nothing happening. |
| 0:10 | Drift toward a black seam in the ground. |
| 0:15 | The player dies in it — a real death, the real handler fires. |
| 0:21 | Hold while Gloo picks the passage and YouVersion returns the words. A stone rises. |
| 0:29 | Push in until the verse is readable. |
| 0:40 | Cut somewhere else entirely. A stone a stranger left. |
| 0:54 | Pull up and out over the world. |

Nothing in it is staged. The death is real, the API calls are real, the camera is
just pointed at it.

---

## 7 · The end card

Add four seconds of black at the end in Clipchamp (built into Windows, no install):

> Every word is Scripture from the YouVersion Platform.
> Gloo AI only chose which verse. It never wrote one.

No music with lyrics. Silence under the verse is better than a soundtrack.

---

## 8 · Submit

| what | where |
|---|---|
| Repo | `github.com/dLounce/ebenezer` |
| Writeup | `WRITEUP.md` in the repo |
| Live map | `https://ebenezer-2c4o.onrender.com/map` |
| All 35 verses resolve | `https://ebenezer-2c4o.onrender.com/selftest` |

---

## If the stone doesn't appear

The Output will say `[Film] no stone appeared`. The backend went to sleep. Reopen
`/health`, wait for the JSON, Stop, Play, and run the script again.

## If you want a second take with different framing

Run it again — the camera move is identical every time, but Gloo may choose a
different passage for the same death, so the verse can differ between takes. Take
whichever reads better.
