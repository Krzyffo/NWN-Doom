// doom_inc: shared constants and helpers for NWN-Doom.
// Script names must stay at 16 characters or fewer (NWN resref limit).

#include "nw_inc_nui"

// ---- Weapons -------------------------------------------------------------
const int DOOM_WEAPON_PISTOL  = 1;
const int DOOM_WEAPON_SHOTGUN = 2;

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
const string DOOM_HUD_ID       = "doom_hud";
const string DOOM_FX_TAG       = "DOOM_FX";

// ---- Helpers -------------------------------------------------------------

int DoomRandomRange(int nMin, int nMax)
{
    return nMin + Random(nMax - nMin + 1);
}

string DoomWeaponName(int nWeapon)
{
    if (nWeapon == DOOM_WEAPON_SHOTGUN) return "SHOTGUN";
    return "PISTOL";
}

int DoomGetAmmo(object oPC)
{
    if (GetLocalInt(oPC, DOOM_VAR_WEAPON) == DOOM_WEAPON_SHOTGUN)
        return GetLocalInt(oPC, DOOM_VAR_SHELLS);
    return GetLocalInt(oPC, DOOM_VAR_BULLETS);
}

void DoomMessage(object oPC, string sMsg)
{
    FloatingTextStringOnCreature(sMsg, oPC, FALSE, FALSE);
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

void DoomCameraFirstPerson(object oPC)
{
    DoomClearFx(oPC);
    SetCameraMode(oPC, CAMERA_MODE_CHASE_CAMERA);
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
    SetCameraHeight(oPC, 0.0);
    SetCameraLimits(oPC, -1.0, -1.0, -1.0, -1.0);
    DoomClearFx(oPC);
    SetLocalInt(oPC, DOOM_VAR_FPS, FALSE);
}

// ---- HUD (NUI) -----------------------------------------------------------

json DoomHudCell(string sCaption, string sBind)
{
    json jValue = NuiLabel(NuiBind(sBind), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE));
    jValue = NuiStyleForegroundColor(jValue, NuiColor(220, 40, 30));
    jValue = NuiHeight(jValue, 34.0);
    json jCaption = NuiLabel(JsonString(sCaption), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_MIDDLE));
    jCaption = NuiStyleForegroundColor(jCaption, NuiColor(200, 200, 200));
    jCaption = NuiHeight(jCaption, 18.0);

    json jCol = JsonArray();
    jCol = JsonArrayInsert(jCol, jValue);
    jCol = JsonArrayInsert(jCol, jCaption);
    return NuiWidth(NuiCol(jCol), 130.0);
}

void DoomHudOpen(object oPC)
{
    int nOld = NuiFindWindow(oPC, DOOM_HUD_ID);
    if (nOld) NuiDestroy(oPC, nOld);

    json jRow = JsonArray();
    jRow = JsonArrayInsert(jRow, DoomHudCell("AMMO",   "ammo"));
    jRow = JsonArrayInsert(jRow, DoomHudCell("HEALTH", "health"));
    jRow = JsonArrayInsert(jRow, DoomHudCell("ARMOR",  "armor"));
    jRow = JsonArrayInsert(jRow, DoomHudCell("ARMS",   "weapon"));
    jRow = JsonArrayInsert(jRow, DoomHudCell("WAVE",   "wave"));

    float fW = 700.0;
    float fH = 90.0;
    float fScreenW = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_WIDTH));
    float fScreenH = IntToFloat(GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GUI_HEIGHT));
    if (fScreenW <= 0.0) fScreenW = 1280.0;
    if (fScreenH <= 0.0) fScreenH = 720.0;

    json jWin = NuiWindow(NuiRow(jRow), JsonBool(FALSE),
        NuiRect((fScreenW - fW) / 2.0, fScreenH - fH - 10.0, fW, fH),
        JsonBool(FALSE),   // resizable
        JsonBool(FALSE),   // collapsed
        JsonBool(FALSE),   // closable
        JsonBool(TRUE),    // transparent
        JsonBool(FALSE),   // border
        JsonBool(FALSE));  // accepts input: clicks pass through to the game

    int nToken = NuiCreate(oPC, jWin, DOOM_HUD_ID);
    SetLocalInt(oPC, DOOM_VAR_HUD, nToken);
}

void DoomHudUpdate(object oPC)
{
    int nToken = GetLocalInt(oPC, DOOM_VAR_HUD);
    if (!nToken) return;

    int nMax = GetMaxHitPoints(oPC);
    int nHpPct = 0;
    if (nMax > 0) nHpPct = (GetCurrentHitPoints(oPC) * 100) / nMax;

    NuiSetBind(oPC, nToken, "ammo",   JsonString(IntToString(DoomGetAmmo(oPC))));
    NuiSetBind(oPC, nToken, "health", JsonString(IntToString(nHpPct) + "%"));
    NuiSetBind(oPC, nToken, "armor",  JsonString(IntToString(GetLocalInt(oPC, DOOM_VAR_ARMOR)) + "%"));
    NuiSetBind(oPC, nToken, "weapon", JsonString(DoomWeaponName(GetLocalInt(oPC, DOOM_VAR_WEAPON))));
    NuiSetBind(oPC, nToken, "wave",   JsonString(IntToString(GetLocalInt(GetModule(), DOOM_WAVE_VAR))));
}

// ---- Loadout -------------------------------------------------------------

void DoomResetLoadout(object oPC)
{
    SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_PISTOL);
    SetLocalInt(oPC, DOOM_VAR_BULLETS, DOOM_START_BULLETS);
    SetLocalInt(oPC, DOOM_VAR_SHELLS, 0);
    SetLocalInt(oPC, DOOM_VAR_ARMOR, 0);
    SetLocalInt(oPC, DOOM_VAR_HAS_SG, FALSE);
    SetLocalInt(oPC, DOOM_VAR_LAST_HP, GetCurrentHitPoints(oPC));
}

// ---- Monsters ------------------------------------------------------------

string DoomPickMonster(int nWave)
{
    int nRoll = Random(10);
    if (nWave >= 3 && nRoll < 3) return "nw_skeleton";
    if (nRoll < 6) return "nw_zombie01";
    return "nw_imp";
}

object DoomSpawnMonster(string sResRef, location lLoc, object oPC)
{
    object oMon = CreateObject(OBJECT_TYPE_CREATURE, sResRef, lLoc);
    if (!GetIsObjectValid(oMon))
    {
        WriteTimestampedLogEntry("NWN-Doom: failed to spawn " + sResRef);
        return OBJECT_INVALID;
    }
    SetEventScript(oMon, EVENT_SCRIPT_CREATURE_ON_DEATH, "doom_mdeath");
    // Doom monsters are fast and never give up.
    ApplyEffectToObject(DURATION_TYPE_PERMANENT,
        SupernaturalEffect(EffectMovementSpeedIncrease(50)), oMon);
    if (GetIsObjectValid(oPC))
        AssignCommand(oMon, ActionAttack(oPC));

    object oMod = GetModule();
    SetLocalInt(oMod, DOOM_ALIVE_VAR, GetLocalInt(oMod, DOOM_ALIVE_VAR) + 1);
    return oMon;
}

// Spawns wave nWave: at DOOM_SPAWN waypoints if the area has any,
// otherwise in a ring around the player.
void DoomSpawnWave(object oPC, int nWave)
{
    object oMod = GetModule();
    SetLocalInt(oMod, DOOM_WAVE_VAR, nWave);
    SetLocalInt(oMod, DOOM_NEXT_VAR, FALSE);
    int nCount = 2 + nWave * 2;

    object oArea = GetArea(oPC);
    int nWaypoints = 0;
    object oWp = GetNearestObjectByTag(DOOM_SPAWN_TAG, oPC, 1);
    while (GetIsObjectValid(oWp)) { nWaypoints++; oWp = GetNearestObjectByTag(DOOM_SPAWN_TAG, oPC, nWaypoints + 1); }

    int i;
    for (i = 0; i < nCount; i++)
    {
        location lLoc;
        if (nWaypoints > 0)
        {
            lLoc = GetLocation(GetNearestObjectByTag(DOOM_SPAWN_TAG, oPC, (i % nWaypoints) + 1));
        }
        else
        {
            float fAngle = IntToFloat(Random(360));
            vector vPos = GetPosition(oPC) + AngleToVector(fAngle) * (10.0 + IntToFloat(Random(6)));
            lLoc = Location(oArea, vPos, fAngle + 180.0);
        }
        DoomSpawnMonster(DoomPickMonster(nWave), lLoc, oPC);
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
        DoomMessage(oPC, "Picked up a clip.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_SHELLS)
    {
        int n = GetLocalInt(oPC, DOOM_VAR_SHELLS);
        if (n >= DOOM_MAX_SHELLS) return FALSE;
        n += 4; if (n > DOOM_MAX_SHELLS) n = DOOM_MAX_SHELLS;
        SetLocalInt(oPC, DOOM_VAR_SHELLS, n);
        DoomMessage(oPC, "Picked up 4 shotgun shells.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_STIMPACK)
    {
        if (GetCurrentHitPoints(oPC) >= GetMaxHitPoints(oPC)) return FALSE;
        int nHeal = GetMaxHitPoints(oPC) / 10; if (nHeal < 1) nHeal = 1;
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectHeal(nHeal), oPC);
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_IMP_HEALING_S), oPC);
        DoomMessage(oPC, "Picked up a stimpack.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_ARMOR)
    {
        int n = GetLocalInt(oPC, DOOM_VAR_ARMOR);
        if (n >= 200) return FALSE;
        n += 5; if (n > 200) n = 200;
        SetLocalInt(oPC, DOOM_VAR_ARMOR, n);
        ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_IMP_AC_BONUS), oPC);
        DoomMessage(oPC, "Picked up an armor bonus.");
        return TRUE;
    }
    if (sKind == DOOM_PICKUP_SHOTGUN)
    {
        int bHad = GetLocalInt(oPC, DOOM_VAR_HAS_SG);
        int n = GetLocalInt(oPC, DOOM_VAR_SHELLS) + 8;
        if (n > DOOM_MAX_SHELLS) n = DOOM_MAX_SHELLS;
        SetLocalInt(oPC, DOOM_VAR_SHELLS, n);
        SetLocalInt(oPC, DOOM_VAR_HAS_SG, TRUE);
        if (!bHad) SetLocalInt(oPC, DOOM_VAR_WEAPON, DOOM_WEAPON_SHOTGUN);
        DoomMessage(oPC, "You got the shotgun!");
        return TRUE;
    }
    return FALSE;
}
