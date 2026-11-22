--------------------------- MODULE DeferredEffects ---------------------------
(* The deferred combat effects: everything sketches/core-loop/src/combat/combat.gd holds now and fires later, the
   follow-up procs that fire at once, the shot bits sketches/core-loop/src/combat/bolts.gd carries through a split
   or a bounce, and the exposure marks drawn on an enemy, across the attempt boundaries the run flow in
   sketches/core-loop/src/core/flow.gd makes. references/deferred-coverage.md has the code behind every step.

   Combat's _physics_process returns unless ctx.flow.in_play() (STAGE, BEACON, GATES, LAUNCH, BOSS, LAP), so the
   clock, the queues and the bolts move only in play. An attempt ends at a stage entry or retry (stage_entered ->
   _on_stage_entered -> _start_attempt), an arena entry, arena retry or victory lap (stage_content_cleared ->
   _on_stage_content_cleared -> _start_attempt), a new run (run_started, then stage_entered), a death
   (player_died -> _on_player_died, then flow leaves play) and a quit to the title. Each queue is bounded to one
   waiting item: the items of a queue never meet each other, so one stands for all. A queued item is "fresh" when
   the attempt in play made it and "old" once an attempt boundary has passed over it. One bolt lineage is tracked
   at a time; at a split the model follows the parent or one of the two children (they are copies). *)
EXTENDS Naturals, FiniteSets

CONSTANTS
  MaxAtt,              \* attempt boundaries a behaviour may cross (stage entries, retries, clears, new runs)
  ShotSets,            \* the shot bit sets a player's own press may carry (each at most MAX_SHOT_BITS)
  MaxShotBits,         \* shot_bits.gd MAX_SHOT_BITS
  HoarHeld,            \* Hoar Barrel held: a pierce shot carries hoar and its own hoar_spared list
  TickInPlay,          \* combat._physics_process: `if not playing ... return` gates every deferred step
  AttemptClearsEcho,   \* _start_attempt: _echo = {} (F002)
  AttemptClearsCast,   \* _start_attempt: _cast_pending = {}, _bite_pending = false (P7)
  AttemptClearsGuards, \* _start_attempt: _guards.clear() (P7)
  AttemptClearsPike,   \* _start_attempt: _pike_count = 0, _pike_last = -INF
  AttemptClearsBolts,  \* _start_attempt -> _clear_fight -> bolts.clear()
  RakeNeedsWeapon,     \* rake_follows: only source "weapon" queues a Rake Heart return
  PikeNeedsWeapon,     \* _pike_press: only source "weapon" advances the Slag Pike count
  ProcCarriesNoBits,   \* _fire: `shot = _shot_bits() if source == "weapon" else 0`
  PikeCapsBits,        \* fused_bits: a fourth bit is dropped when pierce is added to a full set
  EchoBare,            \* _tick_echo calls row.fire alone: no echo armed again, no Second Bell rung
  TollBare,            \* _toll never reaches _ring_bell
  ShockBare,           \* _aftershock strikes as item_proc and publishes no slam fact
  ReelBare,            \* _on_reel_chain's jump never emits harpoon_smashed
  ChildSpendsSplit,    \* bolts.gd split_spent: a child has split (and pull) spent
  ChildSpendsPull,     \* the same call: pull spent, so only the first hit pulls
  ChildDropsHoar,      \* split_children: kid.erase("hoar"), kid.erase("hoar_spared")
  BounceSpends,        \* _glance: bounce spent, so a second wall stops the bolt
  ContactDropsMark,    \* _door_caps: an expired row read by a contact hit goes through _drop_exposed (P7)
  DeathDropsMark       \* spawn_enemy's died handler: _drop_exposed(id) and the arc key (P7)

Queues == {"rake", "shock", "bell", "strip", "echo", "cast", "bite"}
\* _on_player_died clears these; echo, the pike count, the guards, heat, exposure and the bolts stay.
DeathClears == {"rake", "shock", "bell", "strip", "cast", "bite"}
BitNames == {"pierce", "bounce", "split", "pull", "heat"}
Order == <<"pierce", "bounce", "split", "pull", "heat">>   \* shot_bits.gd NAMES
Idx(n) == CHOOSE i \in 1..5 : Order[i] = n
Rec == {"none", "fresh", "old"}

ASSUME \A s \in ShotSets : s \subseteq BitNames

VARIABLES
  flow,       \* "play" (flow.in_play()), "dead" (DEAD, or SUMMARY after a death), "title"
  att,        \* attempt boundaries crossed
  q,          \* [Queues -> Rec]: _rakes, _aftershocks, _bells, _strips, _echo, _cast_pending, _bite_pending
  pike,       \* _pike_count: "none" (0) or a count part way to the fuse
  guards,     \* _guards: a guard link held
  heat,       \* _heated: a machine glowing
  foe,        \* one enemy: "alive", "corpse" (dead, its node still in the tree), "gone" (freed)
  expo,       \* its _exposed row: "none", "live", "expired" (until <= _clock, not yet dropped)
  expoOld,    \* the row was set in an earlier attempt
  mark,       \* its CannonExposure or ArcMark node is in the tree
  b,          \* the tracked bolt lineage
  deep,       \* history: something fired at proc depth 2
  stale,      \* history: an item made in one attempt fired in another, or outside play
  last

vars == <<flow, att, q, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale, last>>

NoBolt == [live |-> FALSE, proc |-> FALSE, old |-> FALSE, bits |-> {}, spent |-> {}, gen |-> 0, fam |-> 0,
           bounces |-> 0, hoar |-> FALSE, spared |-> "none", pulledAsChild |-> FALSE]

\* fused_bits: pierce on; a set already at MAX_SHOT_BITS drops its last bit in NAMES order first.
LastOf(s) == CHOOSE x \in s : \A y \in s : Idx(y) <= Idx(x)
Fused(s) == IF "pierce" \in s THEN s
            ELSE IF PikeCapsBits /\ Cardinality(s) >= MaxShotBits THEN (s \ {LastOf(s)}) \cup {"pierce"}
            ELSE s \cup {"pierce"}

\* bolts.fire with a record from _bolt_record: _evolve_record gives a weapon shot hoar only when it pierces.
NewBolt(bits, isProc) ==
  [live |-> TRUE, proc |-> isProc, old |-> FALSE, bits |-> bits, spent |-> {}, gen |-> 0, fam |-> 1, bounces |-> 0,
   hoar |-> (HoarHeld /\ ~isProc /\ "pierce" \in bits), spared |-> IF HoarHeld /\ ~isProc /\ "pierce" \in bits
                                                             THEN "own" ELSE "none",
   pulledAsChild |-> FALSE]

Ready(x) == x \in b.bits \ b.spent

\* Combat's tick runs.
Ticking == flow = "play" \/ ~TickInPlay

\* An item fires: stale when it came from an earlier attempt or fires outside play.
Fires(v) == stale' = (stale \/ v = "old" \/ flow # "play")

\* An attempt boundary: kept records are marked old.
Age(v) == IF v = "none" THEN "none" ELSE "old"
Keep(clears, v) == IF clears THEN "none" ELSE Age(v)

\* _start_attempt (from _on_stage_entered and _on_stage_content_cleared): _clear_fight frees every enemy (their
\* marks with them) and clears the bolts; every queue and record is dropped.
StartAttempt ==
  /\ q' = [k \in Queues |-> CASE k = "echo" -> Keep(AttemptClearsEcho, q[k])
                              [] k \in {"cast", "bite"} -> Keep(AttemptClearsCast, q[k])
                              [] OTHER -> "none"]
  /\ pike' = Keep(AttemptClearsPike, pike)
  /\ guards' = Keep(AttemptClearsGuards, guards)
  /\ heat' = "none"
  /\ foe' = "gone" /\ expo' = "none" /\ expoOld' = FALSE /\ mark' = FALSE
  /\ b' = IF AttemptClearsBolts \/ ~b.live THEN NoBolt ELSE [b EXCEPT !.old = TRUE]

\* Leaving play: nothing is cleared but what _on_player_died clears (dying), and every kept record ages.
LeavePlay(dying) ==
  /\ q' = [k \in Queues |-> IF dying /\ k \in DeathClears THEN "none" ELSE Age(q[k])]
  /\ pike' = Age(pike) /\ guards' = Age(guards) /\ heat' = Age(heat)
  /\ expoOld' = (expo # "none")
  /\ b' = IF b.live THEN [b EXCEPT !.old = TRUE] ELSE b
  /\ UNCHANGED <<foe, expo, mark>>

Init ==
  /\ flow = "title" /\ att = 0
  /\ q = [k \in Queues |-> "none"] /\ pike = "none" /\ guards = "none" /\ heat = "none"
  /\ foe = "gone" /\ expo = "none" /\ expoOld = FALSE /\ mark = FALSE
  /\ b = NoBolt /\ deep = FALSE /\ stale = FALSE /\ last = "Init"

Step(name) == last' = name

(* ---- The run flow's boundaries ---- *)

\* flow.enter_stage (the next stage's entrance, a Continue's entrance) or retry_stage (a held R, the dead screen's
\* key): stage_entered.
EnterStage ==
  /\ flow \in {"play", "dead"} /\ att < MaxAtt
  /\ flow' = "play" /\ att' = att + 1 /\ StartAttempt
  /\ Step("EnterStage") /\ UNCHANGED <<deep, stale>>

\* flow.enter_boss, _retry_arena, the victory lap: stage_content_cleared.
ContentCleared ==
  /\ flow \in {"play", "dead"} /\ att < MaxAtt
  /\ flow' = "play" /\ att' = att + 1 /\ StartAttempt
  /\ Step("ContentCleared") /\ UNCHANGED <<deep, stale>>

\* flow._begin_run or resume_run: run_started (its handler clears the same records and _free_cannon the marks),
\* then enter_stage's stage_entered, in one call.
NewRun ==
  /\ att < MaxAtt
  /\ flow' = "play" /\ att' = att + 1 /\ StartAttempt
  /\ Step("NewRun") /\ UNCHANGED <<deep, stale>>

\* run_state emits player_died: combat._on_player_died, then flow leaves play (DEAD, or SUMMARY with a store).
Death ==
  /\ flow = "play"
  /\ flow' = "dead" /\ LeavePlay(TRUE)
  /\ Step("Death") /\ UNCHANGED <<att, deep, stale>>

\* show_title, from play or the dead screen.
ToTitle ==
  /\ flow \in {"play", "dead"}
  /\ flow' = "title" /\ LeavePlay(FALSE)
  /\ Step("ToTitle") /\ UNCHANGED <<att, deep, stale>>

(* ---- The player's own acts, depth 0 (the ball and its input move only in play) ---- *)

\* A weapon press: _fire(weapon, "weapon"). It may throw a bolt with the build's shot bits, queue a Rake Heart
\* return (claw_rake), and advance the Slag Pike count, which may fuse this volley into one pierce bolt.
Press ==
  /\ flow = "play"
  /\ \E bits \in ShotSets, bolt \in BOOLEAN, rake \in BOOLEAN, fuse \in BOOLEAN :
       /\ fuse => pike = "fresh"
       /\ b' = IF bolt /\ ~b.live THEN NewBolt(IF fuse THEN Fused(bits) ELSE bits, FALSE) ELSE b
       /\ q' = IF rake /\ q["rake"] = "none" THEN [q EXCEPT !["rake"] = "fresh"] ELSE q
       /\ pike' = IF fuse THEN "none" ELSE "fresh"
  /\ Step("Press") /\ UNCHANGED <<flow, att, guards, heat, foe, expo, expoOld, mark, deep, stale>>

\* A tree proc's volley: _proc_volley -> _fire(weapon, "item_proc"), depth 1. It carries no shot bits, queues no
\* rake and leaves the pike count alone.
ProcVolley ==
  /\ Ticking
  /\ \E bits \in ShotSets, bolt \in BOOLEAN :
       /\ b' = IF bolt /\ ~b.live THEN NewBolt(IF ProcCarriesNoBits THEN {} ELSE bits, TRUE) ELSE b
       /\ q' = IF ~RakeNeedsWeapon /\ q["rake"] = "none" THEN [q EXCEPT !["rake"] = "fresh"] ELSE q
       /\ pike' = IF PikeNeedsWeapon THEN pike ELSE "fresh"
       /\ deep' = (deep \/ ~RakeNeedsWeapon \/ ~PikeNeedsWeapon)
  /\ Step("ProcVolley") /\ UNCHANGED <<flow, att, guards, heat, foe, expo, expoOld, mark, stale>>

\* A slam landing with Fault Hammer: _on_fault_slammed queues an aftershock (it returns outside play).
Slam ==
  /\ flow = "play" /\ q["shock"] = "none"
  /\ q' = [q EXCEPT !["shock"] = "fresh"]
  /\ Step("Slam") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale>>

\* A kit special's release (_step_special) or a SPECIAL tap landing (_land_tap): Twin Discharge arms the echo
\* (gauge release only), Second Bell rings the footprint again later (_ring_bell).
Special ==
  /\ flow = "play"
  /\ \E echo \in BOOLEAN, bell \in BOOLEAN :
       q' = [k \in Queues |-> IF (k = "echo" /\ echo) \/ (k = "bell" /\ bell) THEN "fresh" ELSE q[k]]
  /\ Step("Special") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale>>

\* Backwash: a dash or boost lays a strip behind the ball (_lay_strip strikes now, as item_proc).
Dash ==
  /\ flow = "play" /\ q["strip"] = "none"
  /\ q' = [q EXCEPT !["strip"] = "fresh"]
  /\ Step("Dash") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale>>

\* A tap with a cast time: _tap -> _cast_pending.
CastBegins ==
  /\ flow = "play" /\ q["cast"] = "none"
  /\ q' = [q EXCEPT !["cast"] = "fresh"]
  /\ Step("CastBegins") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale>>

\* A line bite with a loaded line skill: grapple_fired -> _bite_load -> _bite_pending.
BiteLoads ==
  /\ flow = "play" /\ q["bite"] = "none"
  /\ q' = [q EXCEPT !["bite"] = "fresh"]
  /\ Step("BiteLoads") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep, stale>>

\* Barbed Reel: a reel-in impact jumps once at once (_on_reel_chain -> _chain, item_proc). Its jump publishes no
\* harpoon_smashed, so it cannot reel again.
ReelChain ==
  /\ flow = "play"
  /\ deep' = (deep \/ ~ReelBare)
  /\ Step("ReelChain") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, expo, expoOld, mark, b, stale>>

\* A guard link made or broken (_guards, the line's guard partner).
GuardLink ==
  /\ flow = "play" /\ guards # "fresh"
  /\ guards' = "fresh"
  /\ Step("GuardLink") /\ UNCHANGED <<flow, att, q, pike, heat, foe, expo, expoOld, mark, b, deep, stale>>

GuardUnlink ==
  /\ flow = "play" /\ guards = "fresh"
  /\ guards' = "none"
  /\ Step("GuardUnlink") /\ UNCHANGED <<flow, att, q, pike, heat, foe, expo, expoOld, mark, b, deep, stale>>

(* ---- The deferred steps: combat's tick ---- *)

\* _tick_rakes: the return pass fires through bolts with bits 0, as item_proc.
RakeFires ==
  /\ Ticking /\ q["rake"] # "none"
  /\ Fires(q["rake"])
  /\ q' = [q EXCEPT !["rake"] = "none"]
  /\ b' = IF b.live THEN b ELSE NewBolt({}, TRUE)
  /\ Step("RakeFires") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, deep>>

\* _tick_aftershocks -> _aftershock: strikes as item_proc, no slam fact.
ShockLands ==
  /\ Ticking /\ q["shock"] # "none"
  /\ Fires(q["shock"])
  /\ q' = [q EXCEPT !["shock"] = IF ShockBare THEN "none" ELSE "fresh"]
  /\ deep' = (deep \/ ~ShockBare)
  /\ Step("ShockLands") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b>>

\* _step_verb_items: a due bell tolls (_toll).
BellTolls ==
  /\ Ticking /\ q["bell"] # "none"
  /\ Fires(q["bell"])
  /\ q' = [q EXCEPT !["bell"] = IF TollBare THEN "none" ELSE "fresh"]
  /\ deep' = (deep \/ ~TollBare)
  /\ Step("BellTolls") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b>>

\* _tick_echo: the release again, smaller, through row.fire alone.
EchoFires ==
  /\ Ticking /\ q["echo"] # "none"
  /\ Fires(q["echo"])
  /\ q' = IF EchoBare THEN [q EXCEPT !["echo"] = "none"]
          ELSE [q EXCEPT !["echo"] = "fresh", !["bell"] = "fresh"]
  /\ deep' = (deep \/ ~EchoBare)
  /\ Step("EchoFires") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b>>

\* _step_verb_items: a live strip strikes what enters it, and goes when its life ends.
StripStrikes ==
  /\ Ticking /\ q["strip"] # "none"
  /\ Fires(q["strip"])
  /\ \E ends \in BOOLEAN : q' = IF ends THEN [q EXCEPT !["strip"] = "none"] ELSE q
  /\ Step("StripStrikes") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep>>

\* _step_cast: the cast lands as the tap it started from (a SPECIAL tap may ring a bell, as Special does).
CastLands ==
  /\ Ticking /\ q["cast"] # "none"
  /\ Fires(q["cast"])
  /\ \E bell \in BOOLEAN :
       q' = [q EXCEPT !["cast"] = "none", !["bell"] = IF bell THEN "fresh" ELSE q["bell"]]
  /\ Step("CastLands") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep>>

\* _step_line: the pending bite fires the loaded line skill.
BiteFires ==
  /\ Ticking /\ q["bite"] # "none"
  /\ Fires(q["bite"])
  /\ q' = [q EXCEPT !["bite"] = "none"]
  /\ Step("BiteFires") /\ UNCHANGED <<flow, att, pike, guards, heat, foe, expo, expoOld, mark, b, deep>>

\* The pike count read by a press in another attempt (pike_advance reads _pike_count and _pike_last).
PikeRead ==
  /\ Ticking /\ pike # "none"
  /\ Fires(pike)
  /\ Step("PikeRead") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, expo, expoOld, mark, b, deep>>

(* ---- The bolt lineage: bolts.step ---- *)

\* The bolt meets a machine (bolts.step's hit loop -> combat's on_hit). Pull and heat act on the hit; a ready split
\* throws two children (fam + 2) and the model follows the parent or one child; pierce lets the parent fly on once.
BoltHits ==
  /\ Ticking /\ b.live /\ foe = "alive"
  /\ stale' = (stale \/ b.old \/ flow # "play")
  /\ heat' = IF "heat" \in b.bits THEN "fresh" ELSE heat
  /\ LET pulled == b.pulledAsChild \/ (b.gen > 0 /\ Ready("pull"))
         splits == Ready("split")
         kidSpent == ((b.spent \cup {"split"} \cup (IF ChildSpendsPull THEN {"pull"} ELSE {}))
                       \ (IF ChildSpendsSplit THEN {} ELSE {"split"})) \ {"pierce"}
         child == [b EXCEPT !.gen = b.gen + 1, !.fam = b.fam + 2, !.spent = kidSpent, !.pulledAsChild = pulled,
                            !.hoar = IF ChildDropsHoar THEN FALSE ELSE b.hoar,
                            !.spared = IF ChildDropsHoar \/ b.spared = "none" THEN "none" ELSE "shared"]
         parentOn == [b EXCEPT !.fam = IF splits THEN b.fam + 2 ELSE b.fam, !.pulledAsChild = pulled,
                               !.spent = b.spent \cup (IF splits THEN {"split"} ELSE {})
                                         \cup (IF Ready("pierce") THEN {"pierce"} ELSE {})]
     IN /\ deep' = (deep \/ (splits /\ b.proc))
        /\ \/ splits /\ b' = child /\ last' = "BoltSplits"
           \/ Ready("pierce") /\ b' = parentOn /\ last' = "BoltPierces"
           \/ b' = NoBolt /\ last' = "BoltStops"
  /\ UNCHANGED <<flow, att, q, pike, guards, foe, expo, expoOld, mark>>

\* bolts._glance: a ready bounce reflects the bolt off the first wall and spends; any other wall stops it.
BoltWall ==
  /\ Ticking /\ b.live
  /\ stale' = (stale \/ b.old \/ flow # "play")
  /\ IF Ready("bounce")
       THEN b' = [b EXCEPT !.bounces = b.bounces + 1, !.spent = IF BounceSpends THEN b.spent \cup {"bounce"} ELSE b.spent]
            /\ last' = "BoltGlances"
       ELSE b' = NoBolt /\ last' = "BoltWall"
  /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, expo, expoOld, mark, deep>>

\* The bolt runs out of range.
BoltSpent ==
  /\ Ticking /\ b.live
  /\ b' = NoBolt
  /\ Step("BoltSpent") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, expo, expoOld, mark, deep, stale>>

(* ---- One enemy's exposure marks ---- *)

Spawn ==
  /\ flow = "play" /\ foe = "gone"
  /\ foe' = "alive"
  /\ Step("Spawn") /\ UNCHANGED <<flow, att, q, pike, guards, heat, expo, expoOld, mark, b, deep, stale>>

\* _cannon_expose / _arc_mark: the row set or refreshed, the enemy's own mark node reused or added.
Expose ==
  /\ flow = "play" /\ foe = "alive"
  /\ expo' = "live" /\ expoOld' = FALSE /\ mark' = TRUE
  /\ Step("Expose") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, b, deep, stale>>

\* _clock passes the row's until (the clock moves only while combat ticks).
Lapses ==
  /\ Ticking /\ expo = "live"
  /\ expo' = "expired"
  /\ Step("Lapses") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, expoOld, mark, b, deep, stale>>

\* _step_cannon_exposure: an expired row, or one whose enemy is gone, is dropped with its mark.
DropExpired ==
  /\ Ticking /\ (expo = "expired" \/ (expo # "none" /\ foe # "alive"))
  /\ Fires(IF expoOld THEN "old" ELSE "fresh")
  /\ expo' = "none" /\ expoOld' = FALSE /\ mark' = FALSE
  /\ Step("DropExpired") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, b, deep>>

\* _door_caps: a contact hit reads an expired row and drops it.
ContactRead ==
  /\ flow = "play" /\ foe = "alive" /\ expo = "expired"
  /\ expo' = "none" /\ expoOld' = FALSE /\ mark' = (mark /\ ~ContactDropsMark)
  /\ Step("ContactRead") /\ UNCHANGED <<flow, att, q, pike, guards, heat, foe, b, deep, stale>>

\* The enemy dies (spawn_enemy's died handler): its rows go, and its heat; the body lingers.
FoeDies ==
  /\ flow = "play" /\ foe = "alive"
  /\ foe' = "corpse" /\ heat' = "none"
  /\ expo' = "none" /\ expoOld' = FALSE /\ mark' = (mark /\ ~DeathDropsMark)
  /\ Step("FoeDies") /\ UNCHANGED <<flow, att, q, pike, guards, b, deep, stale>>

\* The body is freed, and every child node with it.
CorpseFreed ==
  /\ foe = "corpse"
  /\ foe' = "gone" /\ mark' = FALSE
  /\ Step("CorpseFreed") /\ UNCHANGED <<flow, att, q, pike, guards, heat, expo, expoOld, b, deep, stale>>

\* The bounds are spent: the run plays on with nothing new to check.
Done == UNCHANGED vars

Next ==
  \/ Done
  \/ EnterStage \/ ContentCleared \/ NewRun \/ Death \/ ToTitle
  \/ Press \/ ProcVolley \/ Slam \/ Special \/ Dash \/ CastBegins \/ BiteLoads \/ ReelChain \/ GuardLink \/ GuardUnlink
  \/ RakeFires \/ ShockLands \/ BellTolls \/ EchoFires \/ StripStrikes \/ CastLands \/ BiteFires \/ PikeRead
  \/ BoltHits \/ BoltWall \/ BoltSpent
  \/ Spawn \/ Expose \/ Lapses \/ DropExpired \/ ContactRead \/ FoeDies \/ CorpseFreed

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ flow \in {"play", "dead", "title"} /\ att \in 0..MaxAtt
  /\ q \in [Queues -> Rec] /\ pike \in Rec /\ guards \in Rec /\ heat \in Rec
  /\ foe \in {"alive", "corpse", "gone"} /\ expo \in {"none", "live", "expired"}
  /\ {expoOld, mark, deep, stale} \subseteq BOOLEAN
  /\ b.live \in BOOLEAN /\ b.gen \in 0..3 /\ b.fam \in 0..7 /\ b.bounces \in 0..2

(* The rules. Each is one promise to the player. *)

\* A deferred proc is one step from the player's act: nothing a proc fires queues or fires another proc, and a proc
\* volley's bolt never splits.
ProcDepthOne == ~deep

\* Nothing an attempt queued fires in another attempt or outside play, and play never starts holding an earlier
\* attempt's queue, pending cast or bite, strip, bell, aftershock, rake, echo, pike count, guard, heat, exposure row
\* or bolt.
NoEchoAcrossAttempt ==
  /\ ~stale
  /\ flow = "play" => /\ \A k \in Queues : q[k] # "old"
                      /\ pike # "old" /\ guards # "old" /\ heat # "old" /\ ~expoOld /\ ~(b.live /\ b.old)

\* A shot carries at most MAX_SHOT_BITS of the five bits; a bolt's family is at most three (one split, children
\* never split), a lineage glances off one wall, a child never pulls again, never carries hoar and never shares its
\* parent's hoar_spared; and no exposure mark stands without its row.
ShotBitsCap ==
  /\ b.bits \subseteq BitNames /\ Cardinality(b.bits) <= MaxShotBits
  /\ b.gen <= 1 /\ b.fam <= 3 /\ b.bounces <= 1 /\ ~b.pulledAsChild
  /\ b.gen > 0 => (~b.hoar /\ b.spared # "shared")
  /\ mark => expo # "none"

(* Probes that say "never" about things that must happen. Each must break. *)
ProbeEnterStage == last # "EnterStage"
ProbeContentCleared == last # "ContentCleared"
ProbeNewRun == last # "NewRun"
ProbeDeath == last # "Death"
ProbeToTitle == last # "ToTitle"
ProbePress == last # "Press"
ProbeProcVolley == last # "ProcVolley"
ProbeSlam == last # "Slam"
ProbeSpecial == last # "Special"
ProbeDash == last # "Dash"
ProbeCastBegins == last # "CastBegins"
ProbeBiteLoads == last # "BiteLoads"
ProbeReelChain == last # "ReelChain"
ProbeGuardLink == last # "GuardLink"
ProbeGuardUnlink == last # "GuardUnlink"
ProbeRakeFires == last # "RakeFires"
ProbeShockLands == last # "ShockLands"
ProbeBellTolls == last # "BellTolls"
ProbeEchoFires == last # "EchoFires"
ProbeStripStrikes == last # "StripStrikes"
ProbeCastLands == last # "CastLands"
ProbeBiteFires == last # "BiteFires"
ProbePikeRead == last # "PikeRead"
ProbePikeFuse == ~(last = "Press" /\ b.live /\ "pierce" \in b.bits /\ b.spent = {} /\ pike = "none")
ProbeBoltSplits == last # "BoltSplits"
ProbeBoltPierces == last # "BoltPierces"
ProbeBoltStops == last # "BoltStops"
ProbeBoltGlances == last # "BoltGlances"
ProbeBoltWall == last # "BoltWall"
ProbeBoltSpent == last # "BoltSpent"
ProbeHoarChild == ~(b.gen = 1 /\ b.spared = "none" /\ HoarHeld /\ "pierce" \in b.bits)
ProbeSpawn == last # "Spawn"
ProbeExpose == last # "Expose"
ProbeLapses == last # "Lapses"
ProbeDropExpired == last # "DropExpired"
ProbeContactRead == last # "ContactRead"
ProbeFoeDies == last # "FoeDies"
ProbeCorpseFreed == last # "CorpseFreed"
ProbeKeptOverDeath == ~(flow = "dead" /\ q["echo"] = "old" /\ pike = "old" /\ b.live)
=============================================================================
