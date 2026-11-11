# FIRST-TIMER audit

Result: PASS. Runs: Sable seed 1 to stage 3, Rivet seed 1 to stage 3, Kest seed 1 to stage 3, Tarn seed 1 to stage 3, Tally seed 1 to stage 3, Cannon seed 1 to stage 3.

| Mechanic | Needed | Verdict per pilot | First needed | First taught by |
|---|---|---|---|---|
| Roll and steer the ball | required | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 0.0 s | prompt:roll 0.0 s |
| Break the Warden at the beacon | required | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 75.0 s | objective:find_warden 0.0 s |
| Slam the open core | required | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 239.7 s | prompt:slam 239.7 s |
| Roll through a reward gate | required | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 143.4 s | objective:roll_gate 143.4 s |
| Stagger Brindle and smash the opening | required | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 265.3 s | objective:shoot_magnets 260.9 s |
| Run again after being scrapped | required | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached |  | nothing  |
| Harpoon an enemy | optional | Sable: taught in time; Rivet: taught in time; Kest: taught in time; Tarn: taught in time; Tally: taught in time; Cannon: taught in time | 54.9 s | prompt:harpoon 5.9 s |
| Hook the world and swing | optional | Sable: not reached; Rivet: taught in time; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached | 270.9 s | prompt:harpoon 6.0 s |
| Wall grip: stay fast and walls hold | optional | Sable: needed before it is taught; Rivet: taught in time; Kest: taught in time; Tarn: needed before it is taught; Tally: needed before it is taught; Cannon: taught in time | 7.2 s | prompt:tip_grip 8.9 s |
| Jam fields lock slots 2 and 3 | optional | Sable: not reached; Rivet: not reached; Kest: needed before it is taught; Tarn: not reached; Tally: not reached; Cannon: needed before it is taught | 209.1 s | prompt:tip_jam 239.5 s |
| Cast times: a knock drops a cast | optional | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: needed before it is taught; Cannon: not reached | 7.9 s | prompt:tip_cast 8.9 s |
| Radio dial: . next, , back, / skip | optional | Sable: needed before it is taught; Rivet: needed before it is taught; Kest: needed before it is taught; Tarn: needed before it is taught; Tally: needed before it is taught; Cannon: needed before it is taught | 0.0 s | prompt:tip_radio 3.4 s |
| Relay stakes: hold E at the mast | optional | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached |  | nothing  |
| SPIL-9: the next ram calls it in | optional | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached |  | nothing  |
| Actives on F | optional | Sable: needed before it is taught; Rivet: needed before it is taught; Kest: needed before it is taught; Tarn: needed before it is taught; Tally: needed before it is taught; Cannon: needed before it is taught | 0.0 s | prompt:tip_active 6.1 s |
| Scrap makes you heavier | optional | Sable: never taught; Rivet: never taught; Kest: never taught; Tarn: never taught; Tally: never taught; Cannon: never taught | 0.9 s | nothing  |
| Buy from Moss with cogs | optional | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached |  | nothing  |
| Camp between runs | optional | Sable: not reached; Rivet: not reached; Kest: not reached; Tarn: not reached; Tally: not reached; Cannon: not reached |  | nothing  |

- Stagger Brindle and smash the opening: On the park table Brindle's plate names each phase's loop from the arena's first frame (phase 1: "Shoot magnets, then cockpit", objectives.gd's boss rows); the legacy table carried it over from the Warden fights.
- Run again after being scrapped: A death with no earned save ends the run (no free retry), so the lesson is RUN OVER itself: its line naming what scrapped you and its Run again key. A run with no death reads "not reached"; --scrap-at=<s> scraps each pilot that many seconds into stage 1 to measure it.
- Wall grip: stay fast and walls hold: Optional because it is a bonus, not a gate: the run goes on without carving. Taught by the first-meet tip (ui/field_tips.gd), queued when the ball first carves a wall and counted once its toast has been on screen 0.4 s; another tip or toast up at the time delays it.
- Jam fields lock slots 2 and 3: Optional: the jammer's mat sits in a Dig stage the two-stage bot run may not enter, and a fast ball slips its pulse. Taught by the first-meet tip, queued when a pulse first jams the ball.
- Cast times: a knock drops a cast: Optional: only some slot abilities carry a cast time and the bot seldom picks them. Taught by the first-meet tip from the drop when the bar already holds a slot with a cast time (Tally's Gather Plate), else when a cast first starts. It waits behind any tip met now (the radio's, the grip's) and behind a Warden fight, so a cast-slot pilot can cast before the tip shows and the audit reads it late.
- Radio dial: . next, , back, / skip: Optional: the run goes on without touching the radio; the dial only changes the music. Taught by the first-meet tip, which waits for the drop's stage card to clear and then counts once its toast has been on screen 0.4 s, so it comes a few seconds after the dial's first frame and the audit reads it late.
- Relay stakes: hold E at the mast: Optional: a relay is a park site the bot does not seek out. Taught by the first-meet tip from 30 m of a stake post; the probe counts the post met at E's 18 m lock reach, which a fast ball can reach before the tip has been up 0.4 s.
- SPIL-9: the next ram calls it in: Optional: the halo only charges with a companion seated, and a run starts without one. Taught by the first-meet tip, queued when the halo fills.
- Actives on F: Optional: a run starts with an active racked (the actives launch option is on by default, tuning.gd), but nothing needs one. Taught by the first-meet tip, queued when one is first racked, so it comes a few seconds after the drop.
- Scrap makes you heavier: The "Scrap = heft" first-run callout (ui/callouts.gd) was retired with the old HUD (design-v3/LEGIBILITY.md item 33) and nothing replaced it.
- Buy from Moss with cogs: The bay is labelled "Moss's workshop"; nothing says what cogs buy or how to buy.
- Camp between runs: Outside a run: the title page's Camp button (K). The probe does not reach it.
