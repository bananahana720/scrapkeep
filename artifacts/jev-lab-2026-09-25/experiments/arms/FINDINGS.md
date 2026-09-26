# Gameplay findings for Andrew's next play (JL-28, DoD 2)

**Automated; not a feel verdict.** Everything here comes from headless bot play: the scripted and random arms driving each lab's steering, or source reading. It tells you where to look, not how it feels.

Labels: **observed** means counted from retained files or read from source; **inference** means reasoned from those; **unretained** means seen during development with no output kept. "JL-28" gives the Phase B number that bears on a finding (from [RESULTS.md](RESULTS.md)), or "not re-measured".

Launch any sketch with `scrapkeep play ball-lab`, `scrapkeep play cable-bench` or `scrapkeep play spillway-drop`. Tab switches between kinematic and rigid physics in all three, keeping position and velocity. Cable Bench and Spillway start in rigid; the ball-lab HUD shows the current mode.

## Try first

1. Cable Bench, rigid: the ball can fall through the ground near x −34, and the stage then counts the run as cleared.
2. Spillway: stomping a chaser costs HP, and the ball dies in most runs.
3. Cable Bench: about half of all knocks come with a hit on you.
4. ball-lab, rigid: a stomp landed dead centre on a dummy does not count.
5. ball-lab: no bot has ever reached the bench. Can you?

## ball-lab

Automated; not a feel verdict.

**B1. A centred stomp is not credited in rigid mode.**

- **Claim:** in rigid mode, landing dead centre on a dummy from above gives no knock, because the touch check reads the velocity after the bounce.
- **Try:** `scrapkeep play ball-lab`, Tab until the HUD says rigid, jump and land squarely on top of a dummy; then Tab to kinematic and repeat.
- **Look for:** no knock and no air jump back in rigid; a knock in kinematic.
- **Evidence:** observed. The lab's test keeps it as a named known limit and a review confirmed it (EV-0531, EV-0534); from JL-13, before the current epoch.
- **JL-28:** rigid stomp knocks were 0.30 to 1.40 per trial against 3.00 to 11.10 in kinematic, across the four ball-lab scenarios. That fits the finding but does not prove it.

**B2. Rolling on flat ground in rigid mode flickers "grounded".**

- **Claim:** rigid mode's grounded flag drops while rolling on flat ground, which switches drive to air control and flickers jump and brake.
- **Try:** `scrapkeep play ball-lab`, rigid, roll across flat ground at cruise, then press Space to jump and brake mid-roll.
- **Look for:** drive going soft and a jump that doesn't fire.
- **Evidence:** observed flag behaviour (EV-0531, EV-0534). That the ground probe rotating with the body causes it is inference.
- **JL-28:** not re-measured.

**B3. The service ramp ends in a step of about 1.6 m.**

- **Claim:** the top of the service ramp is a step, not a smooth lip.
- **Try:** `scrapkeep play ball-lab`, either mode, drive up the service ramp at x 50, z 76 at cruise.
- **Look for:** a bump or stop at the top.
- **Evidence:** observed, measured by the JL-13 review (EV-0534).
- **JL-28:** not re-measured.

**B4. The raised ends of tilted boxes trap the ball in kinematic mode.**

- **Claim:** the raised ends leave wedge gaps narrower than the ball. A pinned kinematic ball reports rising speed and a cruise tier while not moving.
- **Try:** `scrapkeep play ball-lab`, kinematic, drive into the raised end of a tilted box.
- **Look for:** stuck in place while the HUD speed climbs.
- **Evidence:** observed (EV-0534).
- **JL-28:** kinematic stuck episodes were 1.75 and 1.85 per trial on bench-climb and 2.42 and 1.90 on pillar-weave (scripted, random). Where the ball got stuck was not recorded.

**B5. No bot has reached the bench.**

- **Claim:** the bench stays unreached by both arms. The kicker offer requires a decision-time speed that the run-up never has.
- **Try:** `scrapkeep play ball-lab`, both modes, try for the bench by the steep kicker (about x 30, z 45) and by the service ramp, from a standstill and after a long run-up.
- **Look for:** whether you make it, and how fast you were going at the lip.
- **Evidence:** observed. Bench-climb 0 of 80 at this epoch and 0 of 80 in JL-21; the gate mechanism is read from source (JL-21 review F4).
- **JL-28:** 0 of 80 again (both arms, both modes, 20 trials each).

**B6. Attacking every dummy in reach costs the weave.**

- **Claim:** a player who stomps any dummy within reach loses the pillar weave to one who mixes attacking with pushing on.
- **Try:** `scrapkeep play ball-lab`, kinematic, run the pillar weave twice: once attacking every dummy that closes in, once ignoring them.
- **Look for:** how many gates you pass each way.
- **Evidence:** observed, a pre-registered result. The rule ladder cleared pillar-weave kinematic 4 of 40 against 22 of 40 for random choices, and run-to-pad rigid 12 of 40 against 38 of 40 (both SUPPORTED, RESULTS.md). Reading this as a lesson for a person is inference.
- **JL-28:** as above; gates mean 2.27 against 3.33 on the weave.

**B7. Dummies never die.**

- **Claim:** a knocked dummy comes back every time and chases without end.
- **Try:** `scrapkeep play ball-lab`, knock the same dummy three or four times.
- **Look for:** whether an endless chaser feels right for a practice field.
- **Evidence:** observed from source (JL-21 review F1).
- **JL-28:** not re-measured (design fact).

## Cable Bench

Automated; not a feel verdict.

**C1. In rigid mode the ball can fall through the ground near x −34, and the stage counts it as a clear.**

- **Claim:** a slow rigid ball tunnelled through the terrain twice, fell at the 80 m/s overspeed limit to thousands of metres below, and the scenario then recorded a stage clear or forge clear.
- **Try:** `scrapkeep play cable-bench` (starts rigid), roll slowly at walk speed near (−34, 15, 47) on the climb and near (−34, 55, −138) near the forge; Tab to kinematic and repeat.
- **Look for:** the ball dropping through the ground, and whether the forge charge or stage clear still counts afterwards.
- **Evidence:** observed. Phase B trials `cb-stage-run-rigid` scripted seed 2019 and `cb-forge-charge-rigid` random seed 2015 have a `tunnel` event, then `overspeed` events at y −183 m and −145 m, then `success` (RESULTS.md, Phase B observations). The sketch shows no coordinates, so the position needs a debug readout. That both tunnels are one seam at x ≈ −34 is inference, and so is the claim that the forge charge counts horizontal position only.
- **JL-28:** 2 of 1080 trials, both rigid Cable Bench, and they are the only recorded clears on those two scenarios. No real full-stage or forge clear happened.

**C2. On bench-one, committing to the road beats wandering.**

- **Claim:** the rule ladder (finish, attack in reach, kicker at speed, push on) reached the bench-one goal far more often than random choices, and random choices died more.
- **Try:** `scrapkeep play cable-bench`, Tab to kinematic, run bench-one pushing straight along the road, then again taking every side option.
- **Look for:** how often the detours get you caught.
- **Evidence:** observed, a pre-registered result. Scripted 48 of 80 against random 23 of 80 (SUPPORTED, Holm p 2.6e-4); deaths 15 of 80 against 35 of 80. Why it holds for a person is inference.
- **JL-28:** as above. Rigid bench-one did not resolve: 4 of 40 against 1 of 40, deaths 35 and 37 of 40.

**C3. Knocking a foe usually costs you HP.**

- **Claim:** about half of all knocks, and most rams, land within 3 ticks of a foe's contact hit on the ball.
- **Try:** `scrapkeep play cable-bench`, either mode, stomp and ram chasers while watching HP.
- **Look for:** HP dropping at the moment of the knock.
- **Evidence:** observed coincidence in JL-26-A2 (513 of 1025 knocks kinematic, 120 of 241 rigid; `live/JL-26/findings.md` 1). That the contact radius covers a touching ball is inference.
- **JL-28:** not re-measured (the pinned analysis does not count the coincidence). Bench-one kinematic knocks were 4.86 and 6.26 stomps per trial.

**C4. Rigid climbs road 0 near chaser speed.**

- **Claim:** in rigid, the road-0 climb runs at a median 7.1 m/s, with 48% of samples under the chaser's 7 m/s.
- **Try:** `scrapkeep play cable-bench` (rigid), climb road 0 with chasers behind; Tab to kinematic and repeat.
- **Look for:** chasers catching you on the climb in rigid only.
- **Evidence:** observed speeds (`live/JL-26/findings.md` 2). That rigid physics alone causes it is inference.
- **JL-28:** not re-measured. Rigid bench-one deaths were 35 and 37 of 40, against 15 and 35 of 80 in kinematic.

**C5. The full stage and the forge charge were never really cleared.**

- **Claim:** no bot reached the forge on the full stage, so the cache-versus-clock choice never came up, and the forge charge at tier 1 was never survived (2.5 to 3.3 miniboss hits per trial).
- **Try:** `scrapkeep play cable-bench`, play the whole stage and the forge charge.
- **Look for:** whether you reach the "one more cache" decision, and how the miniboss lands its hits.
- **Evidence:** observed, 0 of 80 each in A1 and A2 (`live/JL-26/findings.md` 3 and 4). Blaming the bots' steering rather than the stage is inference.
- **JL-28:** 0 of 80 real clears on each (see C1 for the two artifacts). 159 of 160 trials across both scenarios died.

**C6. A committed kicker run-up far overshoots.**

- **Claim:** a full run-up arrives at 38 to 45 m/s in kinematic and about 35 in rigid, against the README's "26 m/s clears the gap".
- **Try:** `scrapkeep play cable-bench`, take the kicker to the east ledge with full boost.
- **Look for:** overshooting the ledge.
- **Evidence:** observed (`live/JL-26/findings.md` 5).
- **JL-28:** not re-measured.

**C7. Stomp and ram are harder to get in rigid.**

- **Claim:** the offer gates keep 0.80 of stomp offers in rigid against 0.97 in kinematic, and ram is mostly gated in both.
- **Try:** `scrapkeep play cable-bench`, rigid, try to stomp from a roll and to ram at speed; Tab to kinematic and compare.
- **Look for:** a jump that isn't there when you want to stomp.
- **Evidence:** observed shares (`live/JL-26/findings.md` 6). The link to B2's grounded flicker is inference.
- **JL-28:** not re-measured.

## Spillway Drop

Automated; not a feel verdict.

**S1. The ball dies in most runs, and stomps cost HP.**

- **Claim:** most runs end in death. A stomp costs HP because the rebound keeps horizontal velocity, so the ball never leaves the chaser's 2.6 m reach.
- **Try:** `scrapkeep play spillway-drop` (starts rigid), stomp chasers on the climb while watching HP; Tab to kinematic and repeat.
- **Look for:** HP loss on every stomp, and how soon the run ends.
- **Evidence:** observed deaths and HP per hold (5.0 to 8.6 per stomp hold, `live/JL-27/findings-a3.md`). The rebound mechanism is inference from source.
- **JL-28:**
  - Mid-climb kinematic deaths 20 of 80 (scripted) and 34 of 80 (random); rigid 19 and 17 of 20.
  - Flood-hatch kinematic 10 and 19 of 20; rigid 20 and 20.

**S2. The chute beats the bypass.**

- **Claim:** with the director paused, the chute climb takes 1600 ticks (kinematic) and 1236 (rigid); the bypass takes 2263 and 2985.
- **Try:** `scrapkeep play spillway-drop`, climb once by the chute and once by the bypass.
- **Look for:** whether the bypass ever feels worth taking.
- **Evidence:** observed (`live/JL-27/findings.md` 2).
- **JL-28:** not re-measured.

**S3. A 6 m kerb blocks the bypass.**

- **Claim:** a kerb rising 1.3 m per metre to 6 m stands between the bypass ramp and every shelf.
- **Try:** `scrapkeep play spillway-drop`, rigid, take the bypass slowly.
- **Look for:** the ball riding up the kerb face and falling back.
- **Evidence:** observed from source (`terrain.gd`, `live/JL-27/findings-a3.md`). The slow rigid ball falling back for 30 s is unretained.
- **JL-28:** not re-measured.

**S4. The mid shelf has one clear east-west line.**

- **Claim:** the chute channel and the east bench cut the mid shelf, leaving one clear line north of z ≈ −4.
- **Try:** `scrapkeep play spillway-drop`, cross the mid shelf from the bypass side.
- **Look for:** dropping into the chute or stopping against the bench end.
- **Evidence:** observed from source (`live/JL-27/findings.md` 4). The drops seen during development are unretained.
- **JL-28:** not re-measured.

**S5. After death in the flood, the water keeps pushing the ball.**

- **Claim:** once the ball dies in the flood, the stage stops refreshing its external force, so the last push carries on and can throw the ball out of bounds.
- **Try:** `scrapkeep play spillway-drop`, die in the rising water and keep watching.
- **Look for:** the dead ball drifting or rising away.
- **Evidence:** observed anomalies after death in A1 and A2 (`live/JL-27/findings.md` 5). The cause in `stage.gd` is inference from source.
- **JL-28:** 0 anomalies in 320 Spillway trials, as expected: the lab now ends a trial at death, so it cannot see this.

**S6. Ram is almost never offered.**

- **Claim:** ram survives the offer gate in 0.3 to 15.8% of offers, because the gate reads the tier left by the previous hold.
- **Try:** `scrapkeep play spillway-drop`, get to speed and ram a chaser.
- **Look for:** whether ramming feels available in play (a person is not gated this way).
- **Evidence:** observed shares (`live/JL-27/findings-a3.md`). The gate mechanism is inference from source.
- **JL-28:** not re-measured.

**S7. The stage's own exit test flakes.**

- **Claim:** `exit_test.gd` fails about 1 run in 4 to 6 on the unmodified proto build too. It reads the position one frame before a rigid teleport lands.
- **Try:** run the stage's tests a few times (`scrapkeep test spillway-drop`).
- **Look for:** an intermittent `exit_test` failure.
- **Evidence:** observed (EV-0559).
- **JL-28:** not re-measured.

## Phase B observations, not pre-registered

Automated; not a feel verdict.

- **Tunnelling on Cable Bench rigid** is C1 above: new in Phase B, 2 of 1080 trials, both credited as clears.
- **Flood-hatch kinematic:** scripted 10 of 20 against random 1 of 20. Exploratory, two-sided p 0.004, not a test. If it matters for play, it says that pushing on and finishing wounded chasers beats improvising in the flood run (inference).
- **Stuck episodes:**
  - Random choices stick more on Cable Bench bench-one (6.99 against 2.86 per trial, kinematic) and on ball-lab rigid.
  - The scripted ladder sticks more on Spillway kinematic.
  - Where the ball sticks was not recorded.
- **Blazing speed is rare everywhere:** ball-lab reaches it in almost no sample (at most 0.8%), Spillway 0 to 3%, Cable Bench up to 10%. Whether blazing is worth having in ball-lab is a design question for play.
