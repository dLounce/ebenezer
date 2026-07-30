# Ebenezer — shooting the video

30 of 100 points. Everything below is captured from Roblox Studio playtest, so the
public-link gate is irrelevant to the footage.

## Before you press record

1. **Wake the backend.** Open `https://ebenezer-2c4o.onrender.com/health` in a
   browser. Free hosting cold-starts in ~50s. If you skip this, your first stone
   takes a minute to appear on camera.
2. **Close everything else.** 8 GB of RAM will not hold Studio + Chrome + OBS. Kill
   the browser after you've woken the backend.
3. **OBS:** 1920×1080, 30 fps, encoder **NVENC H.264** (the 3050 encodes on the
   GPU, so RAM stays free). Capture the Studio *window*, not the display.
4. **Make the viewport big.** In Studio close Toolbox, Insert Basic Objects, and
   the Output pane, and drag Explorer/Properties narrow. Ignore the "Update
   failed" badge — it doesn't affect the build.
5. Press Play, then **Shift+F5** or the Roblox menu → toggle off the topbar so the
   Roblox UI is not in your shot. Scroll the mouse wheel back to third person.

## The shots

Six shots, roughly 85 seconds. No narrator. No text overlays until the last card.

| # | shot | how |
|---|---|---|
| 1 | **The world, empty.** Slow walk through fog at pre-dawn. Nothing happens. 8s. | Just walk. `Lighting.FogEnd = 250` is already doing the work. |
| 2 | **The fall.** Walk east into the black chasm at `(74, 26)`. You die. 5s. | The chasm is the dark slab east of spawn. Walk in. |
| 3 | **The stone rises.** Cut to the chasm edge. A slab comes up out of the ground with dust, and the verse fades in. 6s. | This fires automatically on death. The rise takes 2.1s — let it finish. |
| 4 | **Read it.** Walk up close. The inscription only renders inside 85 studs, so the reveal is real, not an edit. 8s. | Hold the shot. Let the verse be readable. |
| 5 | **Someone else's stone.** Walk away into the fog and find a different stone — a landmark someone left. 12s. | Landmarks sit at `(-118, 146)`, `(232, -74)`, `(-286, -198)`, `(96, 318)`. |
| 6 | **The same moment, twelve languages.** A ring of stones around you, each in a different tongue. 15s. | Command bar, context **Server**: `_G.Ebenezer.tour()` — see below. |

Then one card, 4 seconds, no voiceover:

> Every word is Scripture from the YouVersion Platform.
> Gloo AI only chose which verse. It never wrote one.

## Command bar during a playtest

The command bar runs in its own Luau VM, so it **cannot see `_G.Ebenezer`** — that
was tested and it fails with `attempt to index nil with 'tour'`. The helpers are
exposed through a `BindableFunction` on the DataModel instead.

First switch the command bar to the **server**: `Test` menu → **Toggle Client
View**. The viewport border turns green and Explorer shows `NetworkServer`. Then:

```lua
-- the closing shot: one stone per entitled language, in a ring around you
game.ServerStorage.EbenezerHook:Invoke("tour")

-- one stone in a specific language, near you
game.ServerStorage.EbenezerHook:Invoke("stone", "Player died to the same creature five times", "pt")

-- reset the local world between takes (backend record is untouched)
game.ServerStorage.EbenezerHook:Invoke("clear")
```

The tour is twelve HTTP round trips and takes ~20–30s to finish placing.

Force a death without walking to the chasm — this one works from **client**
context, which is the default:

```lua
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(74, 6, 26)
```

That drops you into the chasm, which kills on touch, which fires the real death
path. Verified: death → stone in 3.7 seconds.

## What the judges should be able to verify

- The repo: `github.com/dLounce/ebenezer` — real API calls, no mocks.
- `https://ebenezer-2c4o.onrender.com/map` — the world filling up, live.
- `https://ebenezer-2c4o.onrender.com/selftest` — all 35 pooled references resolve.
- Every stone in-game carries `Theme`, `Usfm`, `Reference`, `Locale`, `StoneId` as
  child values, so a judge poking around in Explorer finds real provenance.

## Studio is unstable on this machine — shoot in short takes

Studio has crashed twice, both times roughly ten minutes into a session, leaving a
blank window that needs a full restart. 8 GB with Studio + a playtest is the likely
cause; adding OBS will not help.

Plan around it rather than fighting it:

- **One shot per Play session.** Press Play, get the shot, Stop, Play again.
- **Restart Studio every three or four takes**, before it decides for you.
- **Ctrl+S before every recording session.** The place is safe on Roblox, but the
  crash takes any unsaved layout with it.
- Keep the browser closed while recording. Wake the backend, then close it.

None of this affects the footage. It only affects how long you can go between
restarts.

## Things that will bite you

- **Cooldown is 25s per player.** Two deaths inside 25 seconds produce one stone.
  Wait between takes, or use `_G.Ebenezer.stone(...)`, which bypasses it.
- **Don't re-run the world script mid-take.** It clears and rebuilds the dressing
  folder.
- **Studio DataStore** is still returning `StudioAccessToApisNotAllowed` even with
  the toggle on — Studio caches that flag, so restart Studio once and it clears.
  Persistence works regardless: stones come back from the backend mirror, which is
  what "1 stones already standing in this world" in the Output was proving.
