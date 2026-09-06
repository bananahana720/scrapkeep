# Section 6 decisions and handoff

## Practical choices for this review edition

- The 2,926-word section starts with the exact requested heading. It explains the player loop, purpose and unresolved detail for all assigned systems. Future rules and the bounded lightning prototype are distinguished throughout.
- The four-slot table is the authoritative readable mapping. U01 depicts those four actions, not the prototype's five-input arrangement. No new named classes, items, recipes, prices, currencies or slot systems were invented.
- U02 uses separate equipment, tree-respec and map frames to demonstrate the crucial permission distinction. The map's anonymous terrain cards do not select a starting world or fixed route.
- Current architecture handoff preserves both playable entries and existing simulation/render/model/input ownership. No gameplay code, build, dependencies or live source files were changed.

## Image issues for cohesion review

- U01: extra empty revival socket implies an unapproved second allowance. Fox-shaped companion appears organic rather than loot-assembled machinery. Tread-heavy player silhouette underexpresses accumulated rolling mass. Combat geometry is illustrative and cannot prove collision agreement. Consider a targeted regeneration at coordinator discretion; none performed here.
- U02: six visible terminal endpoints contradict the required eight, despite the prompt requesting eight. Correct prose and caption explicitly prevent adopting the diagram. Player construction could express accumulation more strongly. Comparison bars are unlabeled placeholders for layout, not proposed final stats. Consider a targeted regeneration at coordinator discretion; none performed here.
- Both sheets have large readable requested labels and support their main layout concepts. Grime stays largely at borders and background hardware.

## Source gaps requiring future design

- Milestone allocation, tree prerequisites/tier structure, material prices and how supply supports completion.
- Respec opportunity scope/frequency/refund behavior; ordinary equipment capacity/slot limits.
- Attunement rules, stacking compatibility, fixed endpoint recipes and discovery disclosure.
- Device capacity/lifetime/recall/resources and level-to-level persistence; companion chassis/assembly details.
- World catalogue, repeats, starting world, levels per world, generation technique and final-encounter placement.
- Revival health/placement, unfinished-level interruption behavior, checkpoint persistence/migration details.
- Chaos miscast frequency, severity, element pool and preview/disclosure behavior.
- Production engine, hardware controller feel and full-run balance remain unproved.

## Evidence and local verification

Prompts prepend the exact locked file, SHA-256 0f694b904454716669d844e833973852c51a6ec48c719918797b06a7841322c7, and literal containment was asserted before submission and at closeout. Each complete prompt was read through exec_command and that returned text was submitted to built-in imagegen. Both actual generated PNGs were copied unchanged and visually reviewed. qa.json records file hashes, observed dimensions, source output paths and valid PNG chunk CRCs. Generation-result JSON files preserve tool metadata while omitting the large data URL whose image bytes are retained separately. No regeneration or paid fallback was used.

The default Python lacks Pillow. PNG structural verification therefore used standard-library signature, dimensions and CRC checks; image inspection used the displayed generated outputs. This does not affect asset copies.

No game verification command was run in this isolated prose/image-only lane. The coordinator owns admitted-document checks and any required repository verification. No memory-derived facts were used in the section; current planning documents supplied the source basis.
