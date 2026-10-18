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
| First-person view | `SetCameraLimits` / `SetCameraHeight` pull the camera into the head; the player's body gets cutscene invisibility. Stiff chase camera with camera turning and tilting disabled and the pitch pinned (`DOOM_CAM_PITCH`), so the view always looks straight ahead where the character faces, like Doom (`/lockcam` toggles this) |
| Moving | NWN's own WASD movement, 50% faster than normal: the engine caps movement bonuses at +50% (measured; +99% and Haste give no more). Backwards and sideways NWN moves at walking pace, about 3 and 1.6 m/s against 6 m/s forwards, and no effect gets past the cap to change that. Turning speed is the client's Options > Controls camera turn speed, which the module cannot change; the default (1.0, the minimum) feels stiff, so raise it |
| Shooting | The player is kept in targeting mode, so every click fires `doom_target`. Shots go straight along the player's facing (the locked camera keeps it at the centre crosshair), not to the cursor: each bullet or pellet is a hitscan ray that hits the first monster on the line within its body radius + 0.4 m aim assist and in line of sight, with no attack roll. Misses spark on the wall the ray reaches. Players, and creatures that are not hostile to the shooter (friendly or neutral NPCs, henchmen, summons), are never hit |
| Weapons | 1 Fist (2-20, 2.5 m reach, more aim assist), 2 Pistol (5-15 per shot; the first shot is exact, rapid follow-ups spread up to 5.6 degrees like Doom), 3 Shotgun (7 pellets of 5-15, each its own ray with Doom's 5.6 degree spread). Fire-rate cooldowns per weapon. Tuned at the top of `doom_inc.nss` |
| Switching weapons | Text macros on F1-F3 that send `/1` `/2` `/3` (instant), added to a character file by `tools/doom_quickbar.py`; or the three inventory items `1: Fist`, `2: Pistol`, `3: Shotgun` dragged onto the quickbar (1 s item activation) |
| Cursor | In gun mode the pointer is a small red dot: targeting uses the stock DM kill cursor (`MOUSECURSOR_KILL`), whose TGA and DDS images the hak replaces (the dot sits at the top-left click point, like the stock cursors' tips). Shots go to the centre crosshair, but the sky cannot be clicked in targeting mode, so the dot shows where the pointer is: keep it on the ground or on monsters. `/cursor` switches to the visible attack cursor |
| Ammo | Bullets and shells tracked as local variables. Running dry falls back to the pistol, then the fist |
| HUD | Doom's status bar (ammo, health %, arms panel, Doomguy's face, armor %, ammo table) and the weapon sprite with firing frames and muzzle flash, drawn with NUI. The face follows Doom: five health levels, idle glances, the rampage face when firing, a turn when hurt, "ouch" on hits of 20% or more, the evil grin on picking up the shotgun, and the dead face |
| Pickups from kills | `doom_mdeath` rolls a drop: clip, shells, stimpack, armor bonus, or the shotgun. Walking over a pickup collects it |
| Armor | Absorbs a third of incoming damage until depleted |
| Doors and using things | Click a door within 3 m to open it; locked doors need their key item. In the same way, clicking a friendly NPC within 3 m talks to it, a usable placeable (chest, lever) is used, and an item on the ground is picked up |
| Waves | Only where the module or the area has the variable `DOOM_WAVES` = 1. Wave 1 spawns 3 s after entering; each cleared wave triggers a bigger one 5 s later. Zombies and imps from wave 1, skeletons from wave 3 |
| Module monsters | Creatures the module places that are hostile to a Doom player are converted once when the player enters their area; later spawns (encounters, scripts) are caught by a sweep every 2 s within 30 m. Plot-flagged, DM-possessed, friendly and neutral creatures are skipped. Converted creatures deal Doom damage through `doom_hit`, banded by challenge rating (CR < 3: 3-12%, 1.2 s; CR < 8: 5-20%, 1.5 s; else 10-30%, 2 s), on their melee weapons and on their ammunition (bows never trigger on-hit, arrows do), and lose damage reduction, resistances, damage-type immunities and on-hit effects from their gear. Their AI, speed and other event scripts stay. On death their own OnDeath script runs first, then the Doom drop. See `DoomConvertCreature` in `doom_inc.nss` |
| Monster defences | Monsters lose damage reduction, resistances and damage-type immunities from their stock gear (imps soaked 5 per hit, skeletons halved piercing), so every gun does its Doom damage |
| Monster damage | A percentage of the player's max HP, using Doom's damage numbers as percents, so a level 1 and a level 5 character face the same fight. NWN still rolls monster attacks, but a damage shield on the player (DR 50/+20) soaks the weapon damage; each hit then runs `doom_hit` (via the stock On Hit: Unique Power tag-based item script) for the real damage, at most once per monster cooldown. Zombie 3-12% (1.2 s), skeleton 4-10% (1.2 s), imp claw and fireball 3-24% (1.2 s), balor 10-30% (2 s). Tuned in `DoomSetupMelee` |
| Monster speed | Zombies and imps +50%, skeletons -30% |
| Balor | Rare (25% per wave from wave 3, one at a time), 40% slower, melee only, ~300 HP. The stock `nw_balorboss` loses all spell-like abilities (Implosion, Fire Storm, ...), its vorpal and other on-hit effects, and its damage reduction |
| Imp fireballs | `doom_imp` strips the stock imp's Magic Missile (it always hits) and Invisibility. Imps run their own AI instead of NWN's: they keep 8-14 m away and stay within 30 degrees of where you are facing (on screen), sidestepping a little, backing off when rushed and clawing only when cornered. At most every 4-6 s (a clock-based cooldown) an imp that sees you at 3-30 m, and is on your screen (within 40 degrees of your facing; it moves there first, and only throws from off screen after 4 s of failing to), winds up and throws a fireball at where you stand: 6 m/s, straight line, stopped by walls. Strafe to dodge. Speed, range and timing are constants at the top of `doom_imp.nss` |
| Death | No death panel; respawn at the module start with a pistol after 3 s. With Doom mode off, the module's own death script runs instead |

### Weapon keys

No script can change a quickbar in game, so the weapon keys go on before
you play: `py tools/doom_quickbar.py CHARACTER` turns F1-F3 of a character
in your localvault into text macros sending `/1`, `/2`, `/3`. It backs the
character file up first (`CHARACTER.bic.bak-<timestamp>`). Single-player
games keep the quickbar in the save, not the character file, so this
stays for every new game with that character.

Without the tool:

The weapon items are created in your inventory on entering the module.
Drag them onto the quickbar: `1: Fist` to F1, `2: Pistol` to F2,
`3: Shotgun` to F3. That lasts for the saved game, but a new game from the
same character file starts with its old quickbar again. The shotgun item
only works after you have picked up a shotgun.

Using a quickbar item takes NWN's 1-second item activation, so switching
is slower than in Doom.

### Chat commands

| Command | Effect |
|---|---|
| `/doom` | Switch Doom mode off and on for you (`/doom off`, `/doom on` also work). Off: normal camera, minimap and compass, no HUD, speed bonus or damage shield, and the other commands and the module's own chat script work as without NWN-Doom. On by default |
| `/1` `/2` `/3` | Select fist / pistol / shotgun (same as F1-F3) |
| `/idkfa` | Cheat for testing: all weapons, full ammo, 200% armor |
| `/balor` | Testing: spawn a balor 12 m ahead |
| `/gun` | Re-arm after right-click / Escape put the gun away |
| `/fps` | Toggle first-person / normal camera |
| `/lockcam` | Toggle locking the camera to where your character faces (on by default) |
| `/wave` | Spawn the next wave now (works without `DOOM_WAVES`, for testing) |
| `/speed N` | Move N% faster than normal NWN speed (0-50, default 50, the engine's cap); `/speed` alone shows it |
| `/cursor` | Toggle the hidden / visible gun-mode cursor |
| `/debug` | Toggle logging every gun click to chat (for troubleshooting) |
| `/hud` | Recreate the HUD (e.g. after changing resolution) |

## Setting up a test module

1. **Art hak:** `py tools/wad_to_hak.py path\to\doom2.wad` extracts the
   status bar, numbers and weapon sprites, writes `build/nwn_doom.hak`,
   copies it to your NWN `hak` folder and regenerates `src/doom_art.nss`.
   Works with id's `doom.wad` / `doom2.wad` and with
   [Freedoom](https://freedoom.github.io/) (Freedoom has no status bar
   face, so that slot stays empty). It also converts the pistol, shotgun,
   punch and imp fireball sounds. Use the official `freedoom2.wad`:
   some repacked WADs ship empty sound stubs, and the tool warns when a
   sound has no audio (the game then stays silent for it).
   It also extracts Doomguy's status bar faces (Freedoom 0.13 has all 42;
   some repacked WADs have blank placeholders, which are skipped).
   The sounds are played through rows 10100-10105 that the tool appends to
   the game's `visualeffects.2da` in the hak (`DOOM_VFX_*` in `doom_art.nss`):
   applying an effect plays reliably, while `PlaySound` depends on the
   playing object's action queue. Another hak that also replaces
   `visualeffects.2da` would conflict.
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
8. Optional: paste [docs/module_description.txt](docs/module_description.txt)
   into **Edit > Module Properties > Description**. It explains the controls
   on the game's module selection screen.
9. **Edit > Module Properties > Advanced > Variables**: add an `int`
   variable `DOOM_WAVES` with value `1`. Without it no waves spawn.
10. Optional: place waypoints tagged `DOOM_SPAWN` where monsters should
   appear. Without them, monsters spawn in a ring 10-15 m around the player.
11. Test: **File > Test Module** in the toolset, or start the game, choose
   **New > Module**, pick the module and a character.

The saved module and the hak live in your NWN user directory (`modules`,
`hak`). That is normally `Documents\Neverwinter Nights`, but the `[Alias]`
section of `nwn.ini` can move it (on the dev machine it is `G:\nwnData`).
Logs are in the same directory under `logs`. The tools read the location
from the `NWN_USER` environment variable when it is set.

Any character of level 1-5 works: monster damage scales with your max HP.

## Using NWN-Doom in another module

The scripts also work when imported into an existing module, e.g. a story
module, rather than a dedicated arena. A step-by-step walkthrough, including
the official campaign chapters, is in
[docs/adding_to_a_module.md](docs/adding_to_a_module.md). In short:

1. Build the hak and the scripts and import `build/nwn_doom.erf` as in
   steps 1, 2, 4 and 5 above. The module must not already have scripts
   named `doom_*`.
2. Hook up `doom_modload`:
   - If the module's OnModuleLoad is empty or a stock script
     (`x2_mod_def_load`), set it to `doom_modload`, which runs
     `x2_mod_def_load` itself.
   - If the module has its own OnModuleLoad script, keep it and add
     `ExecuteScript("doom_modload", OBJECT_SELF);` at its end.
   `doom_modload` takes over OnClientEnter, OnPlayerTarget, OnPlayerDeath,
   OnPlayerChat and OnActivateItem, and keeps whatever scripts the module
   had there in module variables (`DOOM_ORIG_<event number>`). The Doom
   scripts still run them:
   - OnClientEnter: the module's script first, then the Doom setup.
   - OnPlayerChat: chat that is not a Doom command (or all chat but
     `/doom` with Doom mode off) goes on to the module's script.
   - OnActivateItem: every item but the three weapon items goes to the
     module's script (`x2_mod_def_act` if it had none).
   - OnPlayerTarget: the module's script gets the clicks when Doom mode is
     off or the gun is holstered, e.g. for its own targeting items.
   - OnPlayerDeath: the module's script (`nw_o0_death` if it had none) runs
     only for players with Doom mode off; Doom mode respawns you.
   Change these events in the module's load script after `doom_modload`
   runs only if you mean to replace NWN-Doom's.
3. Waves are off unless asked for: set an `int` variable `DOOM_WAVES` = 1
   on the module (Module Properties > Advanced > Variables) for waves
   everywhere, or on single areas (Area Properties > Advanced > Variables)
   for arena areas. Waves follow the player: they start 3 s after a Doom
   player is in such an area and continue while wave monsters are cleared
   there. `/wave` spawns one anywhere, for testing.
4. The module's own hostile creatures become Doom monsters automatically
   (see "Module monsters" above); friendly and neutral NPCs are never
   changed, and shots pass through them. Clicking a friendly NPC, a chest
   or an item up close talks to it, opens it or picks it up. Conversion
   can be tuned with `int` variables on an area, or on the module for
   all areas without their own value:

   | Variable | Default | Effect |
   |---|---|---|
   | `DOOM_STRIP_SPELLS` = 1 | off | Casters lose their prepared and spontaneous spells and spell-like abilities |
   | `DOOM_KEEP_RANGED` = 1 | off | Ranged attacks are left alone: ammunition is not hooked to `doom_hit` |
   | `DOOM_HP_CAP` = N | 0 (off) | Converted creatures start with at most N hit points (their maximum stays, so healing can raise it again) |

   By default casters keep their spells: spell damage is not scaled to
   Doom balance and the damage shield does not stop it, so a caster can
   one-shot a low-level character.
5. Players can type `/doom` to play the module normally and `/doom` again
   to get Doom back. Ammo and weapons are kept meanwhile. This only
   switches the player side; converted creatures stay converted, and
   their `doom_hit` damage skips players with Doom mode off (they take the
   weapon's normal damage instead).

Things to know in a story module:

- Doom mode respawns dead players at the module's start location, not
  where they died.
- Wave state (wave number, monsters alive) is module-wide; leaving an
  arena area with wave monsters still alive pauses the waves until they
  are dead.
- Archers without ammunition items (no arrows, bolts or bullets in their
  slots or inventory, e.g. blueprints relying on the engine's unlimited
  ammo) keep their normal ranged damage, which the damage shield soaks:
  they are harmless to Doom players at range. Thrown weapons sit in the
  hand slot and are hooked like melee weapons.
- Converting a weapon or ammunition retags it `doom_hit`; a module item
  with its own tag-based on-hit script loses that script on converted
  creatures.
- The gun cursor is a targeting mode: while it is up, clicks do not walk
  or open the radial menu. Holster with right-click / Escape, `/gun` to
  re-arm, or `/doom` for normal NWN controls. NWScript cannot end
  targeting mode itself, so after `/doom` off the cursor stays until the
  next click.

## Shipping the module

`py tools/package.py --module NAME --version X.Y` builds
`build/dist/NAME-X.Y.zip` from `NAME.mod` in your NWN modules folder and
the installed `nwn_doom.hak`. It refuses to build if the module does not
use the hak, OnModuleLoad is not `doom_modload`, the module has no
`DOOM_WAVES` = 1 variable, or a `doom_*` script is not compiled into the module, and warns if the description is empty.

The zip mirrors the NWN user folder (`modules/`, `hak/`), so players
unzip it into `Documents\Neverwinter Nights`. It also contains a
`README.txt` (install steps plus `docs/module_description.txt`) and
`FREEDOOM-LICENSE.txt` plus `FREEDOOM-CREDITS.txt`: Freedoom's BSD licence
requires its copyright notice to ship with the art. Nothing is uploaded; publish the zip
yourself (e.g. on the Neverwinter Vault).

Package after importing the latest `build/nwn_doom.erf` and building the
module: the zip contains the module exactly as last saved by the toolset.

## Repository layout

- `src/`: NWScript sources. `doom_inc.nss` holds all tunable constants.
  `doom_art.nss` is generated by `wad_to_hak.py` (weapon sprite positions).
- `tools/wad_to_hak.py`: WAD art to TGA, hak packing and install.
- `tools/build.py`: compile + pack the scripts in one step.
- `tools/package.py`: checks the module and builds the player release zip.
- `tools/doom_quickbar.py`: puts the `/1` `/2` `/3` weapon macros on a character's F1-F3.
- `docs/module_description.txt`: module description / player controls.
- `docs/adding_to_a_module.md`: tutorial for adding NWN-Doom to an existing module.
- `licenses/`: Freedoom's licence (`FREEDOOM-COPYING.txt`) and contributor list
  (`FREEDOOM-CREDITS.txt`), both shipped with the art.
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
