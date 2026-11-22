#!/bin/bash
# Rewrites every earnedsave-*.cfg beside EarnedSave.tla. references/earnedsave-coverage.md says what each one must
# report.
# usage: make-earnedsave-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in ecfg.
cd "$(dirname "$0")"
rm -f earnedsave-*.cfg
ecfg() {
  local name=$1 rules=$2
  shift 2
  local keys="MaxFails MaxWrites SpendWrite SpendOwed OwedOnExit OwedOnResume ClearKeepsOwed ClearFlushes NewRunFlushes Quits ExitLands Crashes"
  # The code at the sync commit (P7 closed ES-1; P9 closed ES-2 and ES-3): one refused write, a quit anywhere, no crash.
  local c_MaxFails=1 c_MaxWrites=4 c_SpendWrite=TRUE c_SpendOwed=TRUE c_OwedOnExit=TRUE c_OwedOnResume=TRUE
  local c_ClearKeepsOwed=TRUE c_ClearFlushes=TRUE c_NewRunFlushes=TRUE c_Quits=TRUE c_ExitLands=FALSE c_Crashes=FALSE
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
# The code: no break with one refused write and a quit anywhere, none with no refused write, none with two refused
# writes in one process (the table ES-3 used to break), none with two refused writes and a quit whose exit flush lands
# (the table ES-2 used to break), and none with three refused writes in a row across a refused death or restart once the
# disk recovers before exit (sustained refusal, matching replay/earned_save_after_p7.gd).
ecfg today "SaveOnce"
ecfg today-nofail "SaveOnce" MaxFails=0
ecfg today-inprocess "SaveOnce" MaxFails=2 Quits=FALSE
ecfg today-clearfail "SaveOnce" MaxFails=2 ExitLands=TRUE
ecfg today-sustained "SaveOnce" MaxFails=3 ExitLands=TRUE
# The same constants as today, under the name the findings use.
ecfg guarded "SaveOnce"
# What write order cannot close: a crash between the refused write and the next one that lands, and a disk that
# refuses every write until the game closes. Each must report SaveOnce (gaps named on the receipt).
ecfg guarded-crash "SaveOnce" Crashes=TRUE
ecfg guarded-allfail "SaveOnce" MaxFails=3
# One guard off each: SaveOnce must break, by that guard's own path.
# broken-spendowed is ES-1 (before P7); broken-clearflush is ES-2 and broken-newrunflush is ES-3 (before P9).
# broken-clearowed needs three refused writes so both store.clear() and _record_end's immediate flush can fail.
ecfg broken-spendowed "SaveOnce" SpendOwed=FALSE
ecfg broken-exitflush "SaveOnce" OwedOnExit=FALSE
ecfg broken-resumeforce "SaveOnce" OwedOnResume=FALSE MaxFails=2 Quits=FALSE
ecfg broken-clearowed "SaveOnce" ClearKeepsOwed=FALSE MaxFails=3 Quits=FALSE
ecfg broken-spendwrite "SaveOnce" MaxFails=0 SpendWrite=FALSE
ecfg broken-clearflush "SaveOnce" ClearFlushes=FALSE MaxFails=2 ExitLands=TRUE
ecfg broken-newrunflush "SaveOnce" NewRunFlushes=FALSE MaxFails=2 Quits=FALSE
# Probes: every one must break.
for probe in Saved Died ContinueHolding Refused Owed TitleFlush RetryFlush ExitFlush; do
  ecfg "reach-$probe" "Probe$probe"
done
ecfg reach-ClearRefused "ProbeClearRefused" MaxFails=2
ecfg reach-ClearFlush "ProbeClearFlush" MaxFails=2
ecfg reach-ClearKeepsOwed "ProbeClearKeepsOwed" MaxFails=3
ecfg reach-ResumeForced "ProbeResumeForced" MaxFails=2
ecfg reach-NewRunOwed "ProbeNewRunOwed" NewRunFlushes=FALSE
ecfg reach-NewRunFlush "ProbeNewRunFlush" MaxFails=2
ecfg reach-NewRunKeepsOwed "ProbeNewRunKeepsOwed" MaxFails=3
