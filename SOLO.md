# Ebenezer — solo checklist

Everything from here to submission. Self-contained: no other file needed, no Claude
running. Keep this open in Notepad, not a browser.

**The build is finished and saved.** Steps 1–5 of the runbook are done and verified.
What's left is one toggle, then filming.

---

## A. One toggle  (2 min)

1. Open **Roblox Studio** → open **Ebenezer** from My Experiences.
2. `File` → `Experience Settings` → `Security` in the left sidebar.
3. Confirm **Allow HTTP Requests** is ON. Turn ON **Enable Studio Access to API
   Services**.
4. **Save** in that dialog, then **Ctrl+S** in Studio.

Optional. Skip it if it fights you — persistence already works through the backend.

---

## B. Wake the backend  (1 min)

Open in a browser:

    https://ebenezer-2c4o.onrender.com/health

Wait for JSON. First load can take ~50 seconds. Then **close the browser
completely** — it will eat the RAM you need for OBS.

---

## C. Set up Studio for capture  (3 min)

In Studio close these panels (click the X on each):

- Terrain Editor
- Toolbox / Creator Store
- Insert Basic Objects
- Output — but keep it until after your first Play, so you can confirm it's working

Drag the Explorer panel narrow. You want the 3D view as large as possible.

---

## D. OBS  (3 min)

- Settings → Output → Encoder: **NVENC H.264** (the 3050 does the encoding, so RAM
  stays free)
- Settings → Video → 1920×1080, 30 fps
- Source: **Window Capture** → Roblox Studio. Not Display Capture.

---

## E. Shoot  (~30 min)

**Studio crashes about ten minutes into a session on 8 GB.** It goes to a blank
window and needs a full restart. So:

> One shot per Play session. Play → shot → Stop. Restart Studio every 3–4 takes.

Press Play. Wait ~20 seconds for the Output to show:

    [Ebenezer] world built -- pre-dawn, fog to 250, chasm at (74, 26)
    [Ebenezer] 8 stones already standing in this world

Then scroll the mouse wheel back for third person, and shoot these six.

| # | shot | how | secs |
|---|---|---|---|
| 1 | **Empty world.** Slow walk through fog. Nothing happens. | just walk | 8 |
| 2 | **The fall.** Walk east into the black chasm. You die. | chasm is at (74, 26) | 5 |
| 3 | **The stone rises.** Cut to the chasm edge, slab comes up with dust. | fires automatically on death; the rise takes 2.1s, let it finish | 6 |
| 4 | **Read it.** Walk close. Text only renders inside 85 studs. | hold the shot, let it be readable | 8 |
| 5 | **A stranger's stone.** Walk into fog, find a different one. | landmarks at (-118,146), (232,-74), (-286,-198), (96,318) | 12 |
| 6 | **Twelve languages.** A ring of stones, each a different tongue. | see below | 15 |

End card, 4 seconds, no voiceover:

> Every word is Scripture from the YouVersion Platform.
> Gloo AI only chose which verse. It never wrote one.

### Command bar snippets

Command bar is the one-line box at the bottom. Paste, then **Ctrl+Enter** (plain
Enter only adds a newline).

**Die on demand** — works in the default client context:

    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(74, 6, 26)

**The twelve-language ring** — first switch context: `Test` menu → **Toggle Client
View**. The viewport border turns green. Then:

    game.ServerStorage.EbenezerHook:Invoke("tour")

Takes 20–30 seconds to place all twelve. Wait for it before you frame the shot.

**Clear stones between takes:**

    game.ServerStorage.EbenezerHook:Invoke("clear")

### Gotchas

- **25-second cooldown per player.** Two deaths inside 25s give you one stone. Use
  the teleport line, which bypasses it.
- If a stone comes up blank, the backend went to sleep. Reopen `/health`, wait,
  retry.
- `_G.Ebenezer.tour()` does **not** work. Use the `EbenezerHook` line above.

---

## F. Cut  (~20 min)

Clipchamp is already installed. Six clips, hard cuts, no transitions. No music with
lyrics — anything under the verse should be quiet or silent. Silence is fine and
often better here.

Target 90 seconds.

---

## G. Submit

| what | where |
|---|---|
| Repo | `github.com/dLounce/ebenezer` |
| Writeup | `WRITEUP.md` in the repo |
| Live map | `https://ebenezer-2c4o.onrender.com/map` |
| Proof all 35 verses resolve | `https://ebenezer-2c4o.onrender.com/selftest` |
| Video | your upload link |

**Public place link:** check `create.roblox.com/dashboard/creations` → Ebenezer →
set Playability to **Public** if the new-creator hold has lifted. If it hasn't, the
public repo satisfies the requirement on its own. Don't lose time here.

---

## If something is broken

**Scripts missing from ServerScriptService** — open `roblox/paste_ALL.txt`, Ctrl+A,
Ctrl+C, paste into the Studio command bar, Ctrl+Enter, click **Continue** on the
"Dangerous Command" prompt, then Ctrl+S. That reinstalls all three from scratch.

**HTTP 401 in Output** — the secret in `EbenezerConfig` doesn't match Render. The
correct value is in `.env`; put it in both places.

**Studio blank window on launch** — it crashed. Kill it in Task Manager and reopen.
If it keeps happening, reinstall from `create.roblox.com`.

---

## What's already true

- Backend deployed, 12 languages, 35-verse pool, 8 landmark stones, `/map` live.
- Place saved to Roblox with all three scripts and the rotated secret.
- Verified working: death → `Psalms 34:18 [loss/en]`, loneliness → `Joshua 1:9
  [fear/en]`. Different themes for different moments.
- `README.md`, `WRITEUP.md`, `SHOOT.md`, `INSTALL.md` all pushed to GitHub.

The only thing standing between you and a submission is the video.
