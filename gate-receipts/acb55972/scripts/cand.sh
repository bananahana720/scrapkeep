#!/bin/bash
# Promotion full gate on /home/user/wt/cand, resumable: non-bot chunks, bot chunks, then the cautious persona.
S=/tmp/claude-0/-home-user-scrapkeep/7e738075-88af-5134-95c5-df1ca3ee0b9d/scratchpad; W=/home/user/wt/cand; G=/home/user/scrapkeep/artifacts/local/gate
git -C $W restore sketches/core-loop/assets sketches/core-loop/design-v3 2>/dev/null
[ "$(git -C $W rev-parse --short=8 HEAD)" = acb55972 ] || { echo "cand moved"; exit 2; }
bash $S/gate.sh $W $S/shards/cand-nonbot.txt candnb 120 || exit $?
bash $S/gate.sh $W $S/shards/cand-bots.txt candbot 3 --bots || exit $?
P=$G/w18/persona-cautious-acb55972.log
[ -f $P.done ] || (cd $W && node scripts/redteam/run.mjs --wave=18 --persona=cautious --slots=2 > $P 2>&1; c=$?; echo "persona exit=$c"; [ $c -eq 0 ] && touch $P.done)
git -C $W restore sketches/core-loop/assets sketches/core-loop/design-v3 2>/dev/null; echo CAND-DONE
