// doom_target: module OnPlayerTarget. Every click in gun mode lands here.
// Fires the current weapon at the clicked creature or spot (hitscan, no
// attack roll), uses doors, then puts the player back into gun mode.

#include "doom_inc"

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

int DoomCanShoot(object oPC, object oTarget)
{
    if (!GetIsObjectValid(oTarget) || GetIsDead(oTarget)) return FALSE;
    if (GetDistanceBetween(oPC, oTarget) > DOOM_WEAPON_RANGE) return FALSE;
    return LineOfSightObject(oPC, oTarget);
}

void DoomPunch(object oPC, object oTarget)
{
    // Like Doom, the punch only makes a sound when it connects.
    if (DoomCanShoot(oPC, oTarget) && GetDistanceBetween(oPC, oTarget) <= DOOM_FIST_RANGE)
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_PUNCH);  // at the spot: the first-person body is invisible
        DoomHit(oPC, oTarget, DoomRandomRange(DOOM_FIST_MIN, DOOM_FIST_MAX));
    }
}

void DoomFirePistol(object oPC, object oTarget, location lAim)
{
    if (DoomCanShoot(oPC, oTarget))
        DoomHit(oPC, oTarget, DoomRandomRange(DOOM_PISTOL_MIN, DOOM_PISTOL_MAX));
    else
        ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_COM_SPARKS_PARRY), lAim);
}

void DoomFireShotgun(object oPC, object oTarget, location lAim)
{
    int nPellets = DOOM_SHOTGUN_PELLETS;
    int bHitMain = DoomCanShoot(oPC, oTarget);

    // Roughly two thirds of the pellets land on the creature you clicked;
    // the rest spray into whatever else is standing close to the aim point.
    int nMain = 0;
    if (bHitMain)
    {
        nMain = (nPellets * 2) / 3 + Random(2);
        int nDamage = 0;
        int i;
        for (i = 0; i < nMain; i++) nDamage += DoomRandomRange(DOOM_PISTOL_MIN, DOOM_PISTOL_MAX);
        DoomHit(oPC, oTarget, nDamage);
    }

    int nStray = nPellets - nMain;
    object oOther = GetFirstObjectInShape(SHAPE_SPHERE, DOOM_SHOTGUN_SPLASH, lAim, TRUE, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(oOther) && nStray > 0)
    {
        if (oOther != oTarget && oOther != oPC && GetIsEnemy(oOther, oPC) && DoomCanShoot(oPC, oOther))
        {
            DoomHit(oPC, oOther, DoomRandomRange(DOOM_PISTOL_MIN, DOOM_PISTOL_MAX) * 2);
            nStray -= 2;
        }
        oOther = GetNextObjectInShape(SHAPE_SPHERE, DOOM_SHOTGUN_SPLASH, lAim, TRUE, OBJECT_TYPE_CREATURE);
    }
    if (!bHitMain)
        ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_COM_SPARKS_PARRY), lAim);
}

// Doors are "used" by clicking them up close, like Doom's use key.
void DoomUseDoor(object oPC, object oDoor)
{
    if (GetDistanceBetween(oPC, oDoor) > 3.0)
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

void main()
{
    object oPC = GetLastPlayerToSelectTarget();
    object oTarget = GetTargetingModeSelectedObject();

    // Right-click / Escape cancels targeting: holster until "/gun".
    if (!GetIsObjectValid(oTarget))
    {
        SetLocalInt(oPC, DOOM_VAR_ARMED, FALSE);
        SendMessageToPC(oPC, "Gun holstered. Type /gun to re-arm.");
        return;
    }

    if (GetIsDead(oPC)) return;

    if (GetObjectType(oTarget) == OBJECT_TYPE_DOOR)
    {
        DoomUseDoor(oPC, oTarget);
        DoomArm(oPC);
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
    location lAim = Location(GetArea(oPC), GetTargetingModeSelectedPosition(), 0.0);
    object oVictim = OBJECT_INVALID;
    if (GetObjectType(oTarget) == OBJECT_TYPE_CREATURE && oTarget != oPC)
        oVictim = oTarget;

    DoomHudFireAnim(oPC);
    if (nWeapon == DOOM_WEAPON_FIST)
    {
        DoomPunch(oPC, oVictim);
    }
    else if (nWeapon == DOOM_WEAPON_SHOTGUN)
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_SHOTGUN);  // at the spot: the first-person body is invisible
        SetLocalInt(oPC, DOOM_VAR_SHELLS, GetLocalInt(oPC, DOOM_VAR_SHELLS) - 1);
        DoomFireShotgun(oPC, oVictim, lAim);
    }
    else
    {
        DoomSfxAt(GetLocation(oPC), DOOM_VFX_PISTOL);  // at the spot: the first-person body is invisible
        SetLocalInt(oPC, DOOM_VAR_BULLETS, GetLocalInt(oPC, DOOM_VAR_BULLETS) - 1);
        DoomFirePistol(oPC, oVictim, lAim);
    }

    DoomHudUpdate(oPC);
    DoomArm(oPC);
}
