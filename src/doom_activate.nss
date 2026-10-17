// doom_activate: module OnActivateItem.
// The "1: Fist", "2: Pistol" and "3: Shotgun" items switch weapons; put
// them on F1-F3. Every other item goes to the stock handler.

#include "doom_inc"

void main()
{
    object oItem = GetItemActivated();
    int nWeapon = GetLocalInt(oItem, DOOM_WITEM_VAR);
    if (nWeapon > 0)
        DoomSelectWeapon(GetItemActivator(), nWeapon);
    else
        ExecuteScript("x2_mod_def_act", OBJECT_SELF);
}
