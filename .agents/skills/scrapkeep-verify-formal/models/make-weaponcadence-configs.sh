#!/bin/bash
# Rewrites every weaponcadence-*.cfg beside WeaponCadence.tla. references/weaponcadence-coverage.md
# says what each one must report.
# usage: make-weaponcadence-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in wcfg.
cd "$(dirname "$0")"
wcfg() {
  local name=$1 rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Mag FloorTicks BufferTicks ReloadTicks WindowOpen WindowClose RecoverTicks ChargeMax MaxPressure CastCost StampRefund MaxReadyBound GuardPlayGate GuardBoundaryReset AllowDirectTitleQuit GuardTitleReset GuardJamNoFreeze GuardInterruptDropsHold GuardPressNoRepeat GuardProcIsolated GuardEarlyPressSpends GuardWindowOnce GuardRefundBound GuardSnapOnce GuardDetLineConsumes GuardSnapHoldLock GuardBeatsNoRepeat GuardBeatsOrder GuardLockInterruptClears"
  local c_Mag=2 c_FloorTicks=2 c_BufferTicks=1 c_ReloadTicks=4
  local c_WindowOpen=2 c_WindowClose=2 c_RecoverTicks=1 c_ChargeMax=2
  local c_MaxPressure=6 c_CastCost=2 c_StampRefund=1 c_MaxReadyBound=4
  local c_GuardPlayGate=TRUE c_GuardBoundaryReset=TRUE c_AllowDirectTitleQuit=FALSE
  local c_GuardTitleReset=TRUE c_GuardJamNoFreeze=TRUE c_GuardInterruptDropsHold=TRUE
  local c_GuardPressNoRepeat=TRUE c_GuardProcIsolated=TRUE c_GuardEarlyPressSpends=TRUE
  local c_GuardWindowOnce=TRUE c_GuardRefundBound=TRUE c_GuardSnapOnce=TRUE
  local c_GuardDetLineConsumes=TRUE c_GuardSnapHoldLock=TRUE c_GuardBeatsNoRepeat=TRUE
  local c_GuardBeatsOrder=TRUE c_GuardLockInterruptClears=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-weaponcadence-configs: unknown constant $key" >&2
        exit 2
        ;;
    esac
  done
  {
    echo "SPECIFICATION Spec"
    echo "CONSTANTS"
    for key in $keys; do
      v="c_$key"
      echo "  $key = ${!v}"
    done
    echo "INVARIANTS TypeOK $rules"
  } > "weaponcadence-$name.cfg"
}
SAFE="NoShotOutsidePlay RestAfterBoundary BoundedReadyAfterInterrupt OneVolleyPerPress WindowPaysAtMostOnce RefundNeverExceedsSpend"
# The code at the sync commit: every guard in place (including AllowDirectTitleQuit).
wcfg today "$SAFE" AllowDirectTitleQuit=TRUE
# One guard off each: the named rule must break.
wcfg broken-play-gate "NoShotOutsidePlay" GuardPlayGate=FALSE
wcfg broken-boundary-reset "RestAfterBoundary" GuardBoundaryReset=FALSE
wcfg broken-title-reset "RestAfterBoundary" AllowDirectTitleQuit=TRUE GuardTitleReset=FALSE
wcfg broken-jam-freeze "BoundedReadyAfterInterrupt" GuardJamNoFreeze=FALSE
wcfg broken-interrupt-hold "BoundedReadyAfterInterrupt" GuardInterruptDropsHold=FALSE
wcfg broken-lock-stuck "BoundedReadyAfterInterrupt" GuardLockInterruptClears=FALSE
wcfg broken-hold-repeat "OneVolleyPerPress" GuardPressNoRepeat=FALSE
wcfg broken-beats-hold-repeat "OneVolleyPerPress" GuardBeatsNoRepeat=FALSE
wcfg broken-snap-hold-lock "OneVolleyPerPress" GuardSnapHoldLock=FALSE
wcfg broken-proc-touch "OneVolleyPerPress" GuardProcIsolated=FALSE
wcfg broken-early-mash "WindowPaysAtMostOnce" GuardEarlyPressSpends=FALSE
wcfg broken-double-notch "WindowPaysAtMostOnce" GuardWindowOnce=FALSE
wcfg broken-double-snap "WindowPaysAtMostOnce" GuardSnapOnce=FALSE
wcfg broken-detline-double "WindowPaysAtMostOnce" GuardDetLineConsumes=FALSE
wcfg broken-beats-skip "WindowPaysAtMostOnce" GuardBeatsOrder=FALSE
wcfg broken-refund "RefundNeverExceedsSpend" GuardRefundBound=FALSE
# Probes: every one must break, or an action can no longer fire.
wcfg reach-boundary-reset "ProbeBoundaryReset"
wcfg reach-cannon-barrage "ProbeCannonBarrage"
wcfg reach-cannon-interrupt "ProbeCannonInterrupt"
wcfg reach-cannon-pulse "ProbeCannonPulse"
wcfg reach-cannon-rail "ProbeCannonRail"
wcfg reach-charged-bolt "ProbeChargedBolt"
wcfg reach-early-spend "ProbeEarlySpend"
wcfg reach-jam-fire "ProbeJamFire"
wcfg reach-kest-detline "ProbeKestDetLine"
wcfg reach-kest-snap "ProbeKestSnap"
wcfg reach-kest-throw "ProbeKestThrow"
wcfg reach-mount-drop "ProbeMountDrop"
wcfg reach-notch-hit "ProbeNotchHit"
wcfg reach-plain-fire "ProbePlainFire"
wcfg reach-proc-no-touch "ProbeProcNoTouch"
wcfg reach-reload "ProbeReload"
wcfg reach-spark "ProbeSpark"
wcfg reach-stamp-refund "ProbeStampRefund"
wcfg reach-tarn-beat3 "ProbeTarnBeat3"
wcfg reach-top-up "ProbeTopUp"
wcfg reach-ult-interrupt "ProbeUltInterrupt"
