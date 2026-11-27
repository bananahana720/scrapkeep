# Systems Audit Pass E — First 15 Minutes (World 1)

Measured on base `aa5c74047` (World 1 unified pre-alpha baseline) with headless probe [`sketches/core-loop/tools/sysaudit/first_15_probe.gd`](../../../sketches/core-loop/tools/sysaudit/first_15_probe.gd) alongside existing [`first15_pace.gd`](../../../sketches/core-loop/tools/sysaudit/first15_pace.gd). No story beats were changed.

## 1. World 1 mechanic introduction order

Observed chronological order for a first-timer dropping onto the Spillway Dam (Stage 1) through the Flume (Stage 2) and Brindle's arena:

| Order | Mechanic / Beat | Typical Window (s) | How It Is Taught |
| --- | --- | --- | --- |
| 1 | Roll & camera steering (`stage_1_drop`, `prompt:roll`, `objective:find_warden`) | `0.0–0.1 s` | Open dam approach lane + single-line glyph prompt |
| 2 | Boost & momentum (`prompt:boost`) | `0.5–0.8 s` | Downhill slope + single-line glyph prompt |
| 3 | Scrap pickup (`scrap_pickup`) | `0.9–1.2 s` | Line of sight scrap trail on first roll |
| 4 | Harpoon & basic combat (`prompt:harpoon`, `first_kill`, `prompt:tip_active`) | `5.5–27.6 s` | Early yard fodder before the first clamp |
| 5 | First damage taken & yard crew (`first_hit_taken`, `objective:break_yard_crew`) | `59.3–94.7 s` | Yard crew pack protecting the dam approach |
| 6 | Harpoon body smash, counter-ram, heft class-up, slam (`harpoon_body`, `harpoon_smash`, `heft_up`, `slam`) | `74.5–101.6 s` | Practice on yard crew before the Warden |
| 7 | Dam Warden engagement & clamp crews (`warden_engaged`, `objective:break_clamp_crews`, `objective:ride_sheet`) | `115.7–122.1 s` | Sealed beacon + Warden arena callout |
| 8 | Reward gates & first part choice (`reward_gates`, `objective:roll_gate`, `first_part`) | `144.8–180.3 s` | Open gate trio + roll-through pick |
| 9 | Stage 2 Flume drop & contextual field tips (`stage_2_drop`, `tip_dunk`, `tip_jam`, `tip_radio`) | `156.1–180.4 s` | Single-line tips gated by live hazards |
| 10 | Flume line fight & Warden stagger (`objective:line_fight`, `warden_staggered`, `prompt:slam`) | `289.5–345.0 s` | Tighter lane combat combining slam + plating |
| 11 | Brindle boss arena (`boss_arena`, `shoot_magnets`, `slam_caps`, `bait_charge`, `ram_scooter`) | `300.0–406.1 s` | Multi-phase boss combining prior verbs |

## 2. Minute-by-minute concept cadence & difficulty chart

### Seed 1 (`runner_gunner`, `skipper`, 406.1 s, cleared World 1 -> Stage 3)

Milestones: first kill `7.5 s`, first hit `94.7 s`, first Warden `115.7 s`, first reward gates `144.8 s`, first part `156.1 s` (`barbed_reel`), first stagger `289.5 s`, total concepts `55`.

| Minute | Stage | New Concepts | Kills | Hits Taken | Damage Taken | Peak Enemies | Warden Active (s) | Parts Gained | Cadence Flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 8 | 11 | 0 | 0.0 | 12 | 0.0 | 0 | Concept-dense opening |
| 2 | 1 | 9 | 29 | 1 | 52.0 | 21 | 4.3 | 0 | Concept-dense (yard + Warden) |
| 3 | 2 | 13 | 18 | 6 | 195.4 | 23 | 24.8 | 1 | Spike (Warden clear + Flume drop) |
| 4 | 2 | 1 | 13 | 2 | 120.0 | 21 | 0.0 | 0 | Low new concepts (steady combat) |
| 5 | 2 | 7 | 42 | 4 | 175.0 | 30 | 15.5 | 0 | Concept-dense (Flume Warden) |
| 6 | 2 | 12 | 6 | 2 | 45.9 | 29 | 52.3 | 1 | Spike (Brindle arena phases) |
| 7 | 3 | 5 | 4 | 2 | 56.4 | 8 | 46.1 | 2 | Boss close + Stage 3 entry |

### Seed 2 (`demolitions_caster`, `skipper`, 372.0 s, lost in Stage 2)

Milestones: first kill `27.2 s`, first hit `59.3 s`, first Warden `122.1 s`, first reward gates `176.1 s`, first part `180.3 s` (`ten_pin`), first stagger `345.0 s`, total concepts `43`.

| Minute | Stage | New Concepts | Kills | Hits Taken | Damage Taken | Peak Enemies | Warden Active (s) | Parts Gained | Cadence Flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 9 | 4 | 1 | 31.2 | 12 | 0.0 | 0 | Concept-dense opening |
| 2 | 1 | 11 | 28 | 0 | 0.0 | 20 | 0.0 | 0 | Concept-dense (synergy burst) |
| 3 | 1 | 9 | 24 | 6 | 156.0 | 24 | 54.0 | 0 | Concept-dense (Dam Warden) |
| 4 | 2 | 4 | 2 | 1 | 30.0 | 19 | 0.0 | 1 | Steady (Stage 2 drop) |
| 5 | 2 | 4 | 27 | 4 | 202.5 | 30 | 0.0 | 0 | Steady (Flume brawl) |
| 6 | 2 | 6 | 17 | 1 | 45.0 | 34 | 17.8 | 0 | Concept-dense (Flume Warden) |
| 7 | 2 | 0 | 0 | 3 | 146.3 | 34 | 12.0 | 0 | Flat concept minute (fatal fight) |

## 3. Spikes, flat stretches, and word-budget compliance

- **Single-line tutorial text (`LEGIBILITY.md` §13 / `ruling cx`):** **PASS.** All `9 / 9` field tips are `1` line (`max_lines: 1`, `max_words: 17`, `0` multi-line tips).
- **Fight-time word budget (`<= 25` words on HUD during active combat):**
  - Seed 1 (`runner_gunner`): peak fight words **`23`**, **`0` violations** (`peak_calm_words: 38`).
  - Seed 2 (`demolitions_caster`): peak fight words **`31`**, **`2` brief samples > 25** at `157.29 s` and `157.79 s` (Stage 1 Warden + clamp-crew objective + status text overlapping simultaneously). No story text changed; logged as a minor HUD tightening follow-up if it recurs in rendered sitting captures.
- **Concept spikes:** Minutes 1–3 (`8–13` concepts/min) reflect passive `synergy_discovered` events firing alongside combat verbs rather than tutorial popups. Actual prompt cadence stays front-loaded to basic verbs (`roll`, `boost`, `harpoon`, `active`) in the first 30 seconds and contextual field tips (`dunk`, `jam`, `radio`) only when the player reaches the Flume.
- **Flat stretches:** Zero flat minutes during live progression on Seed 1 (`flat_minutes: []`); Seed 2's only `0`-concept minute is Minute 7 (the final 12 seconds of a fatal Stage 2 Warden fight with `146.3` damage taken).
- **Evidence boundary:** Headless probe proves deterministic cadence, timing, and HUD word-count compliance on macOS. A rendered first-timer film (`tools/eye_film.gd --film=whole` and `tools/first_timer.gd -- --table=park`) on the Linux PC remains the rendered-play proof for visual feel.

## 4. Reproduction commands

```bash
HOME="$PWD/artifacts/local/home-sysaudit" "$GODOT_BIN" --headless --fixed-fps 90 \
  --path sketches/core-loop -s res://tools/sysaudit/first_15_probe.gd -- \
  --seed=1 --bot=skipper --stages=2 --max-s=900 \
  --out="$PWD/artifacts/local/sysaudit/first15-seed1.json"

HOME="$PWD/artifacts/local/home-sysaudit" "$GODOT_BIN" --headless --fixed-fps 90 \
  --path sketches/core-loop -s res://tools/sysaudit/first_15_probe.gd -- \
  --seed=2 --bot=learner --stages=2 --max-s=900 \
  --out="$PWD/artifacts/local/sysaudit/first15-seed2.json"
```
