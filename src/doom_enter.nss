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
    // Opened after a moment: the client reports its screen size only once
    // the area has loaded, and the HUD is sized from it.
    DelayCommand(1.5, DoomHudOpen(oPC));

    // Hide panels that would sit on top of the Doom view.
    SetGuiPanelDisabled(oPC, GUI_PANEL_MINIMAP, TRUE);
    SetGuiPanelDisabled(oPC, GUI_PANEL_COMPASS, TRUE);

    SendMessageToPC(oPC, "NWN-Doom: WASD to move, click to shoot. Weapons: drag the items '1: Fist', '2: Pistol' and '3: Shotgun' from your inventory to F1, F2, F3 (once). Chat: /gun re-arm, /fps camera, /wave next wave, /hud redraw HUD.");

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
