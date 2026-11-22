#!/bin/bash
# Rewrites every yardlock-*.cfg beside YardLock.tla. references/yardlock-coverage.md says what each one must report.
# usage: make-yardlock-configs.sh
# Each config line: name, invariants, properties, then Constant=VALUE overrides of the table in ycfg.
cd "$(dirname "$0")"
ycfg() {
  local name=$1 rules=$2 props=$3
  shift 3
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Store Stages MaxEntries Waves MaxS MaxRings LongFlight ArmedChecksEngaged EngagedUnlocks LockedYields FlowSpends DeadSpends UnlockSpends UnlockDropsWall ElifUnlock MaxSOpens OfferNeedsWin CashSpends RingCap OvertimeOn StrikeFrom"
  # The code at the sync commit, in a played game (with a store), with bounds shrunk to keep every branch reachable.
  local c_Store=TRUE c_Stages=2 c_MaxEntries=3 c_Waves=2 c_MaxS=5 c_MaxRings=3
  local c_LongFlight=TRUE c_ArmedChecksEngaged=TRUE c_EngagedUnlocks=TRUE c_LockedYields=TRUE c_FlowSpends=TRUE
  local c_DeadSpends=TRUE
  local c_UnlockSpends=TRUE c_UnlockDropsWall=TRUE c_ElifUnlock=TRUE c_MaxSOpens=TRUE c_OfferNeedsWin=TRUE
  local c_CashSpends=TRUE c_RingCap=TRUE c_OvertimeOn=TRUE
  # A shot reaches 70 to 95 m bare and 142.5 m with a horizon optic (weapons.gd, parts.gd), so from every zone the
  # wall can hold a ball in; from "out" (beyond the 150 m share) none reaches the Warden at the beacon.
  local c_StrikeFrom='{"circle", "near", "ring"}'
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-yardlock-configs: unknown constant $key" >&2
        exit 2
        ;;
    esac
  done
  {
    echo "SPECIFICATION Spec"
    echo "CONSTANTS"
    for key in $(printf '%s\n' $keys | sort); do
      v="c_$key"
      echo "  $key = ${!v}"
    done
    echo "INVARIANTS TypeOK${rules:+ $rules}"
    if [ -n "$props" ]; then
      echo "PROPERTIES $props"
    fi
  } > "yardlock-$name.cfg"
}
SAFE="WallOnlyWhileLocked NoLockInWardenFight YardPaysOnce OvertimeOnlyAfterWin StartCardOnce"
OPENS="LockAlwaysOpens"
# The code at the sync commit (P7 closed YL-1 and YL-2), in a played game and in the storeless flow (tests and bots):
# no break. The receipt's code configs.
ycfg today "$SAFE" "$OPENS"
ycfg today-nostore "$SAFE" "$OPENS" Store=FALSE
# YL-1's two paths on their own, kept as regression shapes: a long flight with no hit on the Warden from outside its
# ring, and a ball that rolls in and then shoots the Warden from inside the yard. No break.
ycfg today-flight "$SAFE" "$OPENS" 'StrikeFrom={"ring"}'
ycfg today-ranged "$SAFE" "$OPENS" LongFlight=FALSE
# Every guard in place: the same constants as today, kept under the names the skill's tables use.
ycfg guarded "$SAFE" "$OPENS"
ycfg guarded-nostore "$SAFE" "$OPENS" Store=FALSE
# One guard off each, from today: the named rule must break.
ycfg broken-armedguard "NoLockInWardenFight" "" ArmedChecksEngaged=FALSE
ycfg broken-flowspend "WallOnlyWhileLocked" "" FlowSpends=FALSE
ycfg broken-wall "WallOnlyWhileLocked" "" UnlockDropsWall=FALSE
ycfg broken-maxs "" "LockAlwaysOpens" MaxSOpens=FALSE
ycfg broken-repay "YardPaysOnce" "" UnlockSpends=FALSE
ycfg broken-elif "StartCardOnce" "" ElifUnlock=FALSE
ycfg broken-offer "OvertimeOnlyAfterWin" "" OfferNeedsWin=FALSE
ycfg broken-cash "OvertimeOnlyAfterWin" "" CashSpends=FALSE
ycfg broken-ringcap "OvertimeOnlyAfterWin" "" RingCap=FALSE
# The P7 fixes taken out again: YL-1 (both its guards, the handler and the "locked" branch, since either alone holds
# the rule) and YL-2 (in the storeless flow, where the dead screen is).
ycfg broken-lockedyields "NoLockInWardenFight" "" EngagedUnlocks=FALSE LockedYields=FALSE
ycfg broken-deadspends "WallOnlyWhileLocked" "" DeadSpends=FALSE Store=FALSE
# Probes: every one must break, or an action can no longer fire. One probe per config, because a break stops the
# checker. The storeless probes reach the retry; the rest run on today.
for probe in Lock LockNear Won Timeout SkipEngaged SkipUnsealed Wave Ring Cash FlowSpend Engaged Strike Continue SecondStage \
  EngagedUnlock StrikeUnlock KillWarden Vanished; do
  ycfg "reach-$probe" "Probe$probe" ""
done
ycfg reach-Retry "ProbeRetry" "" Store=FALSE
ycfg reach-DeadSpend "ProbeDeadSpend" "" Store=FALSE
# The "locked" branch's own guard fires only when the handler does not open the yard first.
ycfg reach-Yield "ProbeYield" "" EngagedUnlocks=FALSE
