# Designing a park for speed in 3D

**Status: draft for card [CS-04](../../../../../../BACKLOG.md#cs-04), 19 November 2026.** Written by a GPT-6.2 Astra agent at high effort from public sources and this repository; the coordinator checked that its links to repository files resolve. It has not had its independent review. Each note carries a text diagram. It is a reference only (ruling ef): nothing in it authorizes a change to a map. How it feeds the maps is in [the area blueprint](../../../park/AREA-BLUEPRINT.md).

A missed hook should change where the ball lands. Give the rider a longer way through, a view of the line they missed, and another chance to climb. That is the most useful lesson the 3D Sonic games offer the Spillway. The dam already has routes that leave the same shelf and meet at the Eye. Start there. If the rider misses the high line, what can they do in the next ten seconds? [park_dam.json:12–23](../../../../../../sketches/core-loop/src/world/park/park_dam.json#L12-L23) [W1-135.md:8–12](../../../../../../docs/promises/W1-135.md#L8-L12)

This is a design study for the dam and flume. A park is an open stage with an objective and optional pockets. A seed is the number that lets the game repeat a particular run's draws. The pilot rides a ball whose momentum matters, and the Spillway is a working water system. Its banks, spill channels, crew repairs and machinery supply the shapes for the examples below. [maps-compared.md:10–16](../../../../../../sketches/core-loop/design-v3/research/comps/maps-compared.md#L10-L16) [PARK.md:197](../../../../../../sketches/core-loop/design-v3/PARK.md#L197) [STORY-MAP.md:23–27](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L23-L27) [STORY-MAP.md:84–85](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L84-L85) [STORY-MAP.md:111](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L111)

I read public interviews, reviews, manuals and written player guides, and the Scrapkeep checkout at `1d5d77fc6`. The numbers below are identified as play reports, guide times or project targets. The diagrams show relationships only. All proposed names, geometry, inhabitants, art, music, writing and code for the game must come from Scrapkeep's own work. [BACKLOG.md:6361](../../../../../../BACKLOG.md#L6361) [comps/README.md:30](../../../../../../sketches/core-loop/design-v3/research/comps/README.md#L30)

## 1. Stage anatomy at speed

### What it does

In the modern stages of *Sonic Generations*, staying high can save time. A rider who misses can drop to a longer path and still finish. A ramp glimpsed from the main line gives a reason to come back. Some forks rejoin. Some stretches offer little genuine choice even though the scenery moves fast. A written *Frontiers* guide also identifies jumps that regain an upper route after a split. The sketch combines those local decisions into three roles for the dam. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) · [Generations playtest](https://www.siliconera.com/sonic-generations-playtest-fanservice-with-substance/) · [Gamerch timing guide](https://gamerch.com/sonicfrontiers/486233)

```text
                  ┌─ high: precise entry, short ride ──────────┐
see the fork ─────┼─ middle: ordinary through route ────────────┼─ common landmark
                  └─ low: catches a miss, longer rolling bend ─┘
                         └─ another climb to the middle or high line
```

### Parameters with sources

| What to time or place | Evidence and its limits |
| --- | --- |
| Whole stage | A *Generations* previewer going for speed finished a first modern act in just under three minutes. A *Frontiers* reviewer put most separate linear stages at one to two minutes. These are reported clear times with different players and builds. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) · [GameSpot on Frontiers](https://www.gamespot.com/reviews/sonic-frontiers-review-sonic-is-that-you/1900-6417995/) |
| One section | In a player's written guide to *Frontiers* 1-2, two prompts within a rail passage are four seconds apart (0:24 to 0:28). Six more seconds elapse before the next transition (0:34). That gives about ten seconds from rail entry to a new task, with input partway through. These are video timestamps for one run. The stage's 55-second top-rank target uses the game clock. [Stubbsy’s timed guide](https://kosgames.com/sonic-frontiers-cyber-space-1-2-s-rank-guide-37415/) · [Gamerch timing guide](https://gamerch.com/sonicfrontiers/486233) |
| Camera and path | Director Takashi Iizuka describes turning the *Adventure* camera with the road so that pushing forward still follows a bend. A side view could show a loop in profile. Later, he described a limit of the forward view in *Generations*: much of the input became sidestepping. [Iizuka on the camera](https://browniehideout.wordpress.com/2023/05/22/beep21-interview-with-iizuka-takashi/) · [Iizuka on forward and side views](https://segabits.com/blog/2013/08/08/summer-of-sonic-2013-takashi-iizuka-interview/) |
| Set piece and control | Iizuka describes changing actions to give *Adventure 2* its tempo. A reviewer of *Unleashed* enjoyed watching loops and rail passes even when one held direction did almost all the work. Neither source supplies a target percentage of automated time. [Iizuka on tempo](https://sonichq.net/article/news/igndc-interview-with-sonic-adventure-2-director-takashi-iizuka/) · [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) |

### Why it works

A lower road makes a mistake cost seconds. Seeing the upper road from below tells the rider what to try next time. A shared landmark lets a rider take either branch without losing their bearing. A brief guided arc can buy time to look ahead. It earns that time if the player gets to use what they saw on landing.

### What Scrapkeep borrows

At the dam fork, give a clean hook release the shorter way through. Give the middle route a bank the ball can steer, and let the low route catch a short release on a downslope. Face the next climb along the direction of travel. For a set piece, let the rider choose the approach, carry the ball briefly, then show a choice of exits before steering matters again. Use the existing launch rings to describe an actual flight path. [park_dam.json:14–24](../../../../../../sketches/core-loop/src/world/park/park_dam.json#L14-L24) [W1-135.md:8](../../../../../../docs/promises/W1-135.md#L8) [launch.gd:6–14](../../../../../../sketches/core-loop/src/world/launch.gd#L6-L14)

Keep three clocks separate. The park design gives a pilot 12–45 seconds between waymarks and a median 60–120 seconds from drop-in to Warden engagement. The world pacing file gives a skipper 180–300 bot seconds for each complete park, with combat and exit included. The reference's several-second inputs belong *inside* a route leg. Use Scrapkeep's own clock for the full stage. [PARK.md:510–519](../../../../../../sketches/core-loop/design-v3/PARK.md#L510-L519) [world1-pacing.json:4–10](../../../../../../sketches/core-loop/design-v3/pacing/world1-pacing.json#L4-L10) [world1-pacing.json:28–39](../../../../../../sketches/core-loop/design-v3/pacing/world1-pacing.json#L28-L39)

### What it must not copy

Avoid tracing a course, a chase, a camera track or a set-piece sequence. A spring that fires the rider backward can cost time in the reference. In the Spillway, spend that time on the longer bend. Ruling cu protects a ball that keeps rolling and turning. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) · [DECISIONS.md:199](../../../../../../project-guide/handoff/DECISIONS.md#L199)

### Lab measure

Time from a common fork to the common rejoin on high, middle and low entries, including a deliberate missed hook. A reset or unreachable rejoin counts as a failed ride. See measure 1.

## 2. What to put on a route

### What it does

A piece earns its place by giving the rider distance, height, a new heading or entry to a different route.

```text
see the piece and what lies beyond → choose a line in → touch, ride or bypass
                                                      → release toward a visible landing
```

### Parameters with sources

| Piece and purpose | What the reference tells the rider | Proposed Spillway cue before contact |
| --- | --- | --- |
| Speed giver. Restore speed before a run-up. | An *Adventure 2* guide describes low pads with wheels, often repeated. Its author thought the first one looked like a trapdoor. Repetition helps only after recognition. [Adventure 2 object guide](https://gamefaqs.gamespot.com/dreamcast/291597-sonic-adventure-2/faqs/12957) | Let the water gather into a straight spill channel. Leave its mouth wide enough to choose the bank or spend boost before entering. |
| Launcher. Trade the run-up for a known landing. | The same guide distinguishes an angled panel with arrows from a flat speed pad. It sends the character to a set place. [Adventure 2 object guide](https://gamefaqs.gamespot.com/dreamcast/291597-sonic-adventure-2/faqs/12957) | Frame both the lip and the receiving shelf against open sky. Angle the supporting structure toward the shelf. |
| Rail. Hold a heading while the rider chooses a release. | In *Adventure 2*, the thin continuous rail is the surface the player jumps onto. The player can jump off. A *Frontiers* guide uses the visible start of a pickup line as the cue to change rails. [Adventure 2 object guide](https://gamefaqs.gamespot.com/dreamcast/291597-sonic-adventure-2/faqs/12957) · [Stubbsy’s timed guide](https://kosgames.com/sonic-frontiers-cyber-space-1-2-s-rank-guide-37415/) | A cable pulled taut between two trestles shows where it goes. Leave daylight between cable and cliff so the far support reads. |
| Target chain. Cross space in separate aimed moves. | Airborne targets can carry the character across a gap. In *Unleashed* a reticle appears on an eligible target. The row gives the broad direction before the reticle confirms a bite. [Gap crossing guide](https://www.gamepur.com/guides/how-to-get-s-rank-on-cyberspace-stage-1-2-in-sonic-frontiers) · [Unleashed manual](https://info.sonicretro.org/images/4/4a/Unleashed_360_UK_manual.pdf) | Show a fixed rope bite beyond the first target and the catch below both. An enemy can make the crossing profitable. Its presence must never be needed to survive the gap. |
| Loop or bank. Turn at speed and make the turn visible. | *Adventure* showed a loop side-on. Its banked and inverted roads expose the changing surface angle. The strategy guide distinguishes how to stay on such a road. [Iizuka on the camera](https://browniehideout.wordpress.com/2023/05/22/beep21-interview-with-iizuka-takashi/) · [Adventure DX strategy guide](https://manuals.plus/m/bba0c6657c63aae0ba96ecd8f9d49b0db0b7cfc357a2d2c767fb182e98cdfd9c.pdf) | Use a worn arc rising around a spill basin. Show the far rim before entry. A wider bend must take the ball arriving on boost. |
| Bounce object. Redirect an approach or give a second rise. | *Adventure 2* springs have a distinct face and can point at different angles. A *Frontiers* guide sometimes skips the spring because its arc costs time. [Adventure 2 object guide](https://gamefaqs.gamespot.com/dreamcast/291597-sonic-adventure-2/faqs/12957) · [Stubbsy’s timed guide](https://kosgames.com/sonic-frontiers-cyber-space-1-2-s-rank-guide-37415/) | A pulsing vent and spray leaning toward a shelf show the impulse before it fires. Leave room to roll past its mouth. |
| Breakable shortcut. Let inspection or a well-aimed hit change the route. | A *Generations* player reports that a stomp through a wooden bridge opens a quicker lower line. The material is a clue. The account doesn't establish how early a newcomer could recognize it. [Player’s shortcut note](https://forums.somethingawful.com/showthread.php?threadid=2969807&userid=157145) | Expose daylight through a failed seam. Show the wash continuing behind it. Let a ram open the seam on approach, or a slam open it from above. |

### Why it works

The entry says which action to take. The view past the piece says why it is worth taking. A boost that leads to a blind corner teaches hesitation. A rider who can see both a bank and its exit can choose how much speed to carry.

### What Scrapkeep borrows

Start with the flume's cable endpoints, launch target, thermal and cracked walls that break at cruise. Use the site's job to make each cue distinct. Try a trestle where the rope pivots the ball into a slam on a crew machine. A surface bite keeps a chain alive without raising its count. Enemy bites build the combo, a chained smash pays damage, and the rolling catch gives up that combo. [park_flume.json:279–287](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L279-L287) [HOOK-CHAIN.md:7–17](../../../../../../sketches/core-loop/design-v3/HOOK-CHAIN.md#L7-L17) [HOOK-CHAIN.md:50–58](../../../../../../sketches/core-loop/design-v3/HOOK-CHAIN.md#L50-L58) [STORY-MAP.md:127–131](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L127-L131)

For a first placement pass, convert sight distance to time. A cue 28 m ahead buys 2.0 seconds at 14 m/s and about 1.05 seconds at 26.6 m/s, before allowing for turning or a blocked view. For a hook crossing, check two different distances. The reach probe uses a 45 m rope. After release the chain gives 0.8 seconds to bite again. A target can be within reach yet still appear too late in the rider's view. [TRAVERSAL.md:9–14](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L9-L14) [PARK.md:520](../../../../../../sketches/core-loop/design-v3/PARK.md#L520) [HOOK-CHAIN.md:17](../../../../../../sketches/core-loop/design-v3/HOOK-CHAIN.md#L17)

### What it must not copy

Keep the functions. Invent the tool, its silhouette and its sound from the worksite. Leave the reference's pad graphics, spring faces, signature loops, targeting graphics and enemy arrangements out of the design. Keep the ball on a rope with a player-chosen release. [W1-135.md:12](../../../../../../docs/promises/W1-135.md#L12) [STORY-MAP.md:129–131](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L129-L131)

### Lab measure

Film each approach at the fastest speed a rider can bring to it. Measure how long the rider can identify the action **and its exit** before the last safe steering input. See measure 2.

## 3. Small challenges in an open area

### What it does

*Sonic Frontiers* puts short challenges on the journey across an island. A traversal puzzle can uncover a part of the map. A distant large enemy can turn the journey into a chase. Collectibles form lines across ground paths and along rails. Portals lead from the open area to separate timed stages. The player can notice one invitation while finishing another. [SEGA’s Frontiers manual](https://manual.sega.jp/sonicfrontiers/en/) · [GameSpot on Frontiers](https://www.gamespot.com/reviews/sonic-frontiers-review-sonic-is-that-you/1900-6417995/) · [Game Informer on Frontiers](https://gameinformer.com/review/sonic-frontiers/into-the-wild-blue-yonder) · [Ring placement in Frontiers](https://sonic.fandom.com/wiki/Ring/History_and_appearances)

```text
see a destination ── follow a local challenge ── see something new from the exit
                         ├─ movement puzzle → more map visible
                         ├─ moving enemy → pursuit
                         └─ portal → short linear stage → back to the island
```

### Parameters with sources

| What fills the space | What writers and players observed |
| --- | --- |
| Distance between activities | Director Morio Kishimoto said early testers liked the individual stages but found the ground between them boring. In the released game, GameSpot's reviewer could often choose the next destination from a structure, ramp or pad without opening the map. [Iizuka and Kishimoto on playtests](https://browniehideout.wordpress.com/2022/09/20/sonic-frontiers-a-game-that-even-sakurai-masahiro-said-he-would-definitely-buy-was-initially-met-with-a-lot-of-harsh-opinions/) · [GameSpot on Frontiers](https://www.gamespot.com/reviews/sonic-frontiers-review-sonic-is-that-you/1900-6417995/) |
| Puzzle and reward | Timed runs and small spatial puzzles reveal nearby map detail. A nearby cluster of platforming pieces can instead pay a token. These give the player different reasons to leave a straight course. [SEGA’s Frontiers manual](https://manual.sega.jp/sonicfrontiers/en/) · [GameSpot on Frontiers](https://www.gamespot.com/reviews/sonic-frontiers-review-sonic-is-that-you/1900-6417995/) |
| Enemy and portal | Some large enemies move across the open field and lead the player on a chase. Defeating one gives a gear that can open a portal. The separate linear stage pays keys for its objectives. [Game Informer on Frontiers](https://gameinformer.com/review/sonic-frontiers/into-the-wild-blue-yonder) · [SEGA’s Frontiers manual](https://manual.sega.jp/sonicfrontiers/en/) |
| What feels joined or bolted on | Brian Shea enjoyed linking a pad, rail and bounce into a run. He also found that late-appearing rails made navigation hard. GamesRadar+'s reviewer saw little substance in clusters of floating platforms. In one player discussion, a rider recommended working backward from a token to find its entrance and said pop-in made that difficult. These are individual accounts. [Game Informer on Frontiers](https://gameinformer.com/review/sonic-frontiers/into-the-wild-blue-yonder) · [GamesRadar+ on Frontiers](https://www.gamesradar.com/sonic-frontiers-review/) · [Frontiers player discussion](https://www.reddit.com/r/SonicFrontiers/comments/1ixlm2u/) |

### Why it works

An exit is a good place to offer the next choice. From a high landing the player sees more ground than from the approach. Hiding that view until the player is already underneath the next rail wastes the height. Equally, a quiet stretch can have a job: give the rider space to read the objective and pick an approach.

### What Scrapkeep borrows

Use the flume's optional surge course for the short test of movement. From its exit, frame a second destination, such as the worksite or the mouth of a cache. Let a player who completes a climb learn a shortcut by seeing its far end. Skip the map-unlock chore. If the seed draws the hauler bounty, its movement can draw the eye across an otherwise quiet shelf. Build the sightline from the route and leave a way past the pursuit. W1-141 asks for a purpose and physical evidence for each region's verbs. A rest region can show the next choice while the ball keeps moving. [park_flume.json:297–298](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L297-L298) [PARK.md:257–259](../../../../../../sketches/core-loop/design-v3/PARK.md#L257-L259) [W1-141.md:7–12](../../../../../../docs/promises/W1-141.md#L7-L12) [W1-141.md:26](../../../../../../docs/promises/W1-141.md#L26)

### What it must not copy

Separate portal stages conflict with ruling cv if used for the journey from the dam to the flume or the bowl. The ruling wins. Put the short course beside the main ride. Carry the stage exit's motion through to a visible arrival. Give each structure a job in the waterworks and each creature a reason to be there. [DECISIONS.md:322](../../../../../../project-guide/handoff/DECISIONS.md#L322) [STORY-MAP.md:23–26](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L23-L26) [STORY-MAP.md:111](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L111) [STORY-MAP.md:129–131](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L129-L131)

### Lab measure

Time the longest ride between visible, reachable choices on the main route. A quiet bank that shows two exits offers a choice. A row of distant props with no approach does not. See measure 3.

## 4. Rewards, route choice and replay

### What it does

In *Generations*, a normal pickup line can help refill boost during a fast run. Ramps into alternate paths offered one reviewer shorter times and extra collectibles. There are also five hidden red collectibles per act. This gives a second visit a different purpose: ride the known route cleanly, or spend time finding a place missed on the first pass. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) · [Generations playtest](https://www.siliconera.com/sonic-generations-playtest-fanservice-with-substance/) · [Generations review](https://www.gamesradar.com/sonic-generations-review/2/)

```text
first clear → remember the missed entrance
              ├─ repeat the line → cleaner exit → compare time
              └─ leave the line → find a hidden reward → rejoin
```

### Parameters with sources

| Choice | What changes |
| --- | --- |
| Hold the skill line | A player can keep a boost going by picking up rings and defeating enemies in the modern *Generations* preview. Following the line helps pay for continuing at speed. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) |
| Explore | The visible mouth of another route can be enough of a clue for a later run. A special pickup rewards looking somewhere new. Some occur on a fast line, so collecting and racing can overlap. [Generations playtest](https://www.siliconera.com/sonic-generations-playtest-fanservice-with-substance/) · [Gamerch timing guide](https://gamerch.com/sonicfrontiers/486233) |
| Earn a rank | *Frontiers* 1-2 distinguishes a finish, a 55-second top rank, finishing with 80 ordinary rings, and finding the special collectibles. A player can choose which objective to pursue on a visit. A reviewer liked retrying but found the top times inconsistent in difficulty across stages. [Gamerch timing guide](https://gamerch.com/sonicfrontiers/486233) · [Game Informer on Frontiers](https://gameinformer.com/review/sonic-frontiers/into-the-wild-blue-yonder) |
| Choose difficulty while moving | The high line is often quicker and harder to hold. A player describes improving one jump or branch per retry. Another describes a break-through where the *lower* line is faster. Height offers a trade. A useful exception rewards a rider who reads the ground. [Frontiers player discussion](https://www.reddit.com/r/SonicFrontiers/comments/1ixlm2u/) · [Player’s shortcut note](https://forums.somethingawful.com/showthread.php?threadid=2969807&userid=157145) |

### Why it works

The rider who spots a ledge too late still learned something. If the fork is recognizable next time, that knowledge is a reward. A time target makes the value of a clean release visible. A detour pays for a different intention. Requiring the detour on every clear would remove the decision.

### What Scrapkeep borrows

Let real scrap mark a steerable line through a landing. It already gives the ball size and armour. A visible door can lead to a more valuable part farther off line. One rider can skip it to beat their own split. Another can take it because today's build needs the part. Compare a split only for the same seed, pilot, entry speed and loadout. Keep it optional and local to a leg or surge course. The world objective still sits in the open park. [STORY-MAP.md:84–85](../../../../../../sketches/core-loop/design-v3/STORY-MAP.md#L84-L85) [PARK.md:257–271](../../../../../../sketches/core-loop/design-v3/PARK.md#L257-L271) [park_flume.json:298](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L298) [maps-compared.md:16](../../../../../../sketches/core-loop/design-v3/research/comps/maps-compared.md#L16)

### What it must not copy

Leave out collectible designs, rank emblems, letter-grade ladders and currency gates. A higher tier in the Spillway can pay in exit speed, access or less hull lost while moving. Parking there still has to cost hull. Avoid a speed bonus that turns every other route into a bad choice, or a collectible that the rider must stop and fetch to proceed. [DECISIONS.md:199](../../../../../../project-guide/handoff/DECISIONS.md#L199) [W1-135.md:8–12](../../../../../../docs/promises/W1-135.md#L8-L12) [W1-135.md:24](../../../../../../docs/promises/W1-135.md#L24)

### Lab measure

Compare the time cost and the part paid for the optional pocket against passing its door, using the same fork and rejoin. Keep the part type or rarity visible in the result. A rare part and ten seconds are different units. See measure 4.

## 5. Where speed design goes wrong

### What it does

A course can look fast while the player's input changes little. It can also ask for an exact input before showing enough road to make it. The most useful criticism identifies which of these happened, where, and on which release. [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) · [GameSpot on Unleashed for Wii](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202292/)

```text
late cue → correct input comes too late → crash → learn by dying
forced aim → intended exit passes by → wait for control → backtrack
```

### Parameters with sources

| Failure | Observation | Warning for a park designer |
| --- | --- | --- |
| Steering at speed | GameSpot's review of the HD *Unleashed* describes loose steering, spikes and drops learned by repeated failure. The same publication found the Wii release's different courses and more responsive controls easier to read. [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) · [GameSpot on Unleashed for Wii](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202292/) | Check the approach at the speed boost permits. An obstacle visible on a still can already be too close to avoid. |
| Automation | Iizuka's camera solution made holding forward sufficient through some turns. GameSpot describes spectacular loops with little more to do than hold one direction. [Iizuka on the camera](https://browniehideout.wordpress.com/2023/05/22/beep21-interview-with-iizuka-takashi/) · [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) | Let the rider decide whether to enter. Return influence soon enough to choose a landing or an exit. |
| Camera failure | The HD reviewer describes a restricted view at a narrow crossing. In *Frontiers*, Shea reports stretches that force a side view and a single path until the player finishes or backs out. [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) · [Game Informer on Frontiers](https://gameinformer.com/review/sonic-frontiers/into-the-wild-blue-yonder) | Keep the destination, landing and safe side in the rider's view through the last steering decision. |
| Change of pace | The switch to slow brawling in *Unleashed* drew criticism for repeated attacks. Small precision jumps with speed-oriented controls also sent the character too far. [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) · [GameSpot on Unleashed for Wii](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202292/) | Make a breather a rolling bend with room to steer. A mandatory wait or tiny landing tests a different skill. |
| Empty or cluttered open ground | *Frontiers* testers described uneventful journeys. A release reviewer found floating equipment popping into view close up. Both faults can occur on the same stretch: plenty of objects, nothing the player can plan for. [Iizuka and Kishimoto on playtests](https://browniehideout.wordpress.com/2022/09/20/sonic-frontiers-a-game-that-even-sakurai-masahiro-said-he-would-definitely-buy-was-initially-met-with-a-lot-of-harsh-opinions/) · [GamesRadar+ on Frontiers](https://www.gamesradar.com/sonic-frontiers-review/) | Judge the ride from the entry, with the ball moving. Ask what the rider can reach and why they would go there. |

### Why it works

These failures separate three questions a fast run can hide. Did the rider see the turn? Could they make it at their entry speed? Did choosing it change where they landed? A short clear time answers none of them.

### What Scrapkeep borrows

Try the bend at its fastest plausible entry, with both a clean release and a late one. Compare that with the low route. Scrapkeep's earlier Reach trial supplies a concrete warning. Its fast pilot left a bend at 37 m/s and hit scenery. A rebuilt bank and open ramp later carried that pilot with zero dead stops in the reported sample. That was a Reach trial, not a new result for the Spillway. [TRAVERSAL.md:80–90](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L80-L90) [TRAVERSAL.md:92–96](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L92-L96)

### What it must not copy

Leave out blind pits, prescribed camera turns through open forks and a forced pause to wait for combat to resume. Keep a fight pressing while the player can roll and turn. The project also calls for clean silhouettes, shell cover and a bowl floor for fights. Spectacle provides no evidence for those checks. [DECISIONS.md:199](../../../../../../project-guide/handoff/DECISIONS.md#L199) [map-audit.md:37–39](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L37-L39) [map-audit.md:54–60](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L54-L60)

### Lab measure

Compare a neutral-input pass through each guided piece with a pass that steers for a different reachable exit or releases early. Measure the longest time for which the two inputs cannot change the outcome. See measure 5.

## What this means for Scrapkeep

The first comparison I would make is the dam shelf to the Eye. Its three authored branches give the designer a common start and finish. A clean hook release should earn the high route's advantage. A missed bite has to land somewhere rideable. Then try the flume's surge course as a short, optional test inside the longer world ride. Both comparisons fit existing places and can be tried with the same seed. [park_dam.json:14–17](../../../../../../sketches/core-loop/src/world/park/park_dam.json#L14-L17) [park_flume.json:298](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L298) [W1-135.md:8](../../../../../../docs/promises/W1-135.md#L8) [DECISIONS.md:322](../../../../../../project-guide/handoff/DECISIONS.md#L322)

### Where each relationship belongs

The left column follows ruling ct in order. “Supports” means the reference gives a reason for the existing point. “Adds” names a comparison worth making in the park. A field described as proposed is a suggestion for a later design decision. [DECISIONS.md:321](../../../../../../project-guide/handoff/DECISIONS.md#L321)

| Map point | What the reference contributes | Park field or other owner |
| --- | --- | --- |
| 1. Landmarks seen from across the map | **Supports** a visible destination. **Adds** a second view: from a low catch, can the rider see where to climb back? A skyline marker can pass its sight test while a landing is hidden. | Use `landmark.sight_top`, `sight_share`, the nearest `waymarks` and the approach on `routes.via`. Film the catch in the ordinary chase view. Preserve the existing 85% open-cell and riding-line sight targets. [PARK.md:108–115](../../../../../../sketches/core-loop/design-v3/PARK.md#L108-L115) [PARK.md:193–199](../../../../../../sketches/core-loop/design-v3/PARK.md#L193-L199) [map-audit.md:49–50](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L49-L50) |
| 2. Breathing space between fights | **Supports** letting the player choose the next challenge. **Adds** something to do during the quiet: read the next fork, build speed or line up a rope bite. | Use `home_rows.site` and `event_rows.site` for placed fights. Timer packs have their own breather rule. W1-141 specifies a region's `purpose` and `verbs` in a regions file beside the park file (built for the dam, the flume and the Slag Bowl), with a pack-free rest region and pressure if the rider camps. [PARK.md:133–136](../../../../../../sketches/core-loop/design-v3/PARK.md#L133-L136) [PARK.md:151–157](../../../../../../sketches/core-loop/design-v3/PARK.md#L151-L157) [breather_rows.gd:4–15](../../../../../../sketches/core-loop/src/world/breather_rows.gd#L4-L15) [W1-141.md:21](../../../../../../docs/promises/W1-141.md#L21) [W1-141.md:26](../../../../../../docs/promises/W1-141.md#L26) |
| 3. Heavy and quiet rhythm | **Supports** alternating demands. **Adds** a distinction between quiet and hands-off: a quiet bank can require steering, and a loud launch can require none. Give a spectacle a playable approach and exit. | Read `park_rows.ride_fact`, `event_rows.trigger`, `telegraph.lead_s` and `live_s` alongside region purpose. Mark set pieces by site ID in the study film. Retain the floor-line standard of at least three heavy/quiet switches and at most 45 seconds continuously heavy. [PARK.md:81–82](../../../../../../sketches/core-loop/design-v3/PARK.md#L81-L82) [PARK.md:133–141](../../../../../../sketches/core-loop/design-v3/PARK.md#L133-L141) [map-audit.md:51–52](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L51-L52) [W1-141.md:26](../../../../../../docs/promises/W1-141.md#L26) |
| 4. Fixed frame with per-run variety | **Supports** learning a fork over repeated rides. The seed is Scrapkeep's addition. Keep its geography recognizable while a different pursuit, fight or payout changes the reason to take it. | Keep `routes`, `waymarks`, takeoffs, catches and corresponding landings fixed. Draw eligible `activity_rows.alts`, pockets, rogue sites and modifiers. Keep draws repeatable. The audit distinguishes seeded content from live routes, which it reports are not drawn per run. [PARK.md:193–199](../../../../../../sketches/core-loop/design-v3/PARK.md#L193-L199) [PARK.md:272](../../../../../../sketches/core-loop/design-v3/PARK.md#L272) [map-audit.md:9](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L9) [map-audit.md:94](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L94) |
| 5. Cover and readable safe ground | **Supports** reading a safe landing before committing. Shell cover is a local combat requirement. A visible pier only counts if its collider actually stops the shot while the ball rolls past. | Use `park_rows.recipe` and the collider it builds, plus `home_rows.advantage` and `counter`. The audit distinguishes hard cover from dressing and records a gap in explicit cover tags. W1-141 names the flume pier and the shot that must hit it. [PARK.md:84](../../../../../../sketches/core-loop/design-v3/PARK.md#L84) [PARK.md:154–156](../../../../../../sketches/core-loop/design-v3/PARK.md#L154-L156) [map-audit.md:54–55](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L54-L55) [map-audit.md:94](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L94) [W1-141.md:24](../../../../../../docs/promises/W1-141.md#L24) |
| 6. Features react to the player | **Supports** a breakable shortcut. **Adds** a readable view through the opening and a through route for a player who declines. A hit should change the next few seconds of driving. | Use `contraption_rows.kind` and `site`. The flume already has a valve with a door, and a wall with `break_at_cruise`. For an event that changes access, use `event_rows.route_change` and `hold_clear_m`. Keep a route open. [park_flume.json:279](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L279) [park_flume.json:285–287](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L285-L287) [PARK.md:139–140](../../../../../../sketches/core-loop/design-v3/PARK.md#L139-L140) [PARK.md:195](../../../../../../sketches/core-loop/design-v3/PARK.md#L195) |
| 7. Height in tiers | **Supports** a high line earned by skill. **Adds** a catch and a later climb. Separate height gained by holding a hook from speed gained on the drop. Neither requires an enemy to spawn. | Use `park_rows.y`, `verb`, `routes`, a kick lip's next `via` row, cable endpoints or a launch `target`. Label the fork, entry tier and catch in the measurement sheet. W1-135 requires the hold to match the best early release at 14 m/s or reach a tier the release cannot. Preserve the early release's own baseline. [PARK.md:77–88](../../../../../../sketches/core-loop/design-v3/PARK.md#L77-L88) [PARK.md:241–243](../../../../../../sketches/core-loop/design-v3/PARK.md#L241-L243) [W1-135.md:8](../../../../../../docs/promises/W1-135.md#L8) [W1-135.md:22](../../../../../../docs/promises/W1-135.md#L22) |
| 8. Bowl fights, clear silhouettes, snag-free big pieces | **Supports** a bank that turns a fast rider and a silhouette that shows where to go. Fight-bowl depth and shell behaviour come from Scrapkeep. A scenic loop would say nothing about either. | Use `park_rows.element`, `stamp`, `size`, `recipe` and `home_rows.site`. Align the bank tangent with the next route. Keep the machine visible against sky and roll past the base from either side. Local checks cover bowl depth, machine silhouettes and snagging separately. [PARK.md:73–85](../../../../../../sketches/core-loop/design-v3/PARK.md#L73-L85) [PARK.md:153](../../../../../../sketches/core-loop/design-v3/PARK.md#L153) [map-audit.md:58–60](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L58-L60) |
| 9. Hub joins the tiers | **Supports** a common place to find one's bearing after a split. **Adds** a recovery question: from the catch, can a rider regain height through the hub without reversing? | Give `routes.from`, `to` and `via` a shared place and visible upward ride. At the dam, several rows converge on the Eye. The historical audit warns that an open-ground zone can pass the three-band count without looking like a built hub. [park_dam.json:14–26](../../../../../../sketches/core-loop/src/world/park/park_dam.json#L14-L26) [PARK.md:243](../../../../../../sketches/core-loop/design-v3/PARK.md#L243) [map-audit.md:61](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L61) [map-audit.md:79](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L79) |
| 10. Objectives visible from afar, rewards on skill lines | **Supports** a pickup line and an off-line discovery. **Adds** a reward for reading the terrain: a climb can reveal a cache entrance, and a moving quarry can lead toward it. Offer a split time to the rider who passes the door. | `floor.scrap` in the dam's lines file already sets spacing and rests. The reader lays that trail on the floor path. Aim it past existing ride ends or drops first. If a distinct elevated trail proves useful, it would need a proposed `routes[].scrap` or equivalent line-specific row and a reader for it. Preserve the floor trail and its economy. Use `activity_rows.pay.rarities` for pocket pay, `activity_rows.route` for the surge course and the same waymarks for optional time comparisons. [lines.json:12–13](../../../../../../sketches/core-loop/assets/park/park_dam/lines.json#L12-L13) [park_map.gd:255–266](../../../../../../sketches/core-loop/src/world/park/park_map.gd#L255-L266) [park_scrap_lines_test.gd:3–13](../../../../../../sketches/core-loop/tests/park_scrap_lines_test.gd#L3-L13) [PARK.md:257–271](../../../../../../sketches/core-loop/design-v3/PARK.md#L257-L271) [park_flume.json:297–298](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L297-L298) [DECISIONS.md:320–321](../../../../../../project-guide/handoff/DECISIONS.md#L320-L321) |

**When the reference and the rulings disagree.** A hard fall, compulsory stop or forced reversal can enforce difficulty in a linear stage. Ruling cu wins here. Recover through distance, while keeping pressure on slow, stopped or predictable movement. Pair any advantage from new cover or more valuable scrap with the required pressure read. Similarly, the separate course reached through a portal is useful as a unit of play, but ruling cv wins at each world seam. Use the park's `atlas`, `exit`, `arrives` and the flume's `approach` to carry heading and speed toward the visible next place. A ring on that rail predicts where the ball will fly. [First timed run](https://www.gamesradar.com/sonic-generations-if-ever-a-game-was-built-for-speedruns-its-this/) · [GameSpot on Unleashed](https://www.gamespot.com/reviews/sonic-unleashed-review/1900-6202025/) · [GameSpot on Frontiers](https://www.gamespot.com/reviews/sonic-frontiers-review-sonic-is-that-you/1900-6417995/) · [DECISIONS.md:199](../../../../../../project-guide/handoff/DECISIONS.md#L199) [DECISIONS.md:322](../../../../../../project-guide/handoff/DECISIONS.md#L322) [park_flume.json:7–13](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L7-L13) [handover_rows_test.gd:6–18](../../../../../../sketches/core-loop/tests/handover_rows_test.gd#L6-L18) [launch.gd:6–10](../../../../../../sketches/core-loop/src/world/launch.gd#L6-L10)

**What to hold fixed on replay.** Use the same terrain, fork, recovery floor, hook face, destination and hand-over on each seed. Vary what the rider meets or takes home within those boundaries. For example, the flume can draw a bounty or an ambush at one authored site, while the separate surge row still refers to its authored course. Compare two routes on one seed first. Then repeat across seeds so a lucky part or empty fight cannot masquerade as a better slope. The audit's recorded fifty-seed sample found 47 distinct pocket/site/modifier sets on the dam and 45 on the flume. The figures come from the audit's historical sample. [park_flume.json:297–298](../../../../../../sketches/core-loop/src/world/park/park_flume.json#L297-L298) [PARK.md:197](../../../../../../sketches/core-loop/design-v3/PARK.md#L197) [map-audit.md:94](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L94)

**What remains unmeasured.** The sources give single-run examples and player accounts. I found no series-wide timing for route choices or set pieces, no reliable percentage of a stage spent under automatic control, and no measured distance at which each reference prop becomes readable. I could check the player's breakable-shortcut account and the wiki's field pickup description only in indexed excerpts. I read public sources without opening reference game files or running a game, build or test. The suggestions below need paired rides or rider-height film. Human feel remains for the sitting. [TRAVERSAL.md:3](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L3)

### Ten proposed measures

Use the same stage, pilot, loadout and entry state within each comparison. Record the seed and route. Mark a missed landing, reset or failed clear explicitly so it cannot disappear from the median. Only the cited project thresholds are existing targets. The rest are comparisons to try.

1. **Fork-to-rejoin seconds.** Time the high, middle and low lines between the same points. Add a deliberate miss from the high line. Record a failed recovery if the ball cannot reach the rejoin rolling forward. A longer lower route should cost time without imposing a stop. [park_dam.json:14–17](../../../../../../sketches/core-loop/src/world/park/park_dam.json#L14-L17) [TRAVERSAL.md:10–13](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L10-L13)
2. **Seconds of advance notice.** At normal cruise and the fastest reachable entry, pause rider-height film at the first frame a reader can point to the action and its exit. Subtract that time from the last frame when steering can still reach it. A negative result identifies a blind commitment. Hide the cue in a control frame. [W1-141.md:9](../../../../../../docs/promises/W1-141.md#L9) [map-audit.md:49–50](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L49-L50)
3. **Seconds between route choices.** Mark when two reachable destinations can first be distinguished and chosen. Measure to the next such choice, including the opening and closing stretches. Flag the longest gap and whether it is an intentional moving breather. A visible but unreachable prop earns no mark. [PARK.md:195–199](../../../../../../sketches/core-loop/design-v3/PARK.md#L195-L199) [W1-141.md:21–26](../../../../../../docs/promises/W1-141.md#L21-L26)
4. **Return for the detour.** On a matched seed compare bypass time with door-to-payout-to-rejoin time from the same approach. Report extra seconds alongside the actual part or rarity. A route that takes longer and offers the same return needs a different reason to exist. [PARK.md:257–271](../../../../../../sketches/core-loop/design-v3/PARK.md#L257-L271)
5. **Longest stretch without steering influence.** From identical entries compare no input with a steer or release toward a different exit. Time how long the paths must coincide before the player can change the landing or take a branch. Count a rail with working release or switching as controllable. Count a fixed exit launch separately. [PARK.md:243](../../../../../../sketches/core-loop/design-v3/PARK.md#L243) [launch.gd:6–14](../../../../../../sketches/core-loop/src/world/launch.gd#L6-L14)
6. **Flow share by route tier.** For each tier, divide ticks at speed tier 2 or above by counted riding ticks. Compare pilots on matched seeds. Mark where the ball is airborne: the project's 3D speed measure counts a fast fall, including one off the intended route. [TRAVERSAL.md:7–16](../../../../../../sketches/core-loop/design-v3/TRAVERSAL.md#L7-L16)
7. **Hook sites where holding pays.** Count sites that meet W1-135's hold-versus-best-early-release rule at the same 14 m/s entry. Record the exit speeds or identify the higher ledge reached. An unreachable anchor fails, and a slower early release cannot earn a pass. [W1-135.md:8](../../../../../../docs/promises/W1-135.md#L8)
8. **Seconds between set pieces.** Mark the start of each authored spectacle by site ID on film. Measure start to start, then read the interval with the existing fight/quiet strip. Two launches with no meaningful steering between them call for a different approach or exit. [PARK.md:81–82](../../../../../../sketches/core-loop/design-v3/PARK.md#L81-L82) [map-audit.md:51–52](../../../../../../project-guide/handoff/shared/world1/map-audit.md#L51-L52)
9. **Hull loss per minute by movement.** Compare a camper on the tier, a straight cruise and a rolling, turning rider under the same threat and seed. Keep the existing slow-versus-cruise floor of two times hull loss per minute. Check whether the recovery line exposes the turning rider to a compulsory hit. [DECISIONS.md:199](../../../../../../project-guide/handoff/DECISIONS.md#L199) [W1-135.md:24](../../../../../../docs/promises/W1-135.md#L24)
10. **Continuous stage hand-overs.** Count seams where the last exit frames and first arrival frames show one motion toward the next place. Match the film to the row's exit/arrival kind, heading, speed ratio and position ahead. Include a turned-away arrival as the failing control. [DECISIONS.md:322](../../../../../../project-guide/handoff/DECISIONS.md#L322) [handover_rows_test.gd:12–22](../../../../../../sketches/core-loop/tests/handover_rows_test.gd#L12-L22)
