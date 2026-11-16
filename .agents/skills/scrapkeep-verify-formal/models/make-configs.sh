#!/bin/bash
# Rewrites every config beside RunFlow.tla. references/coverage.md says what each one must report.
cd "$(dirname "$0")"
ALL="TakeNamesHeldPart SeamOwned EndsOnce PickHeard StampOnlySeam LaunchLands WardenGoneOpens"
# The code as it is at the sync commit: flow._begin_run calls no _untake.
./mkcfg.sh today-store "$ALL" UntakeOnNewRun=FALSE
./mkcfg.sh today-nostore "$ALL" UntakeOnNewRun=FALSE Store=FALSE
# Every guard in place: the design the rules describe. Must report no break.
./mkcfg.sh guarded-store "$ALL"
./mkcfg.sh guarded-nostore "$ALL" Store=FALSE
# One guard off each: the named rule must break.
./mkcfg.sh broken-retry "TakeNamesHeldPart" Store=FALSE UntakeOnRetry=FALSE
./mkcfg.sh broken-end "TakeNamesHeldPart" UntakeOnEnd=FALSE
./mkcfg.sh broken-vanish "WardenGoneOpens" VanishGuard=FALSE
./mkcfg.sh broken-endguard "EndsOnce" EndGuard=FALSE
./mkcfg.sh broken-keys "PickHeard" SwipeOwnsKeys=FALSE
./mkcfg.sh broken-busy "SeamOwned StampOnlySeam LaunchLands" BusyRefuses=FALSE StageOutlastsSwipe=FALSE
# The time assumption off: shows what the assumption hides.
./mkcfg.sh untimed "$ALL" StageOutlastsSwipe=FALSE
