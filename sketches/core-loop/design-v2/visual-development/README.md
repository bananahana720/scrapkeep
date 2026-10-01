# Scrapkeep visual development

First milestone of Andrew's concept-to-playable plan, authorized 27 September 2026. Andrew selected Style A: "I really like style A". Atlas production and isolated implementation are in progress.

Open [the concept atlas](index.html): the selected Style A reference and nineteen category sheets, with a critique beside each. The [original comparison](treatments.html) preserves the alternatives; the owner choice is already recorded in [owner-choice.json](owner-choice.json).

| Treatment | What changes | Main consideration |
| --- | --- | --- |
| [A: Painted workshop miniature](images/style-a.png) | Broad painted wear, rounded cast machinery, soft material transitions | Recommended for tactile construction and scenic depth |
| [B: Industrial adventure comic](images/style-b.png) | Strong contours, flatter shading bands, graphic chips | Strong silhouettes; reduce background outline weight in engine |
| [C: Carved canyon machinery](images/style-c.png) | Planar rock, faceted foliage and forged surfaces | Geometric clarity; visual facets must not imply collision bumps |

All three use the same generated composition. They are not screenshots or exact camera matches to the current build. Choosing a treatment does not approve the illustrative Warden, terrain layout, danger marking, ancient-light color or detailed ring/growth proposal. [The review](REVIEW.md) lists those limits.

## Sources and authority

The initial implementation baseline was `ad34cd3730bab93788860c6d0456debf55be7f75`. Andrew supplied refreshed base `6a6ef840a14b286a8cdb3e6f70ef3804003dd0ab`; it is now merged into this isolated checkout, with W8 continuing separately in UI files and its two disclosed one-line game hooks. The accepted main revision at intake was `27921442332d605edd1a678675c430a33969e119`. [source-manifest.json](source-manifest.json) pins the individual inputs, including the historical untracked hero and boss snapshots. Its coordinator-refresh section now pins HERO-SPHERE at `56a1970`, WARDEN-DESIGN and ENEMY-LOOKS at `30977c3`, and the incoming design rulings at stage commit `5cf1514`. These are read-only design inputs; none of those sibling branches has been merged.

The Bible and accepted ADRs remain production authority. For this sketch, the later owner request for a true sphere, visible enclosed pilot and gyroscopic rings supersedes the older irregular shell. This package does not amend the Bible. The draft's exact ring counts, growth thresholds, fourth-pilot mechanics and gyro lore are not approved by a style selection.

The source documents disagree in places. VISUAL-LANGUAGE still marks ancient blue pending, whereas later DESIGN-V2 section 11 records Andrew's color ruling. The later explicit choice of Cherenkov blue controls the sketch; the pending label is stale. The coordinator clarified Kest: right-click is `smoke_blink`, and holding Space while falling is glide. Both ship; future images must show both. Tally is the unlockable fourth pilot after the alpha, a friendly glitchy ancient robot whose transmog follows held parts and tree picks. The demo includes only a dormant housing on Moss’s shelf, a codex fragment and one summary flicker. Its playable kit and transmog rules require a later design pass.

## Current coverage

All eight categories in the initial [atlas inventory](ATLAS.md) now have concept references. [COVERAGE.md](COVERAGE.md) maps subjects to sheets and keeps missing states, corrections, motion/audio evidence and runtime work explicit. This is broad first-pass coverage, not completion of every subject.

Andrew also authorized [a layered Spillway concept study](LAYERED-SPILLWAY.md): pinball-inspired momentum and connected elevations expressed through a working gorge. This authorization does not include a new map implementation. The current playable pass preserves terrain collision and gameplay.

Use [the iteration contract](ITERATION.md) for implementation and runtime comparisons. Canonical board admission remains with the existing coordinator; the isolated notes and prototype do not imply that the paused sprint has merged this work.

The Claude sprint retains its worktrees and integration ownership. The refreshed base preserves the incoming terrain queries and overlays; the terrain source before `_build_sky` is byte-identical to that base. Our presentation edits to `src/world/terrain.gd` and `src/core/palette.gd` were disclosed through Andrew. Material sharing now also changes allocation sites in `src/world/contraptions.gd`: seven immutable variants are reused per owner. `Palette.solid` remains fresh for independently animated materials. The other Codex session owns asset tooling. This track reads both as inputs and writes only its own new package. Git metadata in the main checkout is read-only, so work was isolated in `/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/workspace` on `codex/visual-development`.

## Generation and evidence

Built-in imagegen produced the treatments and all category sheets. Every prompt is preserved as a sibling `prompt-*.txt`; [image-manifest.json](image-manifest.json) records hashes, source files and lineage. Corrected versions coexist with their originals. The gallery selects the current reference while retaining its limits. No generated labels, statistics or mechanism drawings override game contracts.

An Astra medium role performed source analysis and direct image critique. The role is pinned by the host tool; the delegate could not independently attest runtime metadata. The global routing observation recorder was read-only, so this assignment has a pilot coverage gap. This does not substitute for visual or runtime evidence.

Native prototype evidence is separate from the concept atlas. The stricter existing demo requirement is retained: rendered dense-fight p99 frame time at or below 16.7 ms on this PC at 1920×1080. Headless simulation timings cannot establish it. A rendered pilot preview works on the RTX 4080; that is not a dense-fight pass or human acceptance. The gallery received static syntax and local-asset checks; browser interaction remains unverified after the earlier browser permission refusal.

[Native pilot inspection checkpoint](NATIVE-PREVIEW.md) shows actual game captures separately from the generated atlas. [Integrated verification](INTEGRATED-VERIFICATION.md) records the refreshed-base checks, material counts and native measurement status; [fidelity gaps](FIDELITY-GAPS.md) name the remaining visual work.

[Coordinator handoff](COORDINATOR-HANDOFF.md) gives the final code identity, file seams, alignment fixes and remaining performance gate.
