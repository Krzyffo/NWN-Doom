// doom_hit: tag-based item script for monster weapons (item tag "doom_hit").
// Runs on the attacking monster each time one of its weapons hits, via the
// "On Hit: Unique Power" property added in DoomSetupMelee. Deals the
// monster's melee damage as a percentage of the player's max HP; NWN's own
// weapon damage is soaked by the player's damage shield.

#include "x2_inc_switches"
#include "doom_inc"

void main()
{
    if (GetUserDefinedItemEventNumber() != X2_ITEM_EVENT_ONHITCAST) return;

    object oMon = OBJECT_SELF;
    object oTarget = GetSpellTargetObject();
    if (!GetIsPC(oTarget) || GetIsDead(oTarget)) return;

    // One damaging hit per cooldown, however many attacks NWN gives it.
    int nNow = GetMicrosecondCounter();
    int nLast = GetLocalInt(oMon, DOOM_HIT_LAST_VAR);
    int nSinceMs = (nNow - nLast) / 1000;
    if (nLast != 0 && nSinceMs >= 0 && nSinceMs < GetLocalInt(oMon, DOOM_HIT_CD_VAR)) return;
    SetLocalInt(oMon, DOOM_HIT_LAST_VAR, nNow);

    int nDamage = DoomPercentDamage(oTarget, GetLocalInt(oMon, DOOM_HIT_MIN_VAR),
                                    GetLocalInt(oMon, DOOM_HIT_MAX_VAR));
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectDamage(nDamage, DAMAGE_TYPE_MAGICAL), oTarget);
}
