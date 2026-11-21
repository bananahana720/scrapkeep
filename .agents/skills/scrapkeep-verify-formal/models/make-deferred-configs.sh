#!/bin/bash
# Rewrites every deferred-*.cfg beside DeferredEffects.tla. references/deferred-coverage.md says what each one must
# report.
# usage: make-deferred-configs.sh
# Each config line: name, invariants, then Constant=VALUE overrides of the table in dcfg.
cd "$(dirname "$0")"
dcfg() {
  local name=$1 rules=$2
  shift 2
  # Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
  local keys="MaxAtt ShotSets MaxShotBits HoarHeld TickInPlay AttemptClearsEcho AttemptClearsCast AttemptClearsGuards AttemptClearsPike AttemptClearsBolts RakeNeedsWeapon PikeNeedsWeapon ProcCarriesNoBits PikeCapsBits EchoBare TollBare ShockBare ReelBare ChildSpendsSplit ChildSpendsPull ChildDropsHoar BounceSpends ContactDropsMark DeathDropsMark"
  # The code at the sync commit. Two shot sets cover every pair of bits the split, pierce, pull, bounce and heat
  # rows name; the second is full, so a Slag Pike fuse must drop a bit to add pierce.
  local c_MaxAtt=2 c_MaxShotBits=3 c_HoarHeld=TRUE
  local c_ShotSets='{{"pierce", "split", "pull"}, {"bounce", "split", "heat"}}'
  local c_TickInPlay=TRUE c_AttemptClearsEcho=TRUE c_AttemptClearsCast=TRUE c_AttemptClearsGuards=TRUE
  local c_AttemptClearsPike=TRUE c_AttemptClearsBolts=TRUE c_RakeNeedsWeapon=TRUE c_PikeNeedsWeapon=TRUE
  local c_ProcCarriesNoBits=TRUE c_PikeCapsBits=TRUE c_EchoBare=TRUE c_TollBare=TRUE c_ShockBare=TRUE c_ReelBare=TRUE
  local c_ChildSpendsSplit=TRUE c_ChildSpendsPull=TRUE c_ChildDropsHoar=TRUE c_BounceSpends=TRUE
  local c_ContactDropsMark=TRUE c_DeathDropsMark=TRUE
  local kv key v
  for kv in "$@"; do
    key=${kv%%=*}
    case " $keys " in
      *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
      *)
        echo "make-deferred-configs: unknown constant $key" >&2
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
  } > "deferred-$name.cfg"
}
RULES="ProcDepthOne NoEchoAcrossAttempt ShotBitsCap"
# The code at the sync commit: no break.
dcfg today "$RULES"
# One guard off each: the named rule must break.
dcfg broken-ungated "NoEchoAcrossAttempt" TickInPlay=FALSE
dcfg broken-keepecho "NoEchoAcrossAttempt" AttemptClearsEcho=FALSE
dcfg broken-keepcast "NoEchoAcrossAttempt" AttemptClearsCast=FALSE
dcfg broken-keepguards "NoEchoAcrossAttempt" AttemptClearsGuards=FALSE
dcfg broken-keeppike "NoEchoAcrossAttempt" AttemptClearsPike=FALSE
dcfg broken-keepbolts "NoEchoAcrossAttempt" AttemptClearsBolts=FALSE
dcfg broken-rakeproc "ProcDepthOne" RakeNeedsWeapon=FALSE
dcfg broken-pikeproc "ProcDepthOne" PikeNeedsWeapon=FALSE
dcfg broken-procbits "ProcDepthOne" ProcCarriesNoBits=FALSE
dcfg broken-echoagain "ProcDepthOne" EchoBare=FALSE
dcfg broken-tollagain "ProcDepthOne" TollBare=FALSE
dcfg broken-shockagain "ProcDepthOne" ShockBare=FALSE
dcfg broken-reelagain "ProcDepthOne" ReelBare=FALSE
dcfg broken-childsplit "ShotBitsCap" ChildSpendsSplit=FALSE
dcfg broken-childpull "ShotBitsCap" ChildSpendsPull=FALSE
dcfg broken-childhoar "ShotBitsCap" ChildDropsHoar=FALSE
dcfg broken-rebounce "ShotBitsCap" BounceSpends=FALSE
dcfg broken-pikebits "ShotBitsCap" PikeCapsBits=FALSE
dcfg broken-contactmark "ShotBitsCap" ContactDropsMark=FALSE
dcfg broken-deathmark "ShotBitsCap" DeathDropsMark=FALSE
# Probes: every one must break, or an action can no longer fire. One probe per config, because a break stops the
# checker.
for probe in EnterStage ContentCleared NewRun Death ToTitle Press ProcVolley Slam Special Dash CastBegins BiteLoads \
  ReelChain GuardLink GuardUnlink RakeFires ShockLands BellTolls EchoFires StripStrikes CastLands BiteFires PikeRead \
  PikeFuse BoltSplits BoltPierces BoltStops BoltGlances BoltWall BoltSpent HoarChild Spawn Expose Lapses DropExpired \
  ContactRead FoeDies CorpseFreed KeptOverDeath; do
  dcfg "reach-$probe" "Probe$probe"
done
