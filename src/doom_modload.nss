// doom_modload: module OnModuleLoad.
// This is the only script you have to assign in the toolset; it wires the
// remaining module events to the NWN-Doom scripts at load time.

#include "x2_inc_switches"

void main()
{
    // Keep the stock module setup (tag-based item scripts etc.).
    ExecuteScript("x2_mod_def_load", OBJECT_SELF);
    // Monster weapons rely on tag-based scripts (doom_hit); make sure they are on.
    SetModuleSwitch(MODULE_SWITCH_ENABLE_TAGBASED_SCRIPTS, TRUE);

    object oMod = GetModule();
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER, "doom_enter");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET, "doom_target");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_DEATH, "doom_pcdeath");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT, "doom_chat");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_ACTIVATE_ITEM, "doom_activate");
    WriteTimestampedLogEntry("NWN-Doom: module events wired");
}
