# Project memory snapshot

Snapshot of the Scrapkeep cloud project's shared memory, taken 2026-10-17 ~20:05Z. Memory sync is one-way (cloud to this file, on request); edit the cloud memory, not this file. Newer rulings in docs/decisions.tsv win over anything here.

## Index

- Private project owned by Andrew (GitHub: bananahana720).
- Created 2026-10-16. Repo: https://github.com/bananahana720/scrapkeep. Local folder: /home/andrew/Projects/scrapkeep (approved, default, Remote Control served).
- Goal (project topic and top of project instructions, set 2026-10-16): Ship Scrapkeep as a finished-feeling Linux alpha by wave 21; Andrew opens it from his app menu and plays through all three worlds and six dressed parks; accepted at his playtest sitting when no area is "Not yet", no blocker open, frame times in budget, zero placeholders. After the sitting: story, lore, characters, boss and system tweaks.
- LIBRARY: decisions register (canonical) + lessons + phone start page, see [[project-library]]. Record every new ruling there.
- SHARED FOLDER MAP: start at /mnt/project-files/INDEX.md (tidied 2026-10-17, again 20:00Z). Music files live in music/ (SOUND-BIBLE.md, INTEGRATION.md, title/, worlds/, fights/, camp-and-endings/, sound-effects/); superseded drafts in archive/. Red team findings in redteam/. Don't write new files to the root.
- CARD QUEUE (authoritative, survives coordinator recycle): /mnt/project-files/alpha-status/queued-cards.md.

## STANDING MERGE AUTHORITY (Andrew typed 19:41:01Z 17 Oct, msg cmsg_01Q3o8RFpavsNskXDb46SG49RxgA38Xukz8uM9LeQmj3gy; 19:41:35Z cmsg_01Q3o8RFpavsNskXDb46SG492Ehk2pTd2v28Czqe5x4K9K "I greenlight anything operationally... maximize speed")
- Coordinator has full authority to close out and merge done PRs, including to main, delete branches and do git housekeeping. No merge cards anymore: merge gate-passed PRs (or send to the machine to admit) and say so in one line. Wave-close pushes to main need no further typed line. When a safety check wants his own words, attach those message ids in context_message_ids.
- Andrew stays key stakeholder for vision end to end: design, taste and decision forks still go to him in the project chat, early and often.

## Design hub, library, consistency (Andrew 19:43-19:46Z 17 Oct)
- Custom view tab is now the DESIGN HUB (replaced the old dashboard): On your radar (open design questions), Decided (canonical rulings by topic), Conflicts with earlier decisions, After the alpha, How we work, Waiting on you. Coordinator rewrites it when the threads below report.
- Design questions page: https://claude.ai/artifact/BkritUa1WFADGzWBiBmJK8 (thread "Design questions page"; answers save to the page store the thread reads; "Copy my answers" fallback -> relay paste to that thread; open list /mnt/project-files/design-questions/OPEN.md). Round 1 (17 Oct) 13 questions + 9 after-alpha seeds; skipped questions keep the recommended option.
- Decisions register (Claude Doc): https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9 (mirror project-guide/DECISIONS.md). Lessons doc: https://claude.ai/code/artifact/95d92907-5cfe-4290-b303-d465baccedde (mirror project-guide/LESSONS.md). Owned by thread "Project library and lessons learned". "Reconcile past decisions" folder thread writes project-guide/RECONCILE.md.
- Why: he dislikes changing his mind unknowingly and spending tokens rediscovering or reconciling old decisions. Newer ruling stands; true contradictions become hub questions.
- INTENT EVERYWHERE (Andrew 19:54Z 17 Oct): no front-loading effort into world 1 as trailer bait; every level, moment and place gets deliberate intent. Standing check: thread "Every-park intentionality check" builds a per-park scorecard (six parks, camp, boss arenas), re-run each wave by the red team (method in /mnt/project-files/alpha-status/intent-check/); plus a gut check as the alpha wraps up. Enemy rosters for worlds 2-3: thread "World 2 and 3 enemy identity" (Andrew 19:52Z hates rehashed enemies; unique but not gimmicky, harder remixes of core verbs; he may send a reference game).

## After the alpha (Andrew 19:48-19:50Z 17 Oct; PARKED until after his sitting)
- He is thrilled with progress. Post-alpha: a roadmap toward beta or a free/low-cost public release, defined by content, not dates. Ideas: origin story of the monsters in each world; societies integrated into the parks; deeper lore; tweaking pilots' personality and design after he plays them; enemy and world design; more between-world transitions; alternative worlds or paths; world mutations as New Game Plus; Binding of Isaac-style endgame pull (discoverable story beats, character unlocks, secrets, collecting). He loves discovery and collecting.
- ALPHA-SIZED exception: a Mind through-line from world 1 (how the Mind first shows itself in the Spillway) is question 9 on the design questions page. Everything else is seeds in its "After the alpha" section.

## Creative tone (Andrew, 2026-10-16) — applies to every beat of the game
- The game is a playground: carefree, experimental, melodramatic framing and cinematography in an anime and comic book style. Touchstone: Scott Pilgrim (melodrama, satirical and meta take on its genre, winking backstory; comic panels, on-screen onomatopoeia, character intro cards). Real swings from intensity to despair, anger or sadness; the sadness is self-aware and a little corny. A game that loves having fun and tries to make you smile.
- "Anime" means the genre's tropes and structure, NOT East Asian instrumentation, scales or motifs (Andrew, 22:19Z). Rule: borrow the tropes, not the sound.
- Tone bible: /mnt/project-files/tone/TONE-BIBLE.md (repo copy on PR #20, with TITLE-INTROS.md). In project instructions. RULED: written lore stays dry crew-log voice; melodrama lives in camera, captions, cards and music.
- Title rotation (PR #20): first launch always Sable's opening (storyboard https://claude.ai/artifact/SP2Rcy3tzwhpwK3hcHAsBk); then pilots and worlds on theme A; each boss on theme B after the player has met it. Theme C (take 1 picked 23:41Z) scores run summary and ending.
- Bosses: Brindle (Spillway), the Waking (Dig), the Mind (Highdraft). Keys: menus/Spillway D, Dig E, Highdraft G.

## Difficulty and enemy direction (Andrew, 23:44Z to 00:45Z)
- Loves chaos: wants many enemies attacking at once, but learnable and fair, with time to read and react. Difficulty scales with player power (items, level-ups, growth) like Binding of Isaac. Attacker budget (SQ2, PR #15): starts 6, +1 per heft class, +2 per world, cap 12 late Highdraft; warnings never within 0.2 s between packs or kinds; one pack's warnings start together (card "Pack as one", 15:30Z 17 Oct). Growth rule: grown pilot clears hives at least 2x faster than small. Bosses never limited.
- Enemies have priorities (kill first, dodge a certain way); pilots may struggle with some enemies, overcome by skill and augments. 3D space as a jungle gym with grapple tricks; ball downforce and half-pipe carving, with maps and enemy placement designed around it. Fun depth, not gimmicks. Design: ENEMY-PRIORITY.md on draft PR #23; phone page https://claude.ai/artifact/1qJBFCBCbQEMNMaSZBPHQu.
- Motif rule (19:37Z): see design-motifs-rule memory file (world-themed enemies, skill-test areas, damage types vs armour, auras, cast times; intentional, not uniform). Auras thread builds on recommended options until his answers (cast on the move; Flow/Plate/Wind; resisted ~60%, weak ~150%; learn on first hit).
- Card taps 2026-10-17: bad matchups "Nudge loot" (counter items 1.5x, no guarantee); kill-first enemies "All four" (Foreman, Dispatcher, Splitter, Linker); wall grip "Speed holds" (auto above cruise speed, on/off toggle for the sitting); Rigger Blue kept as Homecoming reward paint; SG2 fusion reading "Keep it" (03:33Z: "second status on a marked enemy" = already holds an SG2 status); sinkhole "Real basin" (02:37Z), then Andrew typed 15:31Z "Make the sinkhole pool a bowl on PR 29." (20 m bowl).
- More taps 17 Oct 06:16-07:17Z: Merge PR #23 enemy priorities doc; Merge MIND-ROUTE (bot old Mind route); placeholders "Ride lips only" (PR #32); ball speed "Soft cap" (07:17Z: speed past 60 m/s becomes hit damage + blazing trail instead of velocity).
- Posture family (HIVE-GRIND, MIND-POSTURE, SINKHOLE-POSTURE): CONFIRMED Andrew typed "yes, 45 to 70 s" 19:42:36Z 17 Oct (first stagger 45-70 s; #15 skipper floor 45 s ruled).
- Splitter (Andrew 19:19Z): chase the player, keep splitting, a "mama" to identify and kill; urgency. Coordinator accepted PR #60 proof on median hull + damage taken (19:45Z); proof tool now grades damage taken (67ad0d06). Dispatcher must-kill "Escalate" (19:33:49Z).
- Special enemies (Andrew 00:45Z): like Left 4 Dead 2 specials, each of the four has its own visual and audio cues (presence loop, wind-up tell synced to the visual tell, death sting). Sounds done on PR #12; missing cue = placeholder at wave 20. Bodies: PR #24 (https://claude.ai/artifact/CKDMJfJZ8eEtWE6PaFcREE).
- Split the machine accepted: wave 16 CLASS-TILT bug; 17 hook-out, nemesis column, answer weighting, Foreman; 18 Dispatcher, Splitter greybox, matchup lab, grip and carve; 19 Linker plus final models, now the risk wave; 20 start harpoon poles and flails.

## How Andrew wants to work here (all stated 2026-10-16; mirrored in project instructions)
- PHONE-FIRST (23:35Z): Andrew is often away from his computer and will NOT go into threads to steer. Every decision comes as a decision card in the project chat (threads send card text to the coordinator; max three open). Anything to look at goes out as a phone-friendly Artifact page. He taps cards fast.
- RELAYED TAPS LIMIT: the machine coordinator's safety check rejects relayed card taps for protected actions. Needs Andrew's own typed words via context_message_ids. Since 19:41Z 17 Oct, use the standing merge authority messages first.
- Cloud threads may edit src and assets on their own branches and gate them in the cloud (Andrew typed 16:38:44Z 17 Oct); his PC keeps GPU checks.
- The music Remote Control thread and the wave thread stop on permission prompts; he can allow them from his phone inside the thread.
- OVERNIGHT COMPUTE (Andrew 03:34Z, 17 Oct): when he sleeps, maximise compute. 4080 runs the machine gate plus ACE-Step music renders (staggered GPU use). Cloud sandboxes (4 vCPU, no GPU, 2 h background cap each) take CPU work. ACE-Step stays on his PC.
- COORDINATION STYLE (Andrew 03:38Z, 19:38Z): stay on top of threads that are idle or waiting for approval; don't poke threads busy with work or background tasks. Resolve finished threads. Keep parallelizing anything without dependencies. Communication proactive and timely, not ceremonious.
- Claude has full project-management ownership of engineering and design; Andrew is the stakeholder. "Down for anything": Pareto-first, no over-engineering. Ask him only about taste and design, trade-offs that change what he gets, and alignment checks. A fix that changes one of his recorded rules is a card, not an engineering call.
- When idle threads are few, he wants unblocked work started in cloud threads proactively.
- Coordinator relays his taps to threads, quoting card title and tap time.
- Card texts threads send by send_message are lost when the coordinator is recycled; ask the thread to resend, or check queued-cards.md.
- Cross-session send_message to the wave thread's session id fails ("not found"); use message_thread on its thread instead.
- Ambition paradigm adopted 22:17Z (full section in project instructions). Game changes need a tool check plus independent reviewer; a red team plays every wave's build.
- Sweeps: paused 17 Oct after a long-check-in warning; no sweep scheduled.
- Custom view: NO hard-coded colors (dark mode); opacity and positioning get stripped; no scripts.
- Calendar: add a hold for his playtest sitting once wave 21 has a date.
- Memory sync is one-way; snapshot at docs/project/PROJECT-MEMORY.md in the repo on request.

## Alpha scope and plan (full list at /mnt/project-files/alpha-status/grill-alpha-scope-2026-10-16.md)
- Playbook: https://claude.ai/code/artifact/f2247c5f-6d25-473d-aa3b-ee4a590afab4
- Rulings 2026-10-16: storyboards first; all six unstarted systems before the sitting; bug bar and 60 fps budget; placeholder check blocks exports from wave 20; Rigger Harness cut, 18 cosmetics; Cable Stitch trail deep green.
- Veto list cleared 23:37-23:41Z: MIND-ROUTE fix the bot route; keep pipe-vault head-on bounce; stage 5 hand lowered + tether in island dressing; paint via shader tint on dark Core frame; Tarn/Cannon animations ship as is; keep all wave 15 gameplay changes, wave 14 tuning and wave 13 combat defaults; replace old park lore; three-level parts stay on three neutral parts.
- Storyboards approved (https://claude.ai/artifact/GhTEdmmti7aewmmYJnvsk9, PR #14). Camp hub ring; Hanging Isle moving tip (ISLE-TIP, wave 19); headframe legs solid; sinkhole full ring; spire 30 m waist.
- Wave plan: 15 park win (closed); 16 stability, Switch, AUDIO-POOL, SOUND-INT, MIND-ROUTE, CLASS-TILT, park bot stalls, BRINDLE-HULL, STAGE6-GATE, S1-HITCH, PERF-S3; 17 SQ2, SI6, SG2, SG15, landmark placement, paint fixes, PE-INT, enemy items, speed soft cap; 18 SR10, SI3, first dressing, AppImage/menu; 19 rest of dressing, landmark models, camp, ISLE-TIP, island tether, Linker; 20 no placeholders, lore port, bug bar, harpoon poles/flails; 21 release candidate.
- Wave 15 CLOSED: on origin main at cf63e622. Placeholders 1,442.
- Wave 16 red team (692fa3ff): 0 blockers in blocks 1, 2, 4; Brindle stall fixed. Open: STAGE6-GATE (relic_spot fix never landed; thread "Stage 6 exit gate stall", candidate Vector2(-3.3, -121.7)); S1-HITCH (thread "Stage 1 hitch", game-side); new blocker candidate stage 5 Warden never breaks for Tarn completionist 36003 (sent to "Why the Warden never breaks" thread 19:48Z).
- Wave 16 candidate is cand/alpha-w16 (machine admits there; on GitHub at 2fce8953). Machine admitting: tapped list + #32 + cloud gate batch 1 (31 PASS PRs) + batch 2 (#35, #48, #50, #37). Holds: #15 (1.75x growth rule confirmed #15's, reactor 65 s vs 54 s, camper seed 5 0.00 s fight), #43 (shard-43b on shard 2 after #36 bisect), #36 (shard-36), #52, #57 (shard-57 on shard 3), #38 ISLE-TIP (shard-38 on shard 3 after #57), #59, #60 (shard-60 on shard 1; head 67ad0d06), #22 open, #56 after #36.

## Music direction (Andrew, 2026-10-16/17)
- Gritty steampunk-cyberpunk crossover with house influences; jazz in composition. He played sax; melody matters most. Combat 129 BPM, roaming and show-opening 172 BPM. Remote Control thread "Compose Scrapkeep's music and sounds" on his 4080; PR #12. 17:10Z: "the music is on point".
- Combat and boss music: Scott Pilgrim evil-ex battle energy plus Roboquest's driving production.
- Phone listening page https://claude.ai/artifact/1pRSWw44k5VXp7gGtJs9Sq. Integration: drums follow speed, sax enters with combo; hit sound within 5 ms, musical answers on next beat.
- HYPE RULE: boss music amped with electro/Eurodance energy, 808s, catchier versions of existing melodies, 140-150 BPM; Eurodance versions play in the final phase only.
- SCORE ARCHITECTURE (PR #27, page https://claude.ai/artifact/PbEERHmLT5TQ68Bo1cb9X4): "Written themes" and "Build to ending". Don't toss existing tracks; new take replaces only if he picks it by ear.
- Ear-check flags: the Mind final and secret Spillway may not keep their parent melody; the Waking final may drag.

## What Scrapkeep is
- Godot 4.7.2 roguelite: rolling scrap-mech ball with a harpoon, three worlds (Spillway, the Dig, the Highdraft), three bosses. Game in `sketches/core-loop`.
- Claude Code coordinator on his machine (via the wave thread) owns admission to the candidate and GPU checks.

## Andrew's tooling
- A-Stack installed on his claude.ai account; threads get `astack:*` skills; astack:grill-me for "grill me".
- pstack-to-astack path fix is draft PR #2 (not merged).
- Connected on claude.ai: GitHub, Claude Docs, Google Drive, Gmail, Google Calendar, Context7.

## alpha-goal


Andrew adopted this goal on 2026-10-16, replacing "Complete the full game in alpha":

Ship a feature-complete Scrapkeep alpha: one exported Linux build a stranger can install, play from title to the Mind, and win in 30-45 min. Every planned system and all content are in, with first-pass art and no placeholders. Judge against the three Bible pillars with evidence beyond Andrew or Claude: naive players' sessions, runs.ndjson logs, MangoHud frame-time captures, a bug bar. Accepted when no milestone area is "Not yet" at Andrew's 11-area playtest sitting, there are no open crash or blocker bugs, frame times are in budget, and there are zero placeholders.
Dropped 2026-10-17 16:35Z: the rule that five first-time players reach the end of world one unaided (Andrew: "my 11-area sitting is the alpha gate").

**Why:** the old goal mixed alpha, beta and polish, so nothing could be judged done; 14 waves merged on bot evidence alone.
**How to apply:** the playtest build is the final one after all remaining waves. Andrew plays first, from an outside tester's point of view, and gives a verdict per area. Doc: https://claude.ai/code/artifact/e68d8e33-f04a-44d5-8f00-a35bcd50cf95. Playbook: https://claude.ai/code/artifact/f2247c5f-6d25-473d-aa3b-ee4a590afab4. See [[alpha-playbook]].
MVP framing (Andrew, 2026-10-16): the alpha should feel like a finished game: it opens from the app menu to a normal main menu (Play → pilot select, Settings). Later menu work added more; for the current menu ruling see the decisions register https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9. The only "alpha" work left after that sitting is story/lore, characters, bosses, areas and system tweaks, which come from the playbook's "What to change" table. Scope added 2026-10-16: the camp is back in (reverses the W18-R1 cut), the build ships as an AppImage plus an app-menu entry, the gamepad is optional, and results are logged as playtest entry 13 with fixes routed to the wave coordinator. Full tree: /mnt/project-files/alpha-status/grill-alpha-scope-2026-10-16.md. Parks must be fully dressed; verdicts are Accept / Accept with fixes / Not yet across 11 areas.

## alpha-wave-plan


Plan lives on Andrew's machine: artifacts/local/alpha/push/w16/PLAN-w16-plus.md (wave-15 worktree, branch cand/alpha-w15). Machine coordinator ran from thread "Alpha scope into the waves" via Remote Control.

Waves: 16 stability + KD7 Switch; 17 SQ2, SI6, SG2, SG15, landmark placement/beam, pilot paint, storyboards; 18 SR10, SI3, dress dam/flume/pit, AppImage + menu + README; 19 dress sinkhole/islands/crown, six landmark models, camp; 20 no placeholders, lore port, bug bar; 21 release candidate then Andrew's sitting.

Andrew's rulings 2026-10-16 (taps on decision cards): all six unstarted systems before the sitting (adds a wave); storyboards first (48 h veto); push main to origin at each wave close; Rigger Harness cosmetic cut. Stage-swap hitch moved to wave 16 (superseded, not his ruling).

Veto list cleared 2026-10-16 23:41Z by card taps: everything kept except MIND-ROUTE (wave 16: restore the bot's old Mind approach so the 2x small/grown target holds). Also kept: paint via shader tint, Tarn/Cannon clips as is, SG15 levels on three shelf parts only, old park lore replaced.
Storyboards: all five calls tapped 2026-10-16 (camp hub ring; Hanging Isle moving tip = card ISLE-TIP; headframe legs solid; sinkhole full ring; spire 30 m waist), so landmark and camp builds are unblocked and the Oct 18 deadline is void. Stages 3, 4, 5 need re-measuring. Record: storyboards/DECISIONS.md on PR #14.

Cloud threads branch from origin/main; wave-15 files off-limits until wave 15 is pushed. All cloud branches return to the machine coordinator for gate and merge. Remote Control sessions can't receive send_message; relay via start_rc_session `instructions`. See [[alpha-goal]].

Special-enemy cues (Andrew typed, 2026-10-17 00:45Z): the four kill-first enemies (Foreman, Dispatcher, Splitter, Linker) are Left 4 Dead 2-style specials. Each gets its own visual tell and audio cues (presence, wind-up, act), fired from the same telegraph moment. The music thread makes the sounds. A missing cue counts as a placeholder at the wave 20 check.

Andrew typed the confirmation in the wave thread at 2026-10-17 00:47:50Z: all his card taps of 16-17 Oct are his rulings (including All four and the enemy split); push wave 15 to main when it closes. The relayed-taps block is cleared for those.

Wave 15 CLOSED 2026-10-17 ~02:30Z: pushed to origin main at cf63e622 (fast-forward from dfc86d8b); 55 rows in docs/decisions.tsv. Park win proof is best-of-3 (Andrew typed 02:13Z) because Pylon seed 1 wins only ~50% at the stage 6 Mind (Mind perch card, wave 16). Cannon-lane fix now force-strikes a held body only when the lane can't reach it. Next: gate queued PRs #13,#14,#16-19,#21-24,#12,#15 onto wave 16. Placeholders 1,442.

Overnight 17 Oct (Andrew asleep from 03:35Z, wants compute maxed): the machine gates ahead of his taps, stacking each gated PR onto the ones awaiting a tap, and runs wave 16 cards in parallel worktrees. ACE-Step shares the 4080, so perf readings (PERF-S3, S1-HITCH) are taken only on an idle GPU. No push to main overnight; merge cards wait for his morning taps.

## andrew-phone-decisions


Andrew (2026-10-16 23:35Z): he's on his phone and won't open threads to steer. Every decision or veto item goes to the project coordinator as a card (question, 2-3 options with a one-line consequence each, recommendation with its reason); the coordinator posts it in the project chat and relays his tap. At most three cards at a time. Write in game terms, not test or file names. Glanceable artifacts are welcome.

**Why:** thread replies and questions go unseen on mobile; he answers cards in the main chat.
**How to apply:** thread Claudes don't ask him in-thread; send the card text to the coordinator session with send_message. See [[alpha-wave-plan]].

Go-forward rule (Andrew, 2026-10-17 16:30Z, at his computer): limit any need for him to enter a thread to approve. All approvals come to him in the project chat (cards or a one-line typed ask). The coordinator resolves threads that are review-ready or done once their PR is handed to the machine merge queue (13 were resolved 16:30Z). Remote Control sessions (wave/machine and music) were asked to allow-list routine commands so they stop on fewer permission prompts.

## rulings-2026-10-17-afternoon

- 16:33Z poles/flails (PR #35): "Weight" decides pole vs flail; "Rip them out" (grown ball rips turrets out and swings them).
- 16:35Z "Drop it": no five-first-timer requirement; alpha gates on Andrew's 11-area sitting alone. BUG-BAR.md rule 3 being updated by the ambition thread.
- Speed pillar (Andrew 16:33Z) is now in the project instructions and in /mnt/project-files/ways-of-working/rieseberg-ambition-article.md. Targets: 12+ cloud threads at once, ask to draft PR under 2 h, PR to gate verdict under 4 h, no gate-passed PR waits over 12 h. Every sweep reports these.
- Ambition map: https://claude.ai/artifact/Fb7otFCzb4cUhEAsUAr3Xk, briefs in /mnt/project-files/alpha-status/ambition-map.md. Started 16:34Z as cloud threads: crash harvester, RC gate, audio gate, power read, priority proof, first-timer audit, sitting kit, wire-or-cut, cloud gate. FEEL-PROBE folded into the knockback thread. ANCHOR-SWAP and PERF-NIGHT sent to the machine. The machine was asked to push cand/alpha-w<n> to GitHub after each admission (never main).
- More taps, 17 Oct: SPIL-9 "Grow SPIL-9" (one drone grows per module, signature assist; PR #45), assist called by "Next ram" (no new button). Late run "Clearly mightier" (about 3x size, 2x knockback, warnings on top), refined 17:28Z to "Presence, centre clear" (growth via colour heat, words, edge ink and aura; burst size unchanged; 1.5-2x area is OK). Waking/Mind intros "Approved lines". Lore "Collect over runs" (PR #53). Relays "Add to two parks" (Spillway dam and Highdraft; PR #36). Bowling hit "Pinball" (about 36 m cap). Forge test pieces "Keep them out" (PR #46). BUG-BAR PR #37 Merge tapped and sent to the candidate.
- RULE CHANGE (Andrew typed 16:38:44Z, after tapping "Cloud writes and gates"): "Cloud threads may edit src and assets on their own branches and gate them in the cloud; my PC keeps GPU checks and the merge." Recorded in the project instructions' standing-approval paragraph. The four specials (Dispatcher, Splitter, Linker, cue wiring) moved to cloud threads at 17:16Z; the machine keeps admissions, GPU checks, ANCHOR-SWAP, PERF-NIGHT and possibly the Foreman.
- Cloud gate thread is the gate of record except for GPU checks; it shards bot runs across sibling threads (brief /mnt/project-files/gate/BOT-SHARDS.md; pass tests by base name, not res:// path).
- Permission prompts fix: allow-once prompts come from compound shell commands. Fix: one checked-in script with subcommands, allow-listed in .claude/settings.local.json, called as a single plain command. The music session uses scripts/music/mx; the machine was asked to do the same.
- Music 17:10Z: Andrew says "the music is on point". Fill every gap with per-place and per-moment variations from the current motifs, plus hidden tunes to discover. A camp jukebox thread replays discovered tunes.
- Comic words on enemy hits kept "as built" as the coordinator's default (no card).
- 17:46Z taps: relay stake "Budget holds". A stacked relay never stands more attackers than the stage's budget, and minibosses count toward it. A bigger stake means more waves, more minibosses and a longer fight (PR #36). Jukebox "Hints": a blank record names where to find its tune, for example "Not heard yet. Reach the top of the Highdraft." (camp jukebox thread, src/core/tune_rows.gd).

## cloud-src-edits


Andrew typed this rule in the project chat at 2026-10-17T16:38:44Z: "Cloud threads may edit src and assets on their own branches and gate them in the cloud; my PC keeps GPU checks and the merge."

**Why:** waiting on the machine for every src/ change stalled the wave work.
**How to apply:** cloud threads edit src/ and assets/ on their own branch, then run lint, sketch:smoke and an independent review in the cloud. Merging to main and GPU checks (frame times, renders) stay on his PC. This replaces the older note that cloud threads must hand src changes to the machine wave thread. See [[cloud-toolchain]].

## red-team


- Tool: `npm run redteam -- --wave=<n> [--carry=<last findings.json>]` (scripts/redteam/, draft PR #25, tooling only). It takes about 35 min in a 4-core cloud container. Five bot personas (skipper, random, camper, completionist with late offers, traversal) × six pilots, rotated per wave; seeds 1000+100w. Grades on sketches/core-loop/BUG-BAR.md.
- Run it from a cloud thread after each wave lands on origin main. Carry the previous pass's findings.json so its blockers and majors replay. Copies are kept at /mnt/project-files/redteam/w<n>/ because artifacts/local dies with the container.
- Wave 15 (cf63e622, 17 Oct): 0 blockers. Majors: a deterministic stage 6 exit-gate stall (random/Pylon seed 2506; may be the known Mind perch stall, flagged for matching), a game-side stage 1 hitch 5-7 s in (not the music mix), and perf_bench s3 CPU p99 of 38 ms on the cloud box. Phone page: https://claude.ai/artifact/Y5hvZs8tQ6ou4AktKEKS2X
- Overnight sweep 17 Oct (`--sweep --block=0..4`, 180 runs, merged with scripts/redteam/merge.mjs into /mnt/project-files/redteam/w15/sweep-merged/): BLOCKER Brindle boss_stalled in 12 of 108 full runs. Skipper stalled 10 of 36 (Demolitions/Cannon 3/6, Tally/Tarn 2/6, Pylon/Runner 0). All four replays reproduce, so these seeds make a held-out set for BRINDLE-SCUTTLE-2. Fuzz builds hit 160-250 m/s against the 60 m/s cap; Andrew ruled "Soft cap" (07:17Z 17 Oct); sent to wave 17 with repro seeds. The cloud perf bench is unreliable (24-146 ms p99 across sandboxes).
- **Why:** project rules require a red team on every wave build, and no thread may grade its own work.
- **How to apply:** camper stalls without a Warden break and traversal stalls are by design. Hitches count only when they land at the same run moment across seeds; scattered ones are cloud load. See [[cloud-toolchain]].

## sitting-kit


Sitting Kit page (built 2026-10-17, replaces typing into the playbook doc): https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT. Private to Andrew; phone-first.

Store (read with ArtifactData on that URL):
- `verdicts/<area-key>`: {area, verdict: accept|fixes|notyet|null, note, photos:[assetId], updatedAt}. Keys: core-feel, wardens-bosses, in-run-growth, progression, pilots, stage-world, look, sound-music, clarity, difficulty-pacing, stability. Missing doc = not judged.
- `changes/<auto id>`: {area (Story and lore / Characters / Bosses / Stages and areas / Game systems / Anything else), text, photos, createdAt, carded:false}. After posting a row as a card, `update` it with carded:true (pin if_version); the page shows "Card sent".
- `sitting/meta`: {status: done|open, doneAt}. "done" = Andrew finished; log as playtest entry 13 and start cards.
Photos display at `/_blob/<id>` inside the page only.

**Why:** the playbook's area table is hard to fill on a phone; the store is machine-readable for the coordinator.
**How to apply:** at the sitting, send Andrew this link; afterwards read the store, not the playbook doc. See [[alpha-goal]].

## design-motifs-rule

Andrew (17 Oct 2026, 19:37Z, typed in project chat): every idea he gives is a signal to expand and carry through the whole game as a consistent motif. It doesn't have to be used everywhere or equally, but always intentionally and in harmony. His examples:
- enemies that vary world to world, with a mechanical theme for each world
- areas that test one skill (movement, grapple, rolling, momentum or abilities)
- armour with weak points by damage type (plated armour strong against concussive hits, weak to ability or electrical attacks)
- enemy buff and debuff areas, such as an electrical field that interrupts (19:35Z)
- pilot cast times as an MMORPG or MOBA balancing lever (19:35Z)

**Why:** he wants a cohesive, deep design where his ideas resonate across systems, not one-off features.
**How to apply:** when briefing any design or build thread, name the motifs that touch its area and ask it to place them deliberately. Design thread: "Enemy auras and pilot cast times".

## music-current-picks-win


On 2026-10-17 15:59Z Andrew listened to the updated soundtrack page and said the new theme-focused picks are boring. He prefers the current (older) jazzy tracks and especially loves the hard switch-ups near the end and the electro, bassy melodies and rhythms.

**Why:** the score-architecture retakes (PR #27 "Written themes") traded energy for theme consistency, and he hears that as boring.

**How to apply:** current tracks are the picks. Do not replace them with themed retakes. Music work is mix and master plus spicing up the current tracks, leaning into end switch-ups and electro/bass energy (see the hype rule in project memory). Themed takes stay as alternates only. Relayed to the music thread 16:00Z 17 Oct.

Later taps and notes 2026-10-17 16:21-16:23Z: roaming "Ramps with speed" (starts groovy and jazzy; drums and bass build with speed, Roboquest-style); camp, run-loss summary and ending "Keep them lighter". He loves the current run-loss summary (jazz-club feel) and the existing motifs. Rework the current tracks' own beats and melodies into each moment's key and mood (from his local music folder) rather than writing new themes. He loves the Machine themes' machine foley in the groove (pistons, cannon-like hits, steam releases, electro whirs). Percussion is the main carrier of energy.

## cloud-toolchain


- Since 2026-10-16 (PR #11, merged), `.claude/hooks/session-start.sh` installs Godot 4.7.2 + Linux templates (/opt/scrapkeep-toolchain, GODOT_BIN set), Blender 5.2.2 LTS via the PyPI `bpy` wheel (download.blender.org is blocked; `scripts/cloud/blender` shim on PATH), and npm ci. ~70 s fresh, ~2 s cached. No network setting change was needed.
- Cloud runs: sketch:smoke/gate, bot runs, `node scripts/cloud/export-headless.mjs --win-proof` (test build, no stems/boss smoke), Blender recipes (GLBs byte-identical), Cycles CPU.
- Still Andrew's machine: real `sketch:export` (ACE stems gitignored + Vulkan boss smoke), Eevee/Vulkan captures, ACE-Step music, playtests. Container: 4 vCPU, 15 GB RAM, ~30 GB disk, no GPU; win proof ~5.6 min per seed.
- Full gate in cloud (2026-10-17): ~2 h, 722 pass / 10 fail. 3 audio fails fixed by PR #21 (worker pool override.cfg). Cloud-only false fails: item_fuzz_smoke (contention), park_swap (frame budgets), tree_play/alpha_bot_sweep/alpha_posture_bands_w23 (child timeouts), persistence_truncation (runs as root, chmod ignored). scatter_rows hash mismatch unresolved. Keep the full gate on his machine.
- **How to apply:** route headless engine/Blender work to cloud threads; GPU and feel work to his machine. See [[scrapkeep-alpha-scope]].
