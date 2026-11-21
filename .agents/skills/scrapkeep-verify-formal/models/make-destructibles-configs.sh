#!/bin/bash
# Rewrites every destructibles-*.cfg beside Destructibles.tla. references/destructibles-coverage.md says what each one
# must report.
# usage: make-destructibles-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in dcfg.
cd "$(dirname "$0")"
dcfg() {
  local name=$1 rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="TierA TierB Classes Bonuses ScrapCap CogCap MaxRetries BonusCap BlastNeedsIntact UnfileOnShatter CapClamp ColliderOff CutLine DropMount ClearAim RetryRestoresRun RetryClearsDrops"
  # Two pieces, a tier 1 and a tier 3, against caps that bind (the real stage is 14 pieces against 35 and 20).
  local c_TierA=1 c_TierB=3 c_Classes="{1, 2, 3}" c_Bonuses="{1, 2}"
  local c_ScrapCap=3 c_CogCap=1 c_MaxRetries=2 c_BonusCap=1
  local c_BlastNeedsIntact=TRUE c_UnfileOnShatter=TRUE c_CapClamp=TRUE c_ColliderOff=TRUE
  local c_CutLine=TRUE c_DropMount=TRUE c_ClearAim=TRUE c_RetryRestoresRun=TRUE c_RetryClearsDrops=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-destructibles-configs: unknown constant $key" >&2
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
  } > "destructibles-$name.cfg"
}
SAFE="PaysOnce RetryNoFarm NoLineOnRubble NoColliderAfterShatter TierCapNeverStacks"
# The code at the sync commit: every guard in place.
dcfg today "$SAFE"
# on_blast without its intact check is still safe: _unfile keeps a shattered piece out of _near (a second guard).
dcfg belt-repay "PaysOnce" BlastNeedsIntact=FALSE
# One guard off each, from today: the named rule must break. The repay plant takes both halves of "a blast skips
# rubble" off, because either alone holds (belt-repay).
dcfg broken-repay "PaysOnce" BlastNeedsIntact=FALSE UnfileOnShatter=FALSE
dcfg broken-nocap "PaysOnce" CapClamp=FALSE
dcfg broken-cutline "NoLineOnRubble" CutLine=FALSE
dcfg broken-dismount "NoLineOnRubble" DropMount=FALSE
dcfg broken-staleaim "NoLineOnRubble" ClearAim=FALSE
dcfg broken-collider "NoColliderAfterShatter" ColliderOff=FALSE
dcfg broken-retryfarm "RetryNoFarm" RetryRestoresRun=FALSE
dcfg broken-keepdrops "RetryNoFarm" RetryClearsDrops=FALSE
dcfg broken-tierstack "TierCapNeverStacks" BonusCap=2
# Probes: every one must break, or an action can no longer fire. One probe per config, because a break stops the checker.
for probe in OnBall OnBlast OnBlastBonus Aim Latch Mount Release Collect Retry Exit Death FreesLine FreesMount FreesAim \
  ScrapCap CogCap SecondAttemptBanks; do
  dcfg "reach-$probe" "Probe$probe"
done
