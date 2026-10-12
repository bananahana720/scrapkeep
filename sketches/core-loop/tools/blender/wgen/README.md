# Blender park trial

`generate.py` constructs a seeded Blender Bezier wash spine. Its control anchors
place the stamp rows, named waymarks and pilot waypoints together. It emits the existing
`scrapkeep-park/1` format, with no heightfield extension or exported mesh.

The macro surface is a descending bajada with a winding wash, shallow bowls,
small launch lips, side mesas and hoodoo anchor fields. Enemy homes occupy washes.
Two off-line events and three activities exercise the existing tables. Six pilot
entries satisfy the line schema; this trial measures Rivet, Kest and the floor.
These parks are experiments, not stage-table entries or shipped stages.
The export samples the 17 control anchors; curve handles do not affect the JSON.
The trial therefore proves a seeded schema emitter and linked placement, with
little advantage over plain Python at this level. Interior curve sampling,
Geometry Nodes, sculpting and arbitrary mesh-to-stamp conversion remain untested.

```sh
nice -n 10 prlimit --as=12884901888 /home/andrew/.local/bin/blender --background --python-exit-code 1 --python sketches/core-loop/tools/blender/wgen/generate.py -- --seed 1 --out sketches/core-loop/src/world/park/park_wgen_s1.json --lines-out sketches/core-loop/tools/park_lines/park_wgen_s1.json
```

Every process must have XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME and TMPDIR
under the assigned evidence directory. The trial's command recorder does this.
`sweep.py --evidence <directory>` executes generation, schema, bake, graph and
four bot seeds on each of three lines, sequentially at nice 10. Its recorder is
`<directory>/run.py`; logs and scores remain there.

## Loading experimental map ids

The shipped schema rejects unknown map ids even when their rows are valid.
`schema.gd` supplies the validator's existing explicit world-1 context.
`context.gd` adds one experimental map id to a loaded schema script in memory.
The original source file remains unchanged. `bake.gd` and `graph.gd` call the
shipped tool implementations after that registration. Their formats, algorithms
and acceptance bands are unchanged.

`traverse.gd` inherits the shipped traversal tool's sampler, bot, scoring and
output. Its `TrialGame` overrides table selection with a fresh script compiled
from the park table text, changing only the first row's map in that private
instance. It never reloads or writes the shipped stage table resource.
This adapter establishes experimental traversal, not native runner support for
arbitrary maps. No completionist hook is added.

`inspect.gd` calls the shipped density and sight test measurements for one map.
The collider test is fixture-only. A retargeted copy can run from the evidence
directory with its map strings changed and the trial context installed, while
retaining its 10,000-point sampler and 1 cm threshold.

The report at `/tmp/claude-1000/w13-sol/wgen-blender-r1/REPORT.md` owns the verdict,
measured scores, command receipts, limits and the selected seed.

## Measured result

Verdict: PARTIAL. Keep the macro emitter and linked row/line placement. Two
eight-park sweeps produced 192 real headless bot rides. Every ride reached the
Warden. The first revision had zero dead stops; the second had one. The best
candidate is revision 2, `park_wgen_s6`, with zero stops in its twelve rides.
Its two pilot lines and floor pass 18 of 25 scored bands, versus 17 for the best
first-revision candidate.

Across the pilot summaries, median anchor gap fell from 266.525 to 65.05 m,
while flow fell from 0.9695 to 0.7592. Airborne share moved only from 0.0485 to
0.0582; all pilot lines miss the 0.12 floor. Taller rounded hills did not supply
the required airtime or sustained blazing speed.

The selected park passes 10,000-point collider parity, worst error 0.00039 m,
and density, worst distance 14.1421 m. Landmark sight fails at 0/1089 points:
the spire cap hides its central target. Graph pocket and activity clearance
breaches also remain. No completionist win, GPU render or human feel verdict
is claimed. The coordinator's three views are in the report folder's
`stills.json`.
