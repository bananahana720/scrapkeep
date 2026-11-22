#!/bin/bash
# Rewrites every sound-*.cfg beside SoundArbiter.tla. references/sound-coverage.md says what each one
# must report.
# usage: make-sound-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in scfg.
cd "$(dirname "$0")"
scfg() {
  local name=$1 rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="GuardWardenOverChamp GuardUnpinBoss GuardUltStack GuardDeathClearsUlt GuardMelodyLease GuardEpochTrim"
  local c_GuardWardenOverChamp=TRUE c_GuardUnpinBoss=TRUE c_GuardUltStack=TRUE
  local c_GuardDeathClearsUlt=TRUE c_GuardMelodyLease=TRUE c_GuardEpochTrim=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-sound-configs: unknown constant $key" >&2
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
  } > "sound-$name.cfg"
}
SAFE="WardenOwnsFightMusic BossMusicInArena BossFinaleWinsOverAll UltimateRestoresChampion DeathClearsUltFlight OneMelodyNoClash NoStaleTrim"
# The code at the sync commit: every guard in place.
scfg today "$SAFE"
# One guard off each, from today: the named rule must break.
scfg broken-warden-champ "WardenOwnsFightMusic" GuardWardenOverChamp=FALSE
scfg broken-unpin-boss "BossMusicInArena" GuardUnpinBoss=FALSE
scfg broken-ult-champ "UltimateRestoresChampion" GuardUltStack=FALSE
scfg broken-death-ult "DeathClearsUltFlight" GuardDeathClearsUlt=FALSE
scfg broken-melody-clash "OneMelodyNoClash" GuardMelodyLease=FALSE
scfg broken-stale-trim "NoStaleTrim" GuardEpochTrim=FALSE
# Probes: every one must break, or an action can no longer fire.
for probe in WardenOverChamp BossFinale BossRadioPin UltFlight JuneAnswer Death; do
  scfg "reach-$probe" "Probe$probe"
done
