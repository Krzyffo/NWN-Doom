// doom_pcdeath: module OnPlayerDeath.
// No death panel: after a short pause the player respawns at the module
// start with a fresh pistol loadout, like restarting a Doom level.

#include "doom_inc"

void DoomRespawn(object oPC)
{
    if (!GetIsObjectValid(oPC)) return;
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectResurrection(), oPC);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectHeal(GetMaxHitPoints(oPC)), oPC);
    AssignCommand(oPC, ClearAllActions());
    AssignCommand(oPC, JumpToLocation(GetStartingLocation()));
    DoomResetLoadout(oPC);
    if (GetLocalInt(oPC, DOOM_VAR_FPS))
        DelayCommand(0.5, DoomCameraFirstPerson(oPC));
    DelayCommand(1.0, DoomArm(oPC));
    DoomHudUpdate(oPC);
}

void main()
{
    object oPC = GetLastPlayerDied();
    DoomMessage(oPC, "YOU DIED");
    DelayCommand(3.0, DoomRespawn(oPC));
}
