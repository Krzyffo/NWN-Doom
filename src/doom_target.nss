// doom_target: module OnPlayerTarget. Every click in gun mode lands here.
// Clicking anywhere fires the current weapon straight ahead along the
// player's facing, which the locked first-person camera keeps at the centre
// of the screen (the crosshair). Shots are hitscan rays: the first monster
// on the line is hit, no attack roll. Clicking a door, chest, item or
// friendly NPC up close uses it instead. Then the player goes back into gun
// mode. Clicks from other targeting modes, or with Doom mode off, go to the
// module's own OnPlayerTarget script.

#include "doom_inc"

const float DOOM_USE_RANGE = 3.0;  // m: doors, chests, items and NPCs closer than this are used

void DoomHit(object oPC, object oVictim, int nDamage)
{
    // Applied as the player: this script runs on the module, and without
    // AssignCommand the module would get the kill (no XP, no shotgun drop).
    AssignCommand(oPC, ApplyEffectToObject(DURATION_TYPE_INSTANT,
        EffectDamage(nDamage, DAMAGE_TYPE_PIERCING), oVictim));
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_COM_BLOOD_REG_RED), oVictim);
    // Shooting a monster always draws its attention, Doom style
    // (except imps, which keep their distance on their own).
    if (!GetIsDead(oVictim) && !GetLocalInt(oVictim, DOOM_RANGED_VAR))
        AssignCommand(oVictim, ActionAttack(oPC));
}

// ---- Rays ------------------------------------------------------------------
// NWScript has no raycast, so a ray is tested against every creature in
// range: a creature is hit if it is in front of the player, within its
// body radius (+ aim assist) of the line, and in line of sight. The nearest
// one along the line wins. Players, and creatures that are not hostile to
// the shooter (friendly or neutral NPCs, henchmen, summons), are never hit.

float DoomCreatureRadius(object oCreature)
{
    int nSize = GetCreatureSize(oCreature);
    if (nSize <= CREATURE_SIZE_SMALL)  return 0.4;
    if (nSize == CREATURE_SIZE_MEDIUM) return 0.6;
    if (nSize == CREATURE_SIZE_LARGE)  return 1.0;
    return 1.5;
}

// Doom's bullet spread: two random numbers subtracted, so small offsets
// are likelier than large ones, within +-DOOM_SPREAD_DEG.
float DoomSpread()
{
    return IntToFloat(Random(1001) - Random(1001)) / 1000.0 * DOOM_SPREAD_DEG;
}

object DoomTraceRay(object oPC, float fAngle, float fRange, float fAssist)
{
    vector vFrom = GetPosition(oPC);
    vector vDir = AngleToVector(fAngle);
    object oBest = OBJECT_INVALID;
    float fBest = fRange + 1.0;

    // Search a little past the range so big creatures at the edge count.
    float fSearch = fRange + 2.0;
    location lHere = GetLocation(oPC);
    object o = GetFirstObjectInShape(SHAPE_SPHERE, fSearch, lHere, FALSE, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(o))
    {
        if (o != oPC && !GetIsPC(o) && !GetIsDead(o) && GetIsReactionTypeHostile(o, oPC))
        {
            vector vTo = GetPosition(o) - vFrom;
            float fAlong = vTo.x * vDir.x + vTo.y * vDir.y;
            float fRadius = DoomCreatureRadius(o);
            if (fAlong > 0.0 && fAlong - fRadius <= fRange && fAlong < fBest)
            {
                float fPerp = fabs(vTo.x * vDir.y - vTo.y * vDir.x);
                if (fPerp <= fRadius + fAssist && LineOfSightObject(oPC, o))
                {
                    oBest = o;
                    fBest = fAlong;
                }
            }
        }
        o = GetNextObjectInShape(SHAPE_SPHERE, fSearch, lHere, FALSE, OBJECT_TYPE_CREATURE);
    }
    return oBest;
}

// Where a missed shot hits a wall (or runs out of range), for the spark.
location DoomRayEnd(object oPC, float fAngle, float fRange)
{
    vector vEye = GetPosition(oPC);
    vEye.z += DOOM_EYE_HEIGHT;
    vector vDir = AngleToVector(fAngle);
    vector vLast = vEye;
    float f;
    for (f = 1.5; f <= fRange; f += 1.5)
    {
        vector v = vEye + vDir * f;
        if (!LineOfSightVector(vEye, v)) break;
        vLast = v;
    }
    return Location(GetArea(oPC), vLast, 0.0);
}

// Fires one bullet or pellet along fAngle; returns TRUE if it hit.
int DoomFireRay(object oPC, float fAngle, int nMin, int nMax)
{
    object oVictim = DoomTraceRay(oPC, fAngle, DOOM_WEAPON_RANGE, DOOM_AIM_ASSIST);
    if (GetIsObjectValid(oVictim))
    {
        DoomHit(oPC, oVictim, DoomRandomRange(nMin, nMax));
        return TRUE;
    }
    ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_COM_SPARKS_PARRY),
                          DoomRayEnd(oPC, fAngle, DOOM_WEAPON_RANGE));
    return FALSE;
}

// ---- Weapons ---------------------------------------------------------------

void DoomPunch(object oPC)
{
    object oVictim = DoomTraceRay(oPC, GetFacing(oPC), DOOM_FIST_RANGE, DOOM_FIST_ASSIST);
    // Like Doom, the punch only makes a sound when it connects.
    if (GetIsObjectValid(oVictim))
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_PUNCH);  // at the spot: the first-person body is invisible
        DoomHit(oPC, oVictim, DoomRandomRange(DOOM_FIST_MIN, DOOM_FIST_MAX));
    }
}

// Like Doom, the first shot is dead accurate; holding the trigger spreads.
void DoomFirePistol(object oPC, int bRefire)
{
    float fAngle = GetFacing(oPC);
    if (bRefire) fAngle += DoomSpread();
    DoomFireRay(oPC, fAngle, DOOM_PISTOL_MIN, DOOM_PISTOL_MAX);
}

// Doom's shotgun: 7 pellets of 5-15, each with its own spread.
void DoomFireShotgun(object oPC)
{
    float fFacing = GetFacing(oPC);
    int i;
    for (i = 0; i < DOOM_SHOTGUN_PELLETS; i++)
        DoomFireRay(oPC, fFacing + DoomSpread(), DOOM_PISTOL_MIN, DOOM_PISTOL_MAX);
}

// Doors are "used" by clicking them up close, like Doom's use key.
void DoomUseDoor(object oPC, object oDoor)
{
    if (GetDistanceBetween(oPC, oDoor) > DOOM_USE_RANGE)
    {
        DoomMessage(oPC, "Too far away.");
        return;
    }
    if (GetLocked(oDoor))
    {
        string sKey = GetLockKeyTag(oDoor);
        if (sKey != "" && GetIsObjectValid(GetItemPossessedBy(oPC, sKey)))
            SetLocked(oDoor, FALSE);
        else
        {
            DoomMessage(oPC, "You need a key to open this door.");
            return;
        }
    }
    if (GetIsOpen(oDoor))
        AssignCommand(oDoor, ActionCloseDoor(oDoor));
    else
        AssignCommand(oDoor, ActionOpenDoor(oDoor));
}

// Clicking something usable up close, like Doom's use key: friendly NPCs
// are talked to, usable placeables (chests, levers) used, items picked up.
// Returns FALSE if oTarget is none of these, so the click fires.
int DoomUseObject(object oPC, object oTarget)
{
    if (GetDistanceBetween(oPC, oTarget) > DOOM_USE_RANGE) return FALSE;
    int nType = GetObjectType(oTarget);
    if (nType == OBJECT_TYPE_CREATURE)
    {
        if (GetIsPC(oTarget) || GetIsDead(oTarget) || GetIsReactionTypeHostile(oTarget, oPC))
            return FALSE;
        AssignCommand(oPC, ClearAllActions());
        AssignCommand(oPC, ActionStartConversation(oTarget));
        return TRUE;
    }
    if (nType == OBJECT_TYPE_PLACEABLE)
    {
        if (!GetUseableFlag(oTarget)) return FALSE;
        AssignCommand(oPC, ClearAllActions());
        AssignCommand(oPC, ActionInteractObject(oTarget));
        return TRUE;
    }
    if (nType == OBJECT_TYPE_ITEM)
    {
        AssignCommand(oPC, ClearAllActions());
        AssignCommand(oPC, ActionPickUpItem(oTarget));
        return TRUE;
    }
    return FALSE;
}

void main()
{
    object oPC = GetLastPlayerToSelectTarget();
    object oTarget = GetTargetingModeSelectedObject();

    // Not our gun cursor: Doom mode is off, the player holstered, or the
    // module started its own targeting mode.
    if (!DoomIsOn(oPC) || !GetLocalInt(oPC, DOOM_VAR_ARMED))
    {
        DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET);
        return;
    }

    if (GetLocalInt(oPC, DOOM_VAR_DEBUG))
    {
        string sWhat = "nothing (cancelled)";
        if (GetIsObjectValid(oTarget))
            sWhat = "object type " + IntToString(GetObjectType(oTarget)) + " '" + GetName(oTarget) + "'";
        SendMessageToPC(oPC, "[debug] click reached doom_target: " + sWhat);
    }

    // Right-click / Escape cancels targeting: holster until "/gun".
    if (!GetIsObjectValid(oTarget))
    {
        SetLocalInt(oPC, DOOM_VAR_ARMED, FALSE);
        SendMessageToPC(oPC, "Gun holstered. Type /gun to re-arm.");
        return;
    }

    if (GetIsDead(oPC)) return;

    // A door right in front of you is used rather than shot.
    if (GetObjectType(oTarget) == OBJECT_TYPE_DOOR && GetDistanceBetween(oPC, oTarget) <= DOOM_USE_RANGE)
    {
        DoomUseDoor(oPC, oTarget);
        DoomArm(oPC);
        return;
    }
    if (DoomUseObject(oPC, oTarget))
    {
        // Back to gun mode once the conversation or container has opened.
        DelayCommand(0.5, DoomArm(oPC));
        return;
    }

    int nWeapon = GetLocalInt(oPC, DOOM_VAR_WEAPON);
    int nCooldown = DOOM_PISTOL_COOLDOWN_MS;
    if (nWeapon == DOOM_WEAPON_SHOTGUN) nCooldown = DOOM_SHOTGUN_COOLDOWN_MS;
    if (nWeapon == DOOM_WEAPON_FIST)    nCooldown = DOOM_FIST_COOLDOWN_MS;

    // Fire-rate limit. The counter can wrap, so a negative delta also fires.
    int nNow = GetMicrosecondCounter();
    int nDelta = (nNow - GetLocalInt(oPC, DOOM_VAR_LASTSHOT)) / 1000;
    if (nDelta >= 0 && nDelta < nCooldown)
    {
        DoomArm(oPC);
        return;
    }
    int bRefire = nDelta >= 0 && nDelta < DOOM_REFIRE_MS;

    if (nWeapon != DOOM_WEAPON_FIST && DoomGetAmmo(oPC) <= 0)
    {
        DoomMessage(oPC, "Out of ammo!");
        // Like Doom, fall back to the next best weapon that still works.
        if (nWeapon == DOOM_WEAPON_SHOTGUN && GetLocalInt(oPC, DOOM_VAR_BULLETS) > 0)
            SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_PISTOL);
        else
            SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_FIST);
        DoomHudShowWeapon(oPC);
        DoomHudUpdate(oPC);
        DoomArm(oPC);
        return;
    }

    SetLocalInt(oPC, DOOM_VAR_LASTSHOT, nNow);
    DoomHudFireAnim(oPC);
    DoomFaceShow(oPC, "kill", DOOM_FACE_FIRE_MS);  // Doomguy's rampage face
    if (nWeapon == DOOM_WEAPON_FIST)
    {
        DoomPunch(oPC);
    }
    else if (nWeapon == DOOM_WEAPON_SHOTGUN)
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_SHOTGUN);  // at the spot: the first-person body is invisible
        SetLocalInt(oPC, DOOM_VAR_SHELLS, GetLocalInt(oPC, DOOM_VAR_SHELLS) - 1);
        DoomFireShotgun(oPC);
    }
    else
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_PISTOL);  // at the spot: the first-person body is invisible
        SetLocalInt(oPC, DOOM_VAR_BULLETS, GetLocalInt(oPC, DOOM_VAR_BULLETS) - 1);
        DoomFirePistol(oPC, bRefire);
    }

    DoomHudUpdate(oPC);
    DoomArm(oPC);
}
