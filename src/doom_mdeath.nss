// doom_mdeath: creature OnDeath for spawned monsters.
// Rolls a Doom-style drop at the corpse, counts the kill for the wave
// system, then runs the stock death script so XP and AI shouts still work.

#include "doom_inc"

void main()
{
    object oMod = GetModule();
    int nAlive = GetLocalInt(oMod, DOOM_ALIVE_VAR) - 1;
    if (nAlive < 0) nAlive = 0;
    SetLocalInt(oMod, DOOM_ALIVE_VAR, nAlive);

    location lCorpse = GetLocation(OBJECT_SELF);
    object oKiller = GetLastKiller();

    // The first kill of wave 2 or later drops the shotgun if the killer
    // does not have it yet, so the shotgun shows up early.
    if (GetIsPC(oKiller) && !GetLocalInt(oKiller, DOOM_VAR_HAS_SG)
        && GetLocalInt(oMod, DOOM_WAVE_VAR) >= 2)
    {
        DoomDropPickup(lCorpse, DOOM_PICKUP_SHOTGUN);
    }
    else
    {
        int nRoll = Random(100);
        if (nRoll < 40)      DoomDropPickup(lCorpse, DOOM_PICKUP_CLIP);
        else if (nRoll < 55) DoomDropPickup(lCorpse, DOOM_PICKUP_SHELLS);
        else if (nRoll < 75) DoomDropPickup(lCorpse, DOOM_PICKUP_STIMPACK);
        else if (nRoll < 85) DoomDropPickup(lCorpse, DOOM_PICKUP_ARMOR);
        // 15%: nothing
    }

    ExecuteScript("nw_c2_default7", OBJECT_SELF);
}
