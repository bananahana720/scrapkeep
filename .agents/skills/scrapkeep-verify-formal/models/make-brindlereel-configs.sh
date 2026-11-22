#!/bin/bash
# Rewrites every brindlereel-*.cfg beside BrindleReel.tla.
# usage: make-brindlereel-configs.sh
cd "$(dirname "$0")"
bcfg() {
  local name=$1
  local rules=$2
  shift 2
  local keys="PhaseFloor TransTicks CraneNormal CraneReel SlagNormal SlagReel ChargeRunMax ChargeRestNormal ChargeRestReel StunTicks MaxReelGap MinTellTenths ReelAttacks ClampPhase2Reel RespectTransition TellGuard KeepCuedPromise"
  local c_PhaseFloor=12 c_TransTicks=2 c_CraneNormal=2 c_CraneReel=4 c_SlagNormal=8 c_SlagReel=5
  local c_ChargeRunMax=2 c_ChargeRestNormal=1 c_ChargeRestReel=1 c_StunTicks=3 c_MaxReelGap=6 c_MinTellTenths=6
  local c_ReelAttacks=TRUE c_ClampPhase2Reel=TRUE c_RespectTransition=TRUE c_TellGuard=TRUE c_KeepCuedPromise=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-brindlereel-configs: unknown constant $key" >&2
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
  } > "brindlereel-$name.cfg"
}
ALL="NoLongReelGap TellFloor NoTransitionCommit CuedPromiseKept"
# The shipped W46-05 behaviour: Brindle keeps pressing while reeling across all three hull phases.
bcfg today "$ALL"
# Planted faults: each disables one guard and must break its named invariant.
bcfg broken-stop "NoLongReelGap" ReelAttacks=FALSE
bcfg broken-unclamped "NoLongReelGap" ClampPhase2Reel=FALSE
bcfg broken-shorttell "TellFloor" TellGuard=FALSE
bcfg broken-transition "NoTransitionCommit" RespectTransition=FALSE
bcfg broken-dropcue "CuedPromiseKept" KeepCuedPromise=FALSE
