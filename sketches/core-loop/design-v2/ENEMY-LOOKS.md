# Enemy looks: the roster pass

One line per roster row (`roster.gd` at `core-loop-v2-enemies` `4106317`, 19 ids): the silhouette, the part that telegraphs the mechanic, and what keeps it from being a reskin. The rule is VISUAL-LANGUAGE §11: a Fleet unit's anti-ball tool is its biggest shape; an ancient's family geometry is its whole body. "Today" is the primitive-mesh look each `.gd` builds now, read from its `_build_crew` or `_build_body`; a flag means the current look does not show the mechanic and the modelled version must.

Every Fleet crew figure is an animal (primer ruling 13; `counter.gd:284-300` builds a rust body, a head with two ears and a brass tag). The Wardens are in `WARDEN-DESIGN.md`.

## Fleet crews (bolted, rust, one brass tag, klaxon family)

| Id | Silhouette | The part that telegraphs | Not a reskin because | Today (primitives) |
| --- | --- | --- | --- | --- |
| `chaser` | A low runner, visor and a dorsal fin, all forward lean | The fin lays flat and the body crouches through the lunge wind-up; the lane is on the ground | The only unit that commits its own body down a lane | Capsule, torus visor, box fin (`chaser.gd:46-53`). Reads. |
| `lobber` | A squat box with a mortar tube and a glowing bulb | The bulb (muzzle) glows through the telegraph, then the reticle lands | The only projectile you can bat back | Box, sphere, tube, band (`lobber.gd:42-65`). Reads. |
| `miniboss` | A tall copper hulk in armour plates with a core and a halo | Crouch before the leap, brace before the charge; plates swing open in the weak window | The only enemy with its own vented window loop | Capsule plus armour (`miniboss.gd`). Reads. |
| `vault` | A plated box on a post with a lamp | Nothing: it never attacks; its plating tint is the whole message | The only enemy that is a cache | Box, rings, post, lamp (`vault.gd:33-54`). Reads. |
| `mag_trapper` | A crew cart with a stack of discs on its back | The top disc lifts off the stack as it throws; the pit is the INSTANT ring | Heft-gated drag, the only counter growth alone beats | Crew plus two parts. **Flag:** the disc stack needs to be the tallest thing on the cart and the throw needs the disc to leave the stack; today the ring appears with no disc in flight. |
| `hooker` | A harpoon gun on a tall anchor post, taller than its crew | The gun swings to the ball and the harpoon slides forward in the rail during the LANE fill | The only tether; snapping it slings you | Post, brass gun box, hazard tip (`hooker.gd:41-43`). Reads at a glance; the harpoon should visibly leave the rail on fire. |
| `netcaster` | Two masts with a net plane between | The net crackles and rises up the masts over the fill (its height band is the telegraph) | The only counter that touches an airborne ball only | Two masts and a flat hazard box (`netcaster.gd:35-36`). Reads. The net should be a mesh, not a solid slab, so the air behind it shows through. |
| `bola_thrower` | A crew figure with a bola whirling overhead, the widest thing about it | The whirl speeds up through the telegraph and the reticle closes on the landing | The only slow arc that wraps a ball in the air | Crew plus one torus (`bola_thrower.gd:41`). **Flag:** a single torus reads as a hoop (VISUAL-BOARD s3 said the same); needs two weights on cords. |
| `plated_brute` | Layered plates, visibly one more than any other crew | The slam: it rears before the INSTANT ring; a plate pops off per breaking hit | The only extra-plate rule | Box plate with a crack glyph, pads (`plated_brute.gd:42-51`). Reads; the layers should be offset so the count is visible from the side. |
| `deflector` | A big curved dish, bigger than the crew | The dish braces toward you and its face lights along the LANE | The only rebound, and the only free vault | Cylinder face and torus rim (`deflector.gd:47-56`). Reads. |
| `winch_drone` | A rotor disc with a winch drum slung beneath, hovering | The drum spins up and the cable lane draws down from it | The only pull toward the pack | Rotor, drum, cable (`winch_drone.gd:37-39`). Reads. |
| `gyro_jammer` | A crew hunched under a tall aerial with a hoop on it | The hoop spins and the aerial sways through the telegraph, then the drift field lands over you | The only counter that steals your line and not your speed | Aerial and torus hoop (`gyro_jammer.gd:30-32`). Reads, but the sway is not animated today; the aerial must wobble, since the wobble is the mechanic. |
| `swatter` | A long low paddle arm, five metres, hazard-tipped | The paddle draws back through the wedge fill and swings at fire | The only knock you can ride with boost | Arm boxes and a hazard tip (`swatter.gd:41-43`). Reads. |
| `ramp_flipper` | A crew hauling a hinged floor plate | The plate is drawn tilting up over the INSTANT ring before the fling | The only tilt fling, and the only one you ride by jumping | One box plate (`ramp_flipper.gd:36`). **Flag:** the hinge and the crew's haul cable are not built; without them the plate reads as a floor tile until it moves. |
| `catch_trap` | A crew setting a spring-jawed cup on the ground | The cup's jaws stand open over the ring and snap shut | The only outright stop | Cylinder cup with a hazard rim (`catch_trap.gd:34-42`). **Flag:** no jaws today, so "spring-jawed" is not shown; two hinged jaw halves are the mechanic. |

## Awakened ancients (cast, seamless, dull petrol, Cherenkov seams, tonal)

| Id | Silhouette | The part that telegraphs | Not a reskin because | Today (primitives) |
| --- | --- | --- | --- | --- |
| `reactor_relic` | Squat, a cooling-tower waist, a dome, three vent stacks | The stacks swell 20% wide and 50% tall over the 2.4 s charge (`reactor_relic.gd:117-120`), then the vent erupts and leaves a crater | The only hazard that becomes terrain | Capsule, skirt, dome, three stacks, seams. Reads; the crown of each stack should carry the seam so the swell is lit. |
| `swarm_remnant` | Flat cast triangles, identical, in a bowling rack | The rack snapping into slots is the wind-up; the LANE from the rack is the telegraph; seams go dark while following | The only formation, and the only identical bodies in the game | Triangular prism with a seam (`swarm_remnant.gd:156-182`). Reads. |
| `mind_hand` | A tall thin three-segment arm on a cast foot with a lens cluster | The lens shows the trigger icon and swells through the warn; the middle joint bends (`mind_hand.gd:188-200`) | The only unit that reads your habit | Foot, three rods with joints, lens sphere, two small eyes, icon (`mind_hand.gd:127-184`). Reads. The brace should take a pose per verb like the Warden's (WARDEN-DESIGN §6). |
| `warden` | One clamp base, three family bodies | Per family: stacks, louvres and iris, arms and eye | See WARDEN-DESIGN | Collar, four jaw plates, core, badge, caps, magnet arm (`warden_look.gd`), kit primitives (`warden_kit.gd`). **Flag:** the kits are the failure this pass exists to fix. |

## What the model pass must keep

- Fleet units keep their tool as the biggest shape, and the tool moves through the telegraph: draw back, spin up, lift off, rise. A tool that sits still until fire is the flag above in every case.
- Ancients never move except to do the thing (VISUAL-LANGUAGE §11 "still, then exact"), and their seams carry the state: dim, charging, open, dark.
- The amber on the hive's brood caps (the caps lesson, `warden_look.gd:233-253`) sits close to the rare rarity colour and to Kest. It is code's material, not a look choice; in the h1 render the caps read as gold ore. The cap's membrane shape (a soft bulge, never a faceted gem or a dome) is the non-colour cue that keeps it from reading as loot (VISUAL-LANGUAGE §10 item 2). Flagged to V1 as a palette question, not changed here.
