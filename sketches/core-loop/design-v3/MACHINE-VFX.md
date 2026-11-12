# Machine and boss effects

Status: built on `claude/vfx-enemies-bosses-yenswc` (2026-10-17), from Andrew's ask for effects "for different points of the game ... on the machine side, for bosses". Code: `src/presentation/machine_fx.gd`, specs in `src/presentation/fx_library.gd` (owner `machine`), test `tests/machine_fx_test.gd`, stills `tools/machine_fx_capture.gd`, bench ablation `--no-machine-fx` in `tools/perf_bench.gd`.

## The ask as verbs

Reading a body's intent before it acts; feeling a hit land on metal; seeing a machine clock out; knowing a special by sight before you hear it; feeling a boss phase as an event and its fall as an ending. Disciplines: VFX, combat readability, sound sync, comic presentation.

## The two materials

| | Fleet crews (and Brindle) | Ancients (reactor, swarm, Mind; the Waking and the Mind) |
| --- | --- | --- |
| Gives off | steam (worn bone puffs that swell as they fade) and brass sparks | seam light (ANCIENT green arcs that crawl and fizz) and cast petrol shell shards |
| Wind-up | a steam jet off the body that builds with the wind-up's progress | seam light crawling round the body, thickening |
| Strike | the jet lets go in one puff | one fizz of arcs |
| Hit | brass sparks; a heavy hit (30+) adds a steam leak and **KLANG** | arcs; heavy adds shell shards and **KRZZT** |
| Death | a sigh of steam and sparks (the tone bible's clock-out gag); an elite or miniboss also sheds plate and stamps **CLOCKED OUT** | the seam light gutters out in rising motes |
| Stagger | a pack unit gets an amber daze halo for its 1.25 s; a posture Warden vents for its 4 s under the halo and stamps **KRNK** | same, in seam light |
| Arrival | each arrival ring vents steam from the ground for its whole second, then a landing puff | seam light wells up in the ring, then motes |

## The four specials

Each moment fires from one frame: the body's own `special_tell(moment)` signal. The same row names the PR #12 render that plays (`MachineFx.SPECIALS[name].sounds`), so audio and picture cannot drift. A tell is a read: never thinned by the density governor, always worded.

| Special | Presence | Tell (with its sound) | Break |
| --- | --- | --- | --- |
| Foreman | a slow steam wisp off the horn mast | horn blast: steam burst and a brass ring out to the crew, **HOOONK** (`foreman_tell`) | **SHIFT OVER**, steam sigh (`foreman_break`) |
| Dispatcher | its model's beacon and the radar loop | tube puff and an amber ping ring, **NEXT** (`dispatcher_tell`) | sparks, **OUT OF ORDER** |
| Splitter | a sputtering amber fuse | the seam flare: sparks and a bone-white ring, **1+1+1** (`splitter_tell`) | rammed: **UNION RULES** (`splitter_break_split`); from above or range: **CLEAN** (`splitter_break_clean`) |
| Linker | the mains-buzz loop | arcs crawl the cable end to end, sparks at the dish, **TWANG** (`linker_tell`) | dish chunks, **CLANG** |

Contract for the behaviour units (waves 17 to 19): a special body declares `signal special_tell(moment: String)`, emits `"tell"` on the committed-telegraph frame, sets meta `split = true` before dying when a Splitter is rammed at ground level, and a Linker exposes `cable_ends() -> [Vector3, Vector3]`. A Foreman as an elite affix is found by meta `elite_affix == "foreman"`.

## Bosses

| Boss | Phase change | Fall (straight, then the wink one beat later at 129 BPM) |
| --- | --- | --- |
| Brindle | brass ring, steam, sparks, plate chunks, no word (PF-26: it covered him); the eject stamps **EJECT** | five blasts walk across the hull 0.22 s apart, a last ring, then **END OF SHIFT** |
| The Waking | each lost chunk: green ring, shell shards, arcs, motes, **KRAKK** | the same walk in seam light, then **BACK TO SLEEP** |
| The Mind | each lost chunk, same, **RECALIBRATING** | then **SIGNAL LOST** |

The Waking and the Mind never publish `boss_phase_changed`; their phase is a lost posture chunk, so the effect keys off `posture_changed`.

## Readability and budget

- Nothing here is committed geometry. Every effect sits on or over the body, below the telegraph's priority 40, so no spark crosses a threat edge (FEEL-READABILITY 1.1). Body effects are P5 and steam and motes P7: the governor thins them (P7 hardest) and drops candy words past density 0.7.
- One pack's arrival effects start on the frame its rings do, so they inherit the 0.2 s gap rule between packs and "one pack's warnings start together".
- Words: four on screen at most, one candy word per 0.4 s, 3-frame overshoot slam, slide off on a diagonal; reduced motion keeps the word and drops the slam, slide and halo spin.
- Pools: machine ceiling 876 particles (pinned), 81 emitters; followers (wind-ups, dazes, arrivals) cap at the pool size and skip silently when full, so 12 attackers winding up at once fit (16 steam jets, 12 arc crawls).

## Open, and who owns it

- Elite and miniboss intro cards are HUD work (tone bible); not here.
- Body poses for wind-ups (`ATTACK_ROWS.pose`) belong to the rig and animate thread.
- GPU frame time on the 4080 under a 12-attacker fight is the machine's check; the cloud bench prices CPU only.
