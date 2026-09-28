# Integrated native visual slice

This checkout combines coordinator base `6a6ef840a14b286a8cdb3e6f70ef3804003dd0ab` with the enclosed-pilot presentation, painted surface treatment, distant Spillway scenery and owner-local prop material reuse. It remains an isolated candidate; canonical integration and Andrew's playtest are separate.

## Checked revisions

| Revision | Evidence | Result |
| --- | --- | --- |
| `aad0a13de06b65fe7ba5eaefb67b63cdeefe8044` | Full `npm run sketch:smoke`, five sketches | 165 checks passed; headless behavior only |
| `e1022e2ff7437da778800c3f7f522943b57f81ce` | Import, capture parse, `spine_movement_test` | Passed after adding `Palette.ANCIENT`, neutral aim reach and warm-white top speed tier |
| `e1022e2ff7437da778800c3f7f522943b57f81ce` | `stage_gorge_perf_test` | Resource counts and relative headless regression guard passed |

[Baseline smoke receipt](verification/baseline-smoke.json), [full log](verification/baseline-smoke.log), [alignment checks](verification/alignment-checks.json), and [material counts](verification/material-counts.log) retain their exact source identities. Later changes require their own evidence; the baseline smoke result does not silently qualify a later Warden implementation.

## Material reuse

The gorge uses **173 distinct materials, down from 227**. Geometry remains **374 mesh instances, 57 collision bodies and shapes, and one light**. Seven immutable solid-material variants are shared within each contraption owner. `Palette.solid` still returns fresh resources, because other callers animate damage flashes, gates, ice, beacons and boss effects independently.

These counts establish reduced material allocation. They do not establish fewer draw calls or a frame-time gain.

## Warden integration and hive correction

Code candidate `52458b3dbdee5126d5f6f0429316f72ddc37c034` attaches the existing clamp and all three family kits through the presentation hook. Kit origins meet the existing weak points; the upper tower joins those mounts. Collider and combat rules remain unchanged. The user-authorized appearance edit in `warden_look.gd` replaces stage-2 domes and heat columns with shallow hexagonal brood membranes and elevated open hex markers. Their material still flashes on cap contact.

Import and capture-script parsing pass outside the sandbox. All four affected tests pass: `hero_warden_assets_test`, `hero_assets_test`, `warden_family_test` and `combat_warden_lessons_test`. The initial sandbox import failed to open editor sockets; that failed result is preserved separately and was not counted as passing. See [focused checks](verification/warden-checks.json), [host import](verification/warden-host-checks.json), and [scope check](verification/warden-scope.json). The earlier whole-suite result is baseline evidence, not a full-suite run of this later candidate.

Independent review found copied shred marks floating off the jaws. Fitted ribbons now enforce positive signed clearance: 4,482 probes across three families measure 1.014–29.058 mm, within the 0.5–30 mm bound. Independent reconstruction also found zero negative samples. Finite sampling does not prove every point on every cue; open-crack ribbons use the helper but are outside this probe set.

Final presentation code is `ba7da85b5df564e1f84cc050f0782a07eebd7ac0`. The first native images exposed an inherited problem: weak-point centers lay inside the beacon mast. A reversible presentation replacement now opens a 2.9 m band around the active target, using two tapered mast sections and six narrow supports. Geometry tests place every support at least 1.44 m from the unchanged 1.3 m target center. Only the real flow Warden can claim the mast; death, stage change and hook teardown restore its original layers and shadows. Beacon/world source, lamp, ring and charge state stay unchanged.

Twelve native orbit views at `7edd066` cover all three families from four directions. They show the solid mast removed from the central targets; rear views can still be occluded by the kits' own housings. The orbit also exposed the hive's opaque front cap remaining closed during the open state. Commit `ba7da85` separates that authored surface into a bottom-hinged hatch driven by `family_open()`. Two final captures confirm a visible blue queen when open and an opaque cap when closed. Both focused hero tests pass again on that final code.

[Final open hive](runtime/warden-hive-hatch-open.png), [closed hive](runtime/warden-hive-hatch-closed.png), [Reactor](runtime/warden-mast-clear-stage1-angle45.png), and [Mind](runtime/warden-mast-clear-stage3-angle45.png) are actual rendered 1920×1080 images. [Hatch checks](verification/hatch-checks.json) retain final source hashes. [Mast handoff](verification/mast-handoff.json) and [orbit index](verification/warden-orbit-index.json) retain the earlier exact candidate identities. All fourteen final inspection captures and their receipts are included in the runtime manifest.

These checks accept the bounded wiring and visibility corrections. They do not establish finished Style A fidelity, chase-camera readability, representative combat performance or human feel. The warning volume and oversized badge still compete with the models in these views.

The 24 immutable ribbon meshes are prepared during startup. In a paired headless component measurement, setup takes 43.645 ms and the first real attachment afterward takes 11.699 ms; subsequent attachments take 4.265–4.584 ms. This moves the known fitting cost before title interaction. It does not qualify native first-use upload or whole-frame latency.

## Native performance

The retained pre-reuse gorge dense encounter at `cf2363e31ffe9864262297d1c6d98711d70ff9cd` measured **14.223 ms p99** over **120.000572 seconds** at an actual rendered **1920×1080**, using Forward+ on the RTX 4080. It kept 42–48 enemies active with a grown player. This is one staged scenario, not full-run or human-feel acceptance.

The first post-reuse run was interrupted during a session restart. Its screenshot survives, but no timing receipt does. Separately, a music-video generation process was observed at 99% GPU utilization. That process belongs to another session and was left running. No after-change performance verdict is claimed from the interrupted run.

The Warden captures are short visual inspections under competing GPU load, explicitly ineligible for performance qualification. Final 120-second after-change traversal, dense-grown and boss scenarios remain pending. No after-change FPS gain or target pass is claimed.

## Integration boundaries

The terrain source before `_build_sky` remains byte-identical to the refreshed base, preserving the gorge, overlays, bay and read-only queries. The scenery module adds seven static mesh batches, 7,968 triangles and no colliders outside the existing stage-1 terrain footprint. Stage visibility follows the terrain root.

W8 is not included in the supplied base. Preserve its workshop node in `_ready` and its `menu_held` input guard when integrating. The scenery hook is placed immediately after the world module is created.

Claude retains the canonical design documents, contracts, tracking and playtest log. `Palette.ANCIENT` is now available for its remaining call-site substitutions in roster, map_gorge, event_kinds and contraptions. No sibling design branch was merged.

The [fidelity gaps](FIDELITY-GAPS.md) remain explicit. The atlas provides direction; the current game does not yet match its sculpting, material depth or every motion sequence.
