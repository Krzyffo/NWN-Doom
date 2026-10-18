# NWN-Doom

Neverwinter Nights: Enhanced Edition played like Doom: a locked
first-person view, click-to-shoot fist, pistol and shotgun, Doom's status
bar and Doomguy's face, monster waves, and ammo, stimpacks and armor
dropping from kills. Plain NWScript, art and sounds from
[Freedoom](https://freedoom.github.io/).

## Play

1. Download `doom-test-<version>.zip` from the
   [latest release](https://github.com/Krzyffo/NWN-Doom/releases/latest).
2. Unzip it into your NWN user folder (normally
   `Documents\Neverwinter Nights`).
3. Start the game, **New > Module**, pick **doom-test**, and play with any
   character; monster damage scales with your hit points.
4. Once per character, drag the inventory items `1: Fist`, `2: Pistol` and
   `3: Shotgun` onto F1-F3.

Requires NWN: Enhanced Edition.

## Add it to your own module

Download `nwn-doom-kit-<version>.zip` from the same release, then follow
[docs/adding_to_a_module.md](docs/adding_to_a_module.md): add the hak,
import the scripts, set OnModuleLoad, build. It works with story modules
and the official campaign chapters, keeps the module's own scripts
running, and turns the module's hostile creatures into Doom monsters.

## Controls

- **W / S** move, **A / D** turn (or strafe, depending on your keys). The
  view always looks where you face.
- **Click** to shoot straight ahead at the crosshair. Keep the red dot
  cursor on the ground or a monster: clicks on the sky don't register.
- **F1-F3** switch weapons.
- **Click up close** to open doors and chests, pick up items and talk to
  friendly NPCs. Walk over pickups to collect them.
- Turning feels stiff? Raise the camera turn speed in Options > Controls.

Faster weapon keys: `py tools/doom_quickbar.py CHARACTER` puts text macros
for `/1` `/2` `/3` on a character's F1-F3, which switch instantly (it backs
the character file up first).

## Chat commands

| Command | Effect |
|---|---|
| `/doom` | Doom mode off (normal NWN camera and controls) and back on |
| `/1` `/2` `/3` | Fist, pistol, shotgun |
| `/gun` | Get the gun back after right-click or Escape put it away |
| `/speed N` | Run N% faster than normal, 0-50 (default 50, the engine's cap) |
| `/fps` | First / third person |
| `/lockcam` | Lock or unlock the camera to your facing |
| `/hud` | Redraw the status bar, e.g. after changing resolution |
| `/cursor` | Visible attack cursor instead of the red dot |
| `/wave` | Next wave now (testing) |
| `/idkfa` | All weapons, full ammo, 200% armor (cheat) |
| `/balor` | Spawn a balor (testing) |
| `/debug` | Log every gun click to chat |

## Known limits

- Weapon items on the quickbar take NWN's 1 s item activation; the
  `/1` `/2` `/3` macros are instant.
- Moving backwards and sideways is NWN's walking pace; nothing gets past
  the engine's +50% speed cap.
- Monsters are NWN's 3D models and animations, not Doom sprites.
- Pickups use the stock potion model with Doom names.
- In Doom mode you respawn at the module's start location.

## More

- [docs/how_it_works.md](docs/how_it_works.md): every mechanic in detail,
  event wiring, module variables, notes for story modules.
- [docs/building.md](docs/building.md): building the hak and scripts from
  source, the test module, packaging a release, repository layout.
