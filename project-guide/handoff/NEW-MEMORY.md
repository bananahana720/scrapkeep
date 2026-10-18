# Scrapkeep

- **Owner and repo.** Andrew (GitHub bananahana720) owns https://github.com/bananahana720/scrapkeep. The game is in `sketches/core-loop`: a Godot 4.7.2 roguelite where you roll a scrap-mech ball with a harpoon.
- **Worlds and bosses.** Spillway (Brindle), the Dig (the Waking) and the Highdraft (the Mind). There are six pilots: Sable, Rivet, Kest, Tarn, Tally and the Cannon.
- **Local folder.** `/home/andrew/Projects/scrapkeep` on his PC: Omarchy/Arch, with an RTX 4080 as GPU device 0 and an RTX 3060 as device 1.
- **Goal.** A finished-feeling Linux alpha by wave 21, opened from his app menu. It is accepted at his 11-area playtest sitting: no "Not yet", no open blocker, frames in budget, zero placeholders. After that comes story, lore, characters, and boss and system tweaks.
- **Moved here from an older project on 18 Oct 2026.** The handoff pack is in the repo under `project-guide/handoff/` (start at START-HERE.md). Threads, cards and Remote Control sessions from the old project don't carry over.

## Where things live (repo copies are canonical here)

- **Decisions register:** `project-guide/handoff/DECISIONS.md`. Every ruling, by topic, newest wins; replaced rulings sit in their own table. Check it before deciding anything, because Andrew hates re-deciding.
- **Lessons and ways of working:** `project-guide/handoff/LESSONS.md`.
- **Current wave, PRs and base reds:** `STATE.md`. Live work: `THREADS.md`. PC and cloud split: `DEVICES.md`. Old pages: `LIBRARY.md`.
- **Repo docs.** `docs/project/README.md` is the project desk. `BIBLE.md` and `adr/` own the game direction, `BACKLOG.md` owns tasks, and `TRACKING.md` and `ORCHESTRATOR.md` own execution.
- **Old pages.** The old project's pages and Claude Docs are private to Andrew's other account. Use the repo copies, and rebuild a page in this account when he needs one on his phone.

## Standing authority

These were typed by Andrew in the old project on 17 and 18 Oct. Ask him to restate them in one line here so safety checks can cite a local message.

- **Merges.** The coordinator merges gate-passed PRs, including to main, and does git housekeeping. There are no merge cards.
- **What still goes to him.** Design, taste and decision forks go to him as cards, early and often. A fix that changes a recorded rule is a card. Engineering thresholds that aren't his rulings are the coordinator's call.
- **Full parallel authority.** Tend threads that need answers first, then keep spinning up parallel work; there's "plenty of usage". His game examples model ambition only, so never copy them on the nose.
- **Keep checking in.** Keep going through threads that need review or answers, and resolve what can be resolved. Split work into code-side and Blender-side threads, put as much as possible in the cloud, and size each to its sandbox.
- **Promote fast.** Short waves, each promoted promptly; open PRs roll to the next wave instead of blocking. The flow is in STATE.md.
- **Permissions.** "Allow for all", plus standing approval for the red team. Ask him as little as possible. Any ask goes in the project chat, as one line or a paste-ready command he runs himself. Threads never ask him in-thread. Prefer a new branch and a fresh PR over force-push.

## How he works

- **Phone-first.** Decisions go to him only as cards in the project chat: at most three open, one question each, a recommended option, and game terms rather than file names. Put the measured number on the card. Things to look at go on phone pages.
- **Answers in words.** If he answers a card in words, close it and record his words. Verify each tap (the decide event, chosen by Andrew) before writing it into the register.
- **Commands.** He happily runs bash in his own terminal when handed a paste-ready block.
- **Claude owns engineering and design PM, Pareto-first.** Keep parallelizing. Stay on idle or waiting threads, don't poke busy ones, and resolve finished ones.
- **Every idea he voices gets filed within the hour.** Rulings go to the register, principles to its Direction table and the project instructions, design ideas to that area's thread, open questions to a design questions page, and after-alpha wishes to the parked list.
- **Every idea is a motif.** Place it deliberately across the game, in harmony, not spread evenly.
- **Usage limits.** Threads stop and don't self-resume, so nudge each after a reset.
- **PC Remote Control sessions.** They often report phantom permission prompts. Raise one only if the session stays stalled for several minutes.
- **Calendar.** Add holds for his wave 19 feel check and the sitting once dates exist.

## Direction (the full list is in the project instructions and the register)

- **Tone.** A carefree, melodramatic anime and comic playground with Scott Pilgrim as the touchstone. Borrow anime tropes, not East Asian sound. Written lore stays in a dry crew-log voice.
- **Intent everywhere.** No front-loading world 1. Inert stations, dead props, white untextured models, mismatched lighting or silent feedback read as placeholders.
- **Polish everything, in the "Soft toy" look.** Crews and round bodies go smooth; machines keep crisp, bevelled edges. The brief is "chunky, bevelled, smooth". Ease every animation. The polish toolkit is #107 (`tools/blender/polish.py`), frozen at 5bc84833. Pilot GLBs are capped at 1,024 KB.
- **The Mind is "All hands".** The crew called it the Mind because it did the thinking, and they were its hands; with them gone, it grew its own. It shows through gloves numbered 04-01 plus FOREMAN, one finger curling shut per phase, a glove set down on defeat, a HIRED stamp, and crew-log plants from the Spillway onward.
- **Overpowered pays.** Strong builds and luck are never punished. "Lift the ceiling" means hits count up to 3x plating and the ultimate fills up to 70%. First-stagger windows are 60-85 s at the hive and 45-70 s at the sinkhole and the Mind, judged on the run median across pilots.
- **Chaos but fair.** The attacker budget is 6, +1 per heft class, +2 per world, capped at 12. "Gap wins" keeps 0.2 s between packs, and each pack attacks as one. Bosses, the Foreman, the Linker and hive defenders are exempt.
- **Kill-first specials.** The Foreman, Dispatcher, Splitter and Linker each have their own presence, tell and death sounds.
- **World enemies.** Unique remixes of the core verbs (roll, ram, grapple, carve): the Dig is "Commit", the Highdraft is "Ring-outs".
- **Items.** Six actives plus maker sets on the 61 items come before the sitting. Overrides and evolved forms come after. Every flash obeys Reduce flashes.
- **Rivet's Breach.** Every heavy Breach lands its crater and hits about 55 ms after touchdown, spread over frames with no hitch. On steep slopes it lands at 0.11 s, which keeps 60 fps.
- **Parks.** One skill per park: dam rolling, flume momentum, pit abilities, sinkhole carving, islands grapple, crown everything. The flume keeps its open 90 m butte gap. In the sinkhole the floor is lava, briefly, and the glazed walls pay carvers. Highdraft edges are ground.
- **Music.** Gritty steampunk-cyberpunk with house and jazz, melody first: combat at 129 BPM, roaming at 172. Boss finals switch to Eurodance at 140-150 BPM in the final phase only. Never replace a pick unless he picks the new take by ear. Theme C plays on a won run's summary and the ending. A place music layer never sits inside an arena.

## Engineering facts

- **Cloud gate.** It is the gate of record except for GPU checks. The fast lane is `npm run sketch:fast -- --base <stage>`. Bot tiers are sharded across threads.
- **Gate traps.** A fresh worktree's first import can segfault, so rerun it. Band sweeps can be killed for running out of memory, so rerun any 300 s row alone. `park_reactor_fight` flaps even solo.
- **Placeholder rule.** A PR that adds an attack E-row or registry row fills every field before it passes. Attack ids are claimed in `alpha-status/attack-ids.md` (new claims E34+).
- **The 4080 checks.** Its results count for frame times and menu-ready time; the cloud can't prove 60 fps. An NVIDIA driver update needs a reboot before GPU work.
- **Red team.** It plays every stage head with one rotating persona, and all five personas play at wave close. It grades on `sketches/core-loop/BUG-BAR.md`. Camper stalls without a Warden break are by design.

## After the alpha (parked until his sitting)

- **The list.** Roadmap, monster origins, park societies, lore, alternate paths, New Game Plus, secrets and collecting, weapon overrides, evolved items, multi-kill callouts.
- **Alpha exception.** The Mind's through-line runs from world 1.
