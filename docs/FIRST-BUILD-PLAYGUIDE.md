# The Iron Orchard play guide

The Iron Orchard is a standalone first playable encounter. Pip pilots a rolling scrap machine past two kinds of orchard worker and one large Grand Pruner arm. Dismantling that arm ends the run. The original yard remains at `/`.

The user approved this first build and its session goal on 5 September 2026. Implementation and build verification are complete. This guide describes the controls and mechanics; the [verification receipt](FIRST-BUILD-VERIFICATION.md) records results and remaining playtest limits.

## Entry and controls

The development entry is `/orchard.html` on the address printed by `npm run dev`. The production build also has an `orchard.html` entry. The opening screen starts through **Roll into the orchard** or Enter. The **Original yard** link returns to `/`.

| Action | Keyboard and mouse | Behavior |
| --- | --- | --- |
| Roll | W, A, S, D | Movement follows the camera's horizontal facing. The ball accelerates and retains momentum while changing direction. |
| Look and aim | Mouse movement after capture, right mouse drag, or arrow keys | Horizontal camera facing sets shot direction. Up and down adjust the view. Clicking the world requests mouse capture where available. |
| Face travel direction | C | Aligns the camera with the ball's current travel direction when the ball is moving. |
| Charge pulse | Hold F or the left mouse button, then release | The release fires one aimed pulse. Full charge takes 1.1 seconds. Holding at full charge does not fire automatically. |
| Ram burst | Space | Bursts in the current movement-input direction, or the facing direction when no movement input is held. The burst has a cooldown. |
| Brake | Hold Shift | Slows the ball and tightens direction changes. Holding a movement key while braking still moves the ball slowly. |
| Deploy Shear Buddy | E | Deploys one companion after a Shear Linkage has been collected. |
| Pause | Escape or P | Freezes the encounter. The pause screen has resume and restart buttons. |
| Restart | R | Starts a fresh run immediately once the opening screen has been left. |
| Field guide | H or the question-mark button | Opens the controls guide and pauses an active encounter. |
| Sound | M or the sound button | Toggles sound. Sound starts disabled. |

The implemented gamepad mapping uses the left stick to roll, the right stick to aim, A to burst, LT to brake, RT to charge and release, X to deploy, and Start to pause. Start resumes a paused encounter. A or Start begins a run from the opening or result screen. Touch controls provide a movement stick and pulse, ram, brake, and buddy buttons on devices identified as coarse-pointer devices. Gamepad and touch usability are not verified by the simulation tests.

Losing window focus or hiding the page pauses an active encounter. A restart clears the current run's health changes, pickups, companion, enemies, and projectiles.

Sources: [entry document](../orchard.html), [controls and screens](../src/orchard/main.js), [build entries](../vite.config.js).

## Enemy behavior and counters

The encounter contains two Snipcarts, two Spreadlegs, and one Grand Pruner arm. Workers activate nearby. They do not form a mandatory kill gate before the arm. The ground route rises onto the terrace without a jump or traversal ability.

| Enemy | Committed attack | Available response |
| --- | --- | --- |
| Snipcart | Opens its jaws during preparation, then closes them inward along the locked aim. | Leave the announced closing reach, then return to its right-side housing during recovery. |
| Spreadleg | Settles its frame, then moves its two feet outward. | Leave the foot path or remain beyond its reach. The forward gap and the flanks have different danger footprints. |
| Grand Pruner arm, nearby | Sweeps its large shearing arm across a locked area. | Leave the sweep, then aim or ram into the exposed housing during recovery. |
| Grand Pruner arm, farther away | Announces a straight path and tosses a rolling pruning offcut down that path. | Move sideways after the direction locks. The offcut keeps travelling after the arm finishes its release. |

Preparation locks attack direction and position. The damaging tool follows the declared motion instead of chasing the player's new position. Ordinary body contact pushes the ball aside without contact damage. Each stroke can damage the player at most once, followed by a short hit-recovery period. Burst itself grants no invulnerability.

Ordinary pulses and rams damage every live enemy state. An attack aimed at the exposed right-side housing during recovery receives a 2.1 damage multiplier. A successful recovery counter loosens scrap once per attack cycle. A Pruner counter also loosens a repair pickup. Merely shooting during preparation does not cancel the attack unless the hit dismantles the enemy.

A released offcut travels at 9 world units per second, has a 0.65 radius, and deals 18 damage before Brace protection. It disappears on player contact, arena exit, or expiry within 3.5 seconds. Offcuts produce no pickups.

The arm's dismantling wins the run, even if workers survive. Zero hull health loses the run. The result screen records counters, collected parts, and elapsed simulation time.

Source: [combat state and damage implementation](../src/orchard/simulation.js).

## Parts earned during the run

| Pickup | Source and effect |
| --- | --- |
| Scrap | Loose pieces, dismantled machines, and successful recovery counters. Increases the ball's bounded size. |
| Shear Linkage | Dropped by a dismantled Snipcart. Each collected linkage adds 9 ram damage, up to three linkages, and the first unlocks Shear Buddy. |
| Adjustable Brace | Dropped by a dismantled Spreadleg. Each Brace improves steering acceleration, reduces burst cooldown by 0.22 seconds, and reduces incoming damage by 15%. Protection caps at 30%; burst cooldown has a 0.85-second minimum. |
| Repair | Dropped by dismantled machines and Pruner recovery counters. Restores up to 16 hull health without exceeding the 100-health maximum. |

Collection fits mechanisms immediately. The models expose attachments for earned Shear and Brace parts. The ball's collision radius grows from 1 to a maximum of 1.65.

Shear Buddy follows beside the ball and attacks a nearby enemy automatically. Its hit deals 7 damage and primes the target for three seconds. The next player hit consumes that prime for a 1.3 damage multiplier. The companion attacks at most once every 2.5 seconds and can be deployed only once per run. The companion requires no second component, and ordinary damage remains sufficient to finish the encounter without deploying it.

This is one following support machine. A planted-device system, classes, item-selection screen, persistent progression, and a full multi-arm boss are outside this build.

Sources: [pickup and companion behavior](../src/orchard/simulation.js), [model attachments](../src/orchard/models.js).

## Scope and verification limits

The first proof is a bounded orchard encounter, not the proposed 30–45 minute expedition. Its final balance, encounter duration, camera readability, and human understanding require playtesting. Browser and fixture results are recorded separately in the [first-build verification receipt](FIRST-BUILD-VERIFICATION.md). A scripted or state-fixture victory does not establish a human playthrough.

The normal entry does not expose the QA bridge. `/orchard.html?qa=1` exposes game and rendering state for instrumented checks. Evidence that changes state through that bridge must identify itself as fixture evidence.

The [build-team record](FIRST-BUILD-SWARM.md) tracks delivered lanes, review, and verification outcomes. The original yard's controls, progression, and verification remain in the [baseline guide](BASELINE-GUIDE.md).
