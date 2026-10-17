// doom_modload: module OnModuleLoad.
// This is the only script you have to assign in the toolset; it wires the
// remaining module events to the NWN-Doom scripts at load time.

void main()
{
    object oMod = GetModule();
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER, "doom_enter");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET, "doom_target");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_DEATH, "doom_pcdeath");
    SetEventScript(oMod, EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT, "doom_chat");
    WriteTimestampedLogEntry("NWN-Doom: module events wired");
}
