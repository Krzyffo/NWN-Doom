// doom_mdeath: creature OnDeath for Doom monsters (spawned by the waves, or
// hostiles of the module converted by DoomConvertCreature).
// First runs the creature's own death script (the stock one for spawned
// monsters), so XP, AI shouts and quest scripts work as before; then rolls
// a Doom-style drop at the corpse and counts the kill for the wave system.

#include "doom_inc"

const int DOOM_PLACED_SHOTGUN_CHANCE = 20;  // % for a module creature to drop the shotgun

void main()
{
    location lCorpse = GetLocation(OBJECT_SELF);
    object oKiller = GetLastKiller();

    string sOwn = GetLocalString(OBJECT_SELF, DOOM_ORIG_DEATH_VAR);
    if (sOwn != "") ExecuteScript(sOwn, OBJECT_SELF);

    object oMod = GetModule();
    int bWaveMonster = GetLocalInt(OBJECT_SELF, DOOM_WAVE_MON_VAR);
    if (bWaveMonster)
    {
        int nAlive = GetLocalInt(oMod, DOOM_ALIVE_VAR) - 1;
        if (nAlive < 0) nAlive = 0;
        SetLocalInt(oMod, DOOM_ALIVE_VAR, nAlive);
    }

    // Drops are Doom pickups, of no use to a player without Doom mode.
    if (!GetIsPC(oKiller) || !DoomIsOn(oKiller)) return;

    // The first kill of wave 2 or later drops the shotgun if the killer
    // does not have it yet, so the shotgun shows up early. Outside waves,
    // module creatures sometimes drop it.
    int bShotgun = bWaveMonster ? GetLocalInt(oMod, DOOM_WAVE_VAR) >= 2
                                : Random(100) < DOOM_PLACED_SHOTGUN_CHANCE;
    if (!GetLocalInt(oKiller, DOOM_VAR_HAS_SG) && bShotgun)
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
}
