// doom_chat: module OnPlayerChat. Slash commands stand in for Doom's
// number keys until a keybinding solution exists.

#include "doom_inc"

void main()
{
    object oPC = GetPCChatSpeaker();
    string sMsg = GetStringLowerCase(GetPCChatMessage());
    if (GetStringLeft(sMsg, 1) != "/") return;

    if (sMsg == "/1")
    {
        SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_PISTOL);
        DoomMessage(oPC, "PISTOL");
    }
    else if (sMsg == "/2")
    {
        if (GetLocalInt(oPC, DOOM_VAR_HAS_SG))
        {
            SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_SHOTGUN);
            DoomMessage(oPC, "SHOTGUN");
        }
        else
            DoomMessage(oPC, "You don't have the shotgun yet.");
    }
    else if (sMsg == "/gun")
    {
        DoomArm(oPC);
    }
    else if (sMsg == "/fps")
    {
        if (GetLocalInt(oPC, DOOM_VAR_FPS)) DoomCameraThirdPerson(oPC);
        else DoomCameraFirstPerson(oPC);
    }
    else if (sMsg == "/wave")
    {
        DoomSpawnWave(oPC, GetLocalInt(GetModule(), DOOM_WAVE_VAR) + 1);
    }
    else if (sMsg == "/hud")
    {
        DoomHudOpen(oPC);
    }
    else
        return;  // not ours, let it through

    SetPCChatMessage("");  // swallow the command
    DoomHudUpdate(oPC);
}
