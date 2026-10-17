# NWN-Doom

A prototype that makes Neverwinter Nights: Enhanced Edition play like Doom:
first-person camera, click-to-shoot hitscan weapons with ammo, monster
waves, Doom-style pickups dropping from kills, and a Doom-like HUD.

Everything runs inside NWN:EE with plain NWScript. No second process,
no NWNX, no custom blueprints.

## What it does

| Doom mechanic | How it works here |
|---|---|
| First-person view | `SetCameraLimits` / `SetCameraHeight` pull the camera into the head; the player's body gets cutscene invisibility |
| Moving | NWN's own WASD movement in chase-camera mode |
| Shooting | The player is kept in targeting mode with an attack cursor. Each click fires `doom_target`, which deals damage instantly (no attack roll, no 6-second rounds) |
| Pistol / shotgun | Pistol 5-15 per shot; shotgun 7 pellets of 5-15, stray pellets hit enemies near the aim point. Fire-rate cooldowns per weapon |
| Ammo | Bullets and shells tracked as local variables, shown on the HUD |
| Pickups from kills | `doom_mdeath` rolls a drop: clip, shells, stimpack, armor bonus, or the shotgun. Walking over a pickup collects it |
| Armor | Absorbs a third of incoming damage until depleted |
| Doors | Click a door within 3 m to open it; locked doors need their key item |
| Waves | Wave 1 spawns on entering; each cleared wave triggers a bigger one 5 s later |
| Death | No death panel; respawn at the start with a pistol after 3 s |

### Chat commands

| Command | Effect |
|---|---|
| `/1` | Pistol |
| `/2` | Shotgun (once picked up) |
| `/gun` | Re-arm after right-click / Escape cancelled the gun cursor |
| `/fps` | Toggle first-person / normal camera |
| `/wave` | Spawn the next wave now |
| `/hud` | Recreate the HUD (e.g. after changing resolution) |

## Setting up a test module

1. Build: `py tools/build.py` compiles `src/` with Beamdog's official
   `nwn_script_comp` and writes `build/nwn_doom.erf` (sources plus compiled
   `.ncs`). Run it again whenever a script in `src/` changes.
   The compiler comes from the
   [neverwinter.nim releases](https://github.com/niv/neverwinter.nim/releases)
   (`neverwinter-x86_64-windows.zip`), unzipped into `tools/neverwinter/`.
   Without it, `py tools/build_erf.py` packs the sources only and the
   toolset compiles them in step 5.
2. Open the toolset (`bin\win32\nwtoolset.exe`). **File > New** and run the
   Area Wizard to make a module with one area (a small interior tileset,
   e.g. Crypt or Castle Interior, works best). Save it, e.g. as `nwn_doom`.
3. **File > Import...**, browse to `build/nwn_doom.erf` and import it. The
   eight `doom_*` scripts appear under **Scripts** in the module tree.
   Re-importing later asks to overwrite; say yes.
4. **Edit > Module Properties > Events > OnModuleLoad**: set it to
   `doom_modload`. That script wires up all other module events itself.
5. **Build > Build Module** (make sure "Compile scripts" is ticked) and
   check the output for compile errors. Then save.
6. Optional: place waypoints tagged `DOOM_SPAWN` where monsters should
   appear. Without them, monsters spawn in a ring 10-15 m around the player.
7. Test: **File > Test Module** in the toolset, or start the game, choose
   **New > Module**, pick the module and a character.

The saved module ends up in
`Documents\Neverwinter Nights\modules\nwn_doom.mod`.

A melee-oriented character of level 5+ is a good test pilot: monsters use
NWN's normal combat against you, so a level 1 character dies very fast.

## Repository layout

- `src/`: NWScript sources. `doom_inc.nss` holds all tunable constants.
- `tools/build.py`: compile + pack in one step (see setup step 1).
- `tools/build_erf.py`: packs `src/*.nss` into `build/nwn_doom.erf` for
  the toolset's File > Import. `--list <file.erf>` shows an ERF's contents.
- `tools/nwn_key.py`: reads the game's KEY/BIF archives to list or extract
  stock resources (scripts, blueprints) from your install, e.g.
  `py tools/nwn_key.py list "nw_imp*" --type utc`.

## Known limits

- The shot goes where the mouse pointer is, not a fixed center crosshair:
  NWScript has no raycast.
- Weapon switching is by chat command; NWN scripts cannot bind keys.
- Monster movement and attack animations are NWN's; they are sped up by
  50% but never reach Doom speed.
- Pickups use the stock potion model with Doom names.
- The `SetCameraLimits` values are a first guess; how close the client lets
  the camera get has to be checked in the game.
