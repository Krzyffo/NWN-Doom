// doom_chat: module OnPlayerChat. Debug and fallback commands; weapons are
// normally switched with the F1-F3 quickbar items.

#include "doom_inc"

void main()
{
    object oPC = GetPCChatSpeaker();
    string sMsg = GetStringLowerCase(GetPCChatMessage());
    if (GetStringLeft(sMsg, 1) != "/") return;

    if (sMsg == "/1")
        DoomSelectWeapon(oPC, DOOM_WEAPON_FIST);
    else if (sMsg == "/2")
        DoomSelectWeapon(oPC, DOOM_WEAPON_PISTOL);
    else if (sMsg == "/3")
        DoomSelectWeapon(oPC, DOOM_WEAPON_SHOTGUN);
    else if (sMsg == "/idkfa")
    {
        // Doom's cheat: all weapons, full ammo, 200% armor. For testing.
        SetLocalInt(oPC, DOOM_VAR_HAS_SG, TRUE);
        SetLocalInt(oPC, DOOM_VAR_BULLETS, DOOM_MAX_BULLETS);
        SetLocalInt(oPC, DOOM_VAR_SHELLS, DOOM_MAX_SHELLS);
        SetLocalInt(oPC, DOOM_VAR_ARMOR, 200);
        DoomPickupMessage(oPC, "Very Happy Ammo Added");
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
    else if (sMsg == "/lockcam")
    {
        int bFree = !GetLocalInt(oPC, DOOM_VAR_CAM_FREE);
        SetLocalInt(oPC, DOOM_VAR_CAM_FREE, bFree);
        if (GetLocalInt(oPC, DOOM_VAR_FPS)) DoomCameraFirstPerson(oPC);
        if (bFree) SendMessageToPC(oPC, "Camera unlocked: it can turn freely.");
        else       SendMessageToPC(oPC, "Camera locked to where your character faces.");
    }
    else if (sMsg == "/wave")
    {
        DoomSpawnWave(oPC, GetLocalInt(GetModule(), DOOM_WAVE_VAR) + 1);
    }
    else if (sMsg == "/balor")
    {
        // Testing: spawn a balor 12 m in front of the player.
        vector vPos = GetPosition(oPC) + AngleToVector(GetFacing(oPC)) * 12.0;
        DoomSpawnMonster(DOOM_RESREF_BALOR, Location(GetArea(oPC), vPos, GetFacing(oPC) + 180.0),
                         oPC, DOOM_BALOR_TAG);
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
