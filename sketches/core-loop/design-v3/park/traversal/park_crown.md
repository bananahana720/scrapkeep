# Traversal: stage 6, the crown (`park_crown`)

## Round 2 on the final geometry, 12 October 2026

FAIL. Runtime head `3614577b2f3863f26463cc220c1c45187afbebdd`. Final documentation commit is named in the round report.
Untraced eight-seed batches: 7/7. Warden breaks: 3/3. Evidence level 4, automated native play. The greybox is not admitted when any batch band misses. Dressing has not started.
Evidence: `/home/andrew/scratch/w13/sol/kd6-crown-r2`. Tool SHA256 f013f06048853958072dbe3dbcb70d17d040c33b393cfe5b1cc1d0dca02ca2c2. All runtime inputs remain byte-identical to 3614577.
Judge bands from the untraced batch under the standing coordinator ruling. Every reproduced solo uses the same fixed export and 90 Hz; its input-equality comparison is in determinism.json. No pre-3614577 traversal result is reused for acceptance. The floor uses the final-head Rivet reference and is gated only by its own row.

Cells: median (worst seed where the band judges it), verdict.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; reported, pilot band, not the floor's |
| time_to_warden_s | 65.49 (66.75); PASS | 72.48 (72.86); PASS | 69.925 (71.38); PASS | 83.61 (85.03); PASS | 82.67 (84.23); PASS | 80.66 (82.56); PASS | 60.01 (63.34); reported, pilot band, not the floor's |
| segment_s | 17.71 / 17.74 / 29.8 (29.795); PASS | 16.57 / 39.31 / 16.68 (39.315); PASS | 16.28 / 19.65 / 34.2 (34.2); PASS | 15.01 / 36.89 / 31.47 (36.885); PASS | 16.82 / 38.45 / 27.08 (38.455); PASS | 15.93 / 38.31 / 26.77 (38.305); PASS | 21.13 / 22.09 / 16.75 (22.09); reported, pilot band, not the floor's |
| flow_share | 0.9469 (0.9448); PASS | 0.8783 (0.8751); PASS | 0.8709 (0.8386); PASS | 0.9517 (0.9071); PASS | 0.8217 (0.8031); PASS | 0.9226 (0.9043); PASS | 0.9315 (0.9117); reported, pilot band, not the floor's |
| airborne_share | 0.231; MISS | 0.2974; PASS | 0.236; MISS | 0.2074; MISS | 0.3486; PASS | 0.3611; PASS | 0.1431; reported, pilot band, not the floor's |
| dead_stops | 0 (0); PASS | 0 (0); PASS | 0 (0); PASS | 0 (1); MISS | 0 (0); PASS | 0 (0); PASS | 0 (0); reported, pilot band, not the floor's |
| peak_speed_mps | 54.85 (54.02); PASS | 43.72 (43.18); PASS | 39.055 (39.05); PASS | 42.375 (38.53); PASS | 44.62 (43.37); PASS | 42.75 (38.04); PASS | 43.72 (43.03); reported, pilot band, not the floor's |
| tier3_s | 39.21; PASS | 14.61; PASS | 7.945; PASS | 8.41; PASS | 8.41; PASS | 8.665; PASS | 18.43; reported, pilot band, not the floor's |
| quiet_max_s | 7.69 (8.3); PASS | 6.43 (6.6); PASS | 4.89 (6.06); PASS | 5.51 (5.82); PASS | 5.8 (6.86); PASS | 10.545 (10.76); PASS | 6.14 (6.14); reported, pilot band, not the floor's |
| max_anchor_gap_m | 44.7 (72.1); MISS | 36.05 (37.1); PASS | 26.2 (31.2); PASS | 21.45 (23.8); PASS | 36.7 (36.8); PASS | 36.25 (37.2); PASS | 102.2 (102.2); reported, pilot band, not the floor's |
| distinct_verbs | 5 (5); PASS | 5 (5); PASS | 4 (4); PASS | 4 (4); PASS | 5 (5); PASS | 5 (5); PASS | 4 (4); reported, pilot band, not the floor's |
| length_ratio | 1.63; PASS | 1.32; PASS | 1.35; PASS | 1.63; PASS | 1.42; PASS | 1.45; PASS | 1.22; reported, pilot band, not the floor's |
| Distinct lines, at least 3 | 3 mutually distinct lines; PASS | | | | | | |
| Floor own row: all seeds reach, time within 2 x reference median, zero stops on every seed | | | | | | | 60.01 s, limit 144.96 s; PASS |


Distinctness compares every x/z tick within 8 m in both directions and takes the worst shared fraction over eight same-seed pairs. Sable/Tarn/Cannon form the passing witness: worst pair fractions 0.457035, 0.181152 and 0.243782, all below 0.5. This proves at least three lines, rather than the maximum over all six. The four-pilot comparison and per-seed fractions are retained in distinct-lines.json.

### Stop classification

| Line | Seed | Batch [x,z] | Batch time s | Solo classification | Enemy kind | Exempt | Trace |
| --- | --- | --- | --- | --- | --- | --- | --- |
| tarn | 1 | [11.3, -596.4] | 7.58 | enemy contact; kind unavailable | unavailable | False | /home/andrew/scratch/w13/sol/kd6-crown-r2/resume-solo-tarn-1/tarn-seed-1-trace.json |

Raw batch stops remain counted. Solo enemy contacts lack the enemy kind needed for an exemption. A non-reproducing stop remains unresolved. See stop-classification.json for contacts and velocities.

### Win proof under the 600 s wrapper

win.gd extends res://tools/bot_run.gd and sets driver.stage_limit=600.0 before its first tick, changing nothing else. Fresh single-seed processes run serially through one eight-core CPU allocation and an overall 1800 s cap. Commands and any capped retry are in commands.ndjson. The classes below are the actual seed-selected classes.

The first three-seed batch hit the 1800 s wall cap after seeds 1 and 2 completed. Its seed 3 is excluded. Seed 3 below comes from a fresh single-seed retry under the same 600 s wrapper and a separate 1800 s outer cap.

```sh
python /home/andrew/scratch/w13/sol/kd6-crown-r2/run.py command resume-win /tmp/claude-1000/w13-s/cpu_queue.sh --cores 8 --name kd6-resume-win -- timeout --signal=TERM --kill-after=10s 1800s nice -n 10 python /home/andrew/scratch/w13/sol/kd6-crown-r2/wins.py resume-win
```

Retry command:

```sh
python /home/andrew/scratch/w13/sol/kd6-crown-r2/run.py command resume-win-retry /tmp/claude-1000/w13-s/cpu_queue.sh --cores 8 --name kd6-resume-win-retry -- timeout --signal=TERM --kill-after=10s 1800s nice -n 10 python /home/andrew/scratch/w13/sol/kd6-crown-r2/win_retry.py 3
```

| Seed | Class | Engaged s | Broken s | Engage to break s | Warden damage | After break / outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | runner_gunner | 123.42 | 187.59 | 64.17 | {"ram": 700.0, "slam": 700.0} | stalled; state=gates; exit_s=600.0 |
| 2 | demolitions_caster | 137.15 | 160.23 | 23.08 | {"ram": 700.0, "slam": 700.0} | stalled; state=gates; exit_s=600.01 |
| 3 | tarn | 140.67 | 215.84 | 75.17 | {"ram": 700.0, "slam": 700.0} | stalled; state=gates; exit_s=600.01 |

```jsonl
{"boss":null,"class":"runner_gunner","game_seconds":603.2,"outcome":"stalled","play_s":599.99,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791828531-267844","seed":1,"slot_casts":{"line":7,"special":64},"stage_reached":6,"stages":[{"cap_hits":0,"cores":[],"evasions":0,"events_joined":[],"exit_s":0.0,"hits":0,"hp_lost":0.0,"magnet_stuns":0,"max_hp":100.0,"parts":[],"plants":0,"plate_slams":0,"punch_short_s":0.0,"slingshots":0,"specials":0,"stage":1,"stuck_detours":0,"thermal_rides":0,"vault_tried":false,"warden_broken_s":null,"warden_engaged_s":null,"warden_fight_s":null,"waypoints":0},{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_ends_ground":26.0,"chain_ends_paid":5.0,"cores":[],"evasions":192.0,"events_joined":[],"exit_s":600.0,"harpoon_bites":68.0,"hit_sources":{"kite_drone":9.0,"plated_brute":60.0,"warden":20.0},"hits":8.0,"hp_lost":89.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":124.78,"shred_peak":0.0,"slingshots":0,"slot_casts_line":7.0,"slot_casts_special":64.0,"specials":64.0,"stage":6,"stall_state":"gates","stuck_detours":0,"thermal_rides":0,"ultimates":3.0,"vault_tried":false,"wall_turns":50.2333333333386,"warden_broken_s":187.59,"warden_damage":{"ram":700.0,"slam":700.0},"warden_engaged_s":123.42,"warden_fight_heft":1.282,"warden_fight_s":40.0,"waypoints":0}],"ticks":54288,"ult_fill_s":[142.86,27.08,236.35],"ult_presses":3,"ult_sources":{"blazing":3.27,"chain_link":6.0,"contact":31.63,"fast":43.85,"kill":75.0,"near_miss":31.63,"shatter":24.0,"smash":115.26,"stagger":32.94},"ult_sources_first_fill":{"blazing":3.15,"contact":10.21,"fast":31.79,"kill":10.0,"near_miss":8.91,"smash":35.0,"stagger":0.94},"ultimates":3,"wall_seconds":734.96}
{"boss":null,"class":"demolitions_caster","game_seconds":602.09,"outcome":"stalled","play_s":600.0,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791829288-278285","seed":2,"slot_casts":{"line":3,"special":62},"stage_reached":6,"stages":[{"cap_hits":0,"cores":[],"evasions":0,"events_joined":[],"exit_s":0.0,"hits":0,"hp_lost":0.0,"magnet_stuns":0,"max_hp":100.0,"parts":[],"plants":0,"plate_slams":0,"punch_short_s":0.0,"slingshots":0,"specials":0,"stage":1,"stuck_detours":0,"thermal_rides":0,"vault_tried":false,"warden_broken_s":null,"warden_engaged_s":null,"warden_fight_s":null,"waypoints":0},{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_ends_dry_fire":1.0,"chain_ends_ground":2.0,"chain_ends_paid":9.0,"cores":[],"evasions":188.0,"events_joined":[],"exit_s":600.01,"harpoon_bites":290.0,"hit_sources":{"plated_brute":24.0},"hits":2.0,"hp_lost":24.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":82.52,"shred_peak":0.0,"slingshots":0,"slot_casts_line":3.0,"slot_casts_special":62.0,"specials":62.0,"stage":6,"stall_state":"gates","stuck_detours":0,"thermal_rides":0,"ultimates":2.0,"vault_tried":false,"wall_turns":48.3888888888939,"warden_broken_s":160.23,"warden_damage":{"ram":700.0,"slam":700.0},"warden_engaged_s":137.15,"warden_fight_heft":1.24,"warden_fight_s":40.0,"waypoints":0}],"ticks":54188,"ult_fill_s":[148.55,215.48],"ult_presses":2,"ult_sources":{"blazing":4.15,"chain_link":14.0,"contact":29.1,"fast":32.51,"kill":36.0,"near_miss":26.16,"shatter":36.0,"smash":40.0,"stagger":31.3},"ult_sources_first_fill":{"blazing":3.63,"chain_link":6.0,"contact":7.35,"fast":23.54,"kill":11.0,"near_miss":6.18,"shatter":12.0,"smash":15.0,"stagger":15.3},"ultimates":2,"wall_seconds":610.07}
{"boss":null,"class":"tarn","game_seconds":603.96,"outcome":"stalled","play_s":600.0,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791830450-834637","seed":3,"slot_casts":{"line":9,"special":69},"stage_reached":6,"stages":[{"cap_hits":0,"cores":[],"evasions":0,"events_joined":[],"exit_s":0.0,"hits":0,"hp_lost":0.0,"magnet_stuns":0,"max_hp":100.0,"parts":[],"plants":0,"plate_slams":0,"punch_short_s":0.0,"slingshots":0,"specials":0,"stage":1,"stuck_detours":0,"thermal_rides":0,"vault_tried":false,"warden_broken_s":null,"warden_engaged_s":null,"warden_fight_s":null,"waypoints":0},{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_ends_ground":23.0,"chain_ends_paid":8.0,"chain_releases":1.0,"cores":[],"evasions":275.0,"events_joined":[],"exit_s":600.01,"harpoon_bites":145.0,"hit_sources":{"plated_brute":24.0},"hits":2.0,"hp_lost":24.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":118.03,"shred_peak":0.0,"slingshots":0,"slot_casts_line":9.0,"slot_casts_special":69.0,"specials":69.0,"stage":6,"stall_state":"gates","stuck_detours":0,"thermal_rides":0,"ultimates":4.0,"vault_tried":false,"wall_turns":35.8222222222253,"warden_broken_s":215.84,"warden_damage":{"ram":700.0,"slam":700.0},"warden_engaged_s":140.67,"warden_fight_heft":1.0,"warden_fight_s":40.0,"waypoints":0}],"ticks":54356,"ult_fill_s":[152.11,34.92,20.89,275.83],"ult_presses":4,"ult_sources":{"blazing":7.94,"chain_link":12.13,"contact":56.92,"fast":86.44,"kill":66.0,"near_miss":32.6,"shatter":24.0,"smash":109.68,"stagger":48.0},"ult_sources_first_fill":{"blazing":4.07,"contact":10.6,"fast":43.08,"kill":5.0,"near_miss":10.5,"smash":26.75},"ultimates":4,"wall_seconds":725.06}
```

The live Warden is the base mind/choir encounter with no spires driver and a 30 m ring. KF8-WIRE owns the shared seam; these wins do not qualify the authored harpoon-enabled spires mounting or 120 m live ring. The graph independently passes its authored 120 m disc and spawn rules, and the active-map dock probe passes.

## Earlier traversal receipts, superseded

## Round 1 result, superseded

FAIL. The greybox is not admitted and the dressed pass has not started. These native automated measurements do not establish human feel.

The final seven-line sweep used data head f63cec77373ec8c15bedc341d792014b1c5d24eb. Tarn alone was measured again after rolling back its failed south waypoint on `e7a5c6a1d4209d785f3f528e2ab5c4d3dee9b3b2`. The park source, bake, graph, shared code and the other six lines are unchanged by that rollback; their receipts are reused. Each run uses the park table, stage 6 and seeds 1 to 8 at fixed 90 Hz, one Godot process outside the CPU queue at a time. Commands, input hashes and outcomes are retained under `/tmp/claude-1000/w13-sol/kd6-crown-r1/`.

The runtime probe finds family=mind, variant=choir, harpoon_anchor=false and driver=null. Its live engage ring is 30 m, while the authored park declares 120 m. The shared spawner does not consume the park Warden mounting. These receipts therefore measure the base mind/choir encounter and do not qualify the requested spires mechanism or 120 m approach.

The bands below retain PARK.md section 8. Anchor gaps use the worst seed, including when the traversal tool reports a green median. Only the floor own row judges the floor; all other floor cells are reported. The floor reference is Rivet from the same unchanged park and line inputs.

### Baseline after alignment, d751070

Cells: median (worst seed where the band judges it), verdict.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; reported, pilot band, not the floor's |
| time_to_warden_s | 61.34 (65.83); PASS | 74.055 (74.26); PASS | 68.605 (70.77); PASS | 82.7 (85.28); PASS | 82.57 (84.85); PASS | 79.565 (81.29); PASS | 56.71 (59.49); reported, pilot band, not the floor's |
| segment_s | 18.02 / 19.43 / 23.63 (23.625); PASS | 16.6 / 39.26 / 18.05 (39.26); PASS | 16.26 / 19.77 / 32.72 (32.715); PASS | 15.03 / 36.66 / 31.05 (36.655); PASS | 16.81 / 38.38 / 27.09 (38.385); PASS | 15.95 / 37.32 / 26.35 (37.32); PASS | 16.74 / 22.05 / 18.05 (22.05); reported, pilot band, not the floor's |
| flow_share | 0.9641 (0.9507); PASS | 0.8868 (0.879); PASS | 0.9436 (0.9083); PASS | 0.951 (0.9387); PASS | 0.8401 (0.7481); PASS | 0.9231 (0.8649); PASS | 0.9502 (0.9124); reported, pilot band, not the floor's |
| airborne_share | 0.2635; PASS | 0.3063; PASS | 0.3514; PASS | 0.2926; PASS | 0.3352; PASS | 0.3876; PASS | 0.1883; reported, pilot band, not the floor's |
| dead_stops | 0 (1); MISS | 0 (0); PASS | 0 (0); PASS | 0 (1); MISS | 0 (0); PASS | 0 (2); MISS | 0 (2); reported, pilot band, not the floor's |
| peak_speed_mps | 53.81 (51.99); PASS | 43.91 (43.36); PASS | 39.435 (38.53); PASS | 42.6 (38.67); PASS | 44.085 (43.34); PASS | 42.1 (38.29); PASS | 44.31 (43.46); reported, pilot band, not the floor's |
| tier3_s | 38.39; PASS | 9.915; PASS | 7.565; PASS | 8.285; PASS | 8.215; PASS | 8.28; PASS | 12.445; reported, pilot band, not the floor's |
| quiet_max_s | 5.86 (7.38); PASS | 6.06 (6.77); PASS | 5.16 (5.27); PASS | 5.47 (5.74); PASS | 6.08 (6.77); PASS | 6.06 (6.34); PASS | 5.08 (6.66); reported, pilot band, not the floor's |
| max_anchor_gap_m | 37.05 (39); PASS | 37.3 (38.8); PASS | 40 (42.4); MISS | 32.45 (38.2); PASS | 36.9 (40.2); MISS | 42 (45.2); MISS | 32.75 (36.9); reported, pilot band, not the floor's |
| distinct_verbs | 5 (4); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 4 (4); reported, pilot band, not the floor's |
| length_ratio | 1.565; PASS | 1.32; PASS | 1.35; PASS | 1.615; PASS | 1.42; PASS | 1.41; PASS | 1.17; reported, pilot band, not the floor's |
| Distinct lines, at least 3 | not measured from ticks | | | | | | |
| Floor own row: all seeds reach, time within 2 x reference median, zero stops on every seed | | | | | | | 56.71 s, limit 148.11 s; MISS |


### Final measured lines

Cells: median (worst seed where the band judges it), verdict.

| Measure | Sable | Rivet | Kest | Tarn | Tally | Cannon | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached_warden | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; PASS | 8; reported, pilot band, not the floor's |
| time_to_warden_s | 60.835 (63.31); PASS | 74.14 (74.69); PASS | 68.26 (70.1); PASS | 83.275 (85.27); PASS | 81.07 (81.85); PASS | 78.245 (80.99); PASS | 60.995 (64.25); reported, pilot band, not the floor's |
| segment_s | 18.03 / 18.91 / 23.24 (23.24); PASS | 16.61 / 39.3 / 18.16 (39.295); PASS | 16.23 / 19.49 / 32.69 (32.69); PASS | 15.03 / 36.71 / 31.22 (36.71); PASS | 16.81 / 37.77 / 26.44 (37.765); PASS | 15.95 / 36 / 26.27 (36); PASS | 21.12 / 21.94 / 17.87 (21.94); reported, pilot band, not the floor's |
| flow_share | 0.9674 (0.9579); PASS | 0.8885 (0.8807); PASS | 0.9472 (0.938); PASS | 0.9535 (0.9029); PASS | 0.8504 (0.8352); PASS | 0.9293 (0.9098); PASS | 0.9439 (0.8734); reported, pilot band, not the floor's |
| airborne_share | 0.268; PASS | 0.2986; PASS | 0.3518; PASS | 0.2941; PASS | 0.3409; PASS | 0.3579; PASS | 0.1571; reported, pilot band, not the floor's |
| dead_stops | 0 (0); PASS | 0 (0); PASS | 0 (0); PASS | 0 (1); MISS | 0 (0); PASS | 0 (0); PASS | 0 (0); reported, pilot band, not the floor's |
| peak_speed_mps | 53.685 (51.23); PASS | 44.03 (43.24); PASS | 39.43 (38.53); PASS | 42.465 (38.67); PASS | 43.82 (43.46); PASS | 42.755 (38.26); PASS | 43.62 (43.34); reported, pilot band, not the floor's |
| tier3_s | 38.155; PASS | 9.77; PASS | 8.555; PASS | 8.115; PASS | 8.28; PASS | 8.43; PASS | 13.59; reported, pilot band, not the floor's |
| quiet_max_s | 4.825 (7.1); PASS | 6.305 (6.77); PASS | 5.175 (5.27); PASS | 5.53 (5.68); PASS | 5.86 (6.77); PASS | 10.665 (11.1); PASS | 5.805 (5.96); reported, pilot band, not the floor's |
| max_anchor_gap_m | 36.95 (37.2); PASS | 36.55 (38.7); PASS | 27.5 (28.9); PASS | 23.85 (25.2); PASS | 37.5 (40.9); MISS | 45.8 (51.6); MISS | 102.2 (102.2); reported, pilot band, not the floor's |
| distinct_verbs | 5 (4); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 5 (5); PASS | 4 (4); reported, pilot band, not the floor's |
| length_ratio | 1.56; PASS | 1.32; PASS | 1.35; PASS | 1.62; PASS | 1.42; PASS | 1.445; PASS | 1.22; reported, pilot band, not the floor's |
| Distinct lines, at least 3 | 3 mutually distinct lines; PASS | | | | | | |
| Floor own row: all seeds reach, time within 2 x reference median, zero stops on every seed | | | | | | | 60.995 s, limit 148.28 s; PASS |


Distinct-line method: compare every recorded x/z tick against the other line within 8 m, in both directions, for the same seed. Use the larger shared fraction, then the worst of eight seeds. A pair is distinct below 0.5. The largest mutually distinct group is ['sable', 'tarn', 'cannon'], count 3. Tarn traces come from the rollback receipt; the other five pilots come from the full sweep. Different fan names alone are not evidence.

### Remaining seed failures

- tarn, seed 1: 1 stops; sites [{"at": [11.1, -596.4], "time": 7.6}].
- tally, seed 3: anchor gap 40.9 m against 40 m.
- cannon, seed 1: anchor gap 51.6 m against 40 m.
- cannon, seed 2: anchor gap 45.3 m against 40 m.
- cannon, seed 3: anchor gap 46.3 m against 40 m.
- cannon, seed 4: anchor gap 44.0 m against 40 m.
- cannon, seed 5: anchor gap 47.2 m against 40 m.
- cannon, seed 6: anchor gap 43.9 m against 40 m.
- cannon, seed 7: anchor gap 43.8 m against 40 m.
- cannon, seed 8: anchor gap 47.2 m against 40 m.

Tarn rollback seed 1 stops at [11.1,-596.4], t=7.6 s. Tick 687 (7.602 s) contacts /root/@Node3D@2/@CharacterBody3D@2264 and reverses z velocity from +23.92 to -4.95 m/s. The trace has no enemy-kind tag. This observed body contact stays in the stop count; it does not establish an exempt pack stop without TRAV-DET.

Tarn had two site reworks. Moving the balanced rock removed Sable anchor cover; restoring it and routing Tarn through [-60,-360] then produced 25 stops across eight seeds and a worst anchor gap of 68.8 m. The second route is discarded and the earlier [-60,-310] waypoint restored. The failed attempt remains in greybox-final/tarn.json; the fresh rollback receipt is tarn-rollback/tarn.json. No third tuning attempt was made.

## Win proof

Exact command:

```sh
/tmp/claude-1000/w13-s/cpu_queue.sh --cores 8 --name kd6-crown-r1-win-final -- timeout --signal=TERM --kill-after=10s 1500s nice -n 0 godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --table=park --policy=completionist --seeds=1,2,3 --from-stage=6 --stages=6 --out=/tmp/claude-1000/w13-sol/kd6-crown-r1/win-proof-final
```

Exit 0. Seeds 1 and 2 break the base Warden at 192.82 s and 186.98 s, then stall at the exit gates. Seed 3 stalls at the beacon without breaking it. All three runs use runner_gunner because --from-stage reads the shared entrance class. These are three RNG seeds. The native probe confirms that the requested spires driver does not run, so two breaks do not qualify that mechanism.

| Seed | Engaged s | Broken s | Broken minus engaged s | Exit state |
| --- | --- | --- | --- | --- |
| 1 | 126.18 | 192.82 | 66.64 | gates |
| 2 | 126.62 | 186.98 | 60.36 | gates |
| 3 | 126.39 | - | - | beacon |

This completed receipt uses the original 240 s stage limit. Rulings 19–22 were appended during this interrupted round and bind from the next round. That next round must use a scratch wrapper with a 600 s stage limit and the integrated deterministic traversal fix. Stops here remain conservatively counted; enemy contacts do not establish an exempt pack stop on this head.

Full bots.ndjson outcome lines:

```jsonl
{"boss":null,"class":"runner_gunner","game_seconds":241.98,"outcome":"stalled","play_s":239.99,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791815841-267844","seed":1,"slot_casts":{"line":7,"special":18},"stage_reached":6,"stages":[{"cap_hits":0,"cores":[],"evasions":0,"events_joined":[],"exit_s":0.0,"hits":0,"hp_lost":0.0,"magnet_stuns":0,"max_hp":100.0,"parts":[],"plants":0,"plate_slams":0,"punch_short_s":0.0,"slingshots":0,"specials":0,"stage":1,"stuck_detours":0,"thermal_rides":0,"vault_tried":false,"warden_broken_s":null,"warden_engaged_s":null,"warden_fight_s":null,"waypoints":0},{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_ends_dry_fire":1.0,"chain_ends_ground":25.0,"chain_ends_paid":7.0,"chain_releases":2.0,"cores":[],"evasions":27.0,"events_joined":[],"exit_s":240.0,"harpoon_bites":217.0,"hit_sources":{"kite_drone":9.0,"warden":10.0},"hits":2.0,"hp_lost":19.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":127.75,"shred_peak":0.0,"slingshots":0,"slot_casts_line":7.0,"slot_casts_special":18.0,"specials":18.0,"stage":6,"stall_state":"gates","stuck_detours":0,"thermal_rides":0,"ultimates":3.0,"vault_tried":false,"wall_turns":38.5777777777813,"warden_broken_s":192.82,"warden_damage":{"ram":1050.0,"runner":175.0,"slam":175.0},"warden_engaged_s":126.18,"warden_fight_heft":1.282,"warden_fight_s":40.0,"waypoints":0}],"ticks":21778,"ult_fill_s":[144.74,24.54,23.51],"ult_presses":3,"ult_sources":{"blazing":3.23,"chain_link":18.0,"contact":16.17,"fast":36.44,"kill":17.0,"near_miss":9.27,"shatter":35.55,"smash":116.34,"stagger":48.0},"ult_sources_first_fill":{"blazing":3.15,"chain_link":6.0,"contact":10.09,"fast":28.33,"kill":10.0,"near_miss":4.59,"smash":21.84,"stagger":16.0},"ultimates":3,"wall_seconds":142.25}
{"boss":null,"class":"runner_gunner","game_seconds":241.86,"outcome":"stalled","play_s":240.0,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791815841-267844","seed":2,"slot_casts":{"line":6,"special":13},"stage_reached":6,"stages":[{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_ends_dry_fire":1.0,"chain_ends_ground":18.0,"chain_ends_paid":12.0,"chain_releases":1.0,"cores":[],"evasions":17.0,"events_joined":[],"exit_s":240.01,"harpoon_bites":142.0,"hit_sources":{"warden":10.0},"hits":1.0,"hp_lost":10.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":112.83,"shred_peak":0.0,"slingshots":0,"slot_casts_line":6.0,"slot_casts_special":13.0,"specials":13.0,"stage":6,"stall_state":"gates","stuck_detours":0,"thermal_rides":0,"ultimates":2.0,"vault_tried":false,"wall_turns":41.5444444444484,"warden_broken_s":186.98,"warden_damage":{"ram":525.0,"slam":875.0},"warden_engaged_s":126.62,"warden_fight_heft":1.073,"warden_fight_s":40.0,"waypoints":0}],"ticks":21767,"ult_fill_s":[150.22,24.82],"ult_presses":2,"ult_sources":{"blazing":3.61,"chain_link":10.0,"contact":13.24,"fast":37.79,"kill":16.0,"near_miss":8.82,"shatter":24.0,"smash":119.8,"stagger":24.0},"ult_sources_first_fill":{"blazing":3.39,"chain_link":2.0,"contact":8.78,"fast":30.54,"kill":11.0,"near_miss":4.5,"smash":39.8},"ultimates":2,"wall_seconds":126.66}
{"boss":null,"class":"runner_gunner","game_seconds":242.86,"outcome":"stalled","play_s":239.99,"policy":"completionist","profile":"","reaction_s":0.25,"run_id":"1791815841-267844","seed":3,"slot_casts":{"line":11,"special":20},"stage_reached":6,"stages":[{"activities_entered":["cracked_cache","hauler_bounty","enemy_camp"],"activities_finished":["enemy_camp"],"cap_hits":0,"chain_breaks_passed":1.0,"chain_ends_grace":2.0,"chain_ends_ground":44.0,"chain_ends_paid":10.0,"chain_releases":2.0,"cores":[],"evasions":30.0,"events_joined":[],"exit_s":240.01,"harpoon_bites":221.0,"hit_sources":{"warden":2.0},"hits":1.0,"hp_lost":2.0,"magnet_stuns":0,"max_hp":100.0,"parts":["activity_camp:rivet_plating"],"plants":0,"plate_slams":0,"punch_short_s":165.41,"shred_peak":0.0,"slingshots":0,"slot_casts_line":11.0,"slot_casts_special":20.0,"specials":20.0,"stage":6,"stall_state":"beacon","stuck_detours":0,"thermal_rides":0,"ultimates":3.0,"vault_tried":false,"warden_broken_s":null,"warden_damage":{"ram":1050.0},"warden_engaged_s":126.39,"warden_fight_heft":1.249,"warden_fight_s":40.0,"waypoints":0}],"ticks":21857,"ult_fill_s":[157.64,26.75,28.88],"ult_presses":3,"ult_sources":{"blazing":4.46,"chain_link":24.0,"contact":18.03,"fast":43.74,"kill":21.0,"near_miss":8.38,"shatter":24.0,"smash":174.87,"stagger":48.0},"ult_sources_first_fill":{"blazing":3.31,"chain_link":2.0,"contact":7.84,"fast":31.08,"kill":6.0,"near_miss":5.08,"smash":44.69},"ultimates":3,"wall_seconds":155.4}
```

The seed-1 and seed-2 logs report the bay warning `no clear dock beside these gates`. The corrected dock probe checks both authored cradles [-34,0,670] and [34,0,670]: both are outside bay.gd MAP_LIMIT=185 and rejected before height or clearance. A level dock beside these gates cannot repair that shared bound. No gate or dock was moved to conceal it.

## Graph and evidence limits

The graph has connected routes and no pocket breaches or line errors, but beacon_ok=false and spawn.run=false. The stage test now fails on both rules; no mounting exemption is accepted. The final section-5 pocket table is generated from graph.json. The requested mounting, live ring and bay bounds need shared integration before further approach tuning and a qualifying win proof. No dressed recipe, GPU draw count, triangle count, stills.json or human play receipt is claimed.

## Historical receipts, superseded

The following older tables preserve prior evidence. Their historical verdict sentences use the former median anchor judgment and do not admit the current candidate. The current table above applies the worst-seed anchor rule and the floor own-row rule.

## Greybox pass on the KB9 head, 11 October 2026 (KD6 continuation)

Measured at commit 1ec7f92 plus this unit's working edits (each summary's `commit` field), park file sha256 `ef7a0f3c…`: the committed file `782c8b23…` differs from it only by the 59 `slickrock_field_*` rows (no recipe, no stamp), and its ground.bin and surface.bin are byte-identical, so the ride is the same. KB9 places the rows at runtime and the ride sensors fire (`ride_chute`, `kicker_launch`, `ride_grapple_line`, `ride_bowl`, `ride_drop` in the run logs), so the distinct-verbs counts do not rest on `lift_fired`, `crater_ride` or `wall_crumbled`. Same command per line as below, seeds 1 to 8, one process at a time; load 20 to 87 on 32 threads (tick-counted measures, wall time only). Cells: median (worst seed), the tool's verdict. Tally and the Cannon were measured on the cut before the last re-cut of their lines (21:21); their committed lines are not yet measured. The floor's time, airborne and length rows are pilot bands, not judged on the floor; its own band is the floor row.

| band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached the Warden, 8 of 8 | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass |8 pass; reported, pilot band, not the floor's |
| time_to_warden_s, median 60 to 120, no seed over 150 | 85.3 (92.8) pass | 73.6 (74.1) pass | 68.8 (72.7) pass | 82.7 (85.0) pass | 87.4 (91.1) pass | 83.3 (86.3) pass |57.4 (57.7) not judged; reported, pilot band, not the floor's |
| segment_s medians 12 to 45 | 12.7 / 45.5 / 26.7 MISS | 16.5 / 39.1 / 17.8 pass | 16.2 / 20.3 / 32.4 pass | 15.0 / 36.6 / 31.0 pass | 16.8 / 40.5 / 30.4 pass | 15.9 / 36.7 / 30.2 pass |17.6 / 21.9 / 17.9 pass; reported, pilot band, not the floor's |
| flow_share, median at least 0.70, no seed under 0.60 | 0.89 (0.86) pass | 0.89 (0.87) pass | 0.94 (0.76) pass | 0.95 (0.91) pass | 0.79 (0.75) pass | 0.90 (0.82) pass |0.91 (0.88) pass; reported, pilot band, not the floor's |
| airborne_share 0.25 to 0.60 (stage 6) | 0.35 pass | 0.30 pass | 0.35 pass | 0.29 pass | 0.19 MISS | 0.37 pass |0.18 not judged; reported, pilot band, not the floor's |
| dead stops 0 on every seed | 5 (6) MISS | 0 (0) pass | 0 (0) pass | 0 (1) MISS | 1.5 (3) MISS | 1 (2) MISS |0 (1) MISS; reported, pilot band, not the floor's |
| peak_speed_mps at least 26.6 every seed | 56.2 (48.4) pass | 44.0 (43.2) pass | 39.8 (39.0) pass | 42.7 (38.6) pass | 43.9 (42.4) pass | 40.9 (38.0) pass |44.4 (43.6) pass; reported, pilot band, not the floor's |
| tier3_s median at least 3 | 49.2 pass | 9.9 pass | 7.7 pass | 8.1 pass | 8.3 pass | 8.4 pass |12.0 pass; reported, pilot band, not the floor's |
| quiet_max_s at most 20 | 7.9 (8.2) pass | 6.5 (6.9) pass | 5.2 (5.9) pass | 5.5 (5.7) pass | 6.3 (7.8) pass | 7.3 (11.3) pass |5.1 (5.7) pass; reported, pilot band, not the floor's |
| max anchor gap at most 40 m (tool judges the median) | 88.1 (88.6) MISS | 37.7 (40.8) pass | 40.0 (43.5) pass | 36.3 (45.0) pass | 37.3 (44.0) pass | 42.1 (45.8) MISS |32.7 (36.4) pass; reported, pilot band, not the floor's |
| distinct ride facts at least 3 | 6 (5) pass | 5 (5) pass | 5 (4) pass | 5 (5) pass | 5 (5) pass | 5 (5) pass |4 (4) pass; reported, pilot band, not the floor's |
| length / straight 1.3 to 2.0 | 2.02 MISS | 1.32 pass | 1.35 pass | 1.61 pass | 1.55 pass | 1.46 pass |1.15 not judged; reported, pilot band, not the floor's |
| progress (graph) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |not measured (KB7b); reported, pilot band, not the floor's |
| floor: reaches the Warden within 2.0 times Rivet's median (147.2 s), 0 dead stops | | | | | | | reaches in 57.4 s; 1 dead stop on 1 seed: MISS |

Result: Rivet and Kest meet every judged band; Sable (re-cut, dead stops, 88 m gap, length 2.02), Tarn (one dead stop on one seed), Tally (airborne 0.19, dead stops), the Cannon (dead stops, gap 42 m) and the floor (one dead stop) miss. The greybox pass is not admitted on traversal.

## Greybox pass, 11 October 2026 (KD6, first run, pre-KB9, superseded)

Measured on `src/world/park/park_crown.json` sha256 `de386d8e6cc308381a5929934aef331561b7ce0b3b03790db36138278b80d1a1`, its committed bake and graph, base `5f2139b`. Lines from `tools/park_lines/park_crown.json`. Command per line: `godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --table=park --stage=6 --pilot=<key> --seeds=1,2,3,4,5,6,7,8 --out=<dir>`, and `--floor` for the floor line (Rivet rolling, Rivet's median as the reference). The machine ran at load 40 to 90 of 32 threads; the measures are tick-counted, so load changes wall time only.

| band | sable | rivet | kest | tarn | tally | cannon | floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reached the Warden, 8 of 8 | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass | 8 pass |8 pass; reported, pilot band, not the floor's |
| time_to_warden_s, median 60 to 120, no seed over 150 | 70.3 (89.0) pass | 71.7 (73.4) pass | 66.8 (68.9) pass | 81.1 (83.9) pass | 99.4 (103.3) pass | 79.4 (80.8) pass |55.7 (58.2) see floor row; reported, pilot band, not the floor's |
| segment_s medians 12 to 45 | 12.0 / 26.8 / 30.2 pass | 16.4 / 38.0 / 17.2 pass | 16.0 / 19.1 / 32.3 pass | 15.0 / 36.3 / 29.8 pass | 16.6 / 37.5 / 45.2 MISS | 16.0 / 35.3 / 27.8 pass |17.4 / 19.8 / 17.9 pass; reported, pilot band, not the floor's |
| flow_share, median at least 0.70, no seed under 0.60 | 0.98 (0.93) pass | 0.89 (0.87) pass | 0.93 (0.83) pass | 0.96 (0.92) pass | 0.85 (0.78) pass | 0.91 (0.90) pass |0.90 (0.87) pass; reported, pilot band, not the floor's |
| airborne_share 0.25 to 0.60 (stage 6) | 0.36 pass | 0.30 pass | 0.35 pass | 0.29 pass | 0.34 pass | 0.39 pass |0.17 (not judged on the floor); reported, pilot band, not the floor's |
| dead stops 0 on every seed | 0 (0) pass | 0 (1) MISS | 0 (1) MISS | 0 (1) MISS | 0 (1) MISS | 0 (0) pass |0 (1) MISS; reported, pilot band, not the floor's |
| peak_speed_mps at least 26.6 every seed | 56.2 (54.8) pass | 44.5 (44.1) pass | 40.2 (39.7) pass | 43.2 (38.6) pass | 44.3 (43.7) pass | 39.6 (38.3) pass |43.8 (43.2) pass; reported, pilot band, not the floor's |
| tier3_s median at least 3 | 51.1 pass | 10.9 pass | 9.6 pass | 8.1 pass | 13.2 pass | 8.2 pass |14.0 pass; reported, pilot band, not the floor's |
| quiet_max_s at most 20 | 6.7 (7.0) pass | 5.3 (5.6) pass | 4.2 (5.3) pass | 5.9 (6.2) pass | 6.6 (7.0) pass | 5.8 (6.9) pass |4.2 (4.3) pass; reported, pilot band, not the floor's |
| max anchor gap at most 40 m | 36.4 (37.9) pass | 37.2 (39.4) pass | 42.0 (45.7) MISS | 33.4 (35.8) pass | 37.3 (38.6) pass | 37.1 (38.8) pass |33.0 (37.0) pass; reported, pilot band, not the floor's |
| distinct ride facts at least 3 | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 (2) pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired | 3 pass, rests on lift_fired |2; reported, pilot band, not the floor's |
| length / straight 1.3 to 2.0 | 1.91 pass | 1.31 pass | 1.34 pass | 1.59 pass | 1.74 pass | 1.42 pass |1.13; reported, pilot band, not the floor's |
| progress (graph) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) | not measured (KB7b) |not measured (KB7b); reported, pilot band, not the floor's |
| floor: reaches the Warden within 2.0 times Rivet's median (143.4 s), 0 dead stops | | | | | | | reaches in 55.7 s; 1 dead stop on 1 seed: MISS |

Distinct lines: six pilots ride six different pairs of fans (Sable west then Gauntlet, Rivet east then centre, Kest centre then masts, Tarn west then masts, Tally east then Gauntlet, the Cannon east then shelf); the band asks for 3.

**What the misses are.**

- Distinct ride facts. Every pilot's third ride fact is `lift_fired`; the others are `kicker_launch` and `ride_grapple_line`. On this head nothing places the park rows at runtime (no caller of `ParkRecipes.place` under `src/`), so no row's ride sensor exists and `ride_chute`, `ride_drop`, `ride_bowl` and `ride_ledge` cannot fire on any park stage. The reachable ride facts are the kicker launch (`map.kickers` plus a baked rise), a cable, a thermal (glide only) and the lift. When KB7b drops `lift_fired` (ruling R11) every pilot reads 2: a miss the park file cannot fix.
- Dead stops: one stop on one seed for Rivet (at [33, 4], the meander bend's wall by the slot), Kest (in the bowl at [-45, 451], the Warden's perch ring), Tarn ([-1, -615] on the butte crest), Tally ([145, 446], the bowl's east rim) and the floor ([4, -593]). The two crest stops are collisions with an enemy body on the drop-in (the trace shows a `CharacterBody3D` contact and the velocity reversing at 5.98 s), not ground.
- Kest's anchor gap: 42.0 m median against 40; the previous full run on the same lines read 38.8 (worst 57.2), so it sits on the edge of the band.
- Tally's third segment (the Gauntlet fan) is 45.2 s against 45: the line rides the tether into the Gauntlet gap, then the ground east of the shelf, because the runtime places no net deck.
- The floor line's time (55.7 s) is under the pilots' 60 s floor; the floor line is judged by its own band (reach within 2.0 times Rivet's median, no dead stops), which it misses only on the one stop.

Progress is not measured: `traversal_line.gd`'s `_construct_graph` discards the graph it reads (ruling R12), so `progress_m` is built from zeros and is not evidence.
