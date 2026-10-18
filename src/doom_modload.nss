// doom_modload: module OnModuleLoad.
// This is the only script you have to assign in the toolset; it wires the
// remaining module events to the NWN-Doom scripts at load time. A module
// with its own OnModuleLoad script can instead run this one from it:
//     ExecuteScript("doom_modload", OBJECT_SELF);
// The module's own scripts for the wired events are kept and still run
// (see DoomRunOriginal in doom_inc).

#include "x2_inc_switches"
#include "doom_inc"

// Puts sScript on module event nEvent and remembers the module's own.
void DoomChainEvent(object oMod, int nEvent, string sScript)
{
    string sOld = GetEventScript(oMod, nEvent);
    // Run twice, the event already has ours: keep the original stored then.
    if (sOld != sScript)
        SetLocalString(oMod, DoomOrigEventVar(nEvent), sOld);
    SetEventScript(oMod, nEvent, sScript);
}

void main()
{
    object oMod = GetModule();
    // Keep the stock module setup (tag-based item scripts etc.), unless a
    // module load script of the module's own called us after doing its own.
    if (GetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_MODULE_LOAD) == "doom_modload")
        ExecuteScript("x2_mod_def_load", oMod);
    // Monster weapons rely on tag-based scripts (doom_hit); make sure they are on.
    SetModuleSwitch(MODULE_SWITCH_ENABLE_TAGBASED_SCRIPTS, TRUE);

    DoomChainEvent(oMod, EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER, "doom_enter");
    DoomChainEvent(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET, "doom_target");
    DoomChainEvent(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_DEATH, "doom_pcdeath");
    DoomChainEvent(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT, "doom_chat");
    DoomChainEvent(oMod, EVENT_SCRIPT_MODULE_ON_ACTIVATE_ITEM, "doom_activate");
    WriteTimestampedLogEntry("NWN-Doom: module events wired");
}
