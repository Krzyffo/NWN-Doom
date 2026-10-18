// doom_pcdeath: module OnPlayerDeath.
// In Doom mode there is no death panel: after a short pause the player
// respawns at the module start with a fresh pistol loadout, like restarting
// a Doom level. With Doom mode off the module's own death script runs.

#include "doom_inc"

void DoomRespawn(object oPC)
{
    if (!GetIsObjectValid(oPC) || !GetIsDead(oPC)) return;
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectResurrection(), oPC);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectHeal(GetMaxHitPoints(oPC)), oPC);
    AssignCommand(oPC, ClearAllActions());
    AssignCommand(oPC, JumpToLocation(GetStartingLocation()));
    DoomResetLoadout(oPC);
    if (GetLocalInt(oPC, DOOM_VAR_FPS))
        DelayCommand(0.5, DoomCameraFirstPerson(oPC));
    DelayCommand(1.0, DoomArm(oPC));
    DoomHudShowWeapon(oPC);
    DoomHudUpdate(oPC);
}

void main()
{
    object oPC = GetLastPlayerDied();
    if (!DoomIsOn(oPC))
    {
        DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_DEATH, "nw_o0_death");
        return;
    }
    DoomMessage(oPC, "YOU DIED");
    DelayCommand(3.0, DoomRespawn(oPC));
}
