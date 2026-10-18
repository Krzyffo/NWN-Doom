# Tutorial: adding NWN-Doom to an existing module

This walks through turning an existing NWN:EE module, for example a story
module or a chapter of the official campaign, into a Doom-style game. The
background (which events NWN-Doom takes over, the variables it reads) is
in [how_it_works.md](how_it_works.md).

All you need is the NWN:EE toolset (`bin\win32\nwtoolset.exe` in the game
folder).

## 1. Unzip the kit

Download `nwn-doom-kit-<version>.zip` from the
[latest release](https://github.com/Krzyffo/NWN-Doom/releases/latest) and
unzip it into your NWN user folder (normally `Documents\Neverwinter Nights`).
That puts the art in `hak\nwn_doom.hak` and the scripts, already compiled,
in `erf\nwn_doom.erf`.

(Changing the scripts yourself? Build them as in [building.md](building.md)
and import `build/nwn_doom.erf` in step 4 instead.)

## 2. Make a copy of the module

Importing scripts and changing events edits the module file, so work on a
copy. Your modules are in the `modules` folder of your NWN user folder.

Copy `YourModule.mod` to `YourModule-doom.mod` and open the copy in the
toolset.

### The official campaign

The campaign chapters are not in `modules`: each one is a `.nwm` file in
the game's `data\nwm` folder (`Prelude.nwm`, `Chapter1.nwm`,
`XP1-Chapter 1.nwm`, `XP2_Chapter1.nwm`, ...). A `.nwm` is the same archive
as a `.mod`, so copy it into `modules` with a `.mod` name, e.g.
`data\nwm\Chapter1.nwm` to `modules\Chapter1-doom.mod`, and open that.

- Each chapter is its own module and needs these steps separately.
- At the end of a chapter the game loads the original next chapter, not
  your copy, so test one chapter at a time from **New > Module**.

Premium modules (Kingmaker, Darkness over Daggerford, ...) are protected
and cannot be opened in the toolset.

If the toolset refuses to open some other module, it is usually missing a
hak or `.tlk` file the module needs: put those in the `hak` and `tlk`
folders of your NWN user directory.

## 3. Add the hak

**Edit > Module Properties > Custom Content**: add `nwn_doom` to the hak
list.

If the module already uses haks, check that none of them replaces
`visualeffects.2da`. `nwn_doom` adds rows to that file for the Doom sounds,
and two haks replacing it conflict (the higher one in the list wins).

## 4. Import the scripts

**File > Import...**, select `nwn_doom.erf` from the `erf` folder of your
NWN user folder, import everything. The `doom_*` scripts appear under
**Scripts**. When importing a newer version later, let it overwrite.

## 5. Start NWN-Doom when the module loads

Open **Edit > Module Properties > Events** and look at **OnModuleLoad**:

- **Empty or `x2_mod_def_load`:** replace it with `doom_modload`. It runs
  `x2_mod_def_load` itself.
- **Any other script** (the official chapters have their own): leave it in
  place, open that script (**Scripts** in the module tree, or the edit
  button next to the event) and add this as the last line of its
  `void main()`:

  ```c
  ExecuteScript("doom_modload", OBJECT_SELF);
  ```

  If the script is a stock one you cannot edit, save it under a new name
  with the line added and put that name in OnModuleLoad.

Leave the other module events as they are. `doom_modload` takes over
OnClientEnter, OnPlayerTarget, OnPlayerDeath, OnPlayerChat and
OnActivateItem when the module loads, and still runs the module's own
scripts for them.

## 6. Optional: waves and tuning

Variables are set under **Advanced > Variables** in Module Properties (for
the whole module) or Area Properties (for one area). All are `int`.

| Variable | Where | Effect |
|---|---|---|
| `DOOM_WAVES` = 1 | module or area | Monster waves run there. Without it, you only fight the module's own monsters |
| `DOOM_STRIP_SPELLS` = 1 | module or area | Hostile casters lose their spells (by default they keep them, and spell damage is not scaled to Doom balance) |
| `DOOM_KEEP_RANGED` = 1 | module or area | Leave the module's archers' damage as NWN's (by default their ammunition deals Doom damage) |
| `DOOM_HP_CAP` = N | module or area | The module's hostiles start with at most N hit points |

For wave areas you can also place waypoints tagged `DOOM_SPAWN` where the
monsters should appear.

## 7. Build and save

**Build > Build Module** with **Compile scripts** ticked. The output should
show no errors. Save the module.

## 8. Play

**File > Test Module** in the toolset, or in the game **New > Module** and
pick your copy. Any character works; monster damage is a percentage of
your hit points.

- WASD moves, clicking shoots straight ahead at the crosshair.
- Doors, chests, items and friendly NPCs are used by clicking them up close.
- Weapons: drag `1: Fist`, `2: Pistol`, `3: Shotgun` from the inventory to
  F1-F3, or put quickbar text macros saying `/1`, `/2`, `/3` there, which
  switch instantly.
- `/doom` switches to normal NWN controls and back, e.g. for a long
  conversation or a puzzle. `/gun` re-arms after right-click or Escape.

## Checklist for a first test

- The module's own start still happens (intro conversation, starting
  items, journal).
- The module's chat commands, tag-based items and death handling still
  work (death only with `/doom` off: in Doom mode you respawn at the
  module start).
- Hostile monsters hurt you and die; quest scripts on their death still
  fire; they drop Doom pickups.
- Shots pass through friendly NPCs and henchmen; clicking a friendly NPC
  up close starts its conversation.
- `/doom` off and on again restores everything.

If something goes wrong, the game log is in the `logs` folder of your NWN
user directory (`nwclientLog1.txt`), and `/debug` in chat logs every gun
click.
