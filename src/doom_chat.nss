// doom_chat: module OnPlayerChat. Debug and fallback commands; weapons are
// normally switched with the F1-F3 quickbar items. Anything that is not a
// Doom command goes on to the module's own chat script.

#include "doom_inc"

void main()
{
    object oPC = GetPCChatSpeaker();
    string sMsg = GetStringLowerCase(GetPCChatMessage());

    // /doom works with Doom mode off too: it is how you switch it back on.
    if (sMsg == "/doom" || sMsg == "/doom on" || sMsg == "/doom off")
    {
        int bOn = !DoomIsOn(oPC);
        if (sMsg == "/doom on")  bOn = TRUE;
        if (sMsg == "/doom off") bOn = FALSE;
        DoomSetMode(oPC, bOn);
        SetPCChatMessage("");
        return;
    }

    // With Doom mode off, the other commands are not ours either.
    if (GetStringLeft(sMsg, 1) != "/" || !DoomIsOn(oPC))
    {
        DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT);
        return;
    }

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
    else if (GetStringLeft(sMsg, 7) == "/speed " || sMsg == "/speed")
    {
        // /speed N: move N% faster than normal NWN speed (0-50, the engine cap).
        string sArg = GetStringRight(sMsg, GetStringLength(sMsg) - 6);
        while (GetStringLeft(sArg, 1) == " ") sArg = GetStringRight(sArg, GetStringLength(sArg) - 1);
        if (sArg == "")
        {
            SendMessageToPC(oPC, "Speed: +" + IntToString(DoomPlayerSpeed(oPC)) + "%. Use /speed 0-" + IntToString(DOOM_MAX_SPEED) + ".");
        }
        else
        {
            int nSpeed = StringToInt(sArg);
            if (nSpeed < 0) nSpeed = 0;
            if (nSpeed > DOOM_MAX_SPEED) nSpeed = DOOM_MAX_SPEED;
            SetLocalInt(oPC, DOOM_VAR_SPEED, nSpeed + 1);
            DoomApplySpeed(oPC);
            SendMessageToPC(oPC, "Speed: +" + IntToString(nSpeed) + "%.");
        }
    }
    else if (sMsg == "/cursor")
    {
        int bShow = !GetLocalInt(oPC, DOOM_VAR_SHOW_CURSOR);
        SetLocalInt(oPC, DOOM_VAR_SHOW_CURSOR, bShow);
        if (bShow) SendMessageToPC(oPC, "Gun cursor: visible attack cursor.");
        else       SendMessageToPC(oPC, "Gun cursor: hidden.");
        DoomArm(oPC);
    }
    else if (sMsg == "/debug")
    {
        int bDebug = !GetLocalInt(oPC, DOOM_VAR_DEBUG);
        SetLocalInt(oPC, DOOM_VAR_DEBUG, bDebug);
        SendMessageToPC(oPC, "Click logging " + (bDebug ? "on." : "off."));
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
    {
        DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT);  // not ours, let it through
        return;
    }

    SetPCChatMessage("");  // swallow the command
    DoomHudUpdate(oPC);
}
