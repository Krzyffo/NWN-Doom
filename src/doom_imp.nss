// doom_imp: imp AI tick, run on each spawned imp every DOOM_IMP_TICK s.
// Imps lose NWN's Magic Missile (which always hits) and instead throw
// Doom-style fireballs: slow, straight, aimed where the player stands at
// the moment of the throw, so strafing dodges them. NWN's own AI still
// handles walking and melee.
//
// A fireball is an invisible placeable carrying a fire effect. Its motion
// is shown with a linear visual-transform lerp (smooth on the client),
// while the script recomputes the same position from elapsed time every
// DOOM_BALL_TICK s to test for hits and walls.

#include "doom_inc"

const float  DOOM_IMP_TICK        = 0.5;
const float  DOOM_IMP_MIN_RANGE   = 3.0;   // closer than this the imp claws instead
const float  DOOM_IMP_MAX_RANGE   = 30.0;
const int    DOOM_IMP_COOLDOWN_MIN = 4;    // in imp ticks: 2-4 s between throws
const int    DOOM_IMP_COOLDOWN_MAX = 8;
const float  DOOM_IMP_WINDUP      = 0.5;   // throw animation before release

const float  DOOM_BALL_SPEED      = 6.0;   // m/s; NWN running is roughly 4 m/s
const float  DOOM_BALL_RANGE      = 35.0;
const float  DOOM_BALL_HEIGHT     = 1.0;
const float  DOOM_BALL_HIT_RADIUS = 0.9;
const float  DOOM_BALL_TICK       = 0.1;
const float  DOOM_BALL_SCALE      = 0.35;  // shrinks the fire effect to a ball
const string DOOM_BALL_RESREF     = "plc_invisobj";

const string DOOM_IMP_INIT_VAR = "DOOM_IMP_INIT";
const string DOOM_IMP_CD_VAR   = "DOOM_IMP_CD";

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
    ApplyEffectAtLocation(DURATION_TYPE_INSTANT, EffectVisualEffect(VFX_IMP_FLAME_M), lHere);
    DestroyObject(oBall);
}

// Runs on the fireball itself, so it stops when the ball is destroyed.
void DoomBallTick(object oBall)
{
    object oImp = GetLocalObject(oBall, "DOOM_BALL_OWNER");
    vector vOrigin = DoomGetVec(oBall, "DOOM_BALL_ORIGIN");
    vector vDir = DoomGetVec(oBall, "DOOM_BALL_DIR");
    vector vLast = DoomGetVec(oBall, "DOOM_BALL_LAST");

    // Position from elapsed time, matching the client-side lerp.
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

    // Players in the way.
    location lPos = Location(GetArea(oBall), vPos, 0.0);
    object oHit = GetFirstObjectInShape(SHAPE_SPHERE, DOOM_BALL_HIT_RADIUS, lPos, FALSE, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(oHit))
    {
        if (GetIsPC(oHit) && !GetIsDead(oHit))
        {
            // Doom imp fireball: 3-24, as % of the player's max HP.
            effect eDamage = EffectDamage(DoomPercentDamage(oHit, 3, 24), DAMAGE_TYPE_FIRE);
            // Credit the imp if it is still alive, so the player retaliates at it.
            if (GetIsObjectValid(oImp) && !GetIsDead(oImp))
                AssignCommand(oImp, ApplyEffectToObject(DURATION_TYPE_INSTANT, eDamage, oHit));
            else
                ApplyEffectToObject(DURATION_TYPE_INSTANT, eDamage, oHit);
            DoomBallExplode(oBall, vPos);
            return;
        }
        oHit = GetNextObjectInShape(SHAPE_SPHERE, DOOM_BALL_HIT_RADIUS, lPos, FALSE, OBJECT_TYPE_CREATURE);
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

    // Facing 0 so the object's local axes are the world axes for the lerp.
    location lSpawn = Location(GetArea(oImp), vStart + vDir * 0.6, 0.0);
    object oBall = CreateObject(OBJECT_TYPE_PLACEABLE, DOOM_BALL_RESREF, lSpawn);
    if (!GetIsObjectValid(oBall))
    {
        WriteTimestampedLogEntry("NWN-Doom: failed to create fireball " + DOOM_BALL_RESREF);
        return;
    }
    SetUseableFlag(oBall, FALSE);
    SetPlotFlag(oBall, TRUE);

    ApplyEffectToObject(DURATION_TYPE_PERMANENT, EffectVisualEffect(VFX_DUR_INFERNO_NO_SOUND), oBall);
    ApplyEffectToObject(DURATION_TYPE_PERMANENT, EffectVisualEffect(VFX_DUR_LIGHT_ORANGE_5), oBall);
    SetObjectVisualTransform(oBall, OBJECT_VISUAL_TRANSFORM_SCALE, DOOM_BALL_SCALE);
    SetObjectVisualTransform(oBall, OBJECT_VISUAL_TRANSFORM_TRANSLATE_Z, DOOM_BALL_HEIGHT);

    float fTime = DOOM_BALL_RANGE / DOOM_BALL_SPEED;
    SetObjectVisualTransform(oBall, OBJECT_VISUAL_TRANSFORM_TRANSLATE_X, vDir.x * DOOM_BALL_RANGE,
                             OBJECT_VISUAL_TRANSFORM_LERP_LINEAR, fTime);
    SetObjectVisualTransform(oBall, OBJECT_VISUAL_TRANSFORM_TRANSLATE_Y, vDir.y * DOOM_BALL_RANGE,
                             OBJECT_VISUAL_TRANSFORM_LERP_LINEAR, fTime);

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

void DoomImpInit(object oImp)
{
    // Remove NWN's always-hit Magic Missile and the invisibility ability.
    DoomStripSpellAbilities(oImp);
    SetLocalInt(oImp, DOOM_IMP_CD_VAR, DoomRandomRange(1, DOOM_IMP_COOLDOWN_MAX));
    SetLocalInt(oImp, DOOM_IMP_INIT_VAR, TRUE);
}

void main()
{
    object oImp = OBJECT_SELF;
    if (!GetIsObjectValid(oImp) || GetIsDead(oImp)) return;
    if (!GetLocalInt(oImp, DOOM_IMP_INIT_VAR)) DoomImpInit(oImp);

    int nCooldown = GetLocalInt(oImp, DOOM_IMP_CD_VAR) - 1;
    SetLocalInt(oImp, DOOM_IMP_CD_VAR, nCooldown);

    object oPC = GetNearestCreature(CREATURE_TYPE_PLAYER_CHAR, PLAYER_CHAR_IS_PC, oImp);
    if (nCooldown <= 0 && GetIsObjectValid(oPC) && !GetIsDead(oPC))
    {
        float fDist = GetDistanceBetween(oImp, oPC);
        if (fDist >= DOOM_IMP_MIN_RANGE && fDist <= DOOM_IMP_MAX_RANGE && LineOfSightObject(oImp, oPC))
        {
            // Wind up, throw at where the player stands now, then resume the chase.
            vector vTarget = GetPosition(oPC);
            ClearAllActions();
            SetFacingPoint(vTarget);
            PlayAnimation(ANIMATION_LOOPING_CONJURE1, 1.0, DOOM_IMP_WINDUP);
            DelayCommand(DOOM_IMP_WINDUP, DoomImpThrow(oImp, vTarget));
            DelayCommand(DOOM_IMP_WINDUP + 0.1, ActionAttack(oPC));
            SetLocalInt(oImp, DOOM_IMP_CD_VAR, DoomRandomRange(DOOM_IMP_COOLDOWN_MIN, DOOM_IMP_COOLDOWN_MAX));
        }
    }

    DelayCommand(DOOM_IMP_TICK, ExecuteScript("doom_imp", oImp));
}
