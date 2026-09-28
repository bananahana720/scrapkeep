# Concept-to-playable iteration contract

## Inputs and handoff

Each category needs its source revision, chosen style reference, named subjects, gameplay fact to communicate, required camera/state, acceptance checks and known unresolved decisions. Keep the source of an owner decision separate from an agent's elaboration.

An implementation brief carries the reference-image hash, baseline commit, relevant asset IDs and shared event/class/threat rows, allowed files, largest visual discrepancies, required functional tests and rendered scenarios. A return carries the candidate commit, changed asset hashes, exact captures, performance receipt and remaining deviations. Do not invent another event/color table or replace code-native icons with generated text.

The asset-tooling track supplies reusable generation/export/inspection tools. This track supplies representative needs: clear sphere and pilot, readable painted materials, independently animated rig pieces, a mechanically readable Warden and a smooth banked route. Budgets are measured against the scene, not inferred from one mesh's triangle count.

## Loop and stopping rule

Brief → imagegen → Astra source/visual critique → bounded implementation → matched runtime stills and motion → compare → correct the largest discrepancy.

Use an actual rendered game capture as the composition reference once the first slice begins. Pin camera transform, field of view, resolution, lighting, scenario seed, character, growth and attack phase. A generated still that moves the camera or changes the danger geometry is a failed match, not a revised gameplay requirement.

Allow an initial attempt and two focused corrections for a named problem. Retain the best passing version. If the result stalls, report the exact tradeoff and continue independent categories; never lower the target or redesign the selected appearance silently. Ask Andrew when the remedy changes the design.

## First scene

Start from an explicitly refreshed v2 integration identity after the sprint coordinator's next handoff. Do not merge uncommitted hero, boss or animation work from sibling worktrees. Use the existing Spillway stage and encounter rules; this concept's terrain is a visual study, not a replacement map.

Demonstrate a visible enclosed pilot, independent gyro motion, banked traversal, clear landmark, collection and growth, a representative enemy attack and the live HUD. Exercise Sable, Rivet and Kest in the same scene. Preserve current movement and committed damage geometry. If a form needs a gameplay change, return it as a named decision before implementation.

## Rendered verification

Record hardware, driver, Godot version, renderer, settings, resolution, source identity and benchmark scene. Use 1920×1080 on this PC. Stop this track's image generation and other known owned GPU jobs before measuring; do not stop another session's processes.

Run three 120-second samples after warm-up for traversal, dense combat with a grown mech, and a boss/effect peak. Report p50, p95, p99, frames over 50 ms, CPU/GPU timing where available, memory, draw calls and visible geometry/effect counts. Separate loads and transitions. Preserve raw timing samples. The existing demo criterion is **p99 ≤16.7 ms in dense combat**, stricter than the first planning draft. Apply that target to this slice's rendered scenarios and report any scenario failure separately. Fixed-fps headless runs only test simulation.

Run `npm run sketch:smoke` and the applicable existing functional tests on the actual candidate. Inspect rolling, jumps, rebound, camera obstruction, collection, growth, ability cues, overlapping telegraphs, menus and restart. Match threat drawings to committed damage geometry and keep the 25-word fight limit. Native Godot evidence and Andrew's play are required; a browser comparison page tests neither.

## Milestones

Treatment choice → atlas category sheets → first playable slice → remaining approved demo spaces and presentation states. Bring Andrew completed category/slice comparisons; ask earlier only for an uncovered identity choice or a change to the selected direction. Wider region candidates remain concepts until separately admitted as gameplay content.
