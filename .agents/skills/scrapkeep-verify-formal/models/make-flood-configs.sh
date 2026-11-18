#!/bin/bash
# Rewrites every flood-*.cfg beside ParkFlood.tla. references/flood-coverage.md says what each one must report.
# usage: make-flood-configs.sh
# Each config line: name, invariants, temporal properties ("-" for none), then Constant=VALUE overrides of the table in fcfg.
cd "$(dirname "$0")"
fcfg() {
  local name=$1 rules=$2 props=$3
  shift 3
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Events Fill Live Cap MaxLives SnapRise WaitUnderBall EndNeedsClear CapGuard"
  local c_Events="{\"a\", \"b\", \"c\"}" c_Fill=2 c_Live=3 c_Cap=2 c_MaxLives=2
  local c_SnapRise=TRUE c_WaitUnderBall=TRUE c_EndNeedsClear=TRUE c_CapGuard=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-flood-configs: unknown constant $key" >&2
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
    echo "INVARIANTS TypeOK $rules"
    [ "$props" = "-" ] || echo "PROPERTIES $props"
  } > "flood-$name.cfg"
}
SAFE="FullWaterNeverHeld FullWaterFreesItsSlot NeverRisesUnderBall NeverEndsUnderBall WithinCap"
LIVE="FloodEnds AnnouncedLands"
# The code with pull request 1135: every real flood row has a live time; a flood with no clock is the test rows' shape.
fcfg today-timed "$SAFE" "$LIVE"
fcfg today-noclock "$SAFE" "AnnouncedLands" Live=0
# One guard off each, from today: the named rule must break.
# The code before pull request 1135: the rise can sit a hair under full.
fcfg broken-nosnap "FullWaterNeverHeld" - SnapRise=FALSE
fcfg broken-nosnap-slot "FullWaterFreesItsSlot" - SnapRise=FALSE Live=0
fcfg broken-nowait "NeverRisesUnderBall" - WaitUnderBall=FALSE
fcfg broken-endunder "NeverEndsUnderBall" - EndNeedsClear=FALSE
fcfg broken-nocap "WithinCap" - CapGuard=FALSE
# Finding PF-1: asked without the ball leaving, a ball parked in a rising basin holds the water for good.
fcfg parked "" "RiseFinishes"
# Probes: every one must break, or an action can no longer fire. One probe per config, because a break stops the checker.
for probe in Full Ends Waits CapHolds SecondLife EndWaits; do
  fcfg "reach-timed-$probe" "Probe$probe" -
done
for probe in Full Waits CapHolds; do
  fcfg "reach-noclock-$probe" "Probe$probe" - Live=0
done
