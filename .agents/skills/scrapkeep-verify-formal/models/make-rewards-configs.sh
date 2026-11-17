#!/bin/bash
# Rewrites every rewards-*.cfg beside Rewards.tla. references/rewards-coverage.md says what each one must report.
# usage: make-rewards-configs.sh
# Each config line: name, rules to check, then Constant=VALUE overrides of the table in rcfg.
cd "$(dirname "$0")"
rcfg() {
  local name=$1
  local rules=$2
  shift 2
  declare -A c=(
    [Procs]="{p1}" [MaxCrashes]=2 [MaxFails]=2 [MaxGen]=6
    [ReconcileCopies]="\"all\"" [LedgerChecked]=TRUE [GrantSavesOnce]=TRUE
  )
  local kv key
  for kv in "$@"; do
    key=${kv%%=*}
    if [ -z "${c[$key]}" ]; then
      echo "make-rewards-configs: unknown constant $key" >&2
      exit 2
    fi
    c[$key]=${kv#*=}
  done
  {
    echo "SPECIFICATION Spec"
    echo "CONSTANTS"
    for key in $(printf '%s\n' "${!c[@]}" | sort); do
      echo "  $key = ${c[$key]}"
    done
    echo "CONSTRAINT Bounded"
    echo "INVARIANTS TypeOK $rules"
  } > "rewards-$name.cfg"
}
BOTH="AtMostOnce NeverLost"
TWO=("Procs={p1, p2}" MaxCrashes=1 MaxGen=5)
# The code at the sync commit: one game, then each with no failed write. Two games on one profile
# check one rule per config, because a break stops the checker before it covers the other rule.
rcfg today-one "$BOTH"
rcfg today-one-nofail "$BOTH" MaxFails=0
rcfg today-two-once "AtMostOnce" "${TWO[@]}" MaxFails=1
rcfg today-two-lost "NeverLost" "${TWO[@]}" MaxFails=2
rcfg today-two-nofail-once "AtMostOnce" "${TWO[@]}" MaxFails=0
rcfg today-two-nofail-lost "NeverLost" "${TWO[@]}" MaxFails=0
# The candidate fix: Continue copies the run document's ledger ids into the profile, never its reward keys.
rcfg guarded-one "$BOTH" ReconcileCopies=\"ledger\"
rcfg guarded-two-once "AtMostOnce" "${TWO[@]}" MaxFails=1 ReconcileCopies=\"ledger\"
rcfg guarded-two-lost "NeverLost" "${TWO[@]}" MaxFails=2 ReconcileCopies=\"ledger\"
# One guard off each, from guarded-one: the named rule must break.
rcfg broken-ledger "AtMostOnce" ReconcileCopies=\"ledger\" LedgerChecked=FALSE
rcfg broken-midsave "NeverLost" ReconcileCopies=\"ledger\" GrantSavesOnce=FALSE
# Reach probes: each MUST break, or an action has gone dead.
rcfg reach "ProbeLands ProbeContinue ProbeFail ProbeCrash ProbeTomb ProbeRunSettled"
