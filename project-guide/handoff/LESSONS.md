# Scrapkeep lessons and ways of working

How this project actually runs, learned the hard way on 16-23 Oct 2026. Each lesson is the rule, then why. Read this before starting a thread, posting a card or running a gate. Andrew's readable copy is the Claude Doc [Scrapkeep lessons and ways of working](https://claude.ai/code/artifact/95d92907-5cfe-4290-b303-d465baccedde); this file (repo project-guide/handoff/LESSONS.md, shared copy /mnt/project-files/project-guide/LESSONS.md) is the copy threads read. Owner: the project coordinator, since 23 Oct. Lesson numbers stay fixed so older receipts still match. Last updated 2026-10-23 by the library sweep thread.

## Getting Andrew's word

1. **A card tap works for design; protected actions on the PC need his own typed words.** The PC coordinator's safety check rejects relayed taps for notes files, register rows, a push to main or waiving a proof. Fix: ask him for one exact line in the project chat, then relay it with `message_thread` and his message id in `context_message_ids`. Worked first time for the wave 15 push (02:13Z 17 Oct).
2. **Try the standing merge authority first.** Since 19:41Z 17 Oct his typed message covers merges, main pushes and git housekeeping. Attach that message id when a check wants his words; ask for a new line only if it is refused.
3. **A tap on a withdrawn card still counts.** He clears cards fast (about 12 in 3 minutes at 15:30Z 17 Oct), including ones a thread already withdrew. Honour the tap.
4. **His typed answer beats the card.** The Splitter card was withdrawn after he typed the behaviour he wanted (18:19Z). Record the typed version.
5a. **Verify a relayed tap before writing it into a record.** A register write based only on a coordinator relay was blocked as unverified (20:03Z 17 Oct). Reading the project timeline for the card's `decide` event with `chosen_by` Andrew's id confirmed it, and the write then went through.
5. **A rule change is a card plus a typed line.** If a fix changes one of his recorded rules (the 0.2 s warning gap, the attacker budget), it is his call, never an engineering default.

## Card discipline

6. **At most three cards open, one question each, a recommended option, game terms not file names.** He reads cards on his phone in the project chat and never opens threads to steer.
7. **Queue overflow in `alpha-status/queued-cards.md`.** Card text sent by `send_message` is lost when the coordinator is recycled. The queue file survives.
8. **Keep working on the recommended option while a card waits.** A card is not a stop.
9. **Batch the boring ones.** Merge approvals cleared fastest as a run of one-tap cards. Since 19:41Z they need no card at all.

## Threads and sessions

10. **Threads never ask Andrew in-thread or ask him to paste between threads.** Raise a hand to the coordinator (`send_message` to the channel session) and carry on.
11. **`send_message` to the PC wave thread's session id fails ("not found").** Use `message_thread` on its thread. Remote Control sessions cannot receive `send_message` at start; brief them through `start_rc_session` instructions.
12. **Resolve finished threads.** A review-ready thread whose PR is in the gate or merge queue is resolved (24 cleared at 19:39Z 17 Oct). Don't poke threads busy with background work.
13. **After `stop_rc_session`, the thread's folder tools did not come back.** Plan folder work before stopping a Remote Control session.
14. **One cloud thread per independent unit; split long sweeps by seed or pilot.** Targets: 12+ cloud threads at once, ask to draft PR under 2 h, draft PR to gate verdict under 4 h, no gate-passed PR waiting over 12 h.

## The cloud container

15. **A cloud container is reclaimed after it sits idle, and `artifacts/local/` goes with it.** Copy evidence you want kept to `/mnt/project-files/` (red team runs live in `redteam/w<n>/`) and push branches before going quiet.
16. **Background tasks cap at 2 hours; the box has 4 vCPU, 15 GB RAM, about 30 GB disk and no GPU.** A full gate takes about 2 h in the cloud, so shard it.
17. **The session-start hook installs Godot 4.7.2, Blender 5.2.2 (PyPI `bpy`) and npm deps** in about 70 s fresh, 2 s cached. download.blender.org is blocked; the `scripts/cloud/blender` shim covers it.
18. **GPU work stays on the 4080:** frame times, ACE-Step music renders, Eevee/Vulkan captures, the real export proof. Cloud perf numbers never count (the bench swings 24-146 ms p99 between sandboxes).

## Gating and testing

19. **No thread grades its own work.** A game change is done only when a tool check passes (smoke, lab gate, placeholder gate) and an independent reviewer agrees.
20. **The cloud gate thread is the gate of record, except GPU checks.** It builds one integration commit from main plus the draft PRs, and sibling threads run bot shards from `gate/BOT-SHARDS.md`. Pass tests by base name (`--test bot_six_tally_test`), not `res://` path. Shards don't push, comment or fix.
21. **Known cloud-only false fails (not the PR's fault):** `item_fuzz_smoke` (CPU contention), `park_swap` (frame budgets), `tree_play`, `alpha_posture_bands_w23` (child timeouts), `persistence_truncation` (runs as root, chmod ignored). `scatter_rows` hash mismatch is unresolved. The gate thread judges these, not the shard.
22. **"Flake" is not a cause.** The effects RNG test failed on and off for a day; the real cause was a 65 s limit on a busy machine (now 180 s). Find the cause before re-running.
23. **Red team every wave, carrying the last findings.** Camper stalls without a Warden break and traversal stalls are by design. A hitch counts only when it lands at the same run moment across seeds.
23a. **A child cap is a measurement, not a guess.** `alpha_bot_sweep` was listed as a "cloud false fail" because its 170 s child cap sat under a 276 s child; time one child alone, then size the cap and the tier from it (`ba10b7c7`).
23b. **Eight seeds can't judge a chaotic median.** Per-seed fight times are fixed on one commit but reshuffle with any gameplay change, so on w18 the 8-seed swarm ratio read 1.77x where 24 seeds read 1.86x. Judge medians on 24 seeds (standard error about 4 s) before calling a band moved.
24. **When fourteen tunings don't fix a design goal, it's a design question.** The Dispatcher stayed cheap to ignore through 14 tunings; one card ("Escalate") settled it.

## Permission prompts

25. **Allow-once prompts come from compound shell commands.** Pipes, `&&` and `cd` chains don't match allow-list rules. Fix: one checked-in script with subcommands (the music session's `scripts/music/mx`), allow-listed in `.claude/settings.local.json`, called as one plain command.
26. **The PC allow-list covers test and check scripts, read-only git, and pushes to `cand/*` and `scratch/*` only.** Never main, force-push or installs.

## Music

27. **Never replace a pick unless he picks the new take by ear.** Theme-consistent retakes sounded "boring" to him (15:59Z 17 Oct); energy, switch-ups and electro bass win over neat theory.
27a. **A place music layer never sits inside an arena.** In the Crown, crown_ramp's sensor sat in the Warden's bowl and the ball re-crossed it mid-fight; each layer change shifted the on-bar telegraphs and turned a 6,262-tick win into a 14,410-tick cap (17 Oct 22:24Z). Put the sensor outside the arena, or have the music director lock layers during a fight.

## Library and records

28. **One register for decisions.** Check `project-guide/DECISIONS.md` (repo: `project-guide/handoff/DECISIONS.md`) before proposing anything that might already be decided; he dislikes re-deciding and the tokens spent rediscovering old calls (19:46Z 17 Oct).
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
40. **Promote fast, the wave 17 flow (PR #106, ORCHESTRATOR).** Fast lane (`npm run sketch:fast -- --base <stage>`) plus a reviewer stacks a PR on the stage branch; each stage head gets the full cloud gate and one rotating red team persona; with no new red or blocker, staging merges the stage PR to main on GitHub; the PC runs GPU checks on each promoted head (GPU red is a next-wave fix unless it crashes); five-persona sweep at wave close.
41. **Claude Docs edit grammar.** `target {"kind":"blocks","ids":[...]}`, `source {"as":"blocks","from":{"kind":"inline","content":[rows]}}`; a table row can't be replaced, so insert the new row after it and `delete` the old one with its `ifHash`.
42. **Artifacts and Claude Docs are private to the account that made them.** For a move to another account, carry the content as files in the repo (project-guide/handoff/) or share the pages with the new account.


## Coordination from the PC, 18-23 Oct (history; the coordinator is back in the project, so lessons 1-13 apply again)

43. **GitHub is the bus for cloud lanes.** Claude Code cloud sessions cannot message other sessions. A lane posts a receipt comment on each PR (verdict, head SHA, commands, nonzero test counts) and raises a hand on the wave's "Wave board" issue. The local coordinator reads both at every check-in, at least every 30 minutes. Local sessions message the coordinator directly.
44. **Escalation goes one step at a time.** An agent asks its lane coordinator; a lane asks the local coordinator; only the coordinator goes to Andrew, with a stakeholder pitch (what's at stake, options with tradeoffs, a recommendation, the measured number, what would change it). Keep building on the recommendation while a pitch waits.
45. **Sync the records before splitting into worktrees.** Lanes clone main, so the rulings, the ownership table and the graph land on main first; a lane that starts from stale docs re-decides settled calls.
46. **Cap concurrent cloud lanes and let each fan out inside its sandbox.** The cap is 7 (19 Oct) and was raised to 11 on 21 Oct. Lanes that run their own agents and workflows replace a dozen flat sessions; the dozen used up the old account in a day.

## Back in the project, 23 Oct

47. **The merge safety check reads a typed line as covering only the PRs it names.** Andrew's 17:27Z line landed #383, but #385, held in the queue it described, was refused. Ask for one line per batch that names the thread, the action and each PR number, and attach it with `context_message_ids`.
48. **Remote Control sessions cannot receive `send_message`.** Reach an RC session through `message_thread` on its thread; other threads route through the coordinator.
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
