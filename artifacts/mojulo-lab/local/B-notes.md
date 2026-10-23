# Part B notes (local PC, via the `mojulo` CLI, in-process, one call per rung)

Rows are in `B-ladder.tsv`. Harness is in `w/` (`h.py`, `b1.py` to `b5.py`). Jobs ran in parallel on a 32-thread box, all under `nice -n 10`, so wall times carry some contention. Mojulo wall_ms is the `[mcp] tool=... ms=N` line the CLI prints per call (the ledger's "last 1" was ambiguous with parallel jobs). The four "not run" rows were written at close-out by someone else; those rungs were killed or never started.

## Ceilings

| Ladder | Highest ok rung | First failing rung | Failure |
|---|---|---|---|
| B1 exact booleans | 512 bores at 128 segments: 283k tris, 20.9 MB, mint 11.6 s + export 272.9 s | 512 bores at 256 segments | mint_solid error, quoted below |
| B2 sampled field | cells 128 (schema max): 95k tris, 8.0 MB, 4 s total | none | not above 128 (schema cap) |
| B3 code kind | 10,000 extrude treads: 272k tris, 18.0 MB, 33 s | 50,000 | export_model >600 s (my cap); 20,000 never finished |
| B4 OpenSCAD | 40x40 holes at $fn 32: 213k tris, 13.7 MB, 101 s | 40x40 at $fn 128 | export_model >600 s (my cap); H=100 not run |
| B5 terrain | 8 features + `plants:true`: 13.4M tris, 30.0 MB, 37 s | none | maxed the feature list (8) |

B1 grid used a z-axis bore grid: 64 = 8x8, 512 = 32x16, 4096 = 64x64 (not run). Bore spacing was 900/max(nx,ny) cm, capsule radius up to 12 cm. B3 used `extrudes` (stair treads), not `fields` boxes. A `fields` exact-box variant is in `w/b3.py` but was never run.

## First error messages, exact

- B1, 512 bores at 256 segments, mint_solid: `memory access out of bounds — parameter manual: get_solid_vocab({ id: 'workbench' }).` (after 9.9 s). This is a WebAssembly (Manifold) memory failure, not a refusal.
- B1, 512 bores at 128 segments, with the default tool budget: `export_model exceeded its 120000ms budget; the work may still be running. Check /observability or get_tool_ledger.` The glb was not written. That is a hard 120 s default per-tool timeout. Setting `MOJULO_MCP_TOOL_TIMEOUT_MS=600000` (read in `lib/mcp/telemetry.js` line 53) lets the same call finish in 273 s with 283k tris. Every later row ran with that variable set. Via MCP the same 120 s default probably applies; I did not test MCP.
- B3 N=50000 and B4 H=40 at $fn 128: no mojulo error. My harness killed the export at 600 s (rows marked `timeout`). Mint was fast: 3.7 s and 36 s.
- B5e first attempt (my mistake, removed from the tsv): `Invalid terrain manifest: terrain.world.features[0].feature must be one of river, range, lake, plateau, volcano, coast`. Sizes like `cordillera`, `tableland`, `shield`, `mesa` go in `size`, not `feature`.

## Where the time goes

Export dominates exact and instance-heavy rungs. Mint dominates the terrain worlds.

- B1: mint 0.4 s (64 bores, 48 seg) to 11.6 s; export 0.5 s to 273 s. 512 bores at 128 segments is 24x slower to export than to mint. Export time grows faster than triangles: 106k tris took 12 s, 283k tris took 273 s.
- B2: mint and export are balanced and cheap, mint about 1.8x export (cells=128: 2.5 s and 1.5 s).
- B3: mint is nearly free (0.04 s at 100, 0.6 s at 10,000). Export grows faster than linear: 0.07 s, 0.4 s, 30.5 s for 100, 1,000, 10,000. 50,000 passed 600 s.
- B4: OpenSCAD wasm, both phases are slow at high `$fn`. 40x40 at $fn 32: mint 8.3 s, export 91 s. 10x10 at $fn 128: mint 2.2 s, export 5.2 s.
- B5: mint 5 to 25 s, export about the same. `plants:true` roughly doubles time (13 s to 39 s default river, 18 s to 37 s for 8 features).

## Surprising

- The glb with plants reports tens of millions of triangles (38M default river, 41.7M continent, 13.4M for the 8-feature world) but only 18 to 30 MB. Triangles are counted over instances. Without plants the same worlds are 130k to 200k tris. The "300k tris" budget in Part C is met only without plants.
- B5g: painted `from` terrain gave the same 69.6k tris at span 8,000 m and 50,000 m. The span and the `detail` min/rock/soil knobs did not change mesh size.
- The CLI truncates a tool's stdout at 65,536 bytes. A mint of 1,000 or more `extrudes` returns a per-monomer stats list that exceeds this, so the JSON is cut and cannot be parsed. The mint still succeeded. My harness recovers `ref` from the head of the output.
- B3 N=100 gave 2,778 tris and N=1000 gave 27,258 (about 27 per tread), so tris scale linearly while export time does not.
- B1 triangle count is not monotonic in bore count in a simple way: 64 bores at 128 segments is 42k tris, 512 bores at 48 segments is 106k.
