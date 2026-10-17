// doom_enter: module OnClientEnter.
// Sets the player up as a Doom marine: first-person camera, starting
// loadout, HUD, gun cursor, the per-player tick loop, and wave 1.

#include "doom_inc"

void main()
{
    object oPC = GetEnteringObject();
    if (!GetIsPC(oPC) || GetIsDM(oPC)) return;

    DoomResetLoadout(oPC);
    DoomCameraFirstPerson(oPC);
    DoomHudOpen(oPC);
    DoomHudUpdate(oPC);

    // Clicking on the HUD-less world is all the player needs; hide panels
    // that would pop up over the view.
    SetGuiPanelDisabled(oPC, GUI_PANEL_MINIMAP, TRUE);
    SetGuiPanelDisabled(oPC, GUI_PANEL_COMPASS, TRUE);

    SendMessageToPC(oPC, "NWN-Doom: WASD to move, click to shoot. Chat commands: /1 pistol, /2 shotgun, /gun re-arm, /fps toggle camera, /wave next wave.");

    // Start the loop only once per player.
    if (!GetLocalInt(oPC, DOOM_VAR_ACTIVE))
    {
        SetLocalInt(oPC, DOOM_VAR_ACTIVE, TRUE);
        DelayCommand(DOOM_TICK, ExecuteScript("doom_tick", oPC));
    }

    DelayCommand(1.0, DoomArm(oPC));
    if (GetLocalInt(GetModule(), DOOM_WAVE_VAR) == 0)
        DelayCommand(3.0, DoomSpawnWave(oPC, 1));
}
