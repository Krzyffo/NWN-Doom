// doom_enter: module OnClientEnter.
// Runs the module's own OnClientEnter first, then sets the player up as a
// Doom marine: first-person camera, starting loadout, HUD, gun cursor and
// the per-player tick loop. Waves start from doom_tick, where enabled.

#include "doom_inc"

void main()
{
    DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER);

    object oPC = GetEnteringObject();
    if (!GetIsPC(oPC) || GetIsDM(oPC)) return;

    // Start the loop only once per player. It keeps running while Doom
    // mode is off, so /doom can switch it back on.
    if (!GetLocalInt(oPC, DOOM_VAR_ACTIVE))
    {
        SetLocalInt(oPC, DOOM_VAR_ACTIVE, TRUE);
        DelayCommand(DOOM_TICK, ExecuteScript("doom_tick", oPC));
    }

    if (!DoomIsOn(oPC))
    {
        SendMessageToPC(oPC, "NWN-Doom is off for you. Type /doom to switch it on.");
        return;
    }

    DoomResetLoadout(oPC);
    DoomCameraFirstPerson(oPC);
    // Opened after a moment: the client reports its screen size only once
    // the area has loaded, and the HUD is sized from it.
    DelayCommand(1.5, DoomHudOpen(oPC));
    DoomHidePanels(oPC, TRUE);

    SendMessageToPC(oPC, "NWN-Doom: WASD to move, click to shoot, click up close to use doors, chests and people. Weapons: drag the items '1: Fist', '2: Pistol' and '3: Shotgun' from your inventory to F1, F2, F3. Chat: /doom Doom mode off/on, /gun re-arm, /fps camera, /wave next wave, /hud redraw HUD.");

    DelayCommand(1.0, DoomArm(oPC));
}
