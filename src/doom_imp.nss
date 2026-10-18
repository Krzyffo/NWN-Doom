// doom_imp: imp AI tick, run on each spawned imp every DOOM_IMP_TICK s.
// Imps lose NWN's Magic Missile (which always hits) and instead throw
// Doom-style fireballs: slow, straight, aimed where the player stands at
// the moment of the throw, so strafing dodges them. They keep their
// distance and stay in view of the player (see the AI tick below).
//
// A fireball is a script loop carried by an invisible placeable. Every
// DOOM_BALL_TICK s it computes the ball's position from elapsed time,
// draws a fire burst there (in world coordinates, so the flames always
// follow the real path) and tests for hits and walls.

#include "doom_inc"

const float  DOOM_IMP_TICK        = 0.5;
const float  DOOM_IMP_MIN_RANGE   = 3.0;   // closer than this the imp claws instead
const float  DOOM_IMP_MAX_RANGE   = 30.0;
const int    DOOM_IMP_COOLDOWN_MIN_MS = 4000;  // at least 4 s between throws,
const int    DOOM_IMP_COOLDOWN_MAX_MS = 6000;  // randomised so imps fire out of sync
const float  DOOM_IMP_WINDUP      = 0.5;   // throw animation before release

const float  DOOM_BALL_SPEED      = 6.0;   // m/s; NWN running is roughly 4 m/s
const float  DOOM_BALL_RANGE      = 35.0;
const float  DOOM_BALL_HEIGHT     = 1.0;
const float  DOOM_BALL_HIT_RADIUS = 0.9;
const float  DOOM_BALL_TICK       = 0.05;  // also how often a flame is drawn
const int    DOOM_BALL_VFX        = DOOM_VFX_FIRETRAIL;  // small flame, no sound
const string DOOM_BALL_RESREF     = "plc_invisobj";

const string DOOM_IMP_INIT_VAR = "DOOM_IMP_INIT";
const string DOOM_IMP_CD_VAR   = "DOOM_IMP_CD";    // ms to wait after the last throw
const string DOOM_IMP_LAST_VAR = "DOOM_IMP_LAST";  // GetMicrosecondCounter() at the last throw

// ---- Fireball --------------------------------------------------------------

// Locals cannot hold vectors, so they are stored as locations.
void DoomSetVec(object o, string sVar, vector v)
{
    SetLocalLocation(o, sVar, Location(GetArea(o), v, 0.0));
}

vector DoomGetVec(object o, string sVar)
{
    return GetPositionFromLocation(GetLocalLocation(o, sVar));
}

void DoomBallExplode(object oBall, vector vPos)
{
    location lHere = Location(GetArea(oBall), vPos, 0.0);
    // Big flame with the Doom explosion sound (row added in the hak).
    DoomSfxAt(lHere, DOOM_VFX_FIREEXPL);
    DestroyObject(oBall);
}

// Runs on the fireball itself, so it stops when the ball is destroyed.
void DoomBallTick(object oBall)
{
    object oImp = GetLocalObject(oBall, "DOOM_BALL_OWNER");
    vector vOrigin = DoomGetVec(oBall, "DOOM_BALL_ORIGIN");
    vector vDir = DoomGetVec(oBall, "DOOM_BALL_DIR");
    vector vLast = DoomGetVec(oBall, "DOOM_BALL_LAST");

    // Position from elapsed time, so the speed does not depend on tick jitter.
    int nElapsedMs = (GetMicrosecondCounter() - GetLocalInt(oBall, "DOOM_BALL_T0")) / 1000;
    if (nElapsedMs < 0) nElapsedMs = FloatToInt(DOOM_BALL_RANGE / DOOM_BALL_SPEED * 1000.0);  // counter wrapped
    float fDist = DOOM_BALL_SPEED * IntToFloat(nElapsedMs) / 1000.0;
    if (fDist > DOOM_BALL_RANGE) fDist = DOOM_BALL_RANGE;
    vector vPos = vOrigin + vDir * fDist;

    // Walls: no line of sight between the last and the new position.
    if (!LineOfSightVector(vLast, vPos))
    {
        DoomBallExplode(oBall, vLast);
        return;
    }

    location lPos = Location(GetArea(oBall), vPos, 0.0);
    ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(DOOM_BALL_VFX), lPos);

    // Players in the way. Creature positions are at their feet while the
    // ball flies at chest height, so measure horizontal distance and allow
    // a generous height difference (a plain 3D sphere never reached them).
    float fSearch = DOOM_BALL_HIT_RADIUS + 2.0;
    object oHit = GetFirstObjectInShape(SHAPE_SPHERE, fSearch, lPos, FALSE, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(oHit))
    {
        vector vOff = GetPosition(oHit) - vPos;
        float fDz = vOff.z;
        vOff.z = 0.0;
        if (GetIsPC(oHit) && !GetIsDead(oHit)
            && VectorMagnitude(vOff) <= DOOM_BALL_HIT_RADIUS
            && fDz > -(DOOM_BALL_HEIGHT + 1.0) && fDz < 1.0)
        {
            // Doom imp fireball: 3-24, as % of the player's max HP.
            int nDamage = DoomPercentDamage(oHit, 3, 24);
            // Credit the imp if it is still alive. NWN credits whoever
            // *creates* an effect, so EffectDamage must be called inside the
            // AssignCommand; created here it showed as "Invisible Object".
            if (GetIsObjectValid(oImp) && !GetIsDead(oImp))
                AssignCommand(oImp, ApplyEffectToObject(DURATION_TYPE_INSTANT,
                    EffectDamage(nDamage, DAMAGE_TYPE_FIRE), oHit));
            else
                ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectDamage(nDamage, DAMAGE_TYPE_FIRE), oHit);
            DoomBallExplode(oBall, vPos);
            return;
        }
        oHit = GetNextObjectInShape(SHAPE_SPHERE, fSearch, lPos, FALSE, OBJECT_TYPE_CREATURE);
    }

    if (fDist >= DOOM_BALL_RANGE)
    {
        DoomBallExplode(oBall, vPos);
        return;
    }

    DoomSetVec(oBall, "DOOM_BALL_LAST", vPos);
    DelayCommand(DOOM_BALL_TICK, DoomBallTick(oBall));
}

void DoomImpThrow(object oImp, vector vTarget)
{
    if (!GetIsObjectValid(oImp) || GetIsDead(oImp)) return;

    vector vStart = GetPosition(oImp);
    vector vDir = vTarget - vStart;
    vDir.z = 0.0;
    if (VectorMagnitude(vDir) < 0.1) return;
    vDir = VectorNormalize(vDir);

    // Leave from in front of the imp at chest height.
    vector vOrigin = vStart + vDir * 0.6;
    vOrigin.z += DOOM_BALL_HEIGHT;

    // The placeable only carries the tick loop and its state; it stays put.
    location lSpawn = Location(GetArea(oImp), vOrigin, 0.0);
    object oBall = CreateObject(OBJECT_TYPE_PLACEABLE, DOOM_BALL_RESREF, lSpawn);
    if (!GetIsObjectValid(oBall))
    {
        WriteTimestampedLogEntry("NWN-Doom: failed to create fireball " + DOOM_BALL_RESREF);
        return;
    }
    SetUseableFlag(oBall, FALSE);
    SetPlotFlag(oBall, TRUE);
    DoomSfx(oImp, DOOM_VFX_FIRESHOT);

    ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(DOOM_BALL_VFX), lSpawn);
    float fTime = DOOM_BALL_RANGE / DOOM_BALL_SPEED;

    SetLocalObject(oBall, "DOOM_BALL_OWNER", oImp);
    DoomSetVec(oBall, "DOOM_BALL_ORIGIN", vOrigin);
    DoomSetVec(oBall, "DOOM_BALL_DIR", vDir);
    DoomSetVec(oBall, "DOOM_BALL_LAST", vOrigin);
    SetLocalInt(oBall, "DOOM_BALL_T0", GetMicrosecondCounter());
    AssignCommand(oBall, DelayCommand(DOOM_BALL_TICK, DoomBallTick(oBall)));
    // Safety net in case the tick loop is ever interrupted.
    DestroyObject(oBall, fTime + 2.0);
}

// ---- Imp AI tick -----------------------------------------------------------
// Imps are ranged skirmishers: they try to stand DOOM_IMP_KEEP_MIN..MAX
// from the player and within DOOM_IMP_FOV degrees of where the player is
// facing, so they are on screen, throwing fireballs on a cooldown. They
// back off when rushed and only claw when cornered. NWN's own AI scripts
// are removed from imps; this tick is their whole brain.

const float DOOM_IMP_KEEP_MIN  = 8.0;    // preferred distance band
const float DOOM_IMP_KEEP_MAX  = 14.0;
const float DOOM_IMP_KEEP_PREF = 11.0;
const float DOOM_IMP_FOV       = 30.0;   // stay within +-this many degrees of the player's facing
const float DOOM_IMP_DRIFT     = 12.0;   // random sidestep around its spot, degrees
const float DOOM_IMP_CORNERED  = 2.2;    // closer than this it claws instead
const float DOOM_IMP_REPATH    = 2.0;    // only re-path if the spot moved this far
const float DOOM_IMP_VIEW      = 40.0;   // counts as "in view" within +-this many degrees
const int   DOOM_IMP_PATIENCE  = 8;      // ticks (4 s) out of view before it throws anyway

const string DOOM_IMP_UNSEEN_VAR = "DOOM_IMP_UNSEEN";

const string DOOM_IMP_BUSY_VAR  = "DOOM_IMP_BUSY";
const string DOOM_IMP_DRIFT_VAR = "DOOM_IMP_DRIFTV";
const string DOOM_IMP_GOAL_VAR  = "DOOM_IMP_GOAL";

// a - b, wrapped to -180..180.
float DoomAngleDiff(float a, float b)
{
    float d = a - b;
    while (d > 180.0) d -= 360.0;
    while (d < -180.0) d += 360.0;
    return d;
}

// TRUE if vPos is on the walkmesh and the player could see an imp there.
int DoomImpSpotOk(object oArea, vector vEye, vector vPos)
{
    if (GetSurfaceMaterial(Location(oArea, vPos, 0.0)) == 0) return FALSE;
    vector vHead = vPos;
    vHead.z += 1.0;
    return LineOfSightVector(vEye, vHead);
}

// Finds where the imp wants to stand: on its side of the player's view,
// pulled into the FOV, at the preferred distance. Falls back to closer
// and more central spots when walls or the walkmesh get in the way.
// Stores the spot in DOOM_IMP_GOAL_VAR; returns FALSE if none was usable.
int DoomImpPickSpot(object oImp, object oPC)
{
    vector vPC = GetPosition(oPC);
    vector vEye = vPC;
    vEye.z += 1.5;
    object oArea = GetArea(oPC);
    float fFacing = GetFacing(oPC);

    float fRel = DoomAngleDiff(VectorToAngle(GetPosition(oImp) - vPC), fFacing);
    fRel += GetLocalFloat(oImp, DOOM_IMP_DRIFT_VAR);
    if (fRel > DOOM_IMP_FOV) fRel = DOOM_IMP_FOV;
    if (fRel < -DOOM_IMP_FOV) fRel = -DOOM_IMP_FOV;

    float fDist = GetDistanceBetween(oImp, oPC);
    if (fDist < DOOM_IMP_KEEP_MIN || fDist > DOOM_IMP_KEEP_MAX) fDist = DOOM_IMP_KEEP_PREF;

    // Try the ideal spot, then shorter distances, then angles nearer the centre.
    int nAngle;
    for (nAngle = 0; nAngle < 3; nAngle++)
    {
        float fA = fRel * (1.0 - 0.5 * IntToFloat(nAngle));
        float fD;
        for (fD = fDist; fD >= 4.0; fD -= 2.0)
        {
            vector vSpot = vPC + AngleToVector(fFacing + fA) * fD;
            if (DoomImpSpotOk(oArea, vEye, vSpot))
            {
                DoomSetVec(oImp, DOOM_IMP_GOAL_VAR, vSpot);
                return TRUE;
            }
        }
    }
    return FALSE;
}

// Throw cooldown on the clock, not in AI ticks, so nothing can shorten it.
// The difference of two GetMicrosecondCounter() values stays correct when
// the counter wraps, as long as less than ~35 minutes have passed.
void DoomImpStartCooldown(object oImp, int nMinMs, int nMaxMs)
{
    SetLocalInt(oImp, DOOM_IMP_LAST_VAR, GetMicrosecondCounter());
    SetLocalInt(oImp, DOOM_IMP_CD_VAR, DoomRandomRange(nMinMs, nMaxMs));
}

int DoomImpReady(object oImp)
{
    int nElapsedMs = (GetMicrosecondCounter() - GetLocalInt(oImp, DOOM_IMP_LAST_VAR)) / 1000;
    return nElapsedMs < 0 || nElapsedMs >= GetLocalInt(oImp, DOOM_IMP_CD_VAR);
}

void DoomImpInit(object oImp)
{
    // Remove NWN's always-hit Magic Missile and the invisibility ability.
    DoomStripSpellAbilities(oImp);

    // Take the imp away from NWN's combat AI, which always charges into melee.
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_HEARTBEAT, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_NOTICE, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_SPELLCASTAT, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_MELEE_ATTACKED, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_DAMAGED, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_DISTURBED, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_END_COMBATROUND, "");
    SetEventScript(oImp, EVENT_SCRIPT_CREATURE_ON_BLOCKED_BY_DOOR, "");
    SetLocalInt(oImp, DOOM_RANGED_VAR, TRUE);

    // First throw 1-6 s after spawning, so a fresh wave does not volley at once.
    DoomImpStartCooldown(oImp, 1000, DOOM_IMP_COOLDOWN_MAX_MS);
    SetLocalInt(oImp, DOOM_IMP_INIT_VAR, TRUE);
}

void main()
{
    object oImp = OBJECT_SELF;
    if (!GetIsObjectValid(oImp) || GetIsDead(oImp)) return;
    if (!GetLocalInt(oImp, DOOM_IMP_INIT_VAR)) DoomImpInit(oImp);
    DelayCommand(DOOM_IMP_TICK, ExecuteScript("doom_imp", oImp));

    object oPC = GetNearestCreature(CREATURE_TYPE_PLAYER_CHAR, PLAYER_CHAR_IS_PC, oImp);
    if (!GetIsObjectValid(oPC) || GetIsDead(oPC)) return;

    int nBusy = GetLocalInt(oImp, DOOM_IMP_BUSY_VAR) - 1;
    SetLocalInt(oImp, DOOM_IMP_BUSY_VAR, nBusy);
    if (nBusy > 0) return;  // mid-throw or mid-claw

    // Now and then pick a new sidestep so it does not stand still.
    if (Random(4) == 0)
        SetLocalFloat(oImp, DOOM_IMP_DRIFT_VAR,
                      IntToFloat(Random(FloatToInt(DOOM_IMP_DRIFT) * 2 + 1)) - DOOM_IMP_DRIFT);

    float fDist = GetDistanceBetween(oImp, oPC);

    // Cornered: claw.
    if (fDist < DOOM_IMP_CORNERED)
    {
        ClearAllActions();
        ActionAttack(oPC);
        SetLocalInt(oImp, DOOM_IMP_BUSY_VAR, 3);
        return;
    }

    // Is the imp on the player's screen? (The first-person camera is locked
    // to the character's facing.) Count how long it has been off screen.
    float fRel = DoomAngleDiff(VectorToAngle(GetPosition(oImp) - GetPosition(oPC)), GetFacing(oPC));
    int bInView = fabs(fRel) <= DOOM_IMP_VIEW;
    int nUnseen = 0;
    if (!bInView) nUnseen = GetLocalInt(oImp, DOOM_IMP_UNSEEN_VAR) + 1;
    SetLocalInt(oImp, DOOM_IMP_UNSEEN_VAR, nUnseen);

    // Throw when ready and the player is in sight, but get into the
    // player's view first so the fireball can be seen coming. If it cannot
    // get there (walls, tight corridors), it throws anyway after a while.
    if (DoomImpReady(oImp) && fDist >= DOOM_IMP_MIN_RANGE && fDist <= DOOM_IMP_MAX_RANGE
        && LineOfSightObject(oImp, oPC)
        && (bInView || nUnseen >= DOOM_IMP_PATIENCE))
    {
        vector vTarget = GetPosition(oPC);
        ClearAllActions();
        SetFacingPoint(vTarget);
        PlayAnimation(ANIMATION_LOOPING_CONJURE1, 1.0, DOOM_IMP_WINDUP);
        DelayCommand(DOOM_IMP_WINDUP, DoomImpThrow(oImp, vTarget));
        DoomImpStartCooldown(oImp, DOOM_IMP_COOLDOWN_MIN_MS, DOOM_IMP_COOLDOWN_MAX_MS);
        SetLocalInt(oImp, DOOM_IMP_BUSY_VAR, 2);
        return;
    }

    // Otherwise move towards its spot: in view, at range.
    vector vOldGoal = DoomGetVec(oImp, DOOM_IMP_GOAL_VAR);
    if (!DoomImpPickSpot(oImp, oPC))
    {
        // No good spot (tight corridor): at least keep away from the player.
        if (fDist < DOOM_IMP_KEEP_MIN)
        {
            ClearAllActions();
            ActionMoveAwayFromObject(oPC, TRUE, DOOM_IMP_KEEP_PREF);
        }
        return;
    }
    vector vGoal = DoomGetVec(oImp, DOOM_IMP_GOAL_VAR);
    if (VectorMagnitude(vGoal - GetPosition(oImp)) < 1.0)
        return;  // already there
    if (GetCurrentAction(oImp) == ACTION_MOVETOPOINT && VectorMagnitude(vGoal - vOldGoal) < DOOM_IMP_REPATH)
        return;  // already on its way to roughly the same spot
    ClearAllActions();
    ActionMoveToLocation(Location(GetArea(oImp), vGoal, VectorToAngle(GetPosition(oPC) - vGoal)), TRUE);
}
