# NWN-Doom

A prototype that makes Neverwinter Nights: Enhanced Edition play like Doom:
first-person camera, click-to-shoot hitscan weapons with ammo, monster
waves, Doom-style pickups dropping from kills, and Doom's status bar and
first-person weapon sprites.

Everything runs inside NWN:EE with plain NWScript. No second process,
no NWNX, no custom blueprints. The Doom art comes from a WAD you supply.

## What it does

| Doom mechanic | How it works here |
|---|---|
| First-person view | `SetCameraLimits` / `SetCameraHeight` pull the camera into the head; the player's body gets cutscene invisibility. Stiff chase camera with camera turning disabled, so the view always points where the character faces (`/lockcam` toggles this) |
| Moving | NWN's own WASD movement in chase-camera mode |
| Shooting | The player is kept in targeting mode with an attack cursor. Each click fires `doom_target`, which deals damage instantly (no attack roll, no 6-second rounds) |
| Weapons | 1 Fist (2-20, 2.5 m reach), 2 Pistol (5-15 per shot), 3 Shotgun (7 pellets of 5-15; stray pellets hit enemies near the aim point). Fire-rate cooldowns per weapon |
| Switching weapons | Three inventory items, `1: Fist`, `2: Pistol`, `3: Shotgun`, that you put on F1-F3 |
| Ammo | Bullets and shells tracked as local variables. Running dry falls back to the pistol, then the fist |
| HUD | Doom's status bar (ammo, health %, arms panel, armor %, ammo table) and the weapon sprite with firing frames and muzzle flash, drawn with NUI |
| Pickups from kills | `doom_mdeath` rolls a drop: clip, shells, stimpack, armor bonus, or the shotgun. Walking over a pickup collects it |
| Armor | Absorbs a third of incoming damage until depleted |
| Doors | Click a door within 3 m to open it; locked doors need their key item |
| Waves | Wave 1 spawns on entering; each cleared wave triggers a bigger one 5 s later. Zombies and imps from wave 1, skeletons from wave 3 |
| Monster damage | A percentage of the player's max HP, using Doom's damage numbers as percents, so a level 1 and a level 5 character face the same fight. NWN still rolls monster attacks, but a damage shield on the player (DR 50/+20) soaks the weapon damage; each hit then runs `doom_hit` (via the stock On Hit: Unique Power tag-based item script) for the real damage, at most once per monster cooldown. Zombie 3-12% (1.2 s), skeleton 4-10% (1.2 s), imp claw and fireball 3-24% (1.2 s), balor 10-30% (2 s). Tuned in `DoomSetupMelee` |
| Monster speed | Zombies and imps +50%, skeletons -30% |
| Balor | Rare (25% per wave from wave 3, one at a time), 40% slower, melee only, ~300 HP. The stock `nw_balorboss` loses all spell-like abilities (Implosion, Fire Storm, ...), its vorpal and other on-hit effects, and its damage reduction |
| Imp fireballs | `doom_imp` strips the stock imp's Magic Missile (it always hits) and Invisibility. Imps run their own AI instead of NWN's: they keep 8-14 m away and stay within 30 degrees of where you are facing (on screen), sidestepping a little, backing off when rushed and clawing only when cornered. Every 2-4 s an imp that sees you at 3-30 m, and is on your screen (within 40 degrees of your facing; it moves there first, and only throws from off screen after 4 s of failing to), winds up and throws a fireball at where you stand: 6 m/s, straight line, stopped by walls. Strafe to dodge. Speed, range and timing are constants at the top of `doom_imp.nss` |
| Death | No death panel; respawn at the start with a pistol after 3 s |

### Weapon keys

The weapon items are created in your inventory on entering the module.
Drag them onto the quickbar once: `1: Fist` to F1, `2: Pistol` to F2,
`3: Shotgun` to F3. The quickbar is saved with the character. The shotgun
item only works after you have picked up a shotgun.

Using a quickbar item takes NWN's 1-second item activation, so switching
is slower than in Doom.

### Chat commands

| Command | Effect |
|---|---|
| `/1` `/2` `/3` | Select fist / pistol / shotgun (same as F1-F3) |
| `/idkfa` | Cheat for testing: all weapons, full ammo, 200% armor |
| `/balor` | Testing: spawn a balor 12 m ahead |
| `/gun` | Re-arm after right-click / Escape cancelled the gun cursor |
| `/fps` | Toggle first-person / normal camera |
| `/lockcam` | Toggle locking the camera to where your character faces (on by default) |
| `/wave` | Spawn the next wave now |
| `/hud` | Recreate the HUD (e.g. after changing resolution) |

## Setting up a test module

1. **Art hak:** `py tools/wad_to_hak.py path\to\doom2.wad` extracts the
   status bar, numbers and weapon sprites, writes `build/nwn_doom.hak`,
   copies it to your NWN `hak` folder and regenerates `src/doom_art.nss`.
   Works with id's `doom.wad` / `doom2.wad` and with
   [Freedoom](https://freedoom.github.io/) (Freedoom has no status bar
   face, so that slot stays empty).
2. **Scripts:** `py tools/build.py` compiles `src/` with Beamdog's official
   `nwn_script_comp` and writes `build/nwn_doom.erf` (sources plus compiled
   `.ncs`). Run it again whenever a script in `src/` changes.
   The compiler comes from the
   [neverwinter.nim releases](https://github.com/niv/neverwinter.nim/releases)
   (`neverwinter-x86_64-windows.zip`), unzipped into `tools/neverwinter/`.
   Without it, `py tools/build_erf.py` packs the sources only and the
   toolset compiles them in step 7.
3. Open the toolset (`bin\win32\nwtoolset.exe`). **File > New** and run the
   Area Wizard to make a module with one area (a small interior tileset,
   e.g. Crypt or Castle Interior, works best). Save it.
4. **Edit > Module Properties > Custom Content**: add the hak `nwn_doom`.
5. **File > Import...**, browse to `build/nwn_doom.erf` and import it. The
   `doom_*` scripts appear under **Scripts** in the module tree.
   Re-importing later asks to overwrite; say yes.
6. **Edit > Module Properties > Events > OnModuleLoad**: set it to
   `doom_modload`. That script wires up all other module events itself and
   still runs the stock `x2_mod_def_load`.
7. **Build > Build Module** (make sure "Compile scripts" is ticked) and
   check the output for compile errors. Then save.
8. Optional: place waypoints tagged `DOOM_SPAWN` where monsters should
   appear. Without them, monsters spawn in a ring 10-15 m around the player.
9. Test: **File > Test Module** in the toolset, or start the game, choose
   **New > Module**, pick the module and a character.

The saved module and the hak live in your NWN user directory (`modules`,
`hak`). That is normally `Documents\Neverwinter Nights`, but the `[Alias]`
section of `nwn.ini` can move it (on the dev machine it is `G:\nwnData`).
Logs are in the same directory under `logs`. The tools read the location
from the `NWN_USER` environment variable when it is set.

Any character of level 1-5 works: monster damage scales with your max HP.

## Repository layout

- `src/`: NWScript sources. `doom_inc.nss` holds all tunable constants.
  `doom_art.nss` is generated by `wad_to_hak.py` (weapon sprite positions).
- `tools/wad_to_hak.py`: WAD art to TGA, hak packing and install.
- `tools/build.py`: compile + pack the scripts in one step.
- `tools/build_erf.py`: ERF/HAK writer; `--list <file>` shows an archive's contents.
- `tools/nwn_key.py`: reads the game's KEY/BIF archives to list or extract
  stock resources (scripts, blueprints, 2DAs) from your install, e.g.
  `py tools/nwn_key.py list "nw_imp*" --type utc`.

## Known limits

- The shot goes where the mouse pointer is, not a fixed center crosshair:
  NWScript has no raycast.
- Weapon switching goes through quickbar items with a 1 s activation.
  An instant version would need custom feats (2DA edits in the hak).
- Monster movement and attack animations are NWN's; they are sped up by
  50% but never reach Doom speed.
- Pickups use the stock potion model with Doom names.
- The `SetCameraLimits` values are a first guess; how close the client lets
  the camera get has to be checked in the game.
- The HUD is sized from the screen width when you enter; after changing
  resolution, type `/hud`.
