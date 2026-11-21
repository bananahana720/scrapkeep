#!/bin/bash
# Rewrites every yardlock-*.cfg beside YardLock.tla. references/yardlock-coverage.md says what each one must report.
# usage: make-yardlock-configs.sh
# Each config line: name, invariants, properties, then Constant=VALUE overrides of the table in ycfg.
cd "$(dirname "$0")"
ycfg() {
  local name=$1 rules=$2 props=$3
  shift 3
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Store Stages MaxEntries Waves MaxS MaxRings LongFlight ArmedChecksEngaged LockedYields FlowSpends DeadSpends UnlockSpends UnlockDropsWall ElifUnlock MaxSOpens OfferNeedsWin CashSpends RingCap OvertimeOn StrikeFrom"
  # The code at the sync commit, in a played game (with a store), with bounds shrunk to keep every branch reachable.
  local c_Store=TRUE c_Stages=2 c_MaxEntries=3 c_Waves=2 c_MaxS=5 c_MaxRings=3
  local c_LongFlight=TRUE c_ArmedChecksEngaged=TRUE c_LockedYields=FALSE c_FlowSpends=TRUE c_DeadSpends=FALSE
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
# The code at the sync commit, in a played game: must report NoLockInWardenFight (finding YL-1).
ycfg today "$SAFE" "$OPENS"
# The same code with each of YL-1's two paths on its own: a long flight with no hit on the Warden from outside its
# ring, and a ball that rolls in and then shoots the Warden from inside the yard. Each must report
# NoLockInWardenFight.
ycfg today-flight "$SAFE" "$OPENS" 'StrikeFrom={"ring"}'
ycfg today-ranged "$SAFE" "$OPENS" LongFlight=FALSE
# Neither path: a ball that rolls in and lands no hit on the Warden before it enters the ring. No break. The
# receipt's code config while YL-1 is open.
ycfg today-unfired "$SAFE" "$OPENS" LongFlight=FALSE 'StrikeFrom={"ring"}'
# The storeless flow (tests and bots): must report WallOnlyWhileLocked on the dead screen (finding YL-2). It leaves
# NoLockInWardenFight out so the checker reaches the dead screen's break instead of stopping on YL-1's.
ycfg today-nostore "WallOnlyWhileLocked YardPaysOnce OvertimeOnlyAfterWin StartCardOnce" "$OPENS" Store=FALSE
# Every guard in place, with and without a store: the YL-1 and YL-2 fixes on. No break.
GUARDS=(LockedYields=TRUE DeadSpends=TRUE)
ycfg guarded "$SAFE" "$OPENS" "${GUARDS[@]}"
ycfg guarded-nostore "$SAFE" "$OPENS" "${GUARDS[@]}" Store=FALSE
# One guard off each, from guarded: the named rule must break.
ycfg broken-armedguard "NoLockInWardenFight" "" "${GUARDS[@]}" ArmedChecksEngaged=FALSE
ycfg broken-flowspend "WallOnlyWhileLocked" "" "${GUARDS[@]}" FlowSpends=FALSE
ycfg broken-wall "WallOnlyWhileLocked" "" "${GUARDS[@]}" UnlockDropsWall=FALSE
ycfg broken-maxs "" "LockAlwaysOpens" "${GUARDS[@]}" MaxSOpens=FALSE
ycfg broken-repay "YardPaysOnce" "" "${GUARDS[@]}" UnlockSpends=FALSE
ycfg broken-elif "StartCardOnce" "" "${GUARDS[@]}" ElifUnlock=FALSE
ycfg broken-offer "OvertimeOnlyAfterWin" "" "${GUARDS[@]}" OfferNeedsWin=FALSE
ycfg broken-cash "OvertimeOnlyAfterWin" "" "${GUARDS[@]}" CashSpends=FALSE
ycfg broken-ringcap "OvertimeOnlyAfterWin" "" "${GUARDS[@]}" RingCap=FALSE
# Probes: every one must break, or an action can no longer fire. One probe per config, because a break stops the
# checker. The storeless probes reach the retry; the rest run on today.
for probe in Lock LockNear Won Timeout SkipEngaged SkipUnsealed Wave Ring Cash FlowSpend Engaged Strike Continue SecondStage; do
  ycfg "reach-$probe" "Probe$probe" ""
done
ycfg reach-Retry "ProbeRetry" "" Store=FALSE
