#!/bin/bash
# Rewrites every earnedsave-*.cfg beside EarnedSave.tla. references/rewards-findings.md (finding ES-1) says what each
# one must report.
# usage: make-earnedsave-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in ecfg.
cd "$(dirname "$0")"
ecfg() {
  local name=$1 rules=$2
  shift 2
  local keys="MaxFails MaxWrites SpendWrite SpendOwed Crashes"
  # The code at the sync commit: one refused write, a quit or a crash anywhere.
  local c_MaxFails=1 c_MaxWrites=3 c_SpendWrite=TRUE c_SpendOwed=FALSE c_Crashes=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-earnedsave-configs: unknown constant $key" >&2
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
  } > "earnedsave-$name.cfg"
}
# The code: must report SaveOnce (finding ES-1). With no refused write it holds.
ecfg today "SaveOnce"
ecfg today-nofail "SaveOnce" MaxFails=0
# The ES-1 fix (an owed spend written again before the pause menu's quit): no break with no crash; a crash in the
# window between the refused write and the next one that lands still hands the save back, which this config shows.
ecfg guarded "SaveOnce" SpendOwed=TRUE Crashes=FALSE
ecfg guarded-crash "SaveOnce" SpendOwed=TRUE
# The fix, no crash, with every write refused until the game closes: the owed spend never lands, so SaveOnce breaks.
ecfg guarded-allfail "SaveOnce" SpendOwed=TRUE Crashes=FALSE MaxFails=3
# The guard the code has, off, from today-nofail: SaveOnce must break.
ecfg broken-spendwrite "SaveOnce" MaxFails=0 SpendWrite=FALSE
# Probes: every one must break.
for probe in Saved Died ContinueHolding Refused; do
  ecfg "reach-$probe" "Probe$probe"
done
