# Spillway Drop findings, A3 re-derivation (JL-27-A3, automated; not feel verdicts)

From the JL-27-A3 handoff, saved verbatim by the coordinator. Findings 2 to 5 as in `findings.md` (A2), with A3's zero anomalies confirming finding 5. Pre-existing stage flake: `exit_test.gd` fails about 1 run in 4 to 6 on the unmodified proto build too (it reads the position one frame before a rigid teleport lands); for Andrew's gameplay list, not a lab defect.

Epochs A1 (threat rule 1), A2 (rule 2) and A3 (rule 2 plus end-on-death); `--seed 1`; automated only, not feel verdicts, not primary.

**Finding 1: the ball dies in most trials under both arms (re-derived on A3).**
- **Observed:** deaths are A1 138/160, A2 129/160, A3 129/160. A3 median death is 19.6–40.1 s (`logs-a3/13-findings-a3.txt`).
- **Observed, per arm, A1 → A2 → A3 (success; deaths out of 20):**

| batch | success | deaths |
|---|---|---|
| mid-climb random kinematic | 6 → 3 → 3 | 10 → 13 → 13 |
| mid-climb random rigid | 1 → 1 → 1 | 18 → 19 → 19 |
| mid-climb scripted kinematic | 6 → 8 → 8 | 12 → 4 → 4 |
| mid-climb scripted rigid | 0 → 0 → 0 | 20 → 20 → 20 |
| flood-hatch random kinematic | 0 → 2 → 2 | 20 → 18 → 18 |
| flood-hatch random rigid | 0 → 0 → 0 | 20 → 20 → 20 |
| flood-hatch scripted kinematic | 2 → 5 → 5 | 18 → 15 → 15 |
| flood-hatch scripted rigid | 0 → 0 → 0 | 20 → 20 → 20 |

- **Observed (review F2):** rule 2 turned A1's kinematic mid-climb tie, random 6 vs scripted 6, into random 3 vs scripted 8 in A2 and A3.
- **Observed, A3 HP lost per 1 s hold, live-ball holds only:**
  - Outside stomp: 0.0–8.6 HP. The high end comes from small samples (sweep 8.6 over 17 holds, retreat 7.7 over 35).
  - Stomp: 5.0–7.6 in kinematic, 4.0–8.4 in rigid.
  - These are higher than A2's diluted figures (0.0–3.7 and 3.4–5.6), because dead-ball holds lost 0 HP.
  - The loss between the last state and the death isn't counted, since no state follows the death.
- **Observed, with post-hoc thresholds** (6 m and 10 m were chosen after the A1 runs; F6): HP lost while a struck enemy was within 6 m and no unstruck enemy within 10 m was 1–16% in A3, 1–16% in A2 and 2–25% in A1. Under rule 2 the arm can see those enemies.
- **Inference:** rule 2 helps the scripted ladder because its stomp rung finishes the wounded chaser (scripted kinematic stomp knocks 71 → 124 in A2). It costs random kinematic mid-climb three successes, a mechanism I haven't isolated. Rigid mode is weighed down by the stomp crediting JL-13 reported (A3 rigid stomp knocks 5–7 per batch against 39–109 in kinematic).
- **Inference:** the stomp costs HP because the rebound keeps horizontal velocity (`player_ball.gd:161`), so the ball stays inside the chaser's 2.6 m reach at and after contact (review F6 correction: it doesn't "land" there, it never leaves).

**Finding 6: the gate removes most ram offers and, in rigid, many stomp offers (re-derived on A3).**
- **Observed (A3):**
  - `ram_target` survives in 0.3–15.8% of offers (1/379 to 106/670).
  - `stomp_target` survives in 96–98% of offers in kinematic and 63–80% in rigid.
  - The recorded `spillway_gated_offer_share` is 0.15–0.19 in kinematic and 0.19–0.23 in rigid, counting live-ball snapshots only.
- **Inference:** ram's gate reads the tier left by the previous hold (JL-21 F4 shape). No Spillway option carries `requires_speed_ms`.

**Kerb slope for finding 3 (F6).**
- **Formula** (`terrain.gd:141-143`): the lip is `min((adx - 9) * 1.3, 6)`, so the face rises **1.3 m per m** over x 131 → about 126.4, capped at 6 m.
- **Sampled:** 1.2 m per m between x 131 and 126 (`logs/16-bypass-kerb-profile.txt`, uncommitted scratch probe). The 5 m sample span includes about 0.4 m of the flat cap.

**Findings 2–5:** unchanged from A2, with one A3 addition. A3 has **0 anomalies in 160 trials** (`logs-a3/13-findings-a3.txt`), which confirms finding 5: every A1/A2 anomaly came after death.
