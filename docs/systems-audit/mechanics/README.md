# Mechanic depth and feel (pass C, world 1)

**What changed.** The game had no controller rumble anywhere, and carving was the one verb that published nothing, so nothing could answer it. This pass adds both: every hard moment now asks the pad for a short, sized rumble through one call in `juice.gd`, and a carve that ends publishes `carved`, answered by a new release sound and a tap. Everything else in the table below was read in code and counted in four world 1 bot runs; three mechanics ask no real decision today, and all three belong to other threads or passes (Heat on PR 763, passes B and D), so this pass names them and leaves them alone.

**Read at.** `stage/alpha-w37` head `995f3dd2` with pass A's docs (PR 765), 11 Nov 2026. Card: [SA-C in BACKLOG.md](../../BACKLOG.md#sa-c). Scope: world 1 (the dam, the flume, Brindle).

**Words used here.** "Anticipation, impact, recovery" are the three moments of feedback the brief asks for: before (the player can see it coming or set it up), on contact (it lands), after (the player can see what it cost and when it is ready again). "The census" is the event count in section 3.

## 1. The mechanics

One row per world 1 mechanic the player drives or answers. "Decision" is the choice it asks; a row that asks none is flagged. File names are under `sketches/core-loop/src/`.

| Mechanic | Decision it asks | Counterplay (what the world does back) | Risk and reward | Anticipation | Impact | Recovery | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Rolling and speed tiers (`movement/speed_tier.gd`: walk, cruise, fast, blazing at 0, 0.55, 1.15, 1.9 x cruise) | Which line, how fast | Lanes and rings are committed where you will be | Speed raises ram punch from cruise up (`combat` `ram_punch_now`) and costs nothing | Tier colours, streaks | Ram stop and shake by throw | none needed | **No decision**: faster is always right (loops.md finding 3). Fix owned by Heat, PR 763 |
| Boost (`movement/tuning.gd` `BOOST_IMPULSE` 11, cooldown 1.1 s) | When to spend it | none of its own | A spent boost is not there for a dodge | none (cooldown not shown on the ball; not checked in the HUD) | whoosh, squash, camera | not shown | keep; the cooldown read belongs to the UI thread |
| Jump and the speed bank (`tuning.gd` `BANK_*`) | Land fast enough to bank; jump inside the last 0.25 s to keep it | none | A jump too early spends the bank | none | hop, squash | none | keep; the bank has no cue, a finding for pass E |
| Slam and the dunk (`combat/dunk.gd`, 3 s window) | Slam now, then reel within 3 s for the stored damage | Wardens' guard and plating | The slam commits you to the ground | dunk coil glows on the collar (`player_fx.gd`) | squash, kick, FOV punch, `core_slam`; **now a strong-motor rumble** | coil fades as the window runs | keep |
| Harpoon line and the chain (`combat/chain.gd`: link +1, pivot +0, smash pays 1 + 0.3 per link to x2.5) | What to bite, link or pivot, when to smash | Two pivots with no enemy end it | A dry fire locks the harpoon 0.6 s | reach preview (BIBLE section 4.1) | 40 ms bite stop, clink, the chain's pentatonic ladder; **now a light tap on the bite** | dry tick on a miss | keep |
| Carve (`movement/ball_rules.gd`: grip contact steeper than 25 degrees at the fast tier) | Ride the wall to hold speed round a bend, or take the floor | none | Holds speed; pays nothing else | none | sparks (`player_fx.gd`), but only past 35 degrees and at fast (see finding 2) | **none before this pass** | **fixed: a `carved` event, a release sound and a tap** |
| Ram and plating (`combat` `resolve`) | Hit it now or build punch first | Plating deflects a short punch to 20% | A deflected ram wastes the line | **amber or slate tint**: punch beats plating or not, every tick | stop and shake by throw, dust, number, deflect clank; **now rumble by throw** | shred visible as the tint turns | keep: the best-read mechanic in the game |
| Weapons and aim (`combat/weapons.gd`) | Which target | Plating, cover | none beyond time | reticle | kick and recoil per weapon (`event_kinds.gd` JUICE `shot_fired`) | none | keep |
| Actives and the ultimate (`combat/actives/`, `core/ultimate_meter.gd`) | When to fire | none | A cooldown spent | `ultimate_ready` cue | per-active sound, enemy_struck | heat tick (`active_heat`) | keep |
| Enemy telegraphs (`combat/telegraph.gd`; chaser 0.6 s lane, lobber 1.3 s glow then a 1.9 s ring) | Leave the shape, or tank it | the attack lands where it said | A hit costs hull and spills scrap armour | committed shape on the floor, the danger mark over the ball | hit edge flash toward the source, squash, number; **now a rumble sized by damage** | regen after 5 s (see below) | keep |
| Near miss (`combat/near_miss.gd`) | Skim the edge or go wide | none | Pays the ultimate at most 0.05 a second (`ultimate_meter.gd`) | the danger mark | FOV punch -5, chevron glyph, ring, a whoosh and two notes; its 45 ms stop row is never sent (finding 3); **now a 60 ms light tap** | none | **Asks no decision**: a skim pays almost nothing. Fix owned by Heat (skims fill the gauge), PR 763 |
| Hull regen (`core/run_state.gd`: 6 a second after 5 s) | none | none | Any hull price comes back in 9 to 18 s | none | none | hull bar | **No decision** (systems map problem 1). Owned by pass B (numbers) and D (rule) |
| Scrap armour spill (`build/scrap_field.gd`) | Chase the spilled scrap back or keep rolling | Spill lands near threats | Lost mass and armour | none | rip sound, shell shrinks | pieces on the ground | keep: a real decision after every hit |
| SPIL-9 escape window (`core/run_state.gd`) | none (it fires on its own) | none | Once a zone | companion pip (HUD) | companion act | none | keep |
| Warden guard, weak points and posture (`combat/warden*.gd`, `boss_posture.gd`) | Which point, reel or ram | guard, vents, magnet tug | A stagger window wasted | weak point opens with a cue | crit stop and kick; **now a rumble** | posture bar | keep (Warden files are the board thread's; only juice changed) |
| Heft class (`build/accretion.gd`) | Pick up or stay light | heft drops on hits | Bigger punch, bigger target | none | pop, `class_up`, toast; **now a long strong-motor swell** | class down sound | keep |

Rumble rows and starting strengths are in `RUMBLE` in `src/presentation/juice.gd`. They are start values for a pad check on Andrew's PC, not a feel verdict.

## 2. Findings

1. **No rumble anywhere.** Confirmed: no `start_joy_vibration` call in `src/` before this pass. Fixed by `juice.rumble(fact, share)`: one row per fact, scaled by the caller (a ram by its throw, a hit by its damage), a weaker request under a running one is dropped so the big moment is never blurred, and the Screen shake comfort row scales it until the settings form has its own row. Heat's rise and blast rumbles go through the same call (note sent to the Heat thread).
2. **Carve had no fact and two definitions.** Physics carves at 25 degrees and grip speed (`ball_rules.gd` `state.carving`); the sparks (`player_fx.gd` `carving()`) need 35 degrees and the fast tier. So a shallow carve showed nothing at all. This pass adds `carved(at, seconds, speed)` when a carve of 0.3 s or more ends, and juice plays `carve_release` and taps the pad. The sparks threshold is in `player_fx.gd`, which the Heat thread holds; the one-line fix (read `state.carving`) is passed to them.
3. **The near miss is not silent, but it is small.** loops.md says a near miss shows nothing. The census counts 50 to 86 a run. The code answers it with an FOV punch, a chevron, a ring and a whoosh with two notes; its 45 ms stop row is dropped on purpose, because only a strike may freeze time (`juice.gd` `STRIKE_STOP_FACTS`). What is true is that it pays almost nothing, so it asks no decision. Heat fixes the pay; this pass adds the tap.
4. **Three mechanics ask no decision**: speed (Heat), the near miss (Heat) and hull regen (passes B and D). None sits in this pass's files, so none is changed here.
5. **Grammar facts with no answer.** `maker_set_completed`, `overflow_cashed`, `special_broken` and `trade_taken` have no impact by an earlier ruling ("Achievement facts own no impact; the earned toast is the cue", `event_kinds.gd`). The achievement toast fires once across all runs, so a second completed maker set in a later run has no answer at all. That is the build feedback systems-map problem 3 asks for; it goes to pass D with the fold of the ten build doors.

## 3. The census

Four world 1 runs on the park table at `--fixed-fps 90`, from the title to the frame stage 3 opens after Brindle falls: the skipper and the completionist bots on seeds 2860 (Tally) and 2861. Every run reached stage 3 (`bots.ndjson` outcome `until`). Each count is one bus event; the joined files are in [evidence/pass-c/runs/](../evidence/pass-c/runs/).

| Fact | completionist-2860 | completionist-2861 | skipper-2860 | skipper-2861 |
| --- | --- | --- | --- | --- |
| run time (s) | 629 | 622 | 488 | 425 |
| seconds carving | 6.25 | 6.23 | 4.45 | 4.14 |
| carves started | 50 | 45 | 33 | 27 |
| `carved` | 4 | 7 | 5 | 3 |
| `near_miss` | 86 | 50 | 86 | 56 |
| `player_hit` | 7 | 4 | 26 | 12 |
| `slammed` | 48 | 42 | 68 | 68 |
| `landed` | 156 | 167 | 112 | 133 |
| `harpoon_bit` | 111 | 99 | 76 | 68 |
| `harpoon_smashed` | 23 | 23 | 38 | 44 |
| `enemy_struck` | 457 | 304 | 412 | 284 |
| `strike_deflected` | 213 | 116 | 230 | 66 |
| `boosted` | 0 | 0 | 0 | 0 |
| `jumped` | 52 | 41 | 31 | 47 |
| `boss_weak_point_hit` | 36 | 7 | 22 | 5 |
| `heft_class_changed` | 6 | 5 | 7 | 5 |
| `maker_set_completed` | 0 | 0 | 0 | 0 |
| `escape_window` | 0 | 0 | 0 | 0 |
| `ultimate_ready` | 4 | 4 | 4 | 4 |
| `enemy_killed` | 54 | 42 | 65 | 67 |
| rumbles sent / held | 328 / 184 | 259 / 184 | 374 / 120 | 320 / 122 |

What the numbers say:

- **The near miss fires 50 to 86 times a run**, more than once every ten seconds. So the read works; what loops.md calls silent is a fact that happens constantly and pays almost nothing. That is why it asks no decision, and why Heat feeding on skims is the right fix.
- **A third to a half of all strikes are deflected** (66 to 230 `strike_deflected` against 284 to 457 `enemy_struck`). A deflected strike deals 20%. The amber or slate tint says beforehand whether a hit will land, and the bots ignore it, so this measures the bots more than the game; but it shows how much the plating read carries. A player who reads the tint is choosing; one who cannot see it is losing four fifths of their hits. Pass E should check the tint is learnt in the first minutes.
- **Real carves are rare and short**: 27 to 50 carve starts a run but only 3 to 7 last 0.3 s or more, and 4 to 6 seconds of carving in a whole world. The bots do not plan wall lines, so this undercounts a player; it does show that most wall contacts are seam hops, which is why the event waits for 0.3 s.
- **The bots never boost** (`boosted` 0 in all four). The bot driver does not press boost, so boost has no automated evidence at all. A harness gap for pass F.
- **No maker set completed and no escape window** in any run, so neither has evidence here.
- **Rumble**: 259 to 374 rumbles sent a run, one every 1.3 to 2.4 s. Most held rows are soft landings below the floor (impact under 10 m/s asks nothing). Whether that is too busy on a real pad is the PC check's question.

## 4. Clips and review

| Changed mechanic | Clip | What it shows |
| --- | --- | --- |
| Carve release | [clips/carve_release.wav](clips/carve_release.wav), [spectrum](clips/carve_release_spectrum.png) | the new cue, 0.18 s, peak 0.9 before its -8 dB trim |
| Carve and rumble in play | [clips/feel-timeline.png](clips/feel-timeline.png) | from the census: when each carve, near miss, hit and slam happened in a world 1 run, with the rumble each asked for |
| Rumble rules | `tests/feel_rumble_carve_test.gd` | near miss taps, weaker drops, stronger takes over, shake 0 stills, one `carved` per held carve, none per hop |

**Review.** One independent review (mid tier, Opus 5.5) of the code passed with notes. Fixed after review: the landed rumble was wired twice through a lambda (`wire_optional` runs twice), so it moved into `_on_landed`; the "still running" window read game time, which a hit-stop stretches, so it reads real time; `rumble_log` keeps its last 512 rows; a ball switched off mid-carve forgets the carve; `attack_rows_test` re-pins `ROWS_HASH` for the new `carved` row. The census tool's first two runs wrote nothing (it waited for a return value bot_run never gives, then indexed past the seed list); it now writes from `_finalize`.

What was not tested: the pad itself. Cloud runs have no controller, so `Input.start_joy_vibration` is called on no device and only the log is evidence. How the rumble feels, and whether the carve release reads over the music, needs Andrew's PC with a pad (posted as NEEDS: gpu on board 749).

## 5. How to rerun

```bash
# from the repo root, GODOT_BIN set (cloud: /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64)
$GODOT_BIN --headless --import --path sketches/core-loop
for p in skipper completionist; do for s in 2860 2861; do
  mkdir -p artifacts/local/sysaudit-c2/$p-$s; $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/sysaudit/clip_census.gd -- \
    --out="$PWD/artifacts/local/sysaudit-c2/$p-$s" --policy=$p --seeds=$s --table=park --until=2 &
done; done; wait
python3 -I docs/systems-audit/evidence/pass-c/census.py artifacts/local/sysaudit-c2 docs/systems-audit/mechanics/clips
$GODOT_BIN --headless --path sketches/core-loop --script res://tools/sysaudit/clip_carve_sound.gd -- --out="$PWD/docs/systems-audit/mechanics/clips"
$GODOT_BIN --headless --path sketches/core-loop --script res://tests/feel_rumble_carve_test.gd
```
