# Pilot cadence: how each pilot's weapon fires

**Status: design spec for wave 46 unit E0-01, written 22 November 2026 against `stage/alpha-w46` at `c0a4bba6f`. Nothing here is built, run or played.** Ruling ek ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md), 22 Nov) orders the work this page specifies. Every number is a start value. Each one sits inside the damage table in section 1, and Andrew can overturn any of them (section 9).

**What this page is for.** Today every bolt weapon fires while the button is held, at a fixed rate, with no reload. Ruling ek replaces that with six weapons that each ask for a small act of timing and never slow the ball. This page is the one home for each weapon's full cycle: every timer, the least time between shots, what interrupts it, what a proc may not do, the damage it can reach, what the player looks at to time it, and the first tree pick that changes its feel. A code unit builds a weapon from its section here and from nothing else.

**What this page does not own.** The six kits around the weapon stay in the pilot pages ([pilots/](pilots/sable.md)). Kit swaps and shot bits stay in [ABILITY-MUTATIONS.md](ABILITY-MUTATIONS.md). The split between the aim reticle and the tube rail is [LEGIBILITY.md](LEGIBILITY.md) section 14. The sounds for each fact go in SOUND-BIBLE.md once the open Sound V4 pull request, which edits that page, is stacked. Names are in [NAMES.md](NAMES.md).

Paths without a prefix are under `sketches/core-loop/`.

## 1. The damage table

All figures are damage a second against one target, with no upgrades, before the `wet` bonus, with no other kit slot pressed. The ball rolls at cruise (14 m/s) unless a row says otherwise.

- **Careless** is mashing or holding with no timing.
- **Skilled** is every timing window hit at its first frame.
- **Most by arithmetic** is the best any input can do at any ball speed, proved in section 3.
- **Ceiling** is the figure `weapon_envelope_test` must refuse to pass. Ruling ek set it.

| Pilot (weapon id) | Today | Careless | Skilled | Most by arithmetic | Ceiling |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rivet (`rapid_laser`) | 84.0 | 36.9 | 62.6 | 62.6 | 75 |
| Sable (`arc_caster`) | 60.0 | 26.7 | 70.0 at the blazing speed tier; 45.7 at cruise | 70.0 | 80 |
| Sable mounted (`pylon_turret`) | 99.0 | 30.0 | 75.0 for 3 s after a blazing plant; 48.9 after | 75.0 | 80 |
| Tarn (`claw_sweep`) | 64.0 | 40.0 | 72.0 | 78.4 | 80 |
| Kest (`sticky_charge`) | 26.7 | 18.3 | 36.7 | 36.7 | 44 |
| Tally (`ledger_reader`), sustained | 13.4 | 11.0 | 22.0 to 23.0 | 26.4 | 30 |
| Tally, most in any one second | 80.4 | 66.0 | 79.2 | 79.2 | 80 |
| Cannon (`cannon_lane`) | 30.0 | 22.9 | 42.0 | 42.0 | 50 |

What the table buys:

- Careless fire is 38 to 56% weaker than today on Rivet, Sable and Tarn, and 18 to 31% weaker on Kest, Tally and the Cannon. A 60 HP chaser now lives long enough to run its 0.6 s wind-up, with no change to any machine's health (ruling al).
- Skilled fire on Rivet, Sable and Tarn is close to what holding the button gives today. Skilled fire on Kest, Tally and the Cannon is above today's, which ruling ek allows for those three because their careless fire falls.
- The gap between the strongest and the weakest of the bolt, claw and charge weapons falls from 3.7 times today (mounted Sable 99.0 against Kest 26.7) to 2.0 times (mounted Sable 75.0 against Kest 36.7). Tally is paced by pressure and is read on her own two rows.
- Tarn keeps the heaviest single hit of the six baselines at every ball speed: his third beat is 43.0 at a standstill and the next heaviest hit is the Cannon's rail at 42.0.

`weapon_envelope_test` holds each ceiling. It must also fail a planted figure above a ceiling, so the test is known to bite.

## 2. Rules for every baseline

### 2.1 Six rules

1. **No movement tax.** Every fire, charge, reload and timing verb works at any speed, in the air and on the harpoon. Nothing asks the ball to slow, and nothing sets its velocity (ruling cu).
2. **The press is never late.** A press acts inside 100 ms. No verb waits for a release to tell a tap from a hold. Where a weapon fires on release (Kest's throw, the Cannon's lane, Sable's bolt), the press has already done its own visible thing: opened the gauge, painted the lane, fired the spark.
3. **A miss is never a punishment.** A missed window gives the plain result at its usual time. No jam and no lockout.
4. **The window is drawn and has a sound twin.** It shows on the aim reticle, or on the thing in the world the eye is already on, and no fact arrives by sound alone. No tutorial words (LEGIBILITY section 13).
5. **A proc never plays the instrument** (section 2.4).
6. **The old way stays as a data row.** Each weapon keeps a `hold_auto` row (section 4), so a baseline that fails its film review goes back for one pilot with no code change.

### 2.2 Terms every cycle uses

- **Floor.** The least time between two shots, swings, casts or throws of one weapon. A press before the floor ends does nothing, except as the next two terms say.
- **Buffer.** A press made in the last 0.10 s before the trigger is ready is kept and acts the instant it is ready. One press deep. This is how rule 2 holds at a floor.
- **Window.** A short span in which a press pays more. Each window opens on a named event, has a fixed open and close time after it, and pays at most once.
- **One press per window.** The first press after the window's opening event decides it. Inside the window it pays. Before the window opens it spends the window, and the plain result follows at its usual time. This rule is what stops mashing from hitting every window by luck, and it locks nothing: the next plain shot is exactly as fast as it would have been.
- **Rest.** A weapon's cleared state: a full cylinder of plain rounds, no charge, beat one, no window open, no lane painted.

### 2.3 What interrupts a cycle

| Event | What the trigger does |
| --- | --- |
| An attempt boundary: stage entry, retry, arena entry and retry, the lap, death, a new run, Continue, quit to title | Goes to rest. Nothing a trigger holds is saved or carried across. Tally's pressure follows its own reset, as today. |
| Pause | Every timer stops and resumes where it was. A pause is not an interruption. |
| A pulse that jams picks 2 and 3 | Nothing. A jam never freezes the trigger, a reload, a charge or a window. |
| A hold (hooker tether, mag pit, jolt mat) | Nothing. Every firing verb works while held, and none is stronger for being held. Sable's charge is slower there because the ball is slower. |
| The ultimate starts | A charge is dropped, a painted lane is cleared and an open window is spent. A reload keeps running. The trigger is ready when the ultimate hands control back. |
| Sable mounts or dismounts | A charge is dropped with no bolt. The spark floor carries over. |
| The weapon is swapped (a relic or a tree pick) | The old weapon's state is dropped and the new weapon starts at rest. |
| The ball is hit | Nothing. A hit is not an interruption. |

From any state, each event above returns the trigger to ready in a bounded number of steps. It is never left holding. `WeaponCadence.tla` (unit E1-17) checks this, with a planted fault for each rule.

### 2.4 Procs

A shot that an item, a tree proc or a device fires is not the player's press. This covers the `item_proc` source, a tree `volley`, Kick Shot, the pylon sentry and the F actives.

- It fires the weapon's **plain shot**: a plain round, a spark, a first beat, a pulse. Never a hot round, a charged bolt, a third beat, a stamp or a rail.
- It spends no round and no pressure, advances no beat, opens no window, spends no window, and neither resets nor extends a floor, a reload or a charge.
- Proc depth stays one, as `DeferredEffects.tla` already holds: a proc shot starts no further proc.

### 2.5 Plating, posture and the rest of the kit

- **A piercing shot raises chip, and never ignores plating.** Two baseline shots pierce, Rivet's sixth hot round and the Cannon's rail, and no other does. Against plating above the shot's punch, that hit chips 50% in place of 20%. The outer plate still eats the first full hit, so a plated brute stays the one ordinary machine that holds.
- **Posture is paid on the careless figure.** `warden_reactor.gd` `base_dps` reads one figure from the weapon module, the careless column of section 1 (the row in section 4 while a weapon runs `hold_auto`). Skill shortens a Warden fight by rhythm, never by a hidden multiplier, and no tree pick gives a posture spike.
- **Other kit slots are outside the ceiling and each is bounded where it is named.** Rivet's Overdrive and Tarn's Clamp are in their sections. Sable's discharge, the opening rocket rack and the `wet` weakness change in units E1-06 and E1-07 and are recorded in ruling ek, not here.

## 3. The six cycles

### 3.1 Rivet: twin revolvers (`rapid_laser`)

One round per press. Six rounds, then a reload with a notch.

| Step | Value |
| --- | --- |
| Press | One round, 12 damage. A held button fires once and waits. |
| Floor between rounds | 0.20 s |
| Cylinder | 6 rounds |
| Reload | 0.95 s. It starts the instant the sixth round leaves. There is no reload key. |
| Notch (the window) | Opens 0.38 s into the reload and closes at 0.54 s. Its opening event is the sixth round. |
| A press in the notch | The cylinder shuts at once, six **hot rounds** are loaded, and that same press fires the first. A hot round is 14.4 (1.2 times). The sixth hot round pierces (section 2.5). |
| A press before the notch | Spends the notch. The reload ends at 0.95 s with plain rounds. |
| Skid landing or Line Drive | Ends a reload at once, or tops a part-used cylinder up to six. The rounds it adds are plain and fire after the rounds already loaded. |
| Overdrive Sprint, button held | The rest of the cylinder fans: one round every 0.10 s at half damage, in a 5 degree cone. A hold never tries the notch. |

Arithmetic:

- Careless, mashing at the floor: 6 × 12 = 72 in 5 × 0.20 + 0.95 = 1.95 s, which is **36.9**. The masher's first press of the reload lands at 0.20 s, before the notch, and spends it.
- Skilled: 6 × 14.4 = 86.4 in 5 × 0.20 + 0.38 = 1.38 s, which is **62.6**. A notch hit on its last frame gives 86.4 / 1.54 = 56.1.
- Most by arithmetic: **62.6**. No two rounds leave less than 0.20 s apart, and a cylinder of hot rounds costs one notch, which puts 0.38 s, not 0.20 s, before its first round. So six hot rounds take at least 1.38 s (62.6), and plain rounds can do no better than 12 / 0.20 = 60.0 even if every reload were a free Skid. Any mix lies between the two.
- The sprint fan adds no damage a second: half the damage at twice the pace is the same 60.0 a second while the cylinder lasts, and it empties sooner (43.2 / 0.88 = 49.1 with every notch hit).

Kit window, outside the ceiling: **Overdrive** (pick 2, 3 s) shortens the floor to 0.125 s and adds no rounds. Inside it skilled fire is 86.4 / 1.005 = 86.0, careless is 45.7, and nothing can pass 96.0. Today's Overdrive is 134.4.

### 3.2 Sable: spark and charged bolt (`arc_caster`, and `pylon_turret` mounted)

Two verbs on one button. A tap is a spark. A hold charges a bolt, and rolling fast charges it sooner.

| Step | Value |
| --- | --- |
| Press | One spark at once, 8 damage. |
| Floor between sparks | 0.30 s |
| Hold | After 0.16 s the charge starts to fill. No more sparks leave while the button is held. |
| Full charge | 0.64 s at the walk and cruise speed tiers; 1.5 times as fast at the fast tier (16.1 m/s and over: 0.43 s); twice as fast at the blazing tier (26.6 m/s and over: 0.32 s). The tiers are `speed_tier.gd`'s. The rate is read every tick from the ball's speed, on the ground, in the air or on the harpoon. |
| Release | A bolt of 34 × the charge fraction. Under a quarter charge no bolt leaves; the spark was the shot. |
| At full | The charge holds for as long as the button is held. It does not decay and does not fire itself. |
| After a bolt | The trigger is ready 0.12 s later. |
| Chains | A spark and a bolt both read the weapon's own chain row, unchanged from today. |

Arithmetic, with `x` the charge fraction and the charge at twice speed:

- Careless, tapping: 8 / 0.30 = **26.7**. Careless, holding at cruise and letting go 0.4 s late: 42 / (0.16 + 0.64 + 0.40 + 0.12) = 31.8.
- Timing alone, at cruise, released on the tick: 42 / 0.92 = 45.7. At the fast tier: 42 / 0.707 = 59.4.
- Skilled, at the blazing tier: (8 + 34) / (0.16 + 0.32 + 0.12) = 42 / 0.60 = **70.0**.
- Most by arithmetic: **70.0**. One press gives one spark and at most one bolt, and the next press waits for the longer of the spark floor and the bolt's own time. A cycle with a bolt does (8 + 34x) in (0.28 + 0.32x) s. That rises with `x` from 45.8 at a quarter charge to 70.0 at full, and a tap alone is 26.7.

Sable's skill has two halves, each worth about half the gain: letting go on the tick, and rolling fast.

**Mounted.** The same two verbs. A spark is 9 and a full bolt is 36, with the same timers. The charge rate reads the speed banked at the plant for 3 s after planting, then the walk rate. That gives 45 / 0.60 = **75.0** for 3 s after a blazing plant and 45 / 0.92 = 48.9 after it, against 99.0 today, so a perch pays for a quick plant, charge and launch and not for camping. Careless tapping is 9 / 0.30 = 30.0.

### 3.3 Kest: cook and snap (`sticky_charge`)

The lob stays. A live charge shows a short window, and a press inside it bursts bigger.

| Step | Value |
| --- | --- |
| Press | Opens the lob gauge, as today. |
| Release | Throws. A release under 0.10 s of gauge drops the charge at the ball's tail. A longer hold lobs it along the drawn arc, to 30 m at 0.6 s, as today. |
| Floor between throws | 0.60 s, the slot's cooldown, unchanged. |
| A charge left alone | 11 damage in a 3.0 m blast, on today's 1.2 s fuse or on a machine's touch once armed. It was 16. |
| The window | Opens 0.30 s after the charge leaves and closes at 0.55 s. It lies inside the throw floor, so a press that starts the next throw never snaps by accident. |
| A press in the window | **Snap**: the charge bursts at once for 22, with 1.35 times the blast radius (4.05 m) and 1.5 times the knock. The press does not open the gauge, even if held. |
| A press before the window | Spends that charge's window. It goes off plain. |
| Detonation Line (pick 2) | Sets charges off as it does today. A charge whose window is open at that instant takes the snap burst; that is its one press. |

Arithmetic:

- Careless: 11 / 0.60 = **18.3**.
- Skilled: 22 / 0.60 = **36.7**.
- Most by arithmetic: **36.7**. One charge leaves per 0.60 s and no charge does more than 22 to one target. A lob adds its gauge time to the 0.60 s, as it does today, so a lobbed cycle is lower.

At the floor's pace windows never overlap: each is 0.25 s wide and they open 0.60 s apart.

### 3.4 Tarn: three beats (`claw_sweep`)

One swing per press. Beats one and two, then a short window for a third, heavier beat that knocks machines into each other.

| Step | Value |
| --- | --- |
| Beat one | 18 damage. The next swing may start 0.45 s later. A held button swings once and waits. |
| Beat two | 22 damage, if pressed within 0.75 s of beat one; later than that the count starts again at one. The next plain swing may start 0.55 s later. |
| The window | Opens 0.30 s after beat two and closes at 0.54 s. |
| A press in the window, beat three | 43 + 0.5 × planar speed, with speed counted to 30 m/s: 50.0 at cruise, 58.0 at most. Twice the knock, so struck machines are thrown into their neighbours through the pin rule combat already has. The next swing may start 0.50 s later, and it is beat one. |
| A press before the window | Spends it. The next swing is beat one, at beat two's usual 0.55 s. |

Arithmetic:

- Careless, mashing: beats one and two for 40 every 0.45 + 0.55 = 1.00 s, which is **40.0**. The masher's press during the second swing spends the window every time.
- Skilled at cruise: (18 + 22 + 50) / (0.45 + 0.30 + 0.50) = 90 / 1.25 = **72.0**. On the window's last frame: 90 / 1.49 = 60.4.
- Most by arithmetic: (18 + 22 + 58) / 1.25 = **78.4**, at 30 m/s or faster. The beats come only in the order one, two, then three or one. A pair takes at least 1.00 s for 40. A triple takes at least 1.25 s for at most 98.

Kit window, outside the ceiling: **Clamp** (pick 2) still makes clamped machines take 1.5 times from every beat, as it does from every sweep today.

### 3.5 Tally: stamp on the beat (`ledger_reader`)

Tally already taps. Now a press on the beat stamps PAID.

| Step | Value |
| --- | --- |
| Press | Balance Due at the aim point at once, as today. It costs 1 pressure, and needs at least 1 in the bar. |
| Damage | 8 + planar speed, to a top of 22, which the ball reaches at cruise. It was 10 + 1.2 × speed, to 56. A slow ball stamps soft; a ball at cruise or faster stamps at full weight. |
| Floor between casts | 0.40 s, today's card recovery. |
| Pressure | A fraction, from 0 to a cap of 3.0. It refills **continuously at 0.5 a second** while the ball is on the ground at cruise or faster, and not otherwise. The rate and the conditions are today's; holding a fraction is new (see the note under the table). |
| The window | Opens 0.40 s after a Balance Due lands and closes at 0.60 s. |
| A press in the window | **PAID**: a Balance Due at 1.2 times (26.4) that refunds 0.5 pressure. It is a hit, so it opens the next window. |
| A press before the window | Spends it. The next cast is plain. |

**Pressure becomes a fraction.** Today the slot holds whole charges (`s.charges`, an integer, in `combat.gd` `_step_roll_restore`) and gains one each time a 2.0 s clock runs out. A stamp gives back half a pressure and the first tree pick deals in halves and quarters, so the Tally code unit of phase E2 turns the count into a fraction that fills at 0.5 a second. For whole costs nothing changes: today's clock already holds the part-filled charge between two whole ones, so a plain cast and the `hold_auto` row are ready at exactly the times they are today. The pressure pips fill partway, so the half a stamp gave back is seen.

Arithmetic. Pressure comes in at 0.5 a second, so sustained damage is damage bought per pressure times 0.5. A one-second span is counted with both of its ends in it:

- Careless, sustained: a plain cast buys 22 for 1 pressure, so 22 × 0.5 = **11.0**.
- Most by arithmetic, sustained: a stamp buys 26.4 for a net 0.5 pressure, so 26.4 × 0.5 / 0.5 = **26.4**. The refund is half what the stamp cost, so pressure can never grow without rolling.
- Skilled, sustained: a chain is one plain opener and then stamps, until the bar holds less than 1. From a full bar, pressed as each window opens (0.40 s apart), the bar reads 2.0 after the opener and falls 0.3 a stamp (0.2 rolls in, 1 is spent, 0.5 comes back): 1.7, 1.4, 1.1, 0.8, and the fifth stamp at 2.0 s leaves 0.5. The bar reads exactly 1.0 before that fifth stamp, so the code compares with a small tolerance. Refilling to 3.0 takes 5.0 s, so the cycle is (22 + 5 × 26.4) / 7 s = **22.0**. Pressed as each window closes (0.60 s apart) the bar falls 0.2 a stamp, the chain runs 7 stamps to 4.2 s and leaves 0.6, and the cycle is (22 + 7 × 26.4) / 9 s = **23.0**. The opener is why skilled play sits under 26.4.
- Most in any one second: windows open 0.40 s apart, so a one-second span holds three hits (at 0, 0.40 and 0.80 s) and never four. Three stamps are 3 × 26.4 = **79.2**. Careless, three plain casts are 66.0. Today's three casts are 80.4.

Link Clips, the gather plate and the World 1 relics are unchanged. A stamp is a direct hit, so it copies to clips exactly as a Balance Due does today.

### 3.6 The Cannon: paint and lock (`cannon_lane`)

Hold to paint a lane whose brackets close. The release picks the shot.

| Step | Value |
| --- | --- |
| Press | Paints the lane on the ground at once. The brackets start to close. |
| Release under 0.30 s | **Pulse**: 16 damage, 16 m reach, 1.5 times the lane's width. |
| Release from 0.30 s to 0.46 s, the lock | **Rail**: 42 damage, on the lane's own 26 m reach and width. It pierces (section 2.5). |
| Release after 0.46 s | **Barrage**: 26 damage, the lane's reach at twice its width. The brackets have opened again. |
| Time between shots | After any release, 0.70 s before the next press paints. |
| Geometry | Each shot strikes each machine inside it once. Widths and the live time come from the lane family's row in `mind_attacks.gd`, as today. What is drawn while the button is held is what will hit. |

Arithmetic:

- Careless, tapping: 16 / 0.70 = **22.9**. Careless, holding too long and letting go at 0.60 s: 26 / 1.30 = 20.0.
- Skilled: 42 / (0.30 + 0.70) = **42.0**. On the lock's last frame: 42 / 1.16 = 36.2.
- Most by arithmetic: **42.0**. Every shot is one press and one release, and the next press waits 0.70 s. The best of the three is the rail at its earliest: pulse 16 / 0.70 = 22.9, rail 42 / 1.00 = 42.0, barrage 26 / 1.16 = 22.4.

The Cannon has no spent window: its shot is chosen by when the button comes up, so a masher simply fires pulses.

## 4. The `hold_auto` rows

Each weapon keeps today's behaviour as one data row. Setting a weapon's trigger to `hold_auto` restores it with no code change. Unit E1-01 moves all six weapons into the weapon module in this mode first, and every run hash must stay equal, which proves the move changed nothing.

| Weapon | `hold_auto` row | Damage a second |
| --- | --- | ---: |
| `rapid_laser` | 7 damage, 12 a second, fires while held | 84.0 |
| `arc_caster` | 12 damage, 5 a second, one chain jump, fires while held | 60.0 |
| `pylon_turret` | 11 damage, 9 a second, two chain jumps, fires while held | 99.0 |
| `sticky_charge` | 16 damage, 0.60 s between throws, 1.2 s fuse, hold to lob, no window | 26.7 |
| `claw_sweep` | 32 damage, 2 swings a second, swings while held | 64.0 |
| `ledger_reader` | Tap to cast, 10 + 1.2 × speed to 56, 3 pressure, no window | 13.4 sustained at cruise |
| `cannon_lane` | 30 damage, 1 lane a second, fires while held | 30.0 |

Two limits. A difficulty calibration is valid only for the trigger modes the build ships, so turning one pilot back means that pilot's band rows are read again. And a weapon in `hold_auto` is above the careless column of section 1 on purpose: it is the way back, not a tuning option.

## 5. Reading the weapon

### 5.1 The plated ball hides the front of the ring

The default ball is the plated ball with a window facing the camera (ruling dm). From the play camera, 7.5 m back and 17 degrees down, a part at ring height on the front of the ball is behind the ball's own disc until it is about 60 degrees round from the nose. That is computed from [ROSTER-LOOK.md](ROSTER-LOOK.md)'s sizes and still needs one capture with `tools/ball_look_capture.gd`. So a weapon model on the nose is a pilot-select and camp piece. In a fight the timing is read in three places, in this order:

1. **The aim reticle**, which every pilot has.
2. **A part that shows beside the ball from behind**: on the sides, the low sides or the crown.
3. **The thing in the world** the eye is already on, where the weapon has one.

No weapon part reaches further than 1.35 m from the ball's centre. The Cannon's barrel, 1.48 m today, is the one recorded exception and must never grow.

### 5.2 One colour for "press now"

The window is drawn in the live colour, mint, for every pilot (LEGIBILITY section 1: mint means your verb works on this right now). The pilot's own colour is for what the press makes. A window that was spent or missed goes to slate. Nothing on a reticle is brass.

### 5.3 The six instruments

Each weapon gives the eye a different kind of thing to track, so the roster is not one timing game in six paint jobs. The instrument sits inside the reticle's ring and never covers the centre dot. It reads one public state call on the weapon module and no private member.

| Pilot | The eye tracks | At rest | Window open | Hit | Missed or spent | Beside the ball, from behind | In the world |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Rivet | An angle: a notch coming round | Six chamber ticks; a spent chamber is hollow | A reload sweep runs round the ring and the notch on it is mint | The six chambers fill copper: hot rounds | The notch goes slate and the sweep runs on to the end | The exhaust stack on the side that fired puffs (an assumption to check in the capture) | A copper bolt |
| Sable | A fill | An empty arc | The arc fills with the charge. At full, one mint tick: let go now | The arc empties as the bolt leaves in her colour | None. A late release still fires the full bolt | The coil mast lights from foot to tip with the charge | The spark, then the bolt's release ring |
| Kest | A size: a ring closing | Nothing | The fuse ring on the live charge closes; inside the window it is mint. The reticle shows one mint tick, so the cue holds when the charge is off screen | A bone burst ring with an amber edge | The fuse ring goes slate and runs to its fuse | The vanes flick on a throw | The fuse ring on the charge itself, the best cue of the six |
| Tarn | A count: one, two, three | Three hollow pips in his cross shape | Pips one and two are filled; pip three is mint | Pip three fills in his colour, then all three clear | Pip three goes slate and the count clears | The claws, low and wide at the sides; the piston draws in between beats two and three | The sweep ribbon, with a bone-light edge so it reads against a rust machine |
| Tally | A period: the flywheel's beat | A hollow square tick | The square tick is mint | The tick fills in ledger cream and PAID lands on the clip | The tick goes slate | The ledger drums at the sides, faces to the camera; the notch passes the index shoe on the beat | The PAID stamp on the machine, in cream. The settlement wave is cream, never mint: it is a payment already made |
| Cannon | Two edges closing | Open brackets | The brackets on the ground lane close; flush, they are mint. The reticle mirrors them at the aim point | A bone shot with a thin uranium-green edge | The brackets open again and go slate for the barrage | The split ports low at the sides close with the brackets | The brackets on the ground lane |

Every state in the table has a sound twin, one plain effect per fact, in the player voice class. None ducks, pins or owns the music.

## 6. The first tree pick: two opposite feels

Depth 1 of each pilot's tree becomes a pair of weapon feels, one fast and light, one slow and heavy. World 1 still gives two picks and the tree keeps its two-card shape. Each row below is data: it sets the cadence fields of section 7 and nothing else. A keystone changes the shape of the damage, never the pilot's ceiling.

Each keystone takes a root's slot, so the perk that root gives today moves down to depth 2 in the same half of the tree, in the World 1 table (`NODES_WORLD_ONE`, the same way Sable's Face Runner already stands in for Live Wire). It takes the slot of a node in that half that no other module reads: the one that only adds a count where there is one, and otherwise the node named below. The moved row keeps its id, its op and its numbers.

### 6.1 The pairs

Figures are careless, skilled and most by arithmetic, as in section 1, from the same sums.

| Pilot | Fast and light | Slow and heavy |
| --- | --- | --- |
| Rivet | **Fan the Hammer** (`r_fan_hammer`). The cylinder holds 12 rounds of 6 (hot 7.2). A held button fans them, one every 0.10 s, in a 5 degree cone. Reload and notch as the baseline. 35.1, 58.4, 60.0. | **Big Iron** (`r_big_iron`). Two shells of 28.8 (hot 34.56, 1.2 times), 0.60 s apart. Each pierces one machine, throws three times the knock and breaks props one heft tier up. Reload and notch as the baseline. 37.2, 70.5 (2 × 34.56 / 0.98 s), 70.5. |
| Sable | **Static Flutter** (`s_static_flutter`). A press flutters three sparks of 3. The charge fills in 0.40 s and lets go as six pulses of 4 over 0.5 s; the trigger is ready 0.12 s after release while the pulses run on. 30.0, 68.8 at blazing, 68.8. | **Rail Lance** (`s_rail_lance`). The charge takes 1.00 s and lets go one bolt of 42 that passes through two machines and does not chain. 26.7, 64.1 at blazing, 64.1. |
| Kest | **Cluster** (`k_cluster`). Each throw scatters three small charges of 3.85 (snapped 7.7) that share one window. With all three on one target: 19.3, 38.5, 38.5. | **Keg** (`k_keg`). One live charge at a time, 1.40 s between throws, 24 (snapped 48), twice the blast radius, and it breaks props one heft tier up. 17.1, 34.3, 34.3. |
| Tarn | **Saw Flurry** (`t_saw_flurry`). Every beat does half the damage on half the floor: 9, 11, then 21.5 + 0.25 × speed. The window opens 0.20 s after beat two and keeps its 0.24 s width. Every fifth hit pierces. 40.0, 66.7, 72.6. | **Guillotine** (`t_guillotine`). Beats one and two keep their damage on floors of 0.60 s and 0.70 s. The window opens at 0.40 s. The third beat is 60 + 0.8 × speed (71.2 at cruise, 84.0 at most), in a 7 m cone, three times the knock, and breaks props one heft tier up; 0.60 s follows it. 30.8, 69.5, 77.5. |
| Tally | **Petty Cash** (`tl_petty_cash`). A cast costs half a pressure and does half the damage (11). The window opens at 0.25 s and closes at 0.45 s. A stamp is 13.2 and refunds a quarter. Sustained 11.0, 24.9 to 26.1, 26.4. Most in one second 66.0: five stamps at 0, 0.25, 0.50, 0.75 and 1.00 s, with both ends of the second counted (52.8 if the last is left out). | **Compound Interest** (`tl_compound_interest`). The window opens at 0.55 s and closes at 0.75 s. Each stamp in a row adds 8 (30, then 38 at most) and refunds a quarter. Sustained 11.0, 19.7 to 20.8, 25.3. Most in one second 76.0. |
| Cannon | **Snap Battery** (`c_snap_battery`). The lock is 0.15 s to 0.31 s and 0.40 s passes between shots. Pulse 9, rail 26, barrage 16. 22.5, 47.3, 47.3. | **Siege Rail** (`c_siege_rail`). The lock is 0.60 s to 0.76 s and 1.00 s passes between shots. The rail is 66, half as wide, 40 m long, and breaks props one heft tier up. Pulse 16, barrage 30. 16.0, 41.3, 41.3. |

Three notes on the table:

- Sable's two keystones both keep `mass_launch`, the weight launch that both of her roots set today, so no Sable run loses it.
- Sable's keystones change the mounted weapon too, so one run has one feel on the ball and on the perch. Mounted Static Flutter keeps three sparks of 3 and lets go six pulses of 4.5: 30.0 careless, (9 + 27) / 0.48 = 75.0 for 3 s after a blazing plant, 52.9 after. Mounted Rail Lance has a spark of 9 and a bolt of 45 that passes through two machines and does not chain: 30.0, 54 / 0.78 = 69.2, then 42.2. Both stay under the mounted ceiling of 80.
- Kest's fast keystone is named Cluster because `k_carpet`, Carpet Bomb, is already a deeper Kest node. A parked depth-4 node, `k_sticky_rain`, says the same thing in words ("each throw scatters three smaller charges"). World 1 never offers it; the unit that reopens worlds 2 and 3 re-cuts that row.
- All twelve new ids were checked against every row in `src/core/trees/` and `world_one_cards.gd` at `c0a4bba6f`: none is in use.
- The heavy keystones may pass Tarn's baseline hit. Tarn's own Guillotine, at 84.0, is the heaviest hit any first pick gives.
- Start names are three words or fewer. The card's one line is unit E2-09's to write and to hold to the eight-word limit. A run's first pick is read before the pilot has fired, so each card says its effect in words the pilot card already uses, and shows the trigger as a picture before a word (LEGIBILITY section 13, carrier order).

### 6.2 Where each root's perk goes

| Pilot | Keystone in the left root | Root perk it displaces | The perk moves to | Keystone in the right root | Root perk it displaces | The perk moves to |
| --- | --- | --- | --- | --- | --- | --- |
| Rivet | Fan the Hammer | `r_gunline`, Gunline: the weapon fires twin rounds at 0.6 times each | The slot of `r_tracer`, Tracer Rounds. The half has no count-only node, and Run and Gun must stay: the wear trail reads it | Big Iron | `r_juggernaut`, Juggernaut: starting a sprint blasts machines back | The slot of `r_ram_fins`, Ram Fins. Second Wind is the half's count-only node, and it must stay: the Riveted Shell reads it |
| Sable | Static Flutter | `s_cannonball`, Cannonball: vault kicks set off a small discharge | The slot of `s_coil_hook`, Coil Hook. The half has no count-only node; Coil Hook is a flat fling scalar | Rail Lance | `s_beachhead`, Beachhead: plant a pylon from twice as far | The slot of `s_arc_nest`, Arc Nest, which only adds one turret chain jump |
| Kest | Cluster | `k_trapper`, Trapper: charges wait longer and five can be live | The slot of `k_demo_expert`, Demo Expert, which only raises the slam's charge count to five | Keg | `k_ghost`, Ghost: cloaked, machines spot you only up close | The slot of `k_ambush`, Ambush. The half has no count-only node, and Smoke Trail must stay: the Riveted Shell reads it |
| Tarn | Saw Flurry | `t_long_claw`, Long Claw: sweeps reach two metres farther | The slot of `t_twin_talons`, Twin Talons, which only adds a second, lighter talon | Guillotine | `t_anchor_line`, Anchor Line: each claw pull sends a shockwave | The slot of `t_spare_claw`, Spare Claw, which only banks a second claw pull |
| Tally | Petty Cash | `tl_audit_stamp`, Audit Stamp: stamp slams send a shockwave | The slot of `tl_line_feed`, Line Feed. The half has no count-only node; Line Feed is the same shockwave on a rarer event | Compound Interest | `tl_steam_bank`, Steam Bank: bank two flywheel surges | The slot of `tl_spring_vent`, Spring Vent. The half has no count-only node; Corner Plate stays because a surge pays pressure |
| Cannon | Snap Battery | `c_quick_lane`, Quick Lane: call lanes a quarter faster | The slot of `c_spare_kick`, Spare Kick, which only banks a second recoil kick | Siege Rail | `c_brace_kick`, Brace Kick: every plate refills a recoil kick | The slot of `c_spare_plate`, Spare Plate, which only banks a second plate |

**Four World 1 nodes are read by other modules, and none of them moves or leaves.** Each keeps its id and its slot, so the code that reads it needs no change.

| Node | Slot | What reads it | After this change it is offered under |
| --- | --- | --- | --- |
| `s_face_runner`, Face Runner | Index 3, left half | The Riveted Shell's air-control inversion S4 (`build.gd`), on by default with `--hotwire-shell` | Static Flutter |
| `r_second_wind`, Second Wind | Index 5, right half | The Riveted Shell's inversion R6 (`build.gd`): sprinting, you steer freely in the air | Big Iron |
| `k_smoke_trail`, Smoke Trail | Index 4, right half | The Riveted Shell's inversion K5 (`build.gd`): steer sharper while you glide | Keg |
| `r_run_gun`, Run and Gun | Index 3, left half | The wear trail (`src/combat/wear_trail.gd`) | Fan the Hammer |

So `build.gd`, the three shell rows of `world_one_cards.gd` (`UNFITTED_ROWS` included) and `wear_trail.gd` are untouched. What does change, on purpose, in unit E2-09: a depth-2 node is offered only under its own root (`upgrade_tree.gd` `_pair_indices`), so the pick paths that reach the three inversions start with a keystone. The hotwire tests reach them today through `r_juggernaut`, `k_ghost` and `s_cannonball` (`hotwire_cue_test`, `hotwire_r6_test`, `hotwire_k5_test`, `hotwire_s4_test`, `hotwire_shell_held_test`); those paths become Big Iron, Keg and Static Flutter, and the K5 test's control path, which picks Ambush today, picks Ghost. The tests that pin the World 1 tables (`world_one_rtree_test`, `world_one_ktree_test`, `world_one_stree_test`, `sable_kit_test`, `tree_data_test`, `tree_safe_picks_test`) are re-cut in the same unit.

The twelve nodes that give up a depth-2 slot leave the World 1 table: `r_tracer`, `r_ram_fins`, `s_coil_hook`, `s_arc_nest`, `k_demo_expert`, `k_ambush`, `t_twin_talons`, `t_spare_claw`, `tl_line_feed`, `tl_spring_vent`, `c_spare_kick` and `c_spare_plate`. No module outside the tree files and `world_one_cards.gd` reads any of them. Their rows stay in the tree files, and where they sit in the full tree is for the unit that reopens worlds 2 and 3.

**A moved perk is an upgrade, and upgrades sit outside section 1.** The ceilings bind a weapon with no upgrades and each keystone alone. A moved perk is offered only under its keystone, so the build a World 1 run can reach is the keystone with the perk. The one that passes a ceiling is the Cannon's. Under the lock trigger, Quick Lane's "a quarter faster" divides the time between shots by 1.25. On the baseline Cannon that would be 0.70 s to 0.56 s and 42 / 0.86 = 48.8, under 50, but World 1 cannot reach that build. Under Snap Battery, where Quick Lane now sits, it is 0.40 s to 0.32 s and 26 / 0.47 = **55.3**. `weapon_envelope_test` holds the ceiling of 50 on the baseline and on each keystone with no depth-2 pick; Snap Battery with Quick Lane is read in calibration as any upgraded build is.

## 7. The data a weapon row carries

`Pattern` (`src/combat/pattern.gd`) gains the cadence fields below. A tree row, a relic or a transformer sets them the way it sets `count` or `rate` today, so a first pick changes the trigger with no code. Unit E1-01 settles the spellings and the clamps; this page fixes what each field means.

| Field | Meaning | Used by |
| --- | --- | --- |
| `trigger` | The trigger mode: `hold_auto`, `press`, `tap_charge`, `lob_snap`, `beats`, `stamp` or `lock` | All |
| `floor_s` | The least time between two shots, casts or throws; per beat for `beats` | All |
| `mag`, `reload_s` | Rounds before a reload, and the reload's length | `press` |
| `window_s` | Open and close times after the window's opening event | All but `tap_charge` and `hold_auto` |
| `window_mult` | What a hit through the window does, as a multiple of the plain hit | `press`, `lob_snap`, `stamp` |
| `charge_s`, `charge_min` | Seconds to a full charge at the walk rate, and the least fraction that fires | `tap_charge` |
| `recover_s` | Time after a heavy shot before the trigger is ready | `tap_charge`, `beats`, `lock` |
| `refund` | Pressure a stamp gives back, never more than it cost | `stamp` |
| `fan` | A held button repeats at half the floor and half the damage | `press` |

The weapon module (`src/combat/weapon_driver.gd`) owns every timer and count in sections 2 and 3. Combat makes one call into it per tick and gets back the shots to fire. The reticle, the sound twins and the flume Warden's `base_dps` each read one public state call. Nothing reaches into its members, and it is a plain object per combat instance with no statics, so it needs no reset between warm-batched tests.

## 8. Bots, tests and models

- **Bots.** `tools/skill_band.gd` gains one dial, the share of windows hit. Start values for the Gate to confirm: Novice 15%, Learner 45% at attempt 5, Expert 85%. The hands a bot needs are: press at a rate and press in the notch (Rivet); tap, hold and release on a charge fraction (Sable); press in the charge's window (Kest); press the third beat (Tarn); press the stamp (Tally); release on the lock (Cannon). A missed window for a bot is what it is for a player: the plain result.
- **Tests.** `weapon_envelope_test` holds section 1. `weapon_cadence_test` holds each cycle's timers, the one-press rule, the buffer and a press acting inside 100 ms. The kit tests that pin today's numbers are re-cut on purpose by the unit that changes each weapon.
- **Models.** `WeaponCadence.tla` holds six rules: no shot leaves outside play; every trigger is at rest after every attempt boundary; every interruption returns the trigger to ready in bounded steps; one press gives at most one volley on a one-shot weapon; a window pays at most once; and Tally's refund never exceeds what the stamp spent. `DeferredEffects.tla` keeps proc depth at one.

## 9. Assumptions Andrew can overturn

Each is a taste call taken inside ruling ek.

1. The numbers in sections 3 and 6. They were chosen to sit inside ruling ek's careless and skilled ranges and under its ceilings; calibration tunes inside them once, last (ruling cy).
2. A window takes one press, and a press before it opens spends it. Without this, mashing hits every window.
3. Rivet has no reload key and a held button fires one round. The fan is the hold's use.
4. Rivet's sprint fan adds pace and no damage a second. The fast keystone is where the fan becomes the weapon.
5. Sable's charge rate comes from the speed tier alone, wherever the ball is. Being in the air or on the harpoon gives no bonus of its own.
6. A late release never costs Sable anything. Her skill is the tick and the speed.
7. Mounted, Sable's fast charge lasts 3 s after the plant.
8. Kest's window lies inside her throw floor, and a snap does not refresh her rocket jump.
9. Tarn's third beat counts speed to 30 m/s and no further, so his ceiling holds at any speed.
10. Tally's cast reaches full weight at cruise and grows no further with speed. Today it grows to 56 at 38 m/s. Holding the ceilings at every speed is worth more than the scaling, and pressure already asks for cruise.
11. Tally's burst limit is read as the most damage in any one second, which is how today's three casts in 0.8 s make 80.4.
12. The Cannon's rail gives no recoil kick. Movement stays the pilot's.
13. Which node gives up its depth-2 slot, in the halves of section 6.2 where the choice is free. Tracer Rounds, Ram Fins and Ambush leave World 1 so that Run and Gun, Second Wind and Smoke Trail can stay.
14. Snap Battery with Quick Lane reaches 55.3, above the Cannon's unupgraded ceiling of 50. If that is too much, Quick Lane's share under the lock trigger is the number to cut.
15. Sable's keystones change the mounted weapon as well as the one on the ball.
16. Tally's pressure is a fraction that fills at 0.5 a second, and the pips show the part-filled one.

## How the figures were checked

Every figure in sections 1, 3 and 6 comes from one short script that recomputes each cycle from the timers in its table. It also sweeps Sable's charge fraction for the best cycle and walks Tally's pressure tick by tick. It ran on 22 November 2026 and is not in the repository; the sums are written out above so a reader can redo each one by hand. Nothing here was run in Godot, and no sum shows how a weapon feels to play.
