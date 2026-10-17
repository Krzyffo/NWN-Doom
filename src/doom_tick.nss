// doom_tick: per-player loop, run on the player every DOOM_TICK seconds.
// Collects pickups the player walks over, applies armor absorption,
// refreshes the HUD, and schedules the next wave when the area is clear.

#include "doom_inc"

// Doom-style armor: soaks a third of incoming damage while it lasts.
void DoomAbsorbDamage(object oPC)
{
    int nNow = GetCurrentHitPoints(oPC);
    int nLast = GetLocalInt(oPC, DOOM_VAR_LAST_HP);
    int nArmor = GetLocalInt(oPC, DOOM_VAR_ARMOR);
    if (nNow < nLast && nArmor > 0 && !GetIsDead(oPC))
    {
        int nSoak = (nLast - nNow) / 3;
        if (nSoak > nArmor) nSoak = nArmor;
        if (nSoak > 0)
        {
            ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectHeal(nSoak), oPC);
            SetLocalInt(oPC, DOOM_VAR_ARMOR, nArmor - nSoak);
            nNow += nSoak;
        }
    }
    SetLocalInt(oPC, DOOM_VAR_LAST_HP, nNow);
}

void DoomCollectPickups(object oPC)
{
    location lHere = GetLocation(oPC);
    object oItem = GetFirstObjectInShape(SHAPE_SPHERE, DOOM_PICKUP_RADIUS, lHere, FALSE, OBJECT_TYPE_ITEM);
    while (GetIsObjectValid(oItem))
    {
        string sKind = GetLocalString(oItem, DOOM_PICKUP_VAR);
        if (sKind != "" && DoomApplyPickup(oPC, sKind))
            DestroyObject(oItem);
        oItem = GetNextObjectInShape(SHAPE_SPHERE, DOOM_PICKUP_RADIUS, lHere, FALSE, OBJECT_TYPE_ITEM);
    }
}

void main()
{
    object oPC = OBJECT_SELF;
    if (!GetIsObjectValid(oPC) || !GetLocalInt(oPC, DOOM_VAR_ACTIVE)) return;

    if (!GetIsDead(oPC))
    {
        DoomAbsorbDamage(oPC);
        DoomCollectPickups(oPC);
    }
    DoomHudUpdate(oPC);

    object oMod = GetModule();
    if (GetLocalInt(oMod, DOOM_WAVE_VAR) > 0
        && GetLocalInt(oMod, DOOM_ALIVE_VAR) <= 0
        && !GetLocalInt(oMod, DOOM_NEXT_VAR))
    {
        SetLocalInt(oMod, DOOM_NEXT_VAR, TRUE);
        DoomMessage(oPC, "Area clear. Next wave in 5 seconds.");
        DelayCommand(5.0, DoomSpawnWave(oPC, GetLocalInt(oMod, DOOM_WAVE_VAR) + 1));
    }

    DelayCommand(DOOM_TICK, ExecuteScript("doom_tick", oPC));
}
