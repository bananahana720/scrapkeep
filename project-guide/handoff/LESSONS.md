# Scrapkeep lessons and ways of working

How this project actually runs, learned the hard way since 16 Oct 2026. Each lesson is the rule, then why. **Do not read it end to end at start-up: read the section for the work you are about to do.** The rules every thread follows are in [AGENTS.md](../../AGENTS.md). Lesson numbers stay fixed so older receipts still match; a retired lesson keeps its number and says what replaced it, and its old text is in git history. Andrew's reading copy is the Claude Doc [Scrapkeep lessons and ways of working](https://claude.ai/code/artifact/95d92907-5cfe-4290-b303-d465baccedde). Owner: the project coordinator. Last trimmed 14 Nov 2026: lessons 2, 9, 11, 16, 17, 20, 26 and 40 retired or pointed at their one home.

## Getting Andrew's word

1. **Act on the standing approval; ask for his typed words only when a safety check refuses.** When a check refuses, ask him for one exact line that names the action and its target, then relay it with `message_thread` and his message id attached. Some threads' checks want the line typed in their own thread.
2. **Retired.** The standing approval is "Steps that need no approval" in [AGENTS.md](../../AGENTS.md); lesson 47 covers a merge check that refuses.
3. **A tap on a withdrawn card still counts.** He clears cards fast (about 12 in 3 minutes at 15:30Z 17 Oct), including ones a thread already withdrew. Honour the tap.
4. **His typed answer beats the card.** The Splitter card was withdrawn after he typed the behaviour he wanted (18:19Z). Record the typed version.
5a. **Verify a relayed tap before writing it into a record.** A register write based only on a coordinator relay was blocked as unverified (20:03Z 17 Oct). Reading the project timeline for the card's `decide` event with `chosen_by` Andrew's id confirmed it, and the write then went through.
5. **A rule change is a card plus a typed line.** If a fix changes one of his recorded rules (the 0.2 s warning gap, the attacker budget), it is his call, never an engineering default.

## Card discipline

6. **At most three cards open, one question each, a recommended option, game terms not file names.** He reads cards on his phone in the project chat and never opens threads to steer.
7. **Queue overflow in `alpha-status/queued-cards.md`.** Card text sent by `send_message` is lost when the coordinator is recycled. The queue file survives.
8. **Keep working on the recommended option while a card waits.** A card is not a stop.
9. **Retired.** Merges need no card since 17 Oct (AGENTS.md, steps that need no approval).

## Threads and sessions

10. **In a project thread, don't ask Andrew in-thread or ask him to paste between threads,** because he reads the project chat on his phone, not threads. Raise a hand to the coordinator and carry on. A local session at his computer asks him directly.
11. **Retired.** Same as lesson 48.
12. **Resolve finished threads.** A review-ready thread whose PR is in the gate or merge queue is resolved (24 cleared at 19:39Z 17 Oct). Don't poke threads busy with background work.
13. **After `stop_rc_session`, the thread's folder tools did not come back.** Plan folder work before stopping a Remote Control session.
14. **One cloud thread per independent unit; split long sweeps by seed or pilot.** Targets: 12+ cloud threads at once, ask to draft PR under 2 h, draft PR to gate verdict under 4 h, no gate-passed PR waiting over 12 h.

## The cloud container

15. **A cloud container is reclaimed after it sits idle, and `artifacts/local/` goes with it.** Copy evidence you want kept to `/mnt/project-files/` (red team runs live in `redteam/w<n>/`) and push branches before going quiet.
16. **Retired.** The cloud box's size and caps are in [DEVICES.md](DEVICES.md). A full gate takes about 2 h in the cloud, so shard it.
17. **Retired.** The cloud setup is in [DEVICES.md](DEVICES.md).
18. **GPU work stays on the 4080:** frame times, ACE-Step music renders, Eevee/Vulkan captures, the real export proof. Cloud perf numbers never count (the bench swings 24-146 ms p99 between sandboxes).

## Gating and testing

19. **No thread grades its own work.** A game change is done only when a tool check passes (smoke, lab gate, placeholder gate) and an independent reviewer agrees.
20. **The Gate is the gate of record (the local session on the PC since 15 Nov, ruling ds; the board thread before that); shards don't push, comment or fix.** Pass tests by base name (`--test bot_six_tally_test`), not `res://` path. The recipe is [GATE.md](GATE.md).
21. **Known reds live in the ledger.** Each red a promotion may carry has a row in [KNOWN-FAILING.tsv](KNOWN-FAILING.tsv) with a cause, an owner and a review date (ruling bq). The 23 Oct list of cloud-only false fails that stood here is in the archive copy.
22. **"Flake" is not a cause.** The effects RNG test failed on and off for a day; the real cause was a 65 s limit on a busy machine (now 180 s). Rerunning a red to see whether it repeats is always fine; what needs a found cause is calling it a flake.
23. **Red team every wave, carrying the last findings.** Camper stalls without a Warden break and traversal stalls are by design. A hitch counts only when it lands at the same run moment across seeds.
23a. **A child cap is a measurement, not a guess.** `alpha_bot_sweep` was listed as a "cloud false fail" because its 170 s child cap sat under a 276 s child; time one child alone, then size the cap and the tier from it (`ba10b7c7`).
23b. **Eight seeds can't judge a chaotic median.** Per-seed fight times are fixed on one commit but reshuffle with any gameplay change, so on w18 the 8-seed swarm ratio read 1.77x where 24 seeds read 1.86x. Judge medians on 24 seeds (standard error about 4 s) before calling a band moved.
24. **When fourteen tunings don't fix a design goal, it's a design question.** The Dispatcher stayed cheap to ignore through 14 tunings; one card ("Escalate") settled it.

## Permission prompts

25. **Allow-once prompts come from compound shell commands.** Pipes, `&&` and `cd` chains don't match allow-list rules. Fix: one checked-in script with subcommands (the music session's `scripts/music/mx`), allow-listed in `.claude/settings.local.json`, called as one plain command.
26. **Retired.** The PC allow-list is in [DEVICES.md](DEVICES.md).

## Music

27. **Replace a music pick only after he picks the new take by ear.** Theme-consistent retakes sounded "boring" to him (15:59Z 17 Oct); energy, switch-ups and electro bass win over neat theory.
27a. **A place music layer never sits inside an arena.** In the Crown, crown_ramp's sensor sat in the Warden's bowl and the ball re-crossed it mid-fight; each layer change shifted the on-bar telegraphs and turned a 6,262-tick win into a 14,410-tick cap (17 Oct 22:24Z). Put the sensor outside the arena, or have the music director lock layers during a fight.

## Library and records

28. **One register for decisions.** Check [DECISIONS.md](DECISIONS.md) before proposing anything that might already be decided; he dislikes re-deciding and the tokens spent rediscovering old calls (19:46Z 17 Oct).
29. **Every idea he gives is a motif.** Brief design threads with the motifs that touch their area (world enemy themes, single-skill areas, damage-type armour, buff/debuff zones, cast times).
30. **The Custom view tab strips colour, opacity and positioning.** Use `currentColor`, no hard-coded colours (dark mode).
31. **Memory sync to his PC is one-way.** A snapshot goes to `docs/project/PROJECT-MEMORY.md` only on request.
32. **New shared files go in an area folder, never the root; superseded drafts move to `archive/`.** `gate/` and `redteam/` belong to the threads writing there.

## Bottling Andrew's stream of thought

33. **Every idea he voices gets filed the same hour, by kind:**

| Kind of idea | Where it goes |
| --- | --- |
| A ruling (a choice between options) | Decisions register, its topic table; replaced rows move to "Replaced rulings" |
| A standing principle ("I want X everywhere") | Register, "Direction" table; the coordinator mirrors it into the project instructions |
| A design idea to expand | The design thread for that area (e.g. "Enemy auras and pilot cast times"), briefed with the motifs it touches |
| An open question or blind spot | The design questions page, as multiple choice or fill-in |
| An after-alpha wish | Register, the "After alpha" Direction line (parked until the sitting) |
| A reference ("like Isaac", "like Roboquest") | The register row or design brief it explains |
| A process complaint (prompts, threads stalling) | This lessons doc, plus a fix thread if it recurs |

He said he won't dictate anything but direction (19:55Z 17 Oct), so the filing is Claude's job, not his.

## Learned overnight, 18 Oct

34. **A check that can't fire proves nothing.** Rivet's faster carves (#73) were reverted out of wave 16 because the park carve check never got a carve to fire, so its timing said nothing. Before trusting a pass, confirm the measured thing happened.
35. **Put the measured number on the card.** The Rivet Breach cards carried the 4080 numbers (24.47 ms against 16.7 ms; 0.11 s as the fastest smooth slope hit) and were answered in seconds.
36. **Usage limits stop threads and they don't self-resume.** About 01:00Z most threads failed with rate_limited; after the reset the coordinator nudges each with `message_thread`.
37. **Permission prompts from the PC's Remote Control sessions are often phantoms.** Raise one to Andrew only if the session is still stalled several minutes later.
38. **An NVIDIA driver auto-update locks the 4080 until a reboot** ("Driver/library version mismatch"). Ask him to reboot after any update; no pacman hold.
39. **Band sweeps OOM on the 4-core cloud box.** posture_bands sweeps spawn about 24 children; a missing record counts as 300 s. Rerun a 300 s or timeout row alone before calling it red.
40. **Retired.** The promotion flow is the tiered gate in [ORCHESTRATOR.md](../../ORCHESTRATOR.md) (ruling cy).
41. **Claude Docs edit grammar.** `target {"kind":"blocks","ids":[...]}`, `source {"as":"blocks","from":{"kind":"inline","content":[rows]}}`; a table row can't be replaced, so insert the new row after it and `delete` the old one with its `ifHash`.
42. **Artifacts and Claude Docs are private to the account that made them.** For a move to another account, carry the content as files in the repo (project-guide/handoff/) or share the pages with the new account.


## Coordination from the PC, 18-23 Oct

43-46. **Moved to the archive on 10 Nov.** They described the PC coordinator and cloud-lane caps of 18-23 Oct, which ruling by replaced; the text is in `/mnt/project-files/archive/instructions-2026-11-10/repo/project-guide/handoff/LESSONS.md`.

## Back in the project, 23 Oct

47. **Gate-passed PRs stack and promote without a typed line (27 Oct); if a merge safety check still refuses, a typed line covers only the PRs it names.** On 23 Oct Andrew's 17:27Z line landed #383, but #385, held in the queue it described, was refused. When a check refuses, ask for one line per batch that names the thread, the action and each PR number, and attach it with `context_message_ids`.
48. **Remote Control sessions cannot receive `send_message`.** Brief one through its start instructions, and reach a running one through `message_thread` on its thread; other threads route through the coordinator.
49. **The image service filter refuses some reference-sheet prompts.** The mag trapper and the Cannon close-ups were refused on PR #387, so those units are incomplete. Word prompts as machinery and tools, not weapons or traps, keep the approved board as image 1, and rerun only the refused views. Sheets are review drafts: check the 1.84 m ball for scale drift before a modeller traces them.
50. **Run the export include check whenever code starts reading a new file type.** Park ground step 2 made `park_terrain` read each park's `surface.bin`, but no `include_filter` pattern shipped it. Every headless test passed; only the 23 Oct release dry run caught it. #390 adds the pattern to both Linux presets and a seeded control test that drops it.
51. **A fix that passes the fast lane can still change a run.** #351 (free a released stage over frames) stalled the seed 6 skipper at stage 4, while the bare stage head won to stage 6. Before calling a bot red "base", run the same seed on the bare head; hold the PR and anything stacked on it (#374) until it is fixed.
52. **A new crash is one that is green on the last promoted main.** The stage 6 quit crash was red on the stage but green on main, so it holds promotion and gets a bisect; a red that is also red on main does not.
53. **Timing captures need an idle 4080.** Both GPUs run throughput work; a frame-time capture runs only when the card would otherwise idle, and is void if another process touched the card during it (use the PC's pause file).
54. **Dictated card answers come as letters and fragments.** "colours a, deals ..., scope a" maps to the card's options in order; record the typed explanation over the card text, and if a message stops mid-sentence, say so and wait for the rest.
55. **Moving entry work into later frames has not paid on the 4080: three tries, three no-gains.** #506 (late radio caches), #516 (activity sites spread) and #531 (sites freed a few a frame) each cut a measured part of an entry on the cloud (#516: activities 20-24 to 7-11 ms; #531: whole entry 97.5 to 68.2 ms). On the PC, each either moved the cost into a new frame (#506: f9703 a 32 ms pipeline-compile frame; #516: f9706 at 42-47 ms, seven frames after the entry, same 12-frame sum) or left the entry within run-to-run spread (#531: 50.5 to 49.4 ms median, the span ending at phys_deleted 17.9 to 14.8). A cloud gain on one part does not predict the 4080 frame, and a spread can re-baseline bots (#531 moved park seed 1 from 30306 to 30900 ticks). Cut the work itself (cache, build ahead off-tree as #514 did, skip), and ask for a 4080 row before calling a spread a gain.
56. **Read a hitch frame by `net_ms`, not by its wall `ms`.** In a bot frame log, a frame's wall ms includes the bot driver's own tick (`bot_ms`). The seed 6 dam "spikes" (185 ms at f7850, 158 ms at f8158 on the #554 row) were 141-181 ms of bot planner time with 8-19 ms of game time. In flume event states 3 and 4, every frame over 60 ms carries 50-120 ms of `bot_ms`, on the same frames in base and head. Check the stage label too: a `--until=2` run's last frame is the world 2 (Dig) entry, not the Brindle bowl.
57. **A shader freed with its last material is rebuilt on its next first use: 12-15 ms on the 4080, and far less on the cloud.** BaseMaterial3D keeps one shader per mode/flag/feature key and frees it when the last material with that key goes. A stage swap that frees every user of a key, such as the dam Warden's enamel (#554) or the plating on its jaws, makes the next stage's first user build the shader again on its entry frame. Colours, energies and which texture is bound do not change the key; toggling `emission_enabled`, or changing a texture filter or a detail blend, does. Hold one material per key for the session: `BakeWarm._kept` holds materials that were drawn, and a copy that is never drawn needs `get_rid()` to build its shader. Size the cost on the PC, because the cloud's dummy renderer hides most of it (#554: 0.2 ms on the cloud for a 12 ms rebuild on the 4080).
58. **Size frame work on the PC; the cloud ratio changes with the kind of work.** Measured on the flume entry grind (28 Oct): script handlers ran about 2.5x slower on the cloud than on the 4080, while the Warden spawn ran 3x faster on the cloud (5.4 against 15 ms) and a shader rebuild 60x faster (0.2 against 12 ms), because the dummy renderer skips the GPU work. A cloud profile can rank script functions, but it folds worker time into frames, so it cannot name main-thread cost. Bracket the frame on the PC instead: the flow and handler probes, then marker nodes that time each subtree's `_process` (the probe recipes are on #512 and #556). The grind also confirmed lesson 55: the cuts that paid were removed work (#551 sites built in flight, #554 and #560 shaders held, 120 to about 58 ms), and the remaining deletes and per-frame budgets only move cost between frames.
59. **Godot 4.7.2's untyped-math cache races across threads, and the crash log blames the scene tree.** The first time a line with an untyped operator runs, the VM caches its evaluator, writing the operand signature before the function pointer, and readers check it without the lock (`gdscript_vm.cpp` `OPCODE_OPERATOR`, still the same on master). A second thread that runs the same cold line inside that window calls a null pointer. The log then shows a bogus `ERROR: /root: The caller thread can't call propagate_notification()`, because the crash handler sends NOTIFICATION_CRASH from the worker. Read the script frame under that error as the crash site, not as a scene-tree touch. The w27 bot crash came from `--warm-band=1` baking `MusicEngine.prepare_rest` on the main thread while the live game's worker baked it too, so any `--warm-band=1` row on a real audio device on a head before #592 can hit it (#587 comments 6510678275 and 6510789416). A cloud repro with two threads on a fresh script crashed 3 of 3 runs; the typed control (validated operators, no cache) survived 2 of 2. Never run the same cold GDScript on two threads in step, and type the operands on lines that run on more than one thread.

## World 1 clipping QA, 30 Oct

60. **Dump drawn geometry under a real renderer, and check an audit finding against the triangles before fixing it.** The headless dummy renderer keeps no MultiMesh buffer, so every dressing instance read at the origin and the first dump showed thousands of false overlaps. `tools/clip_dump.gd` runs under `xvfb-run` with `--rendering-driver opengl3`. The coplanar check also counted cells along an edge that two faces only share: the flume reach tiles "z-fought" 14.6 m² per joint, and a tile lift was built, broke the ride's deck-on-collider pin and had to be undone. Only then did reading the two copies' triangles show they touch at the joint and never overlap. `clip_audit.py` now counts a coplanar cell when either owner's sample sits 5 cm inside the other's faces (either, not both: a strip lying on a large face has only its own samples deep in the face), and lists the rest as `edge_cells`. An edge-to-edge overlap under 5 cm is not flagged.
61. **Blender runs in the cloud, and the recipe scripts rebuild byte-identical GLBs.** The bpy 5.2.2 wheel behind `scripts/cloud/blender` rebuilt the dam drape and landmark GLBs in about 2 s per row, CPU only. First rebuild the committed GLB unchanged and compare it with `cmp` to prove the recipe reproduces it. Then change the recipe, rebuild into a scratch `--out-dir`, and copy the files in only after the builder's own asserts (caps, FLUSH) pass. Do not copy GLBs while a sketch:fast run is going: the copy invalidates that run.
62. **A drawn lift on a ride surface parts the deck the player sees from the deck the ball rides.** Lifting overlapping pieces a few cm separates coplanar faces, but only on dressing. A grind line's drawn deck stays on its collider; only the smaller overlapping piece, or a liner, stands up. A lift also cannot part two walls in one vertical plane, so overlapping landform skins are settled where they are built: the smaller row keeps the ground and the larger one's facets are cut at its outline (lowering a straddling facet 2 cm does not part it from the other skin on a steep wall).

## Flume tile attach, 31 Oct

63. **A Jolt mesh shape can be built off the main thread, but only by querying it.** Godot 4.7.2 Jolt builds a ConcavePolygonShape3D lazily, inside `add_child` or `body_set_space` on the main thread (about 7 ms on the 4080 for a 12,800-triangle tile). Create the shape and call `set_faces` on the main thread (from a worker, the threaded physics server queues `shape_set_data`, so the worker sees a null shape), take `space_get_direct_state` of a private `space_create()` on the main thread, then call `intersect_shape` with the shape's RID on the pool: `JoltShape3D::try_build` caches the built shape, and the later add takes 0.01-0.02 ms. In debug builds, `CollisionShape3D.set_shape` sets the shape's debug colour, which sends the faces again and drops the built shape, so assign the holder's shape before the build. Free the private space and any holder not yet in the tree on every exit path; NOTIFICATION_PREDELETE runs before `_exit_tree` on `free()`. On the 4080, #609 cut attach frames over 7 ms from about 107 to 9 a seed (#607 6540029016).
64. **Size a pool burst by threads, not only by total work.** #609 built the 100 tile shapes on half the pool and a 4-frame slow-draw run (draw 5.5-7.3 ms) appeared near engage+142 on the 4080, where the burst landed. #612 capped the build at two threads (about 350 ms, 20-30 frames, still ahead of the first body): the draw run went (over-16 frames there 4 to 0-1) and attach frames stayed flat (#607 6540916744). The PERF lesson to cap group size rather than lower priority held again. Also never bind a pool job to a Node method: a worker mid-call holds the node's call lock, and a debug `free()` is then refused ("Attempted to free a locked object") and the test hangs. Use a static function with the state bound in.
65. **When a GDScript clip loop dominates, skip the cases whose answer is known before clipping.** The Placer's `anchor_hulls` clipped every triangle of a mesh against each height band (about 1 ms a band, 14-16 ms a flume anchor row). A triangle wholly outside a band clips to nothing and one wholly inside clips to itself, so per-triangle spans worked out once per mesh let both skip the clip (#610). Hull points were identical across 26 keys and 129 bands, and the 4080 spike peak fell from a median 21.5 to 12.3 ms (#607 6540472993). Prove a fast path with an old-against-new output diff over every real input, not only a test.

## Gate tally, 31 Oct

66. **A CLEAN call needs a posted receipt on every shard row; an empty tally row is not a pass.** On 31 Oct the Gate promoted w30 at 13:05Z with tests 346-690 still running, because it misread which tally rows were open. The shard reported PASS at 13:54Z, so the promotion stood, but only by luck (#615 6544267544). Before reporting CLEAN, list the empty rows (`grep -E "\| \|$"` on the gate plan) and wait until that list is empty, then cite each row's receipt path.

## Load-only test crashes, 9 Nov

67. **A "load-only" signal 11 in a headless test is most likely the test calling a node the game freed while the test waited on frames.** In a `--headless --script` run on Godot 4.7.2 that call was not refused as a freed instance: it went through the stale pointer (debugger capture on c5425bf9: the object table slot already held another object and the node's memory was zeroed), so it crashes once the memory is reused and passes otherwise. `screens_first_last` was first seen crashing in the wave 24 gate and carried as a load flake after that (`gate/w24-792df5a1/tests-691-end.md`, `gate/w30-5c5f70f1/tests-691-1080.md`); it crashed 29 times in 40 runs at 8 copies at once on c5425bf9 and 0 in 40 after the fix (`gate/w33-screens-kite-fix/`). `test_mode` sets `bot_driven`, screens.gd closes a bot's ending after 1 s of frame time, and the test's 30-frame credits loop passes 1 s only on a loaded box. Read the GDScript backtrace first: a top frame on a test line just after an `await` means check `is_instance_valid` on what that line calls, then find who freed it (connect a `print_stack()` to the node's closing signal). The pattern to look for is a test that counts frames where the game counts seconds. A related trap: a deferred call whose parameter is typed as a node is refused with an ERROR line when the node is freed before the call runs, so its own validity check never executes (`kite_dive_stack`'s exit error); leave that parameter untyped.

## Reading the build at a death, 9 Nov

68. **Read a dead run's build as it met the Warden or entered the boss arena, never at the killing hit.** Scrap is armour, so at every death the ball is already stripped: anything that reads punch or heft at the killing hit reads a bare ball. The old SCRAPPED gap line did this, and so did the first build of the death note (#637).

## A crashed first import, 10 Nov

69. **A first `--import` that dies on signal 11 or 6 is the engine's, so try it again and let the last try decide.** Godot 4.7.2's threaded font reimport crashed the first headless import of a fresh `.godot` 2 times in 5 on the PC (exit 139 and 134, "malloc(): smallbin double linked list corrupted", the last line a `.ttf`) and 1 time in 5 in the cloud. It leaves imported files missing, so every test after it prints script errors that look like a project red. "Import twice" cleared it only by luck: two crashes running is about 1 run in 6 at the PC's rate. The runner, the fast lane and the gate shard now give an import up to three tries, and a clean import is one that exits 0 with no `SCRIPT ERROR` line; a healthy import prints none ([GATE.md](GATE.md) has each one's rule). By hand, do the same before calling any red on a fresh checkout. Not tried: importing on one thread (`editor/import/use_multiple_threads` off), kept for when three tries stop being enough.

## A finding seen twice, 13 Nov

70. **A kind of UI miss found twice gets a test or a lint, not a second note.** A written rule needs the next reader to notice it; a guard does not. The UI audit's ledger ([UI-FINDINGS.tsv](UI-FINDINGS.tsv)) gives every row a class, and `npm run sketch:ui-audit` fails while a class with two or more rows names no guard. A guard that would start red holds the line with a list of today's misses that may only shrink. [The UI audit loop](../../sketches/core-loop/design-v3/ui-audit/README.md) has the steps.

## A .godot from another tree, 14 Nov

71. **A `.godot` folder imported at one tree and run at another gives a run that is not the checked-out code, with no error line.** In the cloud, a tree imported at one commit and switched without a new import played learner1 seed 40322 as a 32,916-tick run where the proper import plays 51,332. Every passing import now writes `.godot/scrapkeep-import.json` with the sketch's git tree (the fast lane, the smoke runner, the gate shard and the PC gate), and the band harness (`scripts/challenge/run.mjs`) refuses a `.godot` whose stamp is missing or names another tree, or a sketch with uncommitted tracked edits. For a hand-made worktree, run `node scripts/import-stamp.mjs import` (imports twice, then stamps); `check` says whether the stamp matches. Never copy a `.godot` between worktrees. The PC parting on PR 1009 that started this hunt was not a stale import; item 72 has its cause.

## Two physics signals in one tick, 14 Nov

72. **Several physics signals in one tick arrive in an order that differs between launches of the same seed.** Two launches of one stamped base build parted at tick 8,598 of learner seed 40322 on the PC. The ball, hauling on one chaser, met it and its neighbour in one tick, and `body_entered` follows the contact list, which Jolt's worker threads fill in whatever order they finish. Haul body first paid the landing (stomp plus the haul's slam, 74.2 damage); bystander first let the line go on the stomp (50.3). The physics itself matched tick for tick. The ball now orders a tick's new enemies itself (`Contact.meets_first`: the haul's body, the nearest, tree order; `tests/contact_order_test.gd`), and wall grip breaks a tie between two equally steep faces by game state. A handler that can get two contacts, bodies or overlaps in one tick must sort them by game state before it acts. To find such a parting, diff two `--trace-ticks=1` traces: each row's `struck` list gives the tick's hits in order. The 32,916-tick cloud run in item 71 is the haul-first branch of this same contact, so it may have been this flip and not the stale import.

## Frame hitches on the Mac, 17 Nov

73. **A silent frame reading must bake its sound the way a played game does.** `frametime-check --self-play` runs the game on the dummy audio driver, and until w44 the band's chord, riser, stinger and boss bakes only started when a sound device was present. So every first chord rendered on the main thread. That gave 25 to 45 ms frames at the same stage times every run (stage 1 at 90 and 94 s, stage 2 at 5.7, 14 and 45 s) and 40 to 120 ms frames in the boss fight. `Audio.bakes_ahead` now follows the display, not the device. Find a hitch with `tools/self_play.gd --self-play-probe=<file>` (`tools/frame_probe.gd`): it gives each frame over 25 ms with its bot cost (`bot_ms`, `net_ms`), node work by subtree, nodes added and freed, pipeline compiles, and with `--self-play-probe-signals=1` the GameEvents handlers. Read `net_ms` (item 56). The probe raises the median frame, so a graded reading runs without it.
