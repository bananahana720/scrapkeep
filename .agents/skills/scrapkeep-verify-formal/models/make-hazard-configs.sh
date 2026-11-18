#!/bin/bash
# Rewrites every hazard-*.cfg beside HazardCycle.tla. references/hazard-coverage.md says what each one must report.
# usage: make-hazard-configs.sh
# Each config line: name, rules to check, then Constant=VALUE overrides of the table in hcfg.
cd "$(dirname "$0")"
hcfg() {
  local name=$1
  local rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="Places TellTicks MinTell RestTicks StormTicks TellGuard SeekNeedsStall StrikeWhereTold HitsEnemies SeekOn"
  # One tick is 0.3 s: a 1.2 s tell is 4, the 0.6 s floor is 2. The rest and the storm are shortened (the code's
  # 5 s and 20 s); they set the bound's size, not the order of steps.
  local c_Places="{\"p1\", \"p2\", \"p3\"}" c_TellTicks=4 c_MinTell=2 c_RestTicks=3 c_StormTicks=10
  local c_TellGuard=TRUE c_SeekNeedsStall=TRUE c_StrikeWhereTold=TRUE c_HitsEnemies=TRUE c_SeekOn=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-hazard-configs: unknown constant $key" >&2
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
  } > "hazard-$name.cfg"
}
ALL="TellBeforeStrike RollingNeverSought StalledSought EnemyStruck BallOnlyWhereTold"
# The code (W44): every guard in place.
hcfg today "$ALL"
# One guard off each: the named rule must break.
hcfg broken-notell "TellBeforeStrike" TellGuard=FALSE
hcfg broken-seekrolling "RollingNeverSought" SeekNeedsStall=FALSE
hcfg broken-strikeatball "TellBeforeStrike" StrikeWhereTold=FALSE
hcfg broken-skipenemies "EnemyStruck" HitsEnemies=FALSE
hcfg broken-noseek "StalledSought" SeekOn=FALSE
