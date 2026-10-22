# Scrapkeep decisions register

The one place to check what Andrew has decided. Each row gives the ruling that stands now, when he made it, how (card tap or typed line), and what it replaced. Times are UTC. Newest ruling wins; replaced rulings sit in the last section.

Owner: the "Project library and lessons learned" thread. Andrew's readable copy is the Claude Doc [Scrapkeep decisions register](https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9); this file is the copy other threads read and diff. Both change together. Conflicts with older records (Andrew's local folder, docs/decisions.tsv) are listed in [RECONCILE.md](RECONCILE.md) by the "Reconcile past decisions" thread and folded in here. A conflict with no clear later ruling goes to the design questions page, not here.

Sources: project chat card taps and typed lines (16-17 Oct), project memory, alpha-status/queued-cards.md. The machine's own register is docs/decisions.tsv in the repo (1,000 rows since Sept; 55 rows added at wave 15 close).

Last updated 2026-10-21 21:10Z by the local coordinator (coordinator back on the PC for waves 18 to 21, whole-rect stamped rows are ground, #240 tip timing; earlier: single wave 21 playtest, local coordination with 4 cloud lanes, authority restated, escalation ladder; earlier: Instant, 0.11 s later for Rivet Breaches; earlier: Smooth, 0.11 s, Spread every Breach, Keep the carry, #73 to wave 17, All hands detail, Soft toy, Beat later, sinkhole glazed walls, Polish everything, Promote fast).

## Direction (standing principles, not single rulings)

| Principle | When |
| --- | --- |
| Intent everywhere: every park, level and moment gets the care of the first one. World 1 is not front-loaded as trailer bait. | 17 Oct 19:54 |
| Enemies are unique to their world, never rehashed and never gimmicks. They build on the core verbs (roll, ram, grapple, carve), and later worlds are harder remixes as the pilot grows. Worlds 2 and 3 get the focus now. | 17 Oct 19:52 |
| Every idea is a motif, placed deliberately and in harmony, not spread evenly. | 17 Oct 19:37 |
| Chaos you can learn: many attackers, fair and readable, difficulty scaling to player power, like Isaac, but never so far that it cancels out a nutty build (see Overpowered pays). | 16 Oct 23:44 |
| Overpowered pays: strong builds and lucky runs are never punished; an insane setup or plain luck always earns a reward. The "Reward overpowered builds" thread audits against it; any recorded rule it wants to change goes to Andrew as a card first. | 17 Oct 21:55 (typed) |
| Items and actives go broad and deep: tiers, actives (rockets, lasers, force; magic-like but explained in-universe), elemental affixes, weapon overrides, and families by maker, zone or race with collectible sets. His examples (Zaun/Piltover, Borderlands makers, Isaac Mom/Guppy sets, Brimstone) model ambition only; never copy them on the nose. | 17 Oct 21:57-22:01 (typed) |
| Discovery and collecting are the long-term pull: secrets, unlocks, hidden tunes, lore found over runs. | 17 Oct 17:10, 19:50 |
| The Mind is a through-line from the first world onward. | 17 Oct 19:50 |
| A playground that makes you smile: melodrama that winks; energy and switch-ups over tidy theory. | 16 Oct 22:15; 17 Oct 15:59 |
| Stay consistent with himself: one register, newest ruling wins, nothing re-decided without new information. | 17 Oct 19:46 |
| Claude runs operations at full speed with standing merge authority; Andrew is the vision stakeholder, brought design calls early and often. | 17 Oct 19:41 |
| After alpha (parked until the sitting): monster origins, park societies, pilot personality and design tweaks, richer world transitions, alternate worlds or paths, world mutations as new game plus. Roadmap ordered by what to add, not dates, towards a beta or low-cost public release. | 17 Oct 19:48-19:50 |
| Polish everything: bake models and use denser polygons where frame times allow, so nothing reads as spheres tacked together, and tie animation keyframes into smooth blends. Covers terrain, map objects, interactables, particles, enemies and bosses. Every choice carries intent; a joke must still mean something. Work splits into code-side and Blender-side threads, as much as possible in the cloud. | 18 Oct 00:04 and 00:06 (typed) |
| Promote fast: don't hold back promoting to main. Work stays roadmap- and wave-based with short waves, each promoted promptly; open PRs roll to the next wave instead of blocking it. Fail fast in testing and red teaming, and tighten verification loops to move faster. Project management is Claude's call. | 18 Oct 00:08 (typed) |

## 1. Goal and acceptance

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Ship a finished-feeling Linux alpha by wave 21: opens from the app menu to a normal main menu, plays title to the end through all three worlds and six dressed parks. | 16 Oct | typed, project goal | "Complete the full game in alpha" |
| Accepted at Andrew's playtest sitting: 11 areas marked, none "Not yet"; no open blocker; frame times in budget; zero placeholders. | 16 Oct | grill-me, typed | stranger-installs goal with five first-timers |
| Five first-time players are no longer required. The sitting alone is the gate. | 17 Oct 16:35 (tap "Drop it"), 16:38 typed | card + typed | "five first-time players reach the end of world one" |
| After the sitting: story, lore, characters, boss and system tweaks come from the "What to change" table. | 16 Oct | typed | |
| Verdicts are recorded on the Sitting Kit page, not typed into the playbook. | 17 Oct 16:41 | built by thread | playbook table |
| Build all six never-started systems before the sitting (adds about a wave). | 16 Oct 21:41 | tap "All six" | |
| Camp is back in scope; AppImage plus app-menu entry; gamepad optional. | 16 Oct | grill-me | wave 18 camp cut |

## 2. How Andrew is involved (working rules)

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Claude owns engineering, design execution and project management; Andrew is the stakeholder for taste, trade-offs that change what he gets, approvals and alignment checks. | 16 Oct 21:26-21:27 | typed | |
| Phone first: every decision is a card in the project chat, at most three open; anything to look at is a phone page. | 16 Oct 23:35 | typed | in-thread questions |
| No approvals inside threads; all approvals reach him in the project chat. | 17 Oct 16:30 | typed | |
| Standing merge authority: the coordinator may close and merge done PRs, including to main, delete branches and do git housekeeping. Design and taste still go to him, early and often. | 17 Oct 19:41 | typed | merge cards; a typed line for each main push |
| He green-lights anything operational in development; maximise speed. | 17 Oct 19:41:35 | typed | |
| Cloud threads may edit src and assets on their own branches and gate them in the cloud; his PC keeps GPU checks and the merge. | 17 Oct 16:36 tap, 16:38 typed | card + typed | "the machine owns src/" |
| Push each finished wave to GitHub main at wave close. | 16 Oct 22:05 | tap | |
| Ambition paradigm (altitude, depth, range) adopted; speed pillar added. | 16 Oct 22:17; 17 Oct 16:33 | taps, typed | |
| Every idea he gives is a design motif to carry through the game deliberately, not a one-off. | 17 Oct 19:37 | typed | |
| Overnight, maximise compute: 4080 for gate and music renders, cloud for CPU work. | 17 Oct 03:34 | typed | |
| Allow-list routine, reversible commands in Remote Control sessions. | 17 Oct 03:36, 16:30 | typed | |
| One full playtest at the end of wave 21, the alpha release; no wave 19 feel check and no per-wave play asks. | 18 Oct | typed, local coordinator session | wave 19 feel check (17 Oct 22:12) |
| Coordination moves to a local Claude Code session on his PC. Heavy work runs in Claude Code cloud sessions that act as lane sub-coordinators and fan out their own agents and workflows; at most 4 cloud lanes at once (Gate + staging, Systems, World, Perf). The coordinator keeps the workflow graph (project-guide/coord/GRAPH.md) and test dependencies in sync. Hardware must never be the bottleneck. | 18 Oct | typed + structured answer "4 lanes" | claude.ai project threads (other account) |
| Standing authority restated for the local coordinator: merge gate-passed PRs into the stage, merge the stage PR into main, push stage/cand/scratch branches, git housekeeping, without asking. | 18 Oct | structured answer "Yes, all of it" | continues 17 Oct 19:41 |
| For the 20 Oct baseline only, a cloud session holds the coordinator role: it stacks gate-passed PRs onto `stage/alpha-w17`, promotes #116 to main, closes PRs already in the stage and cuts `stage/alpha-w18` (project-guide/coord/BASELINE-2026-10-20.md). The PC coordinator resumes after. Spend about $20 to $30 of credits now and hold the rest for lanes after the 22 Oct weekly reset; Sonnet wherever possible, Opus only on the promotion gate. | 20 Oct | structured answers in the baseline session | |
| Waves 18 to 21: the coordinator role returns to the local session on his PC (the 20 Oct cloud holder was for the baseline only). The wave 17 cloud lanes are reused as wave 18 sub-coordinators by direct message, with the Wave board on issue #241. Systems takes the Systems B units, and Life stays parked in wave 18 (cut candidate 1). Plan: ROADMAP.md. | 21 Oct | plan approved in the coordinator session | 20 Oct cloud baseline coordinator |
| Escalation ladder: agents ask their lane coordinator, lanes ask the local coordinator proactively, and only escalations reach Andrew, as stakeholder pitches (context, options, recommendation). While he is away he answers by phone through decision cards. | 18 Oct | typed | |
| Docs and rulings are synced, and ownership agreed, before lanes split into worktrees; every lane keeps the ambition ethos and LESSONS.md ways of working. | 18 Oct | typed | |

## 3. Tone and story

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Playground tone: anime and comic-book presentation, Scott Pilgrim touchstone, melodrama that winks back. | 16 Oct 22:15 | typed | |
| "Anime" means the genre's tropes, not East Asian instruments, scales or motifs. | 16 Oct 22:19 | typed | |
| Written lore stays dry crew-log voice; melodrama lives in camera, captions, cards and music. | 16 Oct | ruled on tone bible | |
| Title rotation: first launch is Sable's opening; then pilots and worlds on theme A; each met boss on theme B; theme C scores run summary and ending. Title C is take 1. | 16 Oct 23:41 | tap "Take 1" | |
| Replace the old park lore with the new draft. | 16 Oct 23:40 | tap "Replace" | old park lore |
| Lore notes collect over runs: 7-17 per zone, about seven per run, codex fills over several runs. | 17 Oct 16:36 | tap | |
| Waking and Mind intro lines: the approved dry crew-log lines. | 17 Oct 16:36 | tap "Approved lines" | |
| Camp pet: a retired drone Moss rewired ("Pet. One. Unpaid."). | 17 Oct 01:49 | tap | |
| Comic words on enemy hits stay as built. | 17 Oct | coordinator default, no card | |
| The Mind first shows itself in the Spillway as a musical quote. | 17 Oct 22:12 | typed, design questions |  |
| Every run ends as a comic page, collected in a camp scrapbook. | 17 Oct 22:12 | typed, design questions | the plain run summary |
| The camp reacts to the last run with one dry line. | 17 Oct 22:12 | typed, design questions |  |
| Pilots are characters you can relate to, not just balls: each climbs out for two bars (about 3.7 s at 129 BPM), does one signature bit, hops back in. Sable balances on top while it rolls; Rivet leans on it facing the wrong way, then turns, surprised; Kest hovers too long then drops (BOOM); Tarn sits on top while the machine growls; Tally stamps it PAID three times; the Cannon rises very slowly and waves once. Plays in each pilot's title opening, on the title deck (one pilot every 11 s) and on pilot select cards at rest (every 9 s, staggered). Look closer: right-drag or right stick orbits the pilot on title deck and select card, wheel zooms, view drifts back. Bosses get no hop-out; their name card frames closer. Follow-up to PR #20 (branch claude/title-pilot-antics-2hl55w). | 17 Oct 23:38 | typed (the ask); coordinator defaults, no card: six distinct moves, both screens, lighter bosses | |

## 4. Music and sound

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Gritty steampunk-cyberpunk with house, jazz in the writing; melody first. Combat 129 BPM, roaming and show opening 172 BPM. | 16 Oct | typed | |
| Combat and bosses: Scott Pilgrim evil-ex battle energy with Roboquest production. | 16 Oct 22:26 | typed | |
| Hype rule: bosses get electro/Eurodance, 808s, bass and catchier versions of existing melodies; dip under warnings. | 17 Oct 01:37-01:39 | typed | |
| Eurodance boss versions play in the final phase only. | 17 Oct 01:45 | tap "Last phase" | |
| Current jazzy tracks are the picks. Themed retakes are alternates only. Work is mix, master and spice-up. | 17 Oct 15:59 | typed | "Written themes" (03:24) |
| Never toss existing tracks; a new take replaces one only if he picks it by ear. | 17 Oct 03:26 | typed | |
| Build the main theme up across the run to the ending. | 17 Oct 03:24 | tap "Build to ending" | |
| Roaming music ramps with speed: groovy and jazzy, drums and bass build as you go faster. | 17 Oct 16:21 | tap | |
| Camp, run-loss summary and ending stay lighter. | 17 Oct 16:21 | tap | |
| Fill every gap with per-place and per-moment variations of current motifs, plus hidden tunes to discover. | 17 Oct 17:10 | typed | |
| Camp jukebox: blank records hint where to find their tune. | 17 Oct 17:46 | tap "Hints" | |
| Extra sounds: all four ideas from the soundtrack page (crowd cheer on long chains, sour sax honk on a whiffed smash, and the rest). | 17 Oct 01:36 | tap "All four" | |
| Hit sound within 5 ms; musical answers land on the next beat. Drums follow speed, sax enters with combo. | 16-17 Oct | integration plan | |
| Each special enemy has its own presence loop, wind-up tell synced to the visual tell, and death sting. A missing cue is a placeholder at the wave 20 check. | 17 Oct 00:45 | typed | |
| In-game radio on the pilot HUD (GTA/Cyberpunk style): switch or auto-play, playlists, an off switch. Songs are collectibles, the best behind the hardest challenges and special places. Many jazz takes on the same melodies with electro, bass and machine layers as surprises; make more than we need. | 17 Oct 20:02 | typed; radio thread | |
| Wordless vocals on the radio only: six takes get choir pads and chopped vocal sounds, never words; the game score stays vocal-free. | 17 Oct 20:52 | tap "Radio only" | |
| Warden fights take over from the radio with their own score, like bosses, unless a track is pinned. | 17 Oct 20:52 | tap "Warden takes it" | |
| Radio cache spots reward harder reaches with bigger tracks. | 17 Oct 20:52 | default, no card | |
| A boss's Eurodance final phase always plays, even over a pinned radio track; the pin comes back after. Pins win everywhere else. | 17 Oct 20:52 | tap "Finale wins" | |
| Hitting on the beat pays off in sound only, with no gameplay bonus. | 17 Oct 22:12 | typed, design questions |  |
| Pilot radio: the music thread picks the better of the two renders for each of the 81 takes and notes why; Andrew hears the picks at the sitting and can swap any. | 17 Oct 22:28 | tap "Music thread picks" | |
| Percussion serves the song: melody leads, and drums support it the way a band's drummer does. No take may spend most of its length with drums dominating the melodic parts. At most 2 drum-forward takes ship, as labeled genre pieces whose drumming is dynamic and engaging. The Heat station was a miss (Brindle Afterburner the worst); Moss's Backroom was right. Fixes go cheapest first: the other render, then a stem rebalance, then a melody-led re-render. Owner: the music session. | 19 Oct | typed, after hearing half the radio | |
| Radio quality pass: every take is scored on melody, arrangement, percussion share, mix, master and story fit. A take that fails is composed before it is rendered: a written brief names its story moment, its feeling and a motif in the world's key, and a reviewer checks the brief against the tone bible. Then come 6 or more renders, the best 2 mixed and mastered from stems, and 1 picked with a reason. Takes that pass still get the mix and master pass. Meaningful melodies that capture a visceral moment come before speed. Renders run on the 3060 so the 4080 stays free for frame timing. | 19 Oct | typed, "some of them just sound really sloppy" | "the music thread picks the better of the two renders" (now one step inside the pass) |
| Radio quality pass, amended: every song in the game is audited, not only failing takes, on three added axes. **Melodic development:** the motif returns changed (varied, extended, answered, re-harmonized or modulated), and the melody's range or rhythm grows across the song instead of looping one phrase. **Arc:** across its 2 to 3 minutes the song builds through distinct sections to a peak and a resolution, with energy, density and harmony changing on purpose. **Coherence:** no audible seams. Edits land on phrase boundaries, layered parts share one tempo, key, groove and room, and a song generated in pieces or with an overlaid part must pass a seam check before it ships. A take fails on any of the three and goes back through the composed-brief path. | 19 Oct | spoken, "a severe lack of [progression]", "they sound still like stitched together", "it's not very coherent" | extends the radio quality pass above |
| Intense music is an anthem: every mini-boss, boss and intense event gets a high-energy, bass-heavy EDM anthem written for that fight or moment. References: Swedish House Mafia, Avicii and Basshunter. The hook is a singable lead melody, with a big-room build, a drop and a second, bigger drop, which is also the song's arc. Twists are welcome (jazz harmony or horns, Latin rhythm, mixtures) as long as the anthem stays recognisable. The percussion ruling still holds: kick and bass carry the weight, and the lead melody stays on top. Roaming music keeps its jazzy groove. | 19 Oct | spoken, "anthems for the situation it ties itself with", "bassier EDM style vibes" | replaces "current jazzy tracks are the picks" (17 Oct) for boss, mini-boss and intense-event slots only |
| Theme C (the show-opening title song) plays on a won run's summary and on the ending; a lost run keeps the jazz-club summary track. Owner: the music thread. | 17 Oct 23:24 | tap "Won run and ending" | theme C on every summary (brief) |

## 5. Enemies and difficulty

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Loves chaos: many attackers, but learnable and fair with time to read. Difficulty scales with player power, like Binding of Isaac. | 16 Oct 23:44 | typed | |
| Attacker budget starts at 6, +1 per heft class, +2 per world, cap 12 late Highdraft. Bosses are never limited. | 16 Oct 23:43 tap "Six"; SQ2 design | tap | |
| Warnings never within 0.2 s between packs or enemy kinds; one pack's warnings start together. | 17 Oct 15:30 | tap "Pack as one" | every warning 0.2 s apart |
| A grown pilot clears hives at least 2x faster than a small one. | 16 Oct | recorded rule | |
| Big tough enemies first stagger in about 45-70 s under line hits and rams, for ordinary pilots. Amended 17 Oct 22:04: monster builds may break sooner (next row). | 17 Oct 15:34 tap, 19:42 typed "yes, 45 to 70 s" | card + typed | slow-filling stagger bar |
| Monster builds stagger Wardens faster: hits count up to 3x plating (was 1.5x) and the ultimate fills up to 70% of the stagger bar (was 45%). Ordinary pilots still take 45-70 s. | 17 Oct 22:04 | tap "Lift the ceiling" | amends the 45-70 s rule |
| Warden posture follows each fight's own stage page. For ordinary pilots, the stage 3 hive Warden holds 60-85 s before its first stagger (out of ram reach 8 s in every 12); the sinkhole Warden and the Mind hold 45-70 s. Overpowered builds still break them faster. | 17 Oct 22:32 | tap "Per Warden" | refines "Stage-page timing" (15:34); the hive is outside the 45-70 s band |
| Kill-first enemies: all four (Foreman, Dispatcher, Splitter, Linker), Left 4 Dead 2-style specials. | 17 Oct 00:01 | tap "All four" | two specials |
| Dispatcher: each unanswered drop comes faster and lands a tougher add (chaser, hooker, brute). | 17 Oct 19:33 | tap "Escalate" | |
| Splitter chases you and keeps splitting; you find and kill the "mama" that is making the fuse mechs. | 17 Oct 18:19 | typed (card withdrawn) | |
| Bad matchups: counter items show up 1.5x as often; still luck. | 17 Oct 00:01 | tap "Nudge loot" | |
| Relay risk stack: in two parks (Spillway dam and Highdraft), stake 0-4 times. | 17 Oct 16:37 | tap | |
| A stacked relay never goes over the stage budget; minibosses count. Bigger stake means more waves and a longer fight. | 17 Oct 17:46 | tap "Budget holds" | |
| New motifs to place: world-themed enemy mechanics, areas that test one skill, armour weak by damage type, enemy buff/debuff zones (e.g. a stunning electric field), pilot cast times. | 17 Oct 19:35-19:37 | typed | |
| Electric fields jam: casts, charges and specials drop and lock for 0.5 s; the ball keeps full speed. | 17 Oct 19:56 | tap "Jam" | |
| Cast times on big abilities only: Q keeps its 0.35 s interruptible wind-up, stronger Q variants 0.5-0.8 s, Gather Plate 0.3 s; small moves stay instant. | 17 Oct 19:56 | tap "Big ones only" | |
| Spillway's eight never-spawned enemies: netcaster re-homed to the Highdraft, catch trap to the Dig, each reworked; the other six stay out. | 17 Oct 20:03 | tap "Re-home a few" | |
| The Dig's skill is carve and drop: floor threats can't reach a carving ball, so the wall is your safe place. | 17 Oct 20:03 | tap "Commit" | |
| Highdraft heavies barely take damage but die to one knock off an island edge, Smash Bros style. | 17 Oct 20:03 | tap "Ring-outs" | |
| The 0.2 s warning gap holds everywhere, including the first Warden; there the growth target becomes 1.85x, and hives keep 2x. | 17 Oct 20:11 | tap "Gap wins" | 2x at every Warden |
| Hive defenders skip the attacker budget, so a pilot who sits back and shoots gets the whole crowd. Budget exemptions now: Foreman, Linker, hive defenders and bosses; Dispatcher chasers still count. | 17 Oct 20:52 | tap "Swarm campers" | a rare lucky break from range |
| Near a live hive, defenders also skip the 0.2 s warning gap, for every pilot, so their wind-ups can stack. This is a deliberate exception to "Gap wins"; the gap still holds everywhere else. | 17 Oct 21:19 | tap "All at hives" | 0.2 s gap at hives |
| Ranged-only pilots are not blocked from finishing a hive. The rare lucky ranged break (about 1 seed in 16, 222 s) stays in, and Andrew judges it at the sitting (it is on alpha-status/sitting-watch-list.md). | 17 Oct 21:55 | tap "Leave it" | |
| The Dispatcher keeps its escalation cliff and gets judged at the sitting; the Foreman stays out of the Highdraft. | 17 Oct 20:52 | default, no card | |
| Each world owns one mechanical theme: the Spillway Flow, the Dig Plate, the Highdraft Wind. | 17 Oct 22:12 | typed, design questions |  |
| Resistances lean but never wall a build off. | 17 Oct 22:12 | typed, design questions |  |
| The player learns an enemy's weakness on the first hit against it. | 17 Oct 22:12 | typed, design questions |  |
| Hard but fair, Souls-like: bosses must be learned, and you win by using your kit. A cracked build earns its steamroll, but skill still matters. Parks, mobs and events go up a notch too. Extra hardness that would be too much at base moves into the replay difficulty ladder. | 19 Oct 01:58 | typed | "Brindle is beatable every time" now means for a skilled player (Expert band), not every player |
| Skill bands measure it (coordinator call under the ruling above, on the veto list). Bots play at three skill levels. Novice: late reactions, misses many tells, basic attack and ram only. Learner: reads most tells, uses the base kit, and improves across attempts at a boss. Expert: fast reads and the full kit (actives, carve, harpoon, wall grip, ultimate timing). Base-tier targets with an ordinary build: bosses and Wardens beat Novice in at least 85% of attempts; Learner wins 15-35% on a first attempt and 60% or more by the fifth; Expert wins 85% or more; a top-decile (cracked) build with an Expert wins 97% or more and keeps the existing growth ratios. Every lethal attack has a readable tell of at least 0.6 s, and no boss kills a Learner in its first 45 s. Parks: Novice reaches the world's Warden in at most half its runs, Learner in 80% or more. Difficulty comes from boss damage, attack patterns, combos, punish windows, extra phases and mob aggression; the stagger timing, attacker caps and warning-gap rulings above stay. The HARD tier becomes a ladder of levels for replay, where Expert with an ordinary build wins about half the time at the top. | 19 Oct 01:58 | coordinator call, veto list | - |
| Learner attempt 1 is graded as information only at bosses and Wardens; the Learner band counts everywhere else. Wardens must be able to reach the pilot: Warden contact goes into placement or the director, so a Learner on attempt 1 loses hull within 45 s on Wardens 2 to 6 (World-2 card, Challenge measures). Replay ladder: pilot dials such as regen rate are allowed from ladder level 5 up; tiers 0 and 1 stay byte-identical. | 19 Oct 19:00 | coordinator call under the skill bands, on the veto list | Learner attempt 1 as a graded band at bosses and Wardens |

## 6. Movement, combat feel and power

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| 3D space as a jungle gym: grapple tricks, ball downforce and half-pipe carving, maps and enemy placement built around them. | 16 Oct 23:49-23:50 | typed | |
| Wall grip: sticks automatically above cruise speed, peels off when slow, on/off toggle for the sitting. | 17 Oct 00:15 | tap "Speed holds" | |
| Ball speed soft cap: past 60 m/s becomes hit damage and a blazing trail, not more speed. | 17 Oct 07:17 | tap "Soft cap" | uncapped |
| Bowling hits throw up to about 36 m. | 17 Oct 16:51 | tap "Pinball" | |
| Pole or flail is decided by weight: lighter orbits, heavier swings the enemy. | 17 Oct 16:33 | tap "Weight" | |
| A grown ball rips bolted turrets out and swings them. | 17 Oct 16:33 | tap "Rip them out" | |
| Late runs read clearly mightier through presence: hotter colour, bigger comic words, ink edges and aura; burst size unchanged, warnings always on top. | 17 Oct 17:28 | tap "Presence, centre clear" | "Clearly mightier" (3x size, 16:36) |
| SPIL-9 grows with each module seated and gets a signature assist, called by the next ram when its gauge is full. | 17 Oct 16:36, 16:44 | taps "Grow SPIL-9", "Next ram" | |
| Keep the harder head-on bounce in the pipe vault. | 16 Oct 23:37 | tap | |
| Keep wave 13 combat defaults, wave 14 tuning and all six wave 15 gameplay changes. | 16 Oct 23:40-23:41 | taps "Keep all" | |
| Element fusions merge; a second status on a marked enemy means it already holds an SG2 status. | 17 Oct 03:33, 15:31 | taps | |
| Three-level parts on three neutral parts only. | 16 Oct 23:40 | tap "Keep three" | |
| New item layer before the sitting: all six actives (Scrap Rocket Rack first) and maker sets on the existing 61 items; weapon overrides and evolved forms after. Page: [Makers and Actives](https://claude.ai/artifact/38Drb12GsPgDxmgDUt6TWW). | 17 Oct 22:04 | tap "Core now" | |
| Whether a cast keeps the ball rolling depends on the pilot. | 17 Oct 22:12 | typed, design questions | cast on the move for every pilot (default) |
| The game is a pinball machine with a pendulum: the grapple is everyone's mobility (swing, fling, rebound), and reel-in is a gap closer, separate from each pilot's slam. An air slam (jump, then slam: a dunk) stores its slam damage, and the next reel impact spends it on what the line bit. Reel-in impacts are the key to weak points: boss buttons, hatches and seams (Shadow of the Colossus), and weak spots on robots. Coordinator calls (veto list): pilot slams keep their own flavours and all feed the same dunk charge; boss weak points are crew-built maintenance parts (service hatches, override buttons, seam plates), consistent with "All hands"; weak-point posture is the boss-fight length lever in U4. | 21 Oct | typed | |
| "Overpowered pays" (#222): a build is a monster at a Warden only when its heft is above the top of what library builds bring to that Warden, measured at Warden arrival; thresholds are generated from library data and pinned by a test. Stage 6's park Warden and any Warden without a threshold fail closed (no lift). Acceptance: Warden fights in band, monster builds break faster, ordinary pilots at the first two Wardens no faster. | 21 Oct | coordinator, creative charge (veto list) | "above class V" (21 Oct, earlier same evening; V is the top class) |
| Dead offers go even for a full kit: once kit parts are stacked to the cap, the shop offers off-kit parts. The offer bars move to match: greedy-bot kit share floor 0.55 (was the 0.60 band), alpha overlap at most 0.50 (was 0.40). A "17 Oct 22:54Z" ruling cited in #222's code was not found in any record or session, so this row is the ruling the code cites. | 21 Oct | coordinator, creative charge (veto list) | |

## 7. Bosses

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Bosses: Brindle (Spillway), the Waking (Dig), the Mind (Highdraft). Keys: menus/Spillway D, Dig E, Highdraft G. | 16 Oct | tone bible | |
| Fix the bot's Mind route rather than accept slower numbers; the 2x target stays. | 16 Oct 23:37, 17 Oct 06:16 | taps | |
| Brindle fix merged with the stage 6 bot fixes; Brindle is beatable every time. | 17 Oct 15:29 | tap | |
| Keep pre-boss exploration. | 16 Oct | storyboard ruling | |
| The Waking gets two or three attacks of its own, built on Dig enemies: burrow lanes, cave-ins and bore breaches. | 17 Oct 20:11 | tap "Give it attacks" | stub Warden plus floor drops |
| Each boss has one line for each pilot. | 17 Oct 22:12 | typed, design questions |  |
| An ordinary build at the Waking and the Mind is a library build as it arrives (heft class V). The fights reach 50 to 90 s through pattern and read-gated evasion, never by cutting the player's build. The Miniboss's fist keeps its visible elbow at the end of the slam crouch. | 19 Oct 19:00 | coordinator call, on the veto list | |
| #222 (Overpowered pays) is admitted against the 50 to 90 s Waking and Mind target as base-red and improved (Waking 21 to 31 s, Mind 17 s unchanged). The target stays. Boss fight length is Challenge's unit U4, its own PR with its own band table, using only pattern and read-gated evasion levers plus fixes for verified misconfiguration (for example a Waking gain inherited from the stage-4 row). No player-build cut, no enemy health change. | 21 Oct | coordinator, creative charge (veto list) | |
| Why the Mind is a hand: "All hands". The crew called it the Mind because it did the thinking, and they were its hands. With the crew gone, it grew its own hands to keep their jobs going. Shown through gloves and crew numbers 04-01 plus FOREMAN on its fingers, one finger curling shut per phase, a glove set by the empty place on defeat, a HIRED stamp on its victory screen, and crew-log plants from the Spillway onward. Page: https://claude.ai/artifact/Trhb9ecLx1cDN3NYzFisJc | 18 Oct 00:16 | tap "All hands" (not picked: Hand signs, Maker's hand) | PR #113; mesh by "Smoother, more detailed models" |

## 8. Parks, landmarks, camp and art

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Storyboards before building. All five calls made: camp hub ring; Hanging Isle moving tip; headframe legs solid; sinkhole full ring; spire 30 m waist. | 16 Oct 21:41, 22:38 | taps | 48 h veto window (void) |
| Sinkhole pool is a 20 m bowl the player can see. | 17 Oct 02:37 tap, 15:31 typed | card + typed | flat basin |
| Stage 5 hand stays lowered, with a tether added in island dressing. | 16 Oct 23:37 | tap | |
| Placeholders: tunnel mouths, half-pipe edges, kickers and caverns get real pieces; plain banks, mesas and drops count once ground and scatter are on. | 17 Oct 06:16 | tap "Ride lips only" | a model for every slope |
| Asset-forge test pieces stay out of the game. | 17 Oct 17:02 | tap "Keep them out" | |
| Placeholder check warns only until wave 20, then blocks exports. | 16 Oct 21:45 | tap | |
| First landmark board looked confusing; others approved, more bake rounds allowed. | 17 Oct 02:57 | typed | |
| The Highdraft gets its own people before the sitting: a Fleet mooring crew and the net-weavers in the islands and the crown, with no new systems. | 17 Oct 20:11 | tap "Now, light" | |
| Every world has a pilot rescue: a cage on the Highdraft's sky islands joins Rivet's and Kest's. The parks had no cages yet, so Rivet's and Kest's are being added to the dam and pit on PR #40. | 17 Oct 20:12 | tap "Rescue on the isles" | rescue only at the Mind |
| Each park tests one skill. | 17 Oct 22:12 | typed, design questions |  |
| The light changes over a run: one day, dawn in the Spillway to dusk at the Mind; the Highdraft gives up its morning light. | 17 Oct 22:12 | typed, design questions | fixed light per world |
| The game ends with a 60 s free roll around Meteor Crater. | 17 Oct 22:12 | typed, design questions | a closing camera shot on the crater |
| Highdraft: the full-width mesa edges count as ground, not ride lips; they get scatter, and the mesa silhouette is the shaped ground itself. 18 edges, about 29 km (the card said 21 and 34 km by mistake). Narrower lips (fin nose, lookout) still get ride pieces. | 17 Oct 22:29 | tap "Edges are ground" | refines "Ride lips only" |
| Any stamped greybox row whose cross size spans the whole play rect counts as ground, not only kickers. This adds the islands rows `slickrock_run`, `fan_band`, `net_carve` and `isle_apron` (`park_map.gd` `mesa_edge`, `placeholder-gate.mjs` `MESA_EDGE`). `cloud_wash_west` ships as a full-coverage sheet, and `fin_chute` stays greybox. A whole-row sheet at the 0.12 m band would cost 136k to 283k tris against the 8k landform cap. | 21 Oct | coordinator call under "Edges are ground", on the veto list (World NEEDS on #149, option a) | - |
| Sinkhole: carving the tube walls is the safe, fastest line, like a skate bowl's coping. Ropes and geysers move onto the walls; the floor is slower and bites. (Pilots carved only 2-3% of the time there before.) | 17 Oct 22:37 | tap "Wall pays" | refines "one skill per park" (the sinkhole tests carving) |
| Sinkhole floor is lava, briefly: touching the floor is free, bowling through foes or quick zigzags are fine, but lingering does slow damage. Built (PR #102, src/world/cinder_heat.gd, all constants): first 1.5 s on the tube floor free, then 4 hull/s in 0.5 s pulses, stopping at 1 hull (never lethal); timer resets on leaving the floor or landing a hit; tell is cinder glow, a sizzle as the burn starts, a hiss and steam puff on leaving; light floor drag 0.08 stays (heat alone tied floor and walls at 100 s); no cinder in the lava channel. Owner: "Sinkhole park authored pass". | 17 Oct 23:24 | typed (answers the sinkhole card, withdrawn) | Cinder floor drag as the main fix |
| Glazed tube walls: the sinkhole's polish band is lava glass that pays a carver, a push of 7 m/s/s along the direction of travel between 4 and 36 m/s (PR #102, head 52368195). Every carving line beats the floor route for ground pilots. On the sitting watch list for your feel check. | 18 Oct 00:29 | coordinator call under "Wall pays", not a tap | - |
| Sable is exempt from Wall pays as a flyer: its airborne line counts as its own route in the sinkhole. On the sitting watch list for your feel check. | 18 Oct 00:29 | coordinator call under "Wall pays", not a tap | - |
| Soft toy models: crews and round bodies (bulbs, domes) go smooth, while machines keep crisp edges with rounded bevels. Bold comic silhouettes stay everywhere, and the 4080 checks frame cost before anything ships. The art brief is now "chunky, bevelled, smooth". Page: https://claude.ai/artifact/AX8GHjV8tbvMvaJTyNJGpZ | 18 Oct 00:40 | tap "Soft toy" (not picked: Crisp only, Sculpted) | "low-poly, chunky, flat colour" brief |
| Flume park butte gap stays open: the momentum line breaks at the butte, and you carry your speed about 90 m across the open canal floor into the next trough's flared mouth. No bridge; the gap stays a landform moment. | 18 Oct 03:09 | tap "Keep the carry" (not picked: Bridge it) | - |
| Lived-in parks: every park reads as lived in or run down, with far more prop variety and a natural, clustered look (vignettes, not an even scatter), and ambient life (critters, locals) that shows people were or are there. Detail budget goes up: hero assets up to about 20,000 triangles at LOD0 with LOD1 and LOD2; small props 300 to 3,000. Ambient life never reads as an enemy, a pickup or a target, and dressing keeps ride lines and telegraphs clear. The 4080 checks frame cost per park. Built by the Dressing and Ambient life cloud lanes. | 19 Oct 01:40 | typed | sparse dressing |

## 9. Pilots, cosmetics and progression

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| 18 cosmetics; Kest's Rigger Harness cut. | 16 Oct 21:46 | tap | 19 cosmetics |
| Pilot paint via a shader tint on the dark Core frame. | 16 Oct 23:40 | tap | |
| Sable's Cable Stitch trail is deep green. | 16 Oct 23:22 | tap | mint |
| Rigger Blue is Homecoming's reward paint for Kest. | 17 Oct 00:20 | tap | |
| Tarn and Cannon ship on their current first-pass animations. | 16 Oct 23:40 | tap | |
| Merge pilot paint and 13 earned cosmetics into wave 16. | 17 Oct 15:32 | taps | |
| Tally unlocks by either path: free her from the Fleet's "INVENTORY" cage on the sky islands, or find three ledger leaves, whichever comes first. | 17 Oct 20:27 | tap "Either path" | extends the leaves ruling |
| Rivet's ultimate carves flat ground as one piece, so the scar shows fewer inner lines and stops freezing. Shape and hits stay the same, it must fit 60 fps, and bot replays may shift slightly at cut edges. | 17 Oct 21:30 | tap "Fewer lines" | exact carve with a 2-4 s freeze |
| Rivet's faster carves (PR #73, 40-60x faster, same shape and hits) merge once the 4080 shows the flat-ground carves under 16.7 ms. The curved-ground carve freeze (about 2.5 s, stage 2 camp) is a separate fix and must pass the same 4080 check before the sitting. | 17 Oct 23:22 | tap "Merge now" | refines "prove the worst carves fit 60 fps before merging" (still holds for the curved-ground fix) |
| Rivet's ultimate on curved ground: the crater and its hits land about 50 ms later, spread over a few frames, with the same shape and no freeze. Flat-ground landings are unchanged. This is the only case where hits may land late. | 18 Oct 00:41 | tap "Beat later" (not picked: Blockier crater, Leave it) | narrows "hits are never delayed" for this one case; settles the curved-ground freeze fix |
| Every heavy Rivet Breach, on flat ground too, lands its crater and hits about 55 ms after touchdown, spread over a few frames, with the same shape and no hitch. Full Cut stays instant (8 ms). The 4080 measured a flat Breach at 24.47 ms against the 16.7 ms budget. | 18 Oct 03:30 | tap "Spread every Breach" (not picked: Smaller Breach, Keep the hitch) | widens "Beat later" from curved-ground landings to every heavy Breach. Flat timing changed 18 Oct 05:46 by "Instant, 0.11 s later": flat Breaches and Full Cut hit instantly |
| On steep slopes, Rivet's Breach hits about 0.11 s after landing and every frame stays inside 60 fps on the 4080. Flat ground and on-the-spot Breaches keep the ~0.055 s timing. Measured: 1 slope Breach in 18 across three long runs had hit at 0.17 s. | 18 Oct 04:42 | tap "Smooth, 0.11 s" (not picked: Faster, 0.1 s; Keep 0.17 s) | refines "Beat later" and "Spread every Breach" for steep slopes. Deferred 18 Oct 05:46 by "Instant, 0.11 s later": now the target to return to, via #137 |
| Rivet's flat Breaches and Full Cut hit instantly, and slope Breaches land at about 0.18 s for now. Busy fights near the frame limit can show a small carve-frame bump (2-4 ms over) until the dense-fight cost work lands. "Smooth, 0.11 s" stays the target for slopes, to return to once dense fights get cheaper (#137). Measured: a dense fight leaves only 5-6 ms per frame on the 4080. | 18 Oct 05:46 | tap "Instant, 0.11 s later" (not picked: Keep hits instant; Every frame smooth) | defers "Smooth, 0.11 s" to a later target; flat Breaches now hit instantly instead of ~55 ms after touchdown ("Spread every Breach") |
| Pilots unlock on a ladder: new players start with Sable and earn the rest; Andrew's sitting profile opens all six. | 17 Oct 22:12 | typed, design questions | amends the fresh-profile ladder |

## 10. Release, gates and process calls

| Ruling | When | How | Replaced |
| --- | --- | --- | --- |
| Bug bar and 60 fps frame-time budget as written (PR #8). | 16 Oct 21:44 | tap | |
| Park-win proof is best of 3. | 17 Oct 02:10 tap, 02:13 typed | card + typed | single try |
| Wave 15 pushed with one bot proof known red. | 17 Oct 01:09 | tap | |
| Close the old audio workaround PR #21. | 17 Oct 15:32 | tap | |
| Replace the library's music docs with the newest versions, archive the old ones. | 17 Oct 01:49 | tap | |
| Memory sync to his PC is one-way and one-time. | 16 Oct 21:23 | typed | |
| The alpha ships a reduce-flashes toggle, without an assist mode. | 17 Oct 22:12 | typed, design questions |  |
| The alpha holds a few secrets back until the first win. | 17 Oct 22:12 | typed, design questions |  |
| All 81 radio takes ship for the sitting, and the sitting waits on the renders. | 17 Oct 22:13 | tap "Hold for all 81" (against the recommendation) | |
| Purpose before making, for all digital art and modeling (models, textures, lighting, grading, animation, effects, props). (1) Before making anything, the agent writes a purpose note in the plan and the PR body: what it is, why it exists in the game (the play moment, ruling or brief it serves), why it will work (readability, scale, budget, palette, telegraph clarity) and what it checked. (2) No guessing: every number, scale, style choice and engine or API claim comes from the repo, a ruling, a cited reference or a measurement; if unknown, research or measure first, or post a NEEDS. (3) Mistakes log: every caught mistake gets one line in `project-guide/handoff/ART-MISTAKES.md` (date, lane, PR, mistake, root cause, preventing rule); each unit reads the log first and its PR names the entries checked. | 21 Oct ~22:15Z | typed ("think logically about why something exists... no guessing allowed... make notes of every mistake") | - |
| Two standing review lenses, every wave, on parks, arenas, enemies, mechanics, spawning, construction and traversal. (1) Canon questioner: asks why and how each thing exists and works in-universe, against the Bible, creatively and out of the box. Places show how the society built itself around the nature of that site, and props, enemies and routes show the state of the place (lived in, run down, mid-event). (2) Bad-faith red team: plays to ignore or bypass systems on purpose. Quirky bad-faith play that stays fun and engaged is fine. A bypass that makes a system pointless ("why does X exist if I can skip it?") is a finding. Both lenses report to Andrew as purpose questions: what doesn't mesh, and the options to design so it flows with play, or to scrap it. | 21 Oct | typed | red team as gate persona only |
| The era: before they left, the humans were partway between a Kardashev Type I and Type II civilization, building at planet scale (terraforming rigs, orbital rings, space elevators, mass drivers, the start of a sun-harvesting swarm). That is why the machines are titan-sized. Space hardware is in scope: the Highdraft's cableways and launch rails can be the ground ends of elevators and launch tracks, and the Mind can sit in an orbital data centre. The backstory is a dystopian satire of the last 20 years of tech acceleration, told cheerfully: the plush crews stay playful and the ruins carry the dark story. Andrew's real-company mentions (Tesla, SpaceX) are conceptual analogies for the era, not brand references: the satire borrows the era's ideas (self-updating robotaxi fleets, reusable rockets and satellite swarms, delivery drones, warehouse robots, endless feeds and terms-of-service pop-ups, crypto rigs, data centres, "move fast and break things"). Where a company is shown, it is an original parody megacorp. Never a real company's name, logo or product name. | 22 Oct ~01:10Z | typed lore, then tap "Original parody megacorps", clarified as analogy | |
| Reference before making, for every digital asset class, big or small (models, rigs, animation, textures, lighting, grading, effects, UI, props, landmarks, mobs, bosses). (1) The approved concept boards in `docs/art/reference/` are the shared point of reference. Every art unit names the board(s) it builds from in its plan and PR body, and its purpose note says how the result matches them (palette roles, shape language, materials, scale to the pilot ball). (2) No reference, no build: an asset class with no board gets its board first, generated against the eight style boards and approved, then built. (3) Effort scales with scope: a one-off prop needs a board citation and a purpose line; a park, mob family, boss or event set gets a set brief that lists its members, the shared board, the shared rules (palette, silhouette, wear, scale ladder) and which lane owns which members, so a group of agents builds one family, not several. (4) Consistency is reviewed: the reviewer compares the result side by side with its board and the style anchors, and a drift is a FAIL with an ART-MISTAKES line. (5) Boards settle look only, not mechanics, scale numbers or collision; those still come from rulings and measurement. | 22 Oct ~01:50Z | typed ("make sure things are done purposefully and with art created beforehand... consistent point of reference... every facet and class of digital asset") | |
| Boards are grounded before they are built from: every gameplay idea on an approved board (UI, mechanics, mobs, neutral machines and their AI, areas, landforms, map flow, cycles) must trace to something in the game or on the roadmap. The record is `docs/art/reference/GROUNDING.md` (321 ideas: 167 in the game, 73 planned, 34 not grounded, 28 conflicts, 19 look only); the 13 new cards are in ROADMAP. Where a board conflicts with canon or code, canon wins and the board row says don't copy. Coordinator defaults on the owner calls, on Andrew's veto list: (a) the Waking's arena has a daylight aperture; (b) the Mind's override is the hand button per U4, and the cuff on the board is the hand enemy's cuff; (c) the splitter keeps ram-to-split as in code, and the board is labelled; (d) furnaces in the Highdraft show closed mouths and no amber emission, and arena rims carry no emissive lights, because emission is for facts; (e) the speed trail past 60 m/s keeps the heat ramp with a rearward streak in the pilot's class colour, not mint for everyone; (f) Cannon's ancient-green seams are an exception for Cannon's relic part only, recorded in VISUAL-LANGUAGE, and no other player part may carry green; (g) the lilac life band stays a proposal and the purple creature is reference only; (h) rogue machines, moving haul trucks, the delivery-drone hive, the cable tender span and the orbital seat are post-alpha. | 22 Oct ~03:00Z | typed ("make sure the suggestions on the mood boards are carried through from a gameplay perspective... ground all of those with something on the roadmap or something that exists already") | |
| The Mind's reach: it is a central intelligence powerful enough to control nearly everything, but not everything. A few machines run outside its control, and they become one-off random event bosses or known, triggerable Easter-egg events, at any class or tier of the enemy hierarchy (a standing OK to build these as hidden discoveries, per the mechanic-callback rule). Some animals fall into deifying and worshipping the Mind; Brindle's Fleet is the first example, so its digging to wake the fleet is devotion, which keeps Brindle "sincere and wrong" (TONE-BIBLE.md:41). The humans' folly and downfall was trusting something more intelligent and more capable than themselves with everything. | 22 Oct ~01:00Z | typed lore (exploring) | |
| Machine lore: the giant machines are the humans' construction, mining, manufacturing and utility fleet, built to work and still running after the humans left. The Mind is the fleet's foreman (its glove already reads 04, 03, 02, 01, FOREMAN) and turned part of the fleet into an army. Machines come in three kinds: corrupted ones are enemies, loyal drones are uncorrupted helpers, and looping workers keep doing their old jobs and are neither friend nor foe. Looping workers become the park's moving pinball parts (a haul truck on its route, a spillway gate on its cycle, a swinging crane), and a boss hatch may open on its machine's work cycle. The Waking is the Mind's buried excavator, and the swarm remnants (hive, brood) are its maintenance crew: when it wakes it calls them home in capped waves that fit seam plates over its weak points, and a reel impact on a fitting drone knocks the plate off. The plush animal crews get through a world of giants in gyrospheres that ride the machines' own rails, chutes and cableways. The ball stays the expanding Hoberman lattice husk that grows with scrap and heft, around a stabilised gimballed cockpit (18 Oct ruling). Replaces "pre-apocalypse war machines" in DESIGN-V2.md:214 for the reason the world fell; the Fleet's digging still woke them. | 22 Oct ~00:50Z | tap "Utility fleet, Mind as foreman" after typed lore | DESIGN-V2.md:214 war-machine origin |
| Difficulty is not a cut candidate: the skill-band targets in all six worlds and the HARD tier replay ladder ship for the sitting. A second Challenge lane takes worlds 4 to 6 and the ladder. | 21 Oct ~22:15Z | typed ("reach the game level of difficulty and challenge that I was expecting") | cut candidate 2, the replay ladder (ROADMAP 20 Oct) |
| Rivet's faster carves (#73) were taken back out of wave 16 because the park carve check couldn't fire a carve, so it proved nothing. The fixed version (10fdd831) rides in wave 17. "Merge now" still applies: it merges once the 4080 shows flat-ground carves under 16.7 ms. | 18 Oct 02:03 | coordinator call under standing merge authority, not a tap | #73 in wave 16 |

## Older rulings still in force

Rulings from 8 Sep to 16 Oct that nothing has replaced, found by the reconcile pass in decisions.tsv (row numbers), the Bible, the 2 Oct owner interview and the design docs. They still stand. A thread that wants to change one brings it to Andrew as a card.

| Ruling | When | Source |
| --- | --- | --- |
| **Run shape.** Three worlds in a row; every run starts in world one; one retry per world, spent only by death; 30-45 min; only unlocks carry over. Continue after a quit stays free. | 2 Oct | interview; tsv 153, 176, 213 |
| First win in three to five attempts. Normal difficulty tuned toward 3 of 5, hard steeper. | Sep, 8 Oct | Bible; interview; tsv 345 |
| Difficulty never raises enemy health. Run tier caps health at 1.6x and damage at 1.3x; Wardens excluded. | Oct | tsv 472, 805, 820 |
| Foreman and Linker take no attacker slot; Dispatcher chasers and Splitter pieces do. | 17 Oct 00:47 | tsv 992 |
| A fall below a map's net deck lands on the deck, never death. | Oct | tsv 231 |
| **Movement belongs to the pilot.** Shared parts change what a verb does, never how far or fast the ball moves. | Oct | tsv 727, 896, 903 |
| **Events never stop the ball:** no drag, stun, hold or slow; weather never changes handling. | 10 Oct | PARK.md |
| A kicker is met only from its ramp face. Shortcuts stay optional and a ground route stays open; skill-test areas stay off the critical path. | Oct | tsv 140, 218, 682; PARK.md |
| Abilities have snap and fire while moving. | Sep | Bible; ALPHA-PLAN |
| Every action has impact and weight, visual paired with audio, for pilots, packs and Wardens. | Oct | tsv 565 |
| Every mechanic shows its cause on the object before you act and its effect when it lands. | Sep | tsv 78 |
| Damage taken never shakes the camera. | Oct | DESIGN-V3 |
| Harpoon spam stays legal, with a combo counter, a miss cost and a skill-shot window. Deflector and counter-ram enemies arrive from world two, none in world one. | Oct | tsv 180, 183; PARK.md |
| Park Wardens fight on their set pieces; the sheet ram is the only shatter. | Oct | tsv 798, 882 |
| One global warning grammar; no per-world telegraph colours. | Oct | tsv 338 |
| Enemy homes are a breakable side goal. | 2 Oct | interview |
| Ancient light is uranium-glass green (#9dff3c), not Cherenkov blue. | Oct | tsv 350, 429 |
| Pilots are Hoberman-sphere mechs. | Oct | tsv 417, 433 |
| Look targets: Arizona sandstone for world one, the approved keyframes for worlds two and three, Southwest finish for parks; branching fans stay readable. | Sep-Oct | tsv 116, 155, 158, 466, 481 |
| Look bar: 80-90% of the concept art. | 28 Sep | ROADMAP |
| A lower preset holds 60 fps on an RTX 3060-class card. | 28 Sep | ROADMAP |
| Activities are signposted from drop-in. | Oct | tsv 181, 184 |
| Tally hands in the ledger at Moss's shop. | Oct | tsv 264, 276 |
| Enemy meshes may start from CC0 or CC-BY bases with the licence recorded; ripped meshes are banned. | Oct | tsv 474 |
| Hot-wired parts carry a real downside. Synergies chain and visibly change the world. Each pilot has at least two play identities in the kit tree. Treasure finds have a four-tier ceremony. Pilots react to wins and failures. | Sep-2 Oct | ROADMAP; interview |
| Gunfire Reborn and Roboquest borrows are alpha scope (44 adopt now, 140 next push). | Oct | tsv 473, 475, 489 |
| Story stays short and skippable, intro cards included. | 2 Oct | interview |
| Music never freezes: pause and the calm bay keep the band playing. | Oct | tsv 764, 777 |
| Scrapped-together HUD: roughness on the frame, never on the information. | 28 Sep | ROADMAP |
| Main menu: Play, Camp, Settings, Help, Achievements. | 16 Oct | tsv 957 |
| Wardens and earlier boss phases stay at 129 BPM; Eurodance at 140-150 is the final phase only. | 16-17 Oct | R-22 veto list; card |
| The speed soft cap is a deliberate exception to "momentum is sacred". | 17 Oct 07:17 | tsv 119, 251; card |
| Hive defenders skipping the 0.2 s gap is a deliberate exception to "Gap wins". | 17 Oct 21:19 | card "All at hives" |
| Growth grows the shell's presence, not the collider; the 1.5-2x area means the aura. | Sep; 17 Oct 17:28 | Bible; card |
| Pilot leitmotifs are built as variations of current motifs, not new themes. | 17 Oct | tsv 993; typed 17:10 |
| "Level-ups" in the scaling rule means heft class-ups; there is no XP curve. | Oct | tsv 489 |

Watch-outs for live design work: the new "electrical field that interrupts" motif must interrupt abilities, not stun the ball, or come back as a card. Pilot cast times must keep abilities firing on the move; a long cast is a card.

## Replaced rulings (kept so nobody revives them)

| Old ruling | Replaced by | When |
| --- | --- | --- |
| Codex (GPT) standing lane beside each Claude wave; "use GPT heavily" (2, 12, 14 Oct) | Retired: Claude cloud threads do all the work (tap "Retire it") | 17 Oct 20:02 |
| Camp recreation cut (W18-R1) | Camp back in, hub ring | 16 Oct |
| Cosmetics as tints; bespoke pilot models cut | Trails, decals, companion paint; 18 cosmetics | 16 Oct |
| Direction sheets as a veto window, builds start | Storyboards first; all five calls tapped | 16 Oct |
| Dig landmarks are non-colliding scenery | Headframe legs solid, sinkhole full ring, 20 m bowl | 16-17 Oct |
| Bot-driver work stops | Fix the bot's Mind route | 16 Oct 23:37 |
| One fix round per wave; a second needs Andrew | Claude owns engineering; standing merge authority | 17 Oct 19:41 |
| Andrew plays each wave before merge | No per-wave play asks before the sitting; merge authority | 16 Oct; 17 Oct 19:41 |
| Worlds 2-3 and title music as synth placeholders | Full ACE score, picks by ear | 16 Oct |
| Three playable pilots | Six | Oct |
| FLUX as the only picture engine, per-picture approval | Astra for detailed subjects; blanket approval | Oct |
| Scrap-bot crew replaces the companion | One SPIL-9 that grows; crew after alpha | 17 Oct 16:36 |
| Bible music "dry rhythm, restrained synth pulses" | Steampunk-cyberpunk, house, jazz; Sound Bible | 16-17 Oct |
| Gamepad after world one | Gamepad optional | 16 Oct |
| Coordinator commits straight to main | Candidate branch, then main at wave close | 16-17 Oct |
| Alpha goal "Complete the full game in alpha" | Finished-feeling Linux alpha by wave 21 | 16 Oct |
| Five first-time players finish world one | Andrew's 11-area sitting is the only gate | 17 Oct 16:35-16:38 |
| "Written themes": three new themes, re-render and re-pick | Current jazzy tracks are the picks | 17 Oct 15:59 |
| "Clearly mightier": late hits 3x size | "Presence, centre clear": burst size unchanged | 17 Oct 17:28 |
| The machine owns src/; cloud threads hand src changes over | Cloud threads write and gate src and assets | 17 Oct 16:38 |
| Merges need his tap; main pushes need his typed line | Standing merge authority | 17 Oct 19:41 |
| Every warning, even within a pack, 0.2 s apart | One pack's warnings start together | 17 Oct 15:30 |
| Sinkhole "Real basin" | 20 m bowl | 17 Oct 15:31 |
| Storyboard 48 h veto deadline (Oct 18) | All five calls tapped; void | 16 Oct 22:38 |
| Rigger Harness cosmetic | Cut | 16 Oct 21:46 |
| One fixed time of day per world (register D19, Sep) | One day per run (design questions) | 17 Oct 22:12 |
| Meteor Crater ends on a camera shot (park veto 6, 10 Oct) | A 60 s free roll (design questions) | 17 Oct 22:12 |
| Models are low-poly, chunky, flat colour | Chunky, bevelled, smooth (Soft toy) | 18 Oct 00:40 |
| Andrew first plays at a wave 19 feel check, ahead of the sitting (17 Oct 22:12) | One full playtest at the end of wave 21 | 18 Oct |
| claude.ai project threads coordinate; PC runs only GPU checks and music through Remote Control | Local coordinator on the PC; up to 4 Claude Code cloud lanes; GPU bench and music as local sessions | 18 Oct |
| Writer model "Opus writers" (decisions.tsv:852, 14 Oct) | Sonnet 5.5 writers, Opus 5.5 gate, Fable 5.1 consequential review, as AGENTS.md pins (coordinator call, RECONCILE.md model pins) | 18 Oct |

## Open (waiting on a call)

- Nothing on the design questions page: Andrew answered rounds 1 and 2 at 22:12 on 17 Oct (design-questions/OPEN.md).
- Old veto lists and deferred feel checks are now "Check while you play" prompts on the Sitting Kit (RECONCILE.md section 4).
- Taste defaults taken under creative charge, on the veto list for the wave 21 playtest: HIVE-GRIND bar fill option A; radio stays off the pad (D-pad down keeps the active); the old `lore.reach.*` set is replaced. Added 21 Oct: first-meet tips (#240) show one tip after the drop and hold the rest until the first Warden fight ends; whole-rect stamped rows count as ground (section 8); #222 monster thresholds at Warden arrival and dead offers for a full kit (section 6).
