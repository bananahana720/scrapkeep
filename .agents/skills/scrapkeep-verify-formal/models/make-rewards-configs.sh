#!/bin/bash
# Rewrites every rewards-*.cfg beside Rewards.tla. references/rewards-coverage.md says what each one must report.
# usage: make-rewards-configs.sh
# Each config line: name, rules to check, then Constant=VALUE overrides of the table in rcfg.
cd "$(dirname "$0")"
rcfg() {
  local name=$1
  local rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Procs MaxCrashes MaxFails MaxGen OldRun ReconcileCopies LedgerChecked GrantSavesOnce LegacyFromProfile PayAgainstFile SaveLock"
  local c_Procs="{p1}" c_MaxCrashes=2 c_MaxFails=2 c_MaxGen=6 c_OldRun=TRUE
  local c_ReconcileCopies="\"ledger\"" c_LedgerChecked=TRUE c_GrantSavesOnce=TRUE
  local c_LegacyFromProfile=TRUE c_PayAgainstFile=TRUE c_SaveLock=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-rewards-configs: unknown constant $key" >&2
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
    echo "CONSTRAINT Bounded"
    echo "INVARIANTS TypeOK $rules"
  } > "rewards-$name.cfg"
}
BOTH="AtMostOnce NeverLost LockInCall"
TWO=("Procs={p1, p2}" MaxCrashes=1 MaxGen=5)
# The code (W1-117): the legacy key honoured from the profile only, and an earn or grant that takes in the
# profile file under the save lock. Every start includes what an older build may have left (OldRun).
# Two games on one profile check one rule per config, because a break stops the checker before it covers the other.
rcfg today-one "$BOTH"
rcfg today-one-nofail "$BOTH" MaxFails=0
rcfg today-two-once "AtMostOnce LockInCall" "${TWO[@]}" MaxFails=1
rcfg today-two-lost "NeverLost" "${TWO[@]}" MaxFails=2
rcfg today-two-nofail-once "AtMostOnce" "${TWO[@]}" MaxFails=0
rcfg today-two-nofail-lost "NeverLost" "${TWO[@]}" MaxFails=0
# Ruling ea's trade, which must break AtMostOnce: game A pays in memory and both its saves fail, game B
# pays the reward that is not on disk, then A's next save lands its own grant too. Never lost outranks at most once.
rcfg ruled-two-twofail-once "AtMostOnce" "${TWO[@]}" MaxFails=2
# The code before W1-117 (pull request 1093 alone): the old-key route loses a reward, and two games each pay it.
BEFORE=(LegacyFromProfile=FALSE PayAgainstFile=FALSE SaveLock=FALSE)
rcfg guarded-one "NeverLost" "${BEFORE[@]}"
rcfg guarded-two-once "AtMostOnce" "${TWO[@]}" MaxFails=0 "${BEFORE[@]}"
rcfg guarded-two-lost "NeverLost" "${TWO[@]}" MaxFails=0 "${BEFORE[@]}"
# One guard off each, from today: the named rule must break.
rcfg broken-ledger "AtMostOnce" LedgerChecked=FALSE
rcfg broken-midsave "NeverLost" GrantSavesOnce=FALSE
rcfg broken-legacyrun "NeverLost" LegacyFromProfile=FALSE
rcfg broken-stale "AtMostOnce" "${TWO[@]}" MaxFails=0 PayAgainstFile=FALSE
rcfg broken-nolock "AtMostOnce" "${TWO[@]}" MaxFails=0 SaveLock=FALSE
# Reach probes: each MUST break, or an action has gone dead. Run each probe on its own: TLC stops at the first break,
# and -continue crashed TLC 1.7.4 on rewards-reach.
rcfg reach "ProbeLands ProbeContinue ProbeFail ProbeCrash ProbeTomb ProbeRunSettled ProbeOldEarn"
rcfg reach-two "ProbeLockWait" "${TWO[@]}" MaxFails=0
