# How NWN-Doom works

Everything runs inside NWN:EE with plain NWScript: no second process, no
NWNX, no custom blueprints. Tunable numbers are constants at the top of
`src/doom_inc.nss` (and `src/doom_imp.nss` for imps).

## Mechanics

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

## Event wiring

`doom_modload` (the module's OnModuleLoad, or run from it) puts the
`doom_*` scripts on OnClientEnter, OnPlayerTarget, OnPlayerDeath,
OnPlayerChat and OnActivateItem, and keeps whatever scripts the module had
there in module variables (`DOOM_ORIG_<event number>`). The Doom scripts
still run them:

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

## Module variables

All are `int` locals, set under Advanced > Variables in Module Properties
or Area Properties. `DOOM_WAVES` = 1 on either turns waves on (on the
module: everywhere). For the other three, an area's own non-zero value
replaces the module's, so `-1` switches a module-wide setting off in one
area. Conversion reads them for the creature's area when it is converted.

| Variable | Default | Effect |
|---|---|---|
| `DOOM_WAVES` = 1 | off | Monster waves run there. They start 3 s after a Doom player is in such an area and continue while the wave monsters are cleared. `/wave` spawns one anywhere, for testing |
| `DOOM_STRIP_SPELLS` = 1 | off | Casters lose their prepared and spontaneous spells and spell-like abilities |
| `DOOM_KEEP_RANGED` = 1 | off | Ranged attacks are left alone: ammunition is not hooked to `doom_hit` |
| `DOOM_HP_CAP` = N | 0 (off) | Converted creatures start with at most N hit points (their maximum stays, so healing can raise it again) |

By default casters keep their spells: spell damage is not scaled to Doom
balance and the damage shield does not stop it, so a caster can one-shot a
low-level character.

`/doom` only switches the player side (camera, gun mode, HUD, speed,
shield). Converted creatures stay converted, and their `doom_hit` damage
skips players with Doom mode off, who take the weapon's normal damage
instead.

## Notes for story modules

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
