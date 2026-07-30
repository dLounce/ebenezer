# Reinstalling Ebenezer into the Roblox place

Use this if Studio was reinstalled, the place got damaged, or you just want the
scripts to match the repo exactly. Takes about a minute.

## 0. If Studio won't open

The install is damaged — the "Update failed" badge was the early warning, and the
window now renders blank. Fix it:

1. Windows Settings → Apps → **Roblox Studio** → Uninstall.
2. Reinstall from `create.roblox.com` → Create → *Start Creating*.
3. Sign in as **TinyTitanss**.
4. Open the **Ebenezer** place from the Studio start screen (My Experiences).

Nothing in the place is lost — it lives on Roblox, not on your disk. Last save was
06:04 and it has all three scripts in it.

## 1. Paste each file into the command bar

Command bar is the one-line box at the bottom of Studio. If you can't see it:
`View` → it's docked under the Output window.

**Studio must be in edit mode, not playing.** Check that the Play button is blue,
not greyed out.

For each file below, in order: open it, `Ctrl+A`, `Ctrl+C`, click the command bar,
`Ctrl+A`, `Ctrl+V`, then **`Ctrl+Enter`** (plain Enter just adds a newline).

| file | what it does | expect in Output |
|---|---|---|
| `paste_0_clean.txt` | removes the old leftover test Script | `cleaned` |
| `paste_1_config.txt` | backend URL + shared secret | `OK EbenezerConfig 1043` |
| `paste_2_world.txt` | the world: light, fog, chasm, scatter | `OK EbenezerWorld 6980` |
| `paste_3_server.txt` | moment detection, stones, filming hook | `OK EbenezerServer 16527` |

Byte counts will be close to those, not exact, if the repo has moved on.

## 2. Turn the two toggles back on

`File` → `Experience Settings` → `Security`:

- **Allow HTTP Requests** — nothing works without it
- **Enable Studio Access to API Services** — for DataStore

These live on the experience, not the place file, so a reinstall shouldn't clear
them. Check anyway.

## 3. Save

`Ctrl+S`. Output should say `Saved new changes in "Ebenezer" to Roblox.`

## 4. Confirm it works

Press Play. Within ~20 seconds Output should show:

```
[Ebenezer] world built -- pre-dawn, fog to 250, chasm at (74, 26)
[Ebenezer] backend awake -- 12 languages, N stones on record
[Ebenezer] N stones already standing in this world
```

Then drop yourself in the chasm from the command bar (client context, the default):

```lua
game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(74, 6, 26)
```

You should get a stone within about four seconds, and a line like:

```
[Ebenezer] TinyTitanss  Psalms 34:18  [loss/en]  Player died for the first time...
```

That is the whole pipeline — Gloo chose the theme and reference, YouVersion
returned the words. If you see that, you are ready to record. See `SHOOT.md`.
