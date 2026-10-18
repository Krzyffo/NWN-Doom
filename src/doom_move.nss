// doom_move: per-player loop, run on the player every DOOM_MOVE_TICK s.
// NWN moves you backwards and sideways at walking pace, half as fast as
// forwards. This compares the direction the player just moved with the
// direction they face, and while it is not forwards it switches the speed
// bonus to the bigger "backwards" one (see DoomApplySpeed).

#include "doom_inc"

const string DOOM_MOVE_LAST_VAR = "DOOM_MOVE_LAST";
const float  DOOM_MOVE_MIN_STEP = 0.05;  // m per tick; less counts as standing still
const float  DOOM_MOVE_FORWARD  = 0.5;   // cos of the widest angle still "forwards" (60 degrees)

void main()
{
    object oPC = OBJECT_SELF;
    if (!GetIsObjectValid(oPC) || !GetLocalInt(oPC, DOOM_VAR_ACTIVE)) return;
    DelayCommand(DOOM_MOVE_TICK, ExecuteScript("doom_move", oPC));
    if (GetIsDead(oPC)) return;

    location lLast = GetLocalLocation(oPC, DOOM_MOVE_LAST_VAR);
    location lNow = GetLocation(oPC);
    SetLocalLocation(oPC, DOOM_MOVE_LAST_VAR, lNow);
    if (GetAreaFromLocation(lLast) != GetArea(oPC)) return;  // first tick or area change

    vector vStep = GetPosition(oPC) - GetPositionFromLocation(lLast);
    vStep.z = 0.0;
    if (VectorMagnitude(vStep) < DOOM_MOVE_MIN_STEP) return;  // standing still: keep the mode

    vector vFacing = AngleToVector(GetFacing(oPC));
    vStep = VectorNormalize(vStep);
    int bBack = vStep.x * vFacing.x + vStep.y * vFacing.y < DOOM_MOVE_FORWARD;
    if (bBack != GetLocalInt(oPC, DOOM_VAR_MOVE_BACK))
    {
        SetLocalInt(oPC, DOOM_VAR_MOVE_BACK, bBack);
        DoomApplySpeed(oPC);
    }
}
