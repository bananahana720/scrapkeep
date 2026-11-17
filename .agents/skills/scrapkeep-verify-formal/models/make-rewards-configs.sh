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
  local keys="Procs MaxCrashes MaxFails MaxGen ReconcileCopies LedgerChecked GrantSavesOnce"
  local c_Procs="{p1}" c_MaxCrashes=2 c_MaxFails=2 c_MaxGen=6
  local c_ReconcileCopies="\"ledger\"" c_LedgerChecked=TRUE c_GrantSavesOnce=TRUE
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
BOTH="AtMostOnce NeverLost"
TWO=("Procs={p1, p2}" MaxCrashes=1 MaxGen=5)
# The code: one game, then each with no failed write. Since pull request 1093 the code is the narrow fix, ReconcileCopies="ledger" (the default above). Two games on one profile
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
