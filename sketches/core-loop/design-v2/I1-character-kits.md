# I1: Core-loop v2 character kits

Buildable in Godot 4.7 GDScript against the existing sketch. Physics: 90 Hz, RigidBody3D, mass 6, `RADIUS = 1.0`. Reuses `movement/augments.gd`, `movement/player_ball.gd`, `combat/combat.gd`, `combat/weapons.gd`, `core/class_def.gd`, `core/run_state.gd`, `core/event_kinds.gd`.

Everyone keeps: jump, double jump (`state.air_actions`), boost (`BOOST_IMPULSE = 11.0`, `BOOST_COOLDOWN = 1.1s`), and a ground smash (`_slam`/`_plant`) with a per-character flavor layered onto the existing flatness-split landing.

## Shared: bowling-ball contact

One rule in `player_ball._on_enemy_touched`, all characters:

- **Rebound** (you're lighter): `enemy.weight >= ctx.run.heft() * 1.15` (not just `would_crush`'s equal-weight line — rebound needs real overmatch, else it's a crush). Reflect `before` velocity across the contact normal at `REBOUND_RESTITUTION = 0.65`, capped so the vertical component never exceeds `tuning.f("jump_speed") * 1.4`. Refreshes `state.air_actions = 1` and `kit.dash_ready = true`, exactly like the existing stomp branch — one line so rebounding and stomping never disagree.
- **Smash-through** (you're heavier): unchanged, `_try_crush` / `would_crush`.
- **Pins:** a knocked enemy (`enemy.knock(...)` velocity above `PIN_MIN_SPEED = 6.0 m/s`) that hits a second enemy within `PIN_RADIUS = 1.2 m` deals `PIN_DAMAGE = 8.0 + 0.5 * carrier_speed` (cap 40) to the second enemy once per knock event, keyed by the carrier's instance id so it can't double-fire in one tick.

## Shared: hold-gauge-release skill shots

Every `special_held`/`special_released` and the engineer's vault/slingshot follow one spec, built from the existing grapple assist rings/reticle (`augments.gd:92-123`, `aim_reticle.gd`):

- **Indicator shape:** sector (area abilities) or line (detonation line / vault aim), drawn as committed geometry — the indicator IS the hit geometry, per TH-16.
- **Gauge fill:** 0–100% radial ring around the reticle, linear over the ability's `charge_max` (0.6–1.4 s, per ability below).
- **Cancel rule:** re-pressing the special key before release cancels with no cooldown spent and no charge kept. Taking knockback/CC mid-charge force-cancels the same way (R2's interrupt rule) — never a stuck-charging state.
- **Forgiveness padding:** indicator radius/length is 15–20% larger than the actual damage geometry (R2 spec).
- **What release scales:** hold fraction `f = held_time / charge_max` scales damage and radius/length linearly from a floor (a tap still does something, per "forgiveness") to the ability's max; auto-fires at `f = 1.0` after a 0.5 s grace so nobody can hold forever.

## Shared: cooldowns and charges

Base cooldowns 2–6 s. Each ability gets `max_charges` (default 1); items raise it, so charges stockpile off-cooldown into HUD pips (W1 owns the display). None of the three kits below assume more than base charges; that's the loot layer's job.

---

## Pylon engineer — Sable

**Fantasy:** plant a beachhead, then launch off it like a slingshot cannonball.

Bible home: **Sable, displacement and traversal** (hook-driver, folding winch anchor) — the movement identity (grapple, vault, mount) is the character's core verb, so it outweighs the arc-caster's resemblance to Fuse. `class_def.gd`'s current placeholder ("Rivet's beam or Sable's anchor") should resolve to Sable.

| Input | Effect | Numbers |
| --- | --- | --- |
| LMB held | Arc caster chain bolt | dmg 12, rate 5/s, range 70 m, chain 1 jump/9 m/0.7 falloff (existing `Weapons.ARC_CASTER`) |
| E tap near a steep face/hook anchor | **Vault kick** — instant, no dwell | exit speed = incoming × 1.8, capped 45 m/s; 1.5 s same-face cooldown (prevents wall-to-wall ping-pong) |
| E hold near a steep face/hook anchor | **Mount** — plant, bank speed (existing `_mount`) | unchanged |
| Space while mounted | **Slingshot** eject (existing `_slingshot`) | keep 0.85, boost +6, floor = `jump_speed` |
| F hold→release | **Detonation gauge**: arc discharge, hold-gauge-release | charge_max 1.0 s; released burst uses existing `Weapons.burst()` curve fed by `f` instead of raw speed; radius 12→30 m, dmg 14→base+charge; cooldown 5 s (`DISCHARGE_COOLDOWN`) |
| Ground smash | **Arc slam** — shock ring in Field mint, tags nearby steep faces (≤12 m) for a 2 s vault-kick highlight | reuses `SLAM_RADIUS`/`SLAM_KNOCK`, no extra cooldown |

**Bowling-ball tuning:** stock shared values. Engineer's mass doesn't change rebound math — the character's edge is positioning (mount/vault), not raw weight.

**Signature:** Field mint `#8bf0d3`, ring shape motif (area = ring, per the shape grammar), rising arpeggio on plant/discharge, VFX: rope line → ring burst → pylon plate glow.

**Harmonizes momentum:** the pylon *banks* speed instead of stopping it — mounting reads as a pause but pays back more than it cost via the slingshot, so standing still is never free (principle 1, principle 7's "harmonize contradictions" example is literally this ability).

**Synergy hooks:** `on_vault_kick`, `on_pylon_discharge` (after a burst lands ≥1 hit), `on_mount_planted`.

---

## Runner-gunner — Rivet

**Fantasy:** an unstoppable laser sprinter who turns crowd control into fuel.

Bible home: **Rivet, precision and controlled corridors** — cutting laser, straight alignment rail. Matches the unchanged rapid-laser weapon and "run and gun, can't be stopped" better than the code's placeholder "Fuse" (Fuse is casting/local-pressure, a better fit for the caster below).

| Input | Effect | Numbers |
| --- | --- | --- |
| LMB held | Rapid laser (unchanged) | dmg 7, rate 12/s, range 85 m, radius 0.25, knock 4 |
| Shift held | **Overdrive sprint** — replaces the shared air dash entirely | CC-immune (ignores knock/slow/stun while held), +25% cruise speed, crush threshold −20% (fights above its weight while sprinting); costs 1 ability charge, 2.0 s duration, 5 s cooldown per charge |
| F hold→release | **Overdrive blast**, now hold-gauge-release | charge_max 1.0 s; release scales existing `OVERDRIVE_RADIUS`(12)/`OVERDRIVE_DAMAGE`(30)/`OVERDRIVE_KNOCK`(34) by `f`; grants `OVERDRIVE_SECONDS`(3 s) fire-rate boost after; cooldown 6 s (`OVERDRIVE_COOLDOWN`) |
| Ground smash | **Shockwave skid** — a forward slide-smash (not vertical) that refunds 0.5 s of sprint cooldown per enemy hit | reuses slam knock, no extra cooldown |

**Bowling-ball tuning:** stock shared values, except while Overdrive Sprint is active the rebound threshold check uses `heft() * 1.0` instead of `1.15` (the lowered crush bar above) — sprinting turns marginal rebounds into smash-throughs, which is the whole point of "unstoppable."

**Signature:** Copper `#b77843`, chevron shape motif (motion = chevron), hi-hat rolls, VFX: speed-line trail that brightens during sprint, laser bolts unchanged.

**Harmonizes momentum:** CC is the one thing that legitimately stops a rolling ball against the player's will (not their own mistake) — Overdrive Sprint is the harmonization: it doesn't remove damage, only removes the stop, so principle 1 ("only the player's own performance costs momentum") holds even against enemies designed to interrupt.

**Synergy hooks:** `on_overdrive_sprint_start`, `on_overdrive_blast_release`, `on_cc_ignored` (fires when an incoming CC effect is nullified mid-sprint — lets items punish enemies that tried to lock the runner down).

---

## Demolitions caster — Fuse

**Fantasy:** vanish in your own smoke, then drop a line of fire where they least expect it.

Bible home: **Fuse, directed casting and local pressure** — emitter, discharge post, local arcs. The explosive skill-shot/burst identity fits casting-and-pressure better than the runner's precision laser.

| Input | Effect | Numbers |
| --- | --- | --- |
| LMB hold→release | **Sticky charges** — lobbed arc indicator (R2 Type C), release throws a bomb | dmg 16, radius 3.0 m, fuse 1.2 s or on-contact, 0.6 s throw cooldown, up to 3 live charges (own stack, separate from the special's charge system) |
| Special hold→release | **Detonation line** — hold draws a line (R2 Type D) forward, release detonates all live sticky charges early plus damages along the line | charge_max 0.8 s; line length 6→14 m by `f`; +25% dmg per live charge caught in the line (cap 3 charges counted); cooldown 6 s |
| Passive | **Rocket jump** off own blast — being inside a detonation's radius (self included) launches you | impulse 22→30 m/s scaled by proximity to blast center, same falloff curve as `_push_enemies`; gated by the 0.6 s throw cooldown plus a 1.0 s self-launch cooldown so it can't chain into flight |
| Passive | **Dust cloak** — any own detonation grants 1.5 s cloak | reduces enemy aggro/target-acquisition range by 40%; first skill shot fired from cloak crits (+100% dmg); grants no speed or defense bonus — triggered only by moving into/causing a blast, so it can't be farmed by standing still |
| Ground smash | **Demo slam** — lobs a 3-charge cluster in a spread on landing | each mini-charge: dmg 5.3 (1/3 of a sticky charge), radius 1.5 m, arms after 0.3 s, 1.0 s fuse or contact |

**Bowling-ball tuning:** stock shared values; the caster's kit doesn't touch mass/heft, it's positioning and burst, matching its "hide, set up, burst" identity rather than a weight trick.

**Signature:** Safety amber `#e5a044`, starburst shape motif (explosive = starburst), low thumps, VFX: amber fuse-spark on arm, dust puff on cloak.

**Harmonizes momentum:** the cloak reads as a stop but is earned only by detonating — an action, not a pause — and the rocket jump turns the caster's own explosion into forward motion, so its whole "hide and strike" identity is built from movement, never from standing still.

**Synergy hooks:** `on_dust_cloak_crit`, `on_rocket_jump`, `on_charge_chain_detonation` (fires when ≥2 sticky charges detonate within one trigger — the chain payoff moment).

---

## New `event_kinds.gd` rows

| name | group | shape | sound | priority |
| --- | --- | --- | --- | --- |
| `enemy_rebounded` | combat | chevron | `rebound_clank` | 1 |
| `enemy_pinned` | combat | burst | `pin_smack` | 1 |
| `vault_kicked` | movement | arrow | `vault_boing` | 1 |
| `gauge_released` | combat | star | `release_thump` | 1 (shared by all three hold-release specials) |
| `overdrive_sprint_started` | movement | arrow | `sprint_rev` | 1 |
| `dust_cloak_started` | combat | diamond | `dust_puff` | 1 |
| `sticky_charge_detonated` | combat | burst | `charge_boom` | 1 |
| `rocket_jumped` | movement | arrow | `rocket_whoosh` | 1 |

## New intent axes

`special_held`, `special_released` (charge/release for all three specials + the caster's primary), `boost_held` (Overdrive Sprint needs a held state; existing `boost_pressed` stays a one-shot for the shared boost).

## Risks

1. **Vault-kick ping-pong.** Two close steep faces could chain speed to absurd values. Mitigated by the 45 m/s cap and 1.5 s same-face cooldown — verify it actually decays, not just caps.
2. **Overdrive Sprint as a standing tank.** CC immunity + lowered crush threshold could let a player park in a crowd. It removes *stopping*, not damage, so it's self-limiting, but the lowered rebound threshold during sprint needs a test that damage still applies at the normal rate.
3. **Detonation line double-dipping.** Sticky charges + line detonation could one-shot a miniboss beyond intended TTK. Capped at 3 charges counted per line trigger; needs a fuzz check against boss HP tables.
4. **Rocket-jump flight chaining.** Throw → detonate → jump → repeat could skip level gating entirely. Gated by the shared 0.6 s throw cooldown plus a 1.0 s self-launch cooldown, so a full bypass needs both to be circumvented — test that neither can be zeroed by a charge item.
5. **Charge interrupt state leak.** A CC hit mid-charge must fully clear the gauge and cooldown, not leave a UI phantom or a free re-charge. This is the single highest-value headless test of the whole batch.
6. **Mount→grapple→vault chaining bypassing fall risk.** Stacking traversal moves could let the engineer cross a whole stage without touching a hazard. `air_actions` refresh stays capped at 1 per contact, same rule as the existing stomp/rebound reset — no new exception should be added per-ability.

## Six headless test cases

1. **Vault kick speed:** incoming 20 m/s → exit ≈36 m/s (±5%); incoming 30 m/s → exit capped at 45 m/s.
2. **Rebound vs. crush boundary:** `enemy.weight = heft()*1.2` → rebound (air_actions reset, no crush exception added); `enemy.weight = heft()*0.8` → crush-through (existing `_try_crush` path, no rebound).
3. **Pin propagation:** a knocked enemy above 6 m/s hitting a second enemy within 1.2 m deals pin damage exactly once per knock event (assert no double-hit in one physics tick).
4. **Gauge-release scaling:** engineer F held 0.3 s vs 1.2 s produces monotonically increasing burst radius and damage, matching the `f`-scaled curve within tolerance.
5. **Sprint CC immunity:** apply a scripted knockback/slow to the runner while Overdrive Sprint is held; assert velocity is unaffected during the window and the CC branch applies normally in the tick after release.
6. **Interrupt refund:** begin the caster's detonation-line charge, apply scripted knockback mid-charge; assert the gauge clears to 0, the cooldown stays uncommitted (0, not started), and no partial-length line fires.
