// doom_inc: shared constants and helpers for NWN-Doom.
// Script names must stay at 16 characters or fewer (NWN resref limit).

#include "nw_inc_nui"
#include "doom_art"

// ---- Weapons -------------------------------------------------------------
// Numbered like Doom's weapon slots; F1-F3 on the quickbar select them.
const int DOOM_WEAPON_FIST    = 1;
const int DOOM_WEAPON_PISTOL  = 2;
const int DOOM_WEAPON_SHOTGUN = 3;

const int   DOOM_FIST_MIN            = 2;    // Doom fist: 2-20
const int   DOOM_FIST_MAX            = 20;
const int   DOOM_FIST_COOLDOWN_MS    = 550;
const float DOOM_FIST_RANGE          = 2.5;
const int   DOOM_PISTOL_MIN          = 5;    // Doom pistol: 5-15 per bullet
const int   DOOM_PISTOL_MAX          = 15;
const int   DOOM_PISTOL_COOLDOWN_MS  = 400;
const int   DOOM_SHOTGUN_PELLETS     = 7;    // Doom shotgun: 7 pellets of 5-15
const int   DOOM_SHOTGUN_COOLDOWN_MS = 950;
const float DOOM_SHOTGUN_SPLASH      = 2.5;  // stray pellets can hit enemies this close to the target
const float DOOM_WEAPON_RANGE        = 40.0;

// ---- Ammo ----------------------------------------------------------------
const int DOOM_START_BULLETS = 50;
const int DOOM_MAX_BULLETS   = 200;
const int DOOM_MAX_SHELLS    = 50;

// ---- Pickups -------------------------------------------------------------
// Pickups are a stock potion item renamed and tagged with a local string,
// so the prototype needs no custom blueprints.
const string DOOM_PICKUP_RESREF   = "nw_it_mpotion001";
const string DOOM_PICKUP_VAR      = "DOOM_PICKUP";
const string DOOM_PICKUP_CLIP     = "clip";
const string DOOM_PICKUP_SHELLS   = "shells";
const string DOOM_PICKUP_STIMPACK = "stimpack";
const string DOOM_PICKUP_ARMOR    = "armor";
const string DOOM_PICKUP_SHOTGUN  = "shotgun";
const float  DOOM_PICKUP_RADIUS   = 1.75;

// ---- Loop / waves --------------------------------------------------------
const float  DOOM_TICK      = 0.25;
const string DOOM_SPAWN_TAG = "DOOM_SPAWN";  // optional waypoints in the area
const string DOOM_ALIVE_VAR = "DOOM_ALIVE";  // on module: living monsters
const string DOOM_WAVE_VAR  = "DOOM_WAVE";   // on module: current wave number
const string DOOM_NEXT_VAR  = "DOOM_NEXT";   // on module: next wave is scheduled

// ---- Local variable names on the PC --------------------------------------
const string DOOM_VAR_ACTIVE   = "DOOM_ACTIVE";
const string DOOM_VAR_ARMED    = "DOOM_ARMED";
const string DOOM_VAR_WEAPON   = "DOOM_WEAPON";
const string DOOM_VAR_BULLETS  = "DOOM_BULLETS";
const string DOOM_VAR_SHELLS   = "DOOM_SHELLS";
const string DOOM_VAR_ARMOR    = "DOOM_ARMOR";
const string DOOM_VAR_HAS_SG   = "DOOM_HAS_SHOTGUN";
const string DOOM_VAR_LASTSHOT = "DOOM_LASTSHOT";
const string DOOM_VAR_FPS      = "DOOM_FPS";
const string DOOM_VAR_HUD      = "DOOM_HUD";
const string DOOM_VAR_LAST_HP  = "DOOM_LAST_HP";
const string DOOM_VAR_ANIM     = "DOOM_ANIM";
const string DOOM_RANGED_VAR   = "DOOM_RANGED";   // on monsters with their own AI (imps)
const string DOOM_HUD_ID       = "doom_hud";

// ---- Quickbar weapon items -----------------------------------------------
// Usable items the player drags to F1-F3 once; using one fires the module
// OnActivateItem event (doom_activate), which switches weapons.
const string DOOM_WITEM_RESREF = "nw_wmgrd002";   // stock rod, properties replaced
const string DOOM_WITEM_VAR    = "DOOM_WEAPON_SLOT";
const string DOOM_WITEM_TAG    = "DOOM_W_";
const string DOOM_FX_TAG       = "DOOM_FX";

// ---- Helpers -------------------------------------------------------------

int DoomRandomRange(int nMin, int nMax)
{
    return nMin + Random(nMax - nMin + 1);
}

string DoomWeaponName(int nWeapon)
{
    if (nWeapon == DOOM_WEAPON_FIST)    return "Fist";
    if (nWeapon == DOOM_WEAPON_SHOTGUN) return "Shotgun";
    return "Pistol";
}

// Ammo for the current weapon, or -1 for the fist (no ammo shown).
int DoomGetAmmo(object oPC)
{
    int nWeapon = GetLocalInt(oPC, DOOM_VAR_WEAPON);
    if (nWeapon == DOOM_WEAPON_FIST)    return -1;
    if (nWeapon == DOOM_WEAPON_SHOTGUN) return GetLocalInt(oPC, DOOM_VAR_SHELLS);
    return GetLocalInt(oPC, DOOM_VAR_BULLETS);
}

int DoomHasWeapon(object oPC, int nWeapon)
{
    if (nWeapon == DOOM_WEAPON_SHOTGUN) return GetLocalInt(oPC, DOOM_VAR_HAS_SG);
    return nWeapon == DOOM_WEAPON_FIST || nWeapon == DOOM_WEAPON_PISTOL;
}

// Monster damage is a percentage of the target's max HP, using Doom's
// damage numbers as percents (Doom's player has 100 HP). This keeps
// difficulty the same for a level 1 and a level 5 character.
int DoomPercentDamage(object oTarget, int nMinPct, int nMaxPct)
{
    int nDamage = (GetMaxHitPoints(oTarget) * DoomRandomRange(nMinPct, nMaxPct) + 50) / 100;
    if (nDamage < 1) nDamage = 1;
    return nDamage;
}

// ---- Sounds ----
// Doom sounds are played as visual effects: wad_to_hak.py adds rows to
// visualeffects.2da (DOOM_VFX_* in doom_art) whose impact sound is the
// extracted WAV. PlaySound was unreliable: it goes through the playing
// object's action queue, and sounds from freshly created objects never
// reached the client at all. Effects play immediately and positionally.

// Plays effect nVfx (and so its sound) on oSource; follows it if it moves.
void DoomSfx(object oSource, int nVfx)
{
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nVfx), oSource);
}

void DoomSfxAt(location lWhere, int nVfx)
{
    ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(nVfx), lWhere);
}

void DoomMessage(object oPC, string sMsg)
{
    FloatingTextStringOnCreature(sMsg, oPC, FALSE, FALSE);
}

// Pickup messages also go to the chat log, like Doom's message line.
void DoomPickupMessage(object oPC, string sMsg)
{
    DoomMessage(oPC, sMsg);
    SendMessageToPC(oPC, sMsg);
}

// Puts the player into "gun" mode: a targeting cursor where each click
// fires the module OnPlayerTarget event (doom_target).
void DoomArm(object oPC)
{
    SetLocalInt(oPC, DOOM_VAR_ARMED, TRUE);
    EnterTargetingMode(oPC, OBJECT_TYPE_CREATURE | OBJECT_TYPE_DOOR | OBJECT_TYPE_TILE,
                       MOUSECURSOR_ATTACK, MOUSECURSOR_ATTACK);
}

// ---- First-person camera -------------------------------------------------

void DoomClearFx(object oPC)
{
    effect e = GetFirstEffect(oPC);
    while (GetIsEffectValid(e))
    {
        if (GetEffectTag(e) == DOOM_FX_TAG)
            RemoveEffect(oPC, e);
        e = GetNextEffect(oPC);
    }
}

// Set by the /lockcam chat command to let the camera turn freely again.
const string DOOM_VAR_CAM_FREE = "DOOM_CAM_FREE";

void DoomCameraFirstPerson(object oPC)
{
    DoomClearFx(oPC);
    if (GetLocalInt(oPC, DOOM_VAR_CAM_FREE))
    {
        SetCameraMode(oPC, CAMERA_MODE_CHASE_CAMERA);
        SetCameraFlags(oPC, CAMERA_FLAG_DISABLE_ZOOM);
    }
    else
    {
        // Camera rigidly behind the character's facing, and no turning the
        // camera on its own: the view always points where the model looks.
        SetCameraMode(oPC, CAMERA_MODE_STIFF_CHASE_CAMERA);
        SetCameraFlags(oPC, CAMERA_FLAG_DISABLE_TURN | CAMERA_FLAG_DISABLE_ZOOM);
    }
    SetCameraHeight(oPC, 1.75);
    // Pitch near horizontal, distance as close as the client allows.
    SetCameraLimits(oPC, 70.0, 100.0, 0.1, 0.4);
    SetCameraFacing(GetFacing(oPC), 0.2, 88.0, CAMERA_TRANSITION_TYPE_SNAP);

    // Hide the player's own body so it does not block the view.
    effect eInvis = SupernaturalEffect(EffectVisualEffect(VFX_DUR_CUTSCENE_INVISIBILITY));
    ApplyEffectToObject(DURATION_TYPE_PERMANENT, TagEffect(eInvis, DOOM_FX_TAG), oPC);
    SetLocalInt(oPC, DOOM_VAR_FPS, TRUE);
}

void DoomCameraThirdPerson(object oPC)
{
    SetCameraMode(oPC, CAMERA_MODE_CHASE_CAMERA);
    SetCameraFlags(oPC, 0);
    SetCameraHeight(oPC, 0.0);
    SetCameraLimits(oPC, -1.0, -1.0, -1.0, -1.0);
    DoomClearFx(oPC);
    SetLocalInt(oPC, DOOM_VAR_FPS, FALSE);
}

// ---- HUD (NUI) -----------------------------------------------------------
// Doom's status bar and first-person weapon, drawn from the dm_* images in
// nwn_doom.hak. Positions use Doom's own 320x200 screen coordinates (the
// status bar is y 168-200); the window covers y DOOM_ART_TOP..200 and is
// scaled to the screen width, at most 4x.

const string DOOM_VAR_HUD_SCALE = "DOOM_HUD_SCALE";

int DoomPow10(int n)
{
    int r = 1;
    int i;
    for (i = 0; i < n; i++) r *= 10;
    return r;
}

float DoomHudScale(object oPC)
{
    float fW = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_WIDTH));
    if (fW <= 0.0) fW = 1280.0;
    float s = fW / 320.0;
    if (s > 4.0) s = 4.0;
    return s;
}

json DoomHudRect(float x, float y, float w, float h, float s)
{
    return NuiRect(x * s, (y - DOOM_ART_TOP) * s, w * s, h * s);
}

json DoomHudImage(json jList, json jEnabled, json jResRef, json jRect)
{
    return JsonArrayInsert(jList, NuiDrawListImage(jEnabled, jResRef, jRect,
        JsonInt(NUI_ASPECT_STRETCH), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE)));
}

// nDigits digit images, right-aligned so the last one ends at fRightX.
// Slot i (0 = ones) is bound to sBind+i (image) and sBind+i+"e" (shown).
json DoomHudNumberSlots(json jList, string sBind, float fRightX, float fY,
                        float fW, float fH, int nDigits, float s)
{
    int i;
    for (i = 0; i < nDigits; i++)
    {
        string sSlot = sBind + IntToString(i);
        jList = DoomHudImage(jList, NuiBind(sSlot + "e"), NuiBind(sSlot),
            DoomHudRect(fRightX - IntToFloat(i + 1) * fW, fY, fW, fH, s));
    }
    return jList;
}

// Shows nValue in the slots made by DoomHudNumberSlots; negative hides it.
void DoomHudSetNumber(object oPC, int nToken, string sBind, int nValue, int nDigits, string sFont)
{
    if (nValue > 999) nValue = 999;
    int i;
    for (i = 0; i < nDigits; i++)
    {
        string sSlot = sBind + IntToString(i);
        int bShow = nValue >= 0 && (i == 0 || nValue >= DoomPow10(i));
        NuiSetBind(oPC, nToken, sSlot + "e", JsonBool(bShow));
        if (bShow)
            NuiSetBind(oPC, nToken, sSlot, JsonString(sFont + IntToString((nValue / DoomPow10(i)) % 10)));
    }
}

string DoomWeaponIdleFrame(int nWeapon)
{
    if (nWeapon == DOOM_WEAPON_FIST)    return "dm_punga0";
    if (nWeapon == DOOM_WEAPON_SHOTGUN) return "dm_shtga0";
    return "dm_pisga0";
}

// Shows weapon frame sGun plus muzzle flash sFlash ("" for none), unless a
// newer animation (nAnim) has started since this frame was scheduled.
void DoomHudGunFrame(object oPC, int nAnim, string sGun, string sFlash)
{
    if (GetLocalInt(oPC, DOOM_VAR_ANIM) != nAnim) return;
    int nToken = GetLocalInt(oPC, DOOM_VAR_HUD);
    if (!nToken) return;
    float s = GetLocalFloat(oPC, DOOM_VAR_HUD_SCALE);

    if (DoomHasSprite(sGun))
    {
        NuiSetBind(oPC, nToken, "gun", JsonString(sGun));
        NuiSetBind(oPC, nToken, "gun_r", DoomSpriteRect(sGun, s));
    }
    int bFlash = sFlash != "" && DoomHasSprite(sFlash);
    NuiSetBind(oPC, nToken, "flash_on", JsonBool(bFlash));
    if (bFlash)
    {
        NuiSetBind(oPC, nToken, "flash", JsonString(sFlash));
        NuiSetBind(oPC, nToken, "flash_r", DoomSpriteRect(sFlash, s));
    }
}

// Shows the current weapon at rest, cancelling any running animation.
void DoomHudShowWeapon(object oPC)
{
    int nAnim = GetLocalInt(oPC, DOOM_VAR_ANIM) + 1;
    SetLocalInt(oPC, DOOM_VAR_ANIM, nAnim);
    DoomHudGunFrame(oPC, nAnim, DoomWeaponIdleFrame(GetLocalInt(oPC, DOOM_VAR_WEAPON)), "");
}

// Plays the current weapon's attack frames, timed after Doom's states.
void DoomHudFireAnim(object oPC)
{
    int nAnim = GetLocalInt(oPC, DOOM_VAR_ANIM) + 1;
    SetLocalInt(oPC, DOOM_VAR_ANIM, nAnim);
    int nWeapon = GetLocalInt(oPC, DOOM_VAR_WEAPON);

    if (nWeapon == DOOM_WEAPON_FIST)
    {
        DoomHudGunFrame(oPC, nAnim, "dm_pungb0", "");
        DelayCommand(0.10, DoomHudGunFrame(oPC, nAnim, "dm_pungc0", ""));
        DelayCommand(0.20, DoomHudGunFrame(oPC, nAnim, "dm_pungd0", ""));
        DelayCommand(0.35, DoomHudGunFrame(oPC, nAnim, "dm_pungc0", ""));
        DelayCommand(0.45, DoomHudGunFrame(oPC, nAnim, "dm_pungb0", ""));
        DelayCommand(0.55, DoomHudGunFrame(oPC, nAnim, "dm_punga0", ""));
    }
    else if (nWeapon == DOOM_WEAPON_SHOTGUN)
    {
        DoomHudGunFrame(oPC, nAnim, "dm_shtga0", "dm_shtfa0");
        DelayCommand(0.10, DoomHudGunFrame(oPC, nAnim, "dm_shtga0", "dm_shtfb0"));
        DelayCommand(0.20, DoomHudGunFrame(oPC, nAnim, "dm_shtgb0", ""));
        DelayCommand(0.35, DoomHudGunFrame(oPC, nAnim, "dm_shtgc0", ""));
        DelayCommand(0.50, DoomHudGunFrame(oPC, nAnim, "dm_shtgd0", ""));
        DelayCommand(0.65, DoomHudGunFrame(oPC, nAnim, "dm_shtgc0", ""));
        DelayCommand(0.80, DoomHudGunFrame(oPC, nAnim, "dm_shtgb0", ""));
        DelayCommand(0.95, DoomHudGunFrame(oPC, nAnim, "dm_shtga0", ""));
    }
    else
    {
        DoomHudGunFrame(oPC, nAnim, "dm_pisgb0", "dm_pisfa0");
        DelayCommand(0.12, DoomHudGunFrame(oPC, nAnim, "dm_pisgc0", ""));
        DelayCommand(0.25, DoomHudGunFrame(oPC, nAnim, "dm_pisgb0", ""));
        DelayCommand(0.38, DoomHudGunFrame(oPC, nAnim, "dm_pisga0", ""));
    }
}

void DoomHudUpdate(object oPC)
{
    int nToken = GetLocalInt(oPC, DOOM_VAR_HUD);
    if (!nToken) return;

    int nMax = GetMaxHitPoints(oPC);
    int nHpPct = 0;
    if (nMax > 0) nHpPct = (GetCurrentHitPoints(oPC) * 100) / nMax;
    if (nHpPct < 0) nHpPct = 0;

    DoomHudSetNumber(oPC, nToken, "am", DoomGetAmmo(oPC), 3, "dm_sttnum");
    DoomHudSetNumber(oPC, nToken, "hp", nHpPct, 3, "dm_sttnum");
    DoomHudSetNumber(oPC, nToken, "ar", GetLocalInt(oPC, DOOM_VAR_ARMOR), 3, "dm_sttnum");
    DoomHudSetNumber(oPC, nToken, "cur0_", GetLocalInt(oPC, DOOM_VAR_BULLETS), 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "cur1_", GetLocalInt(oPC, DOOM_VAR_SHELLS), 3, "dm_stysnum");

    int n;
    for (n = 2; n <= 7; n++)
    {
        string sFont = "dm_stgnum";
        if (DoomHasWeapon(oPC, n)) sFont = "dm_stysnum";
        NuiSetBind(oPC, nToken, "arm" + IntToString(n), JsonString(sFont + IntToString(n)));
    }
}

void DoomHudOpen(object oPC)
{
    int nOld = NuiFindWindow(oPC, DOOM_HUD_ID);
    if (nOld) NuiDestroy(oPC, nOld);

    float s = DoomHudScale(oPC);
    SetLocalFloat(oPC, DOOM_VAR_HUD_SCALE, s);
    json jOn = JsonBool(TRUE);
    json jList = JsonArray();

    // Weapon and muzzle flash first, so the status bar covers their bottom.
    jList = DoomHudImage(jList, jOn, NuiBind("gun"), NuiBind("gun_r"));
    jList = DoomHudImage(jList, NuiBind("flash_on"), NuiBind("flash"), NuiBind("flash_r"));

    jList = DoomHudImage(jList, jOn, JsonString("dm_stbar"), DoomHudRect(0.0, 168.0, 320.0, 32.0, s));
    jList = DoomHudImage(jList, jOn, JsonString("dm_starms"), DoomHudRect(104.0, 168.0, 40.0, 32.0, s));

    jList = DoomHudNumberSlots(jList, "am", 44.0, 171.0, 14.0, 16.0, 3, s);
    jList = DoomHudNumberSlots(jList, "hp", 90.0, 171.0, 14.0, 16.0, 3, s);
    jList = DoomHudImage(jList, jOn, JsonString("dm_sttprcnt"), DoomHudRect(90.0, 171.0, 14.0, 16.0, s));
    jList = DoomHudNumberSlots(jList, "ar", 221.0, 171.0, 14.0, 16.0, 3, s);
    jList = DoomHudImage(jList, jOn, JsonString("dm_sttprcnt"), DoomHudRect(221.0, 171.0, 14.0, 16.0, s));

    // Arms panel: weapon numbers 2-7, yellow when owned.
    int i;
    for (i = 0; i < 6; i++)
        jList = DoomHudImage(jList, jOn, NuiBind("arm" + IntToString(i + 2)),
            DoomHudRect(111.0 + IntToFloat(i % 3) * 12.0, 172.0 + IntToFloat(i / 3) * 10.0, 4.0, 6.0, s));

    // Ammo table: current / max for bullets, shells, rockets, cells.
    for (i = 0; i < 4; i++)
    {
        float fY = 173.0 + IntToFloat(i) * 6.0;
        jList = DoomHudNumberSlots(jList, "cur" + IntToString(i) + "_", 288.0, fY, 4.0, 6.0, 3, s);
        jList = DoomHudNumberSlots(jList, "max" + IntToString(i) + "_", 314.0, fY, 4.0, 6.0, 3, s);
    }

    float fW = 320.0 * s;
    float fH = (200.0 - DOOM_ART_TOP) * s;
    float fScreenW = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_WIDTH));
    float fScreenH = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_HEIGHT));
    if (fScreenW <= 0.0) fScreenW = 1280.0;
    if (fScreenH <= 0.0) fScreenH = 720.0;

    json jRoot = NuiDrawList(NuiSpacer(), JsonBool(FALSE), jList);
    json jWin = NuiWindow(jRoot, JsonBool(FALSE),
        NuiRect((fScreenW - fW) / 2.0, fScreenH - fH, fW, fH),
        JsonBool(FALSE),   // resizable
        JsonBool(FALSE),   // collapsed
        JsonBool(FALSE),   // closable
        JsonBool(TRUE),    // transparent
        JsonBool(FALSE),   // border
        JsonBool(FALSE));  // accepts input: clicks pass through to the game

    int nToken = NuiCreate(oPC, jWin, DOOM_HUD_ID);
    SetLocalInt(oPC, DOOM_VAR_HUD, nToken);

    // Fixed values: max ammo, and no rockets or cells in this prototype.
    DoomHudSetNumber(oPC, nToken, "max0_", DOOM_MAX_BULLETS, 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "max1_", DOOM_MAX_SHELLS, 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "max2_", 50, 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "max3_", 300, 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "cur2_", 0, 3, "dm_stysnum");
    DoomHudSetNumber(oPC, nToken, "cur3_", 0, 3, "dm_stysnum");

    DoomHudShowWeapon(oPC);
    DoomHudUpdate(oPC);
}


// ---- Quickbar weapon items -----------------------------------------------

object DoomGetWeaponItem(object oPC, int nWeapon)
{
    return GetItemPossessedBy(oPC, DOOM_WITEM_TAG + IntToString(nWeapon));
}

// Gives oPC the usable item that selects nWeapon, once. All three items
// stay in the inventory for good, so whatever the player put on F1-F3
// keeps working across deaths.
object DoomGiveWeaponItem(object oPC, int nWeapon)
{
    object oItem = DoomGetWeaponItem(oPC, nWeapon);
    if (GetIsObjectValid(oItem)) return oItem;

    oItem = CreateItemOnObject(DOOM_WITEM_RESREF, oPC, 1, DOOM_WITEM_TAG + IntToString(nWeapon));
    if (!GetIsObjectValid(oItem))
    {
        WriteTimestampedLogEntry("NWN-Doom: failed to create weapon item " + IntToString(nWeapon));
        return OBJECT_INVALID;
    }
    itemproperty ip = GetFirstItemProperty(oItem);
    while (GetIsItemPropertyValid(ip))
    {
        RemoveItemProperty(oItem, ip);
        ip = GetNextItemProperty(oItem);
    }
    AddItemProperty(DURATION_TYPE_PERMANENT,
        ItemPropertyCastSpell(IP_CONST_CASTSPELL_UNIQUE_POWER_SELF_ONLY,
                              IP_CONST_CASTSPELL_NUMUSES_UNLIMITED_USE), oItem);
    SetName(oItem, IntToString(nWeapon) + ": " + DoomWeaponName(nWeapon));
    SetIdentified(oItem, TRUE);
    SetItemCursedFlag(oItem, TRUE);   // cannot be dropped or sold
    SetPlotFlag(oItem, TRUE);
    SetLocalInt(oItem, DOOM_WITEM_VAR, nWeapon);
    return oItem;
}

// Switches to nWeapon if the player has it. Used by the F1-F3 items
// (doom_activate) and the /1 /2 /3 chat commands.
void DoomSelectWeapon(object oPC, int nWeapon)
{
    if (!DoomHasWeapon(oPC, nWeapon))
    {
        DoomMessage(oPC, "You don't have the " + DoomWeaponName(nWeapon) + " yet.");
    }
    else if (GetLocalInt(oPC, DOOM_VAR_WEAPON) != nWeapon)
    {
        SetLocalInt(oPC, DOOM_VAR_WEAPON, nWeapon);
        DoomHudShowWeapon(oPC);
        DoomHudUpdate(oPC);
    }
    // Using a quickbar item cancels the gun cursor; bring it back.
    DelayCommand(0.1, DoomArm(oPC));
}

// ---- Loadout -------------------------------------------------------------

void DoomApplyShield(object oPC);  // defined with the monster melee code

void DoomResetLoadout(object oPC)
{
    DoomApplyShield(oPC);
    DoomGiveWeaponItem(oPC, DOOM_WEAPON_FIST);
    DoomGiveWeaponItem(oPC, DOOM_WEAPON_PISTOL);
    DoomGiveWeaponItem(oPC, DOOM_WEAPON_SHOTGUN);
    SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_PISTOL);
    SetLocalInt(oPC, DOOM_VAR_BULLETS, DOOM_START_BULLETS);
    SetLocalInt(oPC, DOOM_VAR_SHELLS, 0);
    SetLocalInt(oPC, DOOM_VAR_ARMOR, 0);
    SetLocalInt(oPC, DOOM_VAR_HAS_SG, FALSE);
    SetLocalInt(oPC, DOOM_VAR_LAST_HP, GetCurrentHitPoints(oPC));
}

// ---- Monsters ------------------------------------------------------------

const string DOOM_RESREF_ZOMBIE   = "nw_zombie01";
const string DOOM_RESREF_IMP      = "nw_imp";
const string DOOM_RESREF_SKELETON = "nw_skeleton";
const string DOOM_RESREF_BALOR    = "nw_balorboss";

// Balor: a rare, slow, melee-only damage sponge.
const string DOOM_BALOR_TAG        = "DOOM_BALOR";
const int    DOOM_BALOR_FROM_WAVE  = 3;
const int    DOOM_BALOR_CHANCE     = 25;    // % per wave, at most one alive
const int    DOOM_BALOR_EXTRA_HP   = 190;   // ~300 HP in total

string DoomPickMonster(int nWave)
{
    int nRoll = Random(10);
    if (nWave >= 3 && nRoll < 3) return DOOM_RESREF_SKELETON;
    if (nRoll < 6) return DOOM_RESREF_ZOMBIE;
    return DOOM_RESREF_IMP;
}

// Movement speed change in percent per monster type.
int DoomMonsterSpeed(string sResRef)
{
    if (sResRef == DOOM_RESREF_SKELETON) return -30;
    if (sResRef == DOOM_RESREF_BALOR)    return -40;
    return 50;  // Doom monsters are fast
}

// Makes every special ability (spell-like ability) of oMon unusable.
void DoomStripSpellAbilities(object oMon)
{
    int nCount = GetSpellAbilityCount(oMon);
    int i;
    for (i = 0; i < nCount; i++)
    {
        SetSpellAbilityReady(oMon, i, FALSE);
        int nSpell = GetSpellAbilitySpell(oMon, i);
        int n;
        for (n = 0; n < 10 && GetHasSpell(nSpell, oMon); n++)
            DecrementRemainingSpellUses(oMon, nSpell);
    }
}

// Removes item properties of type nType from everything oMon has equipped,
// including creature weapons and hide.
void DoomStripEquippedProperty(object oMon, int nType)
{
    int nSlot;
    for (nSlot = 0; nSlot <= INVENTORY_SLOT_CARMOUR; nSlot++)
    {
        object oItem = GetItemInSlot(nSlot, oMon);
        if (!GetIsObjectValid(oItem)) continue;
        itemproperty ip = GetFirstItemProperty(oItem);
        while (GetIsItemPropertyValid(ip))
        {
            if (GetItemPropertyType(ip) == nType)
                RemoveItemProperty(oItem, ip);
            ip = GetNextItemProperty(oItem);
        }
    }
}

// ---- Monster melee ----
// NWN still rolls monster attacks (so swings, misses and animations look
// normal), but the player's damage shield soaks the weapon damage and the
// real damage comes from doom_hit, which every monster weapon triggers on
// a hit via the stock "On Hit: Unique Power" tag-based item script.

const string DOOM_HIT_TAG      = "doom_hit";   // = the on-hit script's name
const string DOOM_HIT_MIN_VAR  = "DOOM_HIT_MIN";
const string DOOM_HIT_MAX_VAR  = "DOOM_HIT_MAX";
const string DOOM_HIT_CD_VAR   = "DOOM_HIT_CD";
const string DOOM_HIT_LAST_VAR = "DOOM_HIT_LAST";
const string DOOM_SHIELD_TAG   = "DOOM_SHIELD";

// Melee damage in % of the player's max HP, and the minimum time between
// two damaging hits from the same monster (caps multi-attack creatures).
void DoomSetMeleeStats(object oMon, int nMinPct, int nMaxPct, int nCooldownMs)
{
    SetLocalInt(oMon, DOOM_HIT_MIN_VAR, nMinPct);
    SetLocalInt(oMon, DOOM_HIT_MAX_VAR, nMaxPct);
    SetLocalInt(oMon, DOOM_HIT_CD_VAR, nCooldownMs);
}

void DoomSetupMelee(object oMon, string sResRef)
{
    // Doom numbers as %: zombieman 3-15, imp scratch 3-24, baron 10-80
    // (toned down: the balor is meant to be slow, not a one-shot).
    if (sResRef == DOOM_RESREF_ZOMBIE)        DoomSetMeleeStats(oMon, 3, 12, 1200);
    else if (sResRef == DOOM_RESREF_SKELETON) DoomSetMeleeStats(oMon, 4, 10, 1200);
    else if (sResRef == DOOM_RESREF_IMP)      DoomSetMeleeStats(oMon, 3, 24, 1200);
    else if (sResRef == DOOM_RESREF_BALOR)    DoomSetMeleeStats(oMon, 10, 30, 2000);
    else                                      DoomSetMeleeStats(oMon, 5, 15, 1500);

    // Extra elemental damage, poison, vorpal etc. would bypass the shield.
    DoomStripEquippedProperty(oMon, ITEM_PROPERTY_DAMAGE_BONUS);
    DoomStripEquippedProperty(oMon, ITEM_PROPERTY_ON_HIT_PROPERTIES);
    DoomStripEquippedProperty(oMon, ITEM_PROPERTY_ON_MONSTER_HIT);

    int nSlot;
    for (nSlot = 0; nSlot <= INVENTORY_SLOT_CWEAPON_B; nSlot++)
    {
        if (nSlot != INVENTORY_SLOT_RIGHTHAND && nSlot != INVENTORY_SLOT_LEFTHAND
            && nSlot < INVENTORY_SLOT_CWEAPON_L)
            continue;
        object oWeapon = GetItemInSlot(nSlot, oMon);
        if (!GetIsObjectValid(oWeapon)) continue;
        AddItemProperty(DURATION_TYPE_PERMANENT,
            ItemPropertyOnHitCastSpell(IP_CONST_ONHIT_CASTSPELL_ONHIT_UNIQUEPOWER, 1), oWeapon);
        SetTag(oWeapon, DOOM_HIT_TAG);
    }
}

// Damage reduction that soaks NWN weapon hits (monster weapons are far
// below +20). Scripted damage is magical or fire, so it is not affected.
void DoomApplyShield(object oPC)
{
    effect e = GetFirstEffect(oPC);
    while (GetIsEffectValid(e))
    {
        if (GetEffectTag(e) == DOOM_SHIELD_TAG)
            RemoveEffect(oPC, e);
        e = GetNextEffect(oPC);
    }
    effect eShield = SupernaturalEffect(EffectDamageReduction(50, DAMAGE_POWER_PLUS_TWENTY));
    ApplyEffectToObject(DURATION_TYPE_PERMANENT, TagEffect(eShield, DOOM_SHIELD_TAG), oPC);
}

// The stock balor is an endgame boss (Implosion, Fire Storm, vorpal sword,
// damage reduction). This turns it into Doom's baron: it just walks at you
// and hits hard, and takes a lot of shooting to bring down.
void DoomSetupBalor(object oMon)
{
    // Vorpal and other on-hit effects go in DoomSetupMelee, like for all monsters.
    DoomStripSpellAbilities(oMon);
    DoomStripEquippedProperty(oMon, ITEM_PROPERTY_DAMAGE_REDUCTION);
    ApplyEffectToObject(DURATION_TYPE_PERMANENT,
        SupernaturalEffect(EffectTemporaryHitpoints(DOOM_BALOR_EXTRA_HP)), oMon);
}

object DoomSpawnMonster(string sResRef, location lLoc, object oPC, string sTag = "")
{
    object oMon = CreateObject(OBJECT_TYPE_CREATURE, sResRef, lLoc, FALSE, sTag);
    if (!GetIsObjectValid(oMon))
    {
        WriteTimestampedLogEntry("NWN-Doom: failed to spawn " + sResRef);
        return OBJECT_INVALID;
    }
    SetEventScript(oMon, EVENT_SCRIPT_CREATURE_ON_DEATH, "doom_mdeath");
    DoomSetupMelee(oMon, sResRef);

    // Imps get Doom's dodgeable fireball instead of NWN's spells.
    if (sResRef == DOOM_RESREF_IMP)
        ExecuteScript("doom_imp", oMon);
    if (sResRef == DOOM_RESREF_BALOR)
        DoomSetupBalor(oMon);

    int nSpeed = DoomMonsterSpeed(sResRef);
    effect eSpeed = EffectMovementSpeedIncrease(nSpeed);
    if (nSpeed < 0) eSpeed = EffectMovementSpeedDecrease(-nSpeed);
    ApplyEffectToObject(DURATION_TYPE_PERMANENT, SupernaturalEffect(eSpeed), oMon);

    // Melee monsters charge at once; imps run their own AI (doom_imp).
    if (GetIsObjectValid(oPC) && !GetLocalInt(oMon, DOOM_RANGED_VAR))
        AssignCommand(oMon, ActionAttack(oPC));

    object oMod = GetModule();
    SetLocalInt(oMod, DOOM_ALIVE_VAR, GetLocalInt(oMod, DOOM_ALIVE_VAR) + 1);
    return oMon;
}

// Spawn point number i of a wave: the DOOM_SPAWN waypoints in turn if the
// area has any (nWaypoints), otherwise a random spot 10-15 m from the player.
location DoomWaveSpawnLocation(object oPC, int i, int nWaypoints)
{
    if (nWaypoints > 0)
        return GetLocation(GetNearestObjectByTag(DOOM_SPAWN_TAG, oPC, (i % nWaypoints) + 1));
    float fAngle = IntToFloat(Random(360));
    vector vPos = GetPosition(oPC) + AngleToVector(fAngle) * (10.0 + IntToFloat(Random(6)));
    return Location(GetArea(oPC), vPos, fAngle + 180.0);
}

void DoomSpawnWave(object oPC, int nWave)
{
    object oMod = GetModule();
    SetLocalInt(oMod, DOOM_WAVE_VAR, nWave);
    SetLocalInt(oMod, DOOM_NEXT_VAR, FALSE);
    int nCount = 2 + nWave * 2;

    int nWaypoints = 0;
    while (GetIsObjectValid(GetNearestObjectByTag(DOOM_SPAWN_TAG, oPC, nWaypoints + 1)))
        nWaypoints++;

    int i;
    for (i = 0; i < nCount; i++)
        DoomSpawnMonster(DoomPickMonster(nWave), DoomWaveSpawnLocation(oPC, i, nWaypoints), oPC);

    // Rarely, a balor joins the wave.
    if (nWave >= DOOM_BALOR_FROM_WAVE && Random(100) < DOOM_BALOR_CHANCE
        && !GetIsObjectValid(GetObjectByTag(DOOM_BALOR_TAG)))
    {
        location lBalor = DoomWaveSpawnLocation(oPC, Random(nCount), nWaypoints);
        if (GetIsObjectValid(DoomSpawnMonster(DOOM_RESREF_BALOR, lBalor, oPC, DOOM_BALOR_TAG)))
        {
            DoomMessage(oPC, "WAVE " + IntToString(nWave) + " - A BALOR!");
            return;
        }
    }
    DoomMessage(oPC, "WAVE " + IntToString(nWave));
}


// ---- Loot ----------------------------------------------------------------

object DoomDropPickup(location lLoc, string sKind)
{
    object oItem = CreateObject(OBJECT_TYPE_ITEM, DOOM_PICKUP_RESREF, lLoc);
    if (!GetIsObjectValid(oItem)) return OBJECT_INVALID;
    SetLocalString(oItem, DOOM_PICKUP_VAR, sKind);
    string sName = "Ammo Clip";
    if (sKind == DOOM_PICKUP_SHELLS)   sName = "Shotgun Shells";
    if (sKind == DOOM_PICKUP_STIMPACK) sName = "Stimpack";
    if (sKind == DOOM_PICKUP_ARMOR)    sName = "Armor Bonus";
    if (sKind == DOOM_PICKUP_SHOTGUN)  sName = "Shotgun";
    SetName(oItem, sName);
    SetTag(oItem, "DOOM_PICKUP_" + sKind);
    return oItem;
}

// Applies a pickup to the player. Returns FALSE if it could not be used
// (e.g. ammo already full), so the item stays on the ground like in Doom.
int DoomApplyPickup(object oPC, string sKind)
{
    if (sKind == DOOM_PICKUP_CLIP)
    {
        int n = GetLocalInt(oPC, DOOM_VAR_BULLETS);
        if (n >= DOOM_MAX_BULLETS) return FALSE;
        n += 10; if (n > DOOM_MAX_BULLETS) n = DOOM_MAX_BULLETS;
        SetLocalInt(oPC, DOOM_VAR_BULLETS, n);
        DoomPickupMessage(oPC, "Picked up a clip.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_SHELLS)
    {
        int n = GetLocalInt(oPC, DOOM_VAR_SHELLS);
        if (n >= DOOM_MAX_SHELLS) return FALSE;
        n += 4; if (n > DOOM_MAX_SHELLS) n = DOOM_MAX_SHELLS;
        SetLocalInt(oPC, DOOM_VAR_SHELLS, n);
        DoomPickupMessage(oPC, "Picked up 4 shotgun shells.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_STIMPACK)
    {
        if (GetCurrentHitPoints(oPC) >= GetMaxHitPoints(oPC)) return FALSE;
        int nHeal = GetMaxHitPoints(oPC) / 10; if (nHeal < 1) nHeal = 1;
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectHeal(nHeal), oPC);
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_IMP_HEALING_S), oPC);
        DoomPickupMessage(oPC, "Picked up a stimpack.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_ARMOR)
    {
        int n = GetLocalInt(oPC, DOOM_VAR_ARMOR);
        if (n >= 200) return FALSE;
        n += 5; if (n > 200) n = 200;
        SetLocalInt(oPC, DOOM_VAR_ARMOR, n);
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_IMP_AC_BONUS), oPC);
        DoomPickupMessage(oPC, "Picked up an armor bonus.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_SHOTGUN)
    {
        int bHad = GetLocalInt(oPC, DOOM_VAR_HAS_SG);
        int n = GetLocalInt(oPC, DOOM_VAR_SHELLS) + 8;
        if (n > DOOM_MAX_SHELLS) n = DOOM_MAX_SHELLS;
        SetLocalInt(oPC, DOOM_VAR_SHELLS, n);
        SetLocalInt(oPC, DOOM_VAR_HAS_SG, TRUE);
        if (!bHad)
        {
            SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_SHOTGUN);
            DoomHudShowWeapon(oPC);
        }
        DoomPickupMessage(oPC, "You got the shotgun!");
        return TRUE;
    }
    return FALSE;
}
