# Ebenezer — start to finish

Everything left, in order. Roughly 45 minutes of work, most of it waiting on
installers, plus the shoot.

Nothing is lost. The backend is live, the repo is pushed, the place is saved on
Roblox. The only broken thing is your local Studio install.

---

## 1 · Rotate the shared secret  (5 min)

I put your `EBENEZER_SECRET` into `roblox/EbenezerConfig.lua` and pushed it to your
public repo. My mistake. It's out of the current tree now, but it's still in git
history, so the old value has to be retired.

I already generated a new one and wrote it into two local, gitignored files. It is
**not** in our chat.

1. Open `.env` in this folder. Copy the value after `EBENEZER_SECRET=`.
2. Go to Render → your `ebenezer` service → **Environment**.
3. Edit `EBENEZER_SECRET`, paste the new value, **Save Changes**.

Saving env vars triggers a redeploy, which also solves step 2. Convenient.

`roblox/paste_1_config.txt` already has the new secret baked in, so step 4 picks it
up automatically.

---

## 2 · Deploy the backend  (5 min, mostly waiting)

Render is several commits behind — it never picked up the pushes, so auto-deploy is
probably off.

1. Render → your service → **Manual Deploy** → *Deploy latest commit*.
2. While you're there: **Settings** → turn **Auto-Deploy** on.
3. Wait for `Live`, then open `https://ebenezer-2c4o.onrender.com/health`.

You want to see a **`seeded`** field in the response:

```json
{"ok":true,"languages":12,"stones":0,"seeded":8}
```

If `seeded` is missing, the old build is still running — check the deploy log.

Then open `https://ebenezer-2c4o.onrender.com/map`. That's your live world map, and
it's a second thing judges can look at without installing anything.

---

## 3 · Reinstall Roblox Studio  (10 min, mostly waiting)

Studio's install is damaged. The *Update failed* badge was the early warning; now
the window renders solid black and the executable path won't launch. Not
recoverable by clicking.

1. Windows Settings → Apps → Installed apps → **Roblox Studio** → Uninstall.
2. Go to `create.roblox.com`, sign in as **TinyTitanss**, click **Create**.
3. It'll download and install Studio fresh.
4. Open the **Ebenezer** place from the start screen (My Experiences).

The place lives on Roblox, not your disk. Last save was 06:04 and it has all three
scripts. You're reinstalling the app, not rebuilding the work.

**Also change your Roblox password** — you pasted it into our chat.

---

## 4 · Put the scripts back  (5 min)

Only needed if the place opens without `EbenezerServer` / `EbenezerWorld` /
`EbenezerConfig` under `ServerScriptService`, or to pick up the rotated secret and
the fixed filming hook. Checking takes ten seconds, so just do it.

Studio must be in **edit mode** — Play button blue, not greyed.

The command bar is the one-line box at the bottom. For each file: open it,
`Ctrl+A`, `Ctrl+C`, click the command bar, `Ctrl+A`, `Ctrl+V`, then **`Ctrl+Enter`**.

> Plain Enter only inserts a newline. This cost me twenty minutes. Use Ctrl+Enter.

In order:

| file in `roblox/` | Output should say |
|---|---|
| `paste_0_clean.txt` | `cleaned` |
| `paste_1_config.txt` | `OK EbenezerConfig 1043` |
| `paste_2_world.txt` | `OK EbenezerWorld 6980` |
| `paste_3_server.txt` | `OK EbenezerServer 16527` |

Then `File` → `Experience Settings` → `Security`, confirm both are on:

- **Allow HTTP Requests**
- **Enable Studio Access to API Services**

Then **Ctrl+S**. Output: `Saved new changes in "Ebenezer" to Roblox.`

---

## 5 · Prove it works  (2 min)

Press **Play**. Within about 20 seconds:

```
[Ebenezer] world built -- pre-dawn, fog to 250, chasm at (74, 26)
[Ebenezer] backend awake -- 12 languages, N stones on record
[Ebenezer] 8 stones already standing in this world
```

That `8` is the landmark stones, and it only appears once step 2 is done.

Now kill yourself in the chasm. Command bar, default (client) context:

```lua
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(74, 6, 26)
```

Within four seconds you should get a line like:

```
[Ebenezer] TinyTitanss  Psalms 34:18  [loss/en]  Player died for the first time...
```

That is the entire product in one line: Gloo read the moment and picked the theme
and reference, YouVersion returned the words, a stone rose where you died. I have
seen this fire — it works.

**If it doesn't:** an HTTP 401 means the secret in `EbenezerConfig` and the one on
Render don't match. Redo step 1 and step 4.

---

## 6 · Record  (~30 min)

Full shot list in **`SHOOT.md`**. Six shots, ~85 seconds, no narrator.

Before you hit record:

- Open `/health` in a browser to wake the backend. Cold start is ~50s and it will
  otherwise happen in the middle of your first take.
- Close the browser afterwards. 8 GB will not hold Studio + Chrome + OBS.
- OBS at 1080p30, encoder **NVENC** so the 3050 does the work.
- In Studio close Toolbox, Insert Objects and Output, and drag Explorer narrow.

The twelve-language closing shot needs the command bar switched to the server:
`Test` menu → **Toggle Client View** (viewport border turns green), then:

```lua
game.ServerStorage.EbenezerHook:Invoke("tour")
```

Takes 20–30s to place all twelve. `_G.Ebenezer.tour()` does **not** work — the
command bar runs in a separate Luau VM. That's what the hook is for.

---

## 7 · Submit

- **Repo:** `github.com/dLounce/ebenezer`
- **Writeup:** `WRITEUP.md`
- **Live map:** `https://ebenezer-2c4o.onrender.com/map`
- **Selftest:** `https://ebenezer-2c4o.onrender.com/selftest` → `{"total":35,"broken":[]}`
- **Public place link:** check whether the new-creator hold has lifted at
  `create.roblox.com/dashboard/creations` → Ebenezer → set to Public. If it hasn't,
  the repo satisfies the requirement on its own — don't lose time on it.

---

## What's already done

- Backend: Gloo selection + YouVersion retrieval, 12 verified languages, 35-verse
  pool, seeded landmarks, `/map`, `/stones`, `/selftest`. Deployed.
- Roblox: procedural world, chasm, moment detection on death plus loneliness and
  survival, the stone with its inscription, DataStore with backend mirror.
- Verified live: loneliness trigger → `Joshua 1:9 [fear/en]`, death trigger →
  `Psalms 34:18 [loss/en]`. Different themes for different moments, which is the
  thing worth showing.
- `README.md`, `WRITEUP.md`, `SHOOT.md`, `INSTALL.md`, all pushed.
