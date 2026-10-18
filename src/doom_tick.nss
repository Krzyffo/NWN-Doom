// doom_tick: per-player loop, run on the player every DOOM_TICK seconds.
// Collects pickups the player walks over, applies armor absorption,
// refreshes the HUD, gives the area's hostile creatures the Doom treatment,
// and schedules the next wave when the area is clear, where waves are
// enabled (DOOM_WAVES). With Doom mode off it only keeps itself running.

#include "doom_inc"

// Doom-style armor: soaks a third of incoming damage while it lasts.
void DoomAbsorbDamage(object oPC)
{
    int nNow = GetCurrentHitPoints(oPC);
    int nLast = GetLocalInt(oPC, DOOM_VAR_LAST_HP);
    int nArmor = GetLocalInt(oPC, DOOM_VAR_ARMOR);
    if (nNow < nLast && !GetIsDead(oPC))
        DoomFaceHurt(oPC, nLast - nNow);
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

const string DOOM_SCAN_AREA_VAR = "DOOM_SCAN_AREA";  // area of the last hostile scan
const string DOOM_SCAN_TICK_VAR = "DOOM_SCAN_TICK";  // ticks since then
const int    DOOM_SCAN_TICKS    = 8;                 // sweep nearby every 2 s for new spawns

void DoomScanHostiles(object oPC)
{
    object oArea = GetArea(oPC);
    if (!GetIsObjectValid(oArea)) return;  // between areas
    // Just entered: the whole area. Then every 2 s, the creatures nearby.
    if (oArea != GetLocalObject(oPC, DOOM_SCAN_AREA_VAR))
    {
        SetLocalObject(oPC, DOOM_SCAN_AREA_VAR, oArea);
        SetLocalInt(oPC, DOOM_SCAN_TICK_VAR, 0);
        DoomSetupAreaHostiles(oPC, TRUE);
        return;
    }
    int nTick = GetLocalInt(oPC, DOOM_SCAN_TICK_VAR) + 1;
    if (nTick >= DOOM_SCAN_TICKS)
    {
        nTick = 0;
        DoomSetupAreaHostiles(oPC, FALSE);
    }
    SetLocalInt(oPC, DOOM_SCAN_TICK_VAR, nTick);
}

// Delayed wave start; skipped if the player has meanwhile left for an
// area without waves or switched Doom mode off.
void DoomStartWave(object oPC, int nWave)
{
    if (GetIsObjectValid(oPC) && DoomIsOn(oPC) && DoomWavesEnabled(GetArea(oPC)))
        DoomSpawnWave(oPC, nWave);
    else
        SetLocalInt(GetModule(), DOOM_NEXT_VAR, FALSE);
}

void main()
{
    object oPC = OBJECT_SELF;
    if (!GetIsObjectValid(oPC) || !GetLocalInt(oPC, DOOM_VAR_ACTIVE)) return;
    if (!DoomIsOn(oPC))
    {
        DelayCommand(DOOM_TICK, ExecuteScript("doom_tick", oPC));
        return;
    }

    if (!GetIsDead(oPC))
    {
        DoomAbsorbDamage(oPC);
        DoomCollectPickups(oPC);
        DoomScanHostiles(oPC);
    }
    DoomHudUpdate(oPC);

    object oMod = GetModule();
    if (DoomWavesEnabled(GetArea(oPC))
        && GetLocalInt(oMod, DOOM_ALIVE_VAR) <= 0
        && !GetLocalInt(oMod, DOOM_NEXT_VAR))
    {
        SetLocalInt(oMod, DOOM_NEXT_VAR, TRUE);
        int nWave = GetLocalInt(oMod, DOOM_WAVE_VAR);
        if (nWave == 0)
            DelayCommand(3.0, DoomStartWave(oPC, 1));
        else
        {
            DoomMessage(oPC, "Area clear. Next wave in 5 seconds.");
            DelayCommand(5.0, DoomStartWave(oPC, nWave + 1));
        }
    }

    DelayCommand(DOOM_TICK, ExecuteScript("doom_tick", oPC));
}
