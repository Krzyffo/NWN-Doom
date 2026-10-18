// doom_activate: module OnActivateItem.
// The "1: Fist", "2: Pistol" and "3: Shotgun" items switch weapons; put
// them on F1-F3. Every other item goes to the module's own handler (the
// stock tag-based one if the module had none).

#include "doom_inc"

void main()
{
    object oItem = GetItemActivated();
    int nWeapon = GetLocalInt(oItem, DOOM_WITEM_VAR);
    if (nWeapon <= 0)
    {
        DoomRunOriginal(EVENT_SCRIPT_MODULE_ON_ACTIVATE_ITEM, "x2_mod_def_act");
        return;
    }

    object oPC = GetItemActivator();
    if (DoomIsOn(oPC))
        DoomSelectWeapon(oPC, nWeapon);
    else
        SendMessageToPC(oPC, "Doom mode is off. Type /doom to switch it on.");
}
