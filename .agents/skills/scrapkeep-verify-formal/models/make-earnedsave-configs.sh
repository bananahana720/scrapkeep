#!/bin/bash
# Rewrites every earnedsave-*.cfg beside EarnedSave.tla. references/earnedsave-coverage.md says what each one must
# report.
# usage: make-earnedsave-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in ecfg.
cd "$(dirname "$0")"
ecfg() {
  local name=$1 rules=$2
  shift 2
  local keys="MaxFails MaxWrites SpendWrite SpendOwed OwedOnExit OwedOnResume ClearKeepsOwed ClearFlushes NewRunFlushes Quits ExitLands Crashes"
  # The code at the sync commit (P7 closed ES-1): one refused write, a quit anywhere, no crash.
  local c_MaxFails=1 c_MaxWrites=4 c_SpendWrite=TRUE c_SpendOwed=TRUE c_OwedOnExit=TRUE c_OwedOnResume=TRUE
  local c_ClearKeepsOwed=TRUE c_ClearFlushes=FALSE c_NewRunFlushes=FALSE c_Quits=TRUE c_ExitLands=FALSE c_Crashes=FALSE
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
# The code: no break with one refused write and a quit anywhere, and none with no refused write. The receipt's code
# config is today.
ecfg today "SaveOnce"
ecfg today-nofail "SaveOnce" MaxFails=0
# Two refused writes in one process (no quit): the spend write, then a restart from play (the pause menu's Restart or
# a held R) whose first entrance is refused. _begin_run clears the debt and flushes nothing, so the file keeps the old
# run with the save unspent and a Continue from the title fires it again (finding ES-3). Must report SaveOnce;
# newrun-fixed (_begin_run writes the held entrance with the spend first) holds.
ecfg today-inprocess "SaveOnce" MaxFails=2 Quits=FALSE
ecfg newrun-fixed "SaveOnce" MaxFails=2 Quits=FALSE NewRunFlushes=TRUE
# The same constants as today, under the name the findings use.
ecfg guarded "SaveOnce"
# What write order cannot close: a crash between the refused write and the next one that lands, and a disk that
# refuses every write until the game closes. Each must report SaveOnce (gaps named on the receipt).
ecfg guarded-crash "SaveOnce" Crashes=TRUE
ecfg guarded-allfail "SaveOnce" MaxFails=3
# Two refused writes, with the exit's write landing: the spend write and the dead run's tombstone (store.clear()).
# _record_end empties _entrance before the clear, so the owed spend has nothing left to flush at the exit; a later
# launch Continues the dead run with the save back (finding ES-2). today-clearfail is the code at that table and
# must report SaveOnce; TLC's shortest break there is ES-3's restart, so es2-only carries the ES-3 fix and its break
# is ES-2's alone. clearfail-fixed (a refused clear writes the held entrance with the spend first) fixes ES-2 only and
# still breaks, by ES-3; both-fixed, with both fixes, holds.
ecfg today-clearfail "SaveOnce" MaxFails=2 ExitLands=TRUE
ecfg es2-only "SaveOnce" MaxFails=2 ExitLands=TRUE NewRunFlushes=TRUE
ecfg clearfail-fixed "SaveOnce" MaxFails=2 ExitLands=TRUE ClearFlushes=TRUE
ecfg both-fixed "SaveOnce" MaxFails=2 ExitLands=TRUE ClearFlushes=TRUE NewRunFlushes=TRUE
# One guard off each: SaveOnce must break. broken-spendowed is the code before P7 (finding ES-1). The two-refusal
# plants carry the ES-3 fix, so newrun-fixed is the same table with the guard on and holds: each breaks by its own
# guard, not by ES-3.
ecfg broken-spendowed "SaveOnce" SpendOwed=FALSE
ecfg broken-exitflush "SaveOnce" OwedOnExit=FALSE
ecfg broken-resumeforce "SaveOnce" OwedOnResume=FALSE MaxFails=2 Quits=FALSE NewRunFlushes=TRUE
ecfg broken-clearowed "SaveOnce" ClearKeepsOwed=FALSE MaxFails=2 Quits=FALSE NewRunFlushes=TRUE
ecfg broken-spendwrite "SaveOnce" MaxFails=0 SpendWrite=FALSE
# Probes: every one must break.
for probe in Saved Died ContinueHolding Refused Owed TitleFlush RetryFlush ExitFlush NewRunOwed; do
  ecfg "reach-$probe" "Probe$probe"
done
ecfg reach-ClearRefused "ProbeClearRefused" MaxFails=2
ecfg reach-ResumeForced "ProbeResumeForced" MaxFails=2
ecfg reach-NewRunFlush "ProbeNewRunFlush" MaxFails=2 NewRunFlushes=TRUE
