# Scrapkeep visual development

First milestone of Andrew's concept-to-playable plan, authorized 27 September 2026. Andrew selected Style A: "I really like style A". Atlas production and isolated implementation are in progress.

Open [the concept atlas](index.html): the selected Style A reference and sixteen category sheets, with a critique beside each. The [original comparison](treatments.html) preserves the alternatives; the owner choice is already recorded in [owner-choice.json](owner-choice.json).

| Treatment | What changes | Main consideration |
| --- | --- | --- |
| [A: Painted workshop miniature](images/style-a.png) | Broad painted wear, rounded cast machinery, soft material transitions | Recommended for tactile construction and scenic depth |
| [B: Industrial adventure comic](images/style-b.png) | Strong contours, flatter shading bands, graphic chips | Strong silhouettes; reduce background outline weight in engine |
| [C: Carved canyon machinery](images/style-c.png) | Planar rock, faceted foliage and forged surfaces | Geometric clarity; visual facets must not imply collision bumps |

All three use the same generated composition. They are not screenshots or exact camera matches to the current build. Choosing a treatment does not approve the illustrative Warden, terrain layout, danger marking, ancient-light color or detailed ring/growth proposal. [The review](REVIEW.md) lists those limits.

## Sources and authority

The implementation baseline is `ad34cd3730bab93788860c6d0456debf55be7f75`, the paused v2 integration branch. The accepted main revision at intake was `27921442332d605edd1a678675c430a33969e119`. [source-manifest.json](source-manifest.json) pins the individual inputs, including untracked hero and boss proposals.

The Bible and accepted ADRs remain production authority. For this sketch, the later owner request for a true sphere, visible enclosed pilot and gyroscopic rings supersedes the older irregular shell. This package does not amend the Bible. The draft's exact ring counts, growth thresholds, fourth-pilot mechanics and gyro lore are not approved by a style selection.

The source documents disagree in places. VISUAL-LANGUAGE still marks ancient blue pending, whereas later DESIGN-V2 section 11 records Andrew's color ruling. The later explicit choice of Cherenkov blue controls the sketch; the pending label is stale. Likewise, the pinned class data uses `smoke_blink` for Kest while earlier prose says glide. Images must not settle that gameplay contract.

## Current coverage

All eight categories in the initial [atlas inventory](ATLAS.md) now have concept references. [COVERAGE.md](COVERAGE.md) maps subjects to sheets and keeps missing states, corrections, motion/audio evidence and runtime work explicit. This is broad first-pass coverage, not completion of every subject.

Andrew also authorized [a layered Spillway concept study](LAYERED-SPILLWAY.md): pinball-inspired momentum and connected elevations expressed through a working gorge. This authorization does not include a new map implementation. The current playable pass preserves terrain collision and gameplay.

Use [the iteration contract](ITERATION.md) for implementation and runtime comparisons. Canonical board admission remains with the existing coordinator; the isolated notes and prototype do not imply that the paused sprint has merged this work.

The paused Claude sprint retains its worktrees and integration ownership. The other Codex session owns asset tooling. This track reads both as inputs and writes only its own new package. Git metadata in the main checkout is read-only, so work was isolated in `/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/workspace` on `codex/visual-development`.

## Generation and evidence

Built-in imagegen produced the treatments and all category sheets. Every prompt is preserved as a sibling `prompt-*.txt`; [image-manifest.json](image-manifest.json) records hashes, source files and lineage. Corrected versions coexist with their originals. The gallery selects the current reference while retaining its limits. No generated labels, statistics or mechanism drawings override game contracts.

An Astra medium role performed source analysis and direct image critique. The role is pinned by the host tool; the delegate could not independently attest runtime metadata. The global routing observation recorder was read-only, so this assignment has a pilot coverage gap. This does not substitute for visual or runtime evidence.

Native prototype evidence is separate from the concept atlas. The stricter existing demo requirement is retained: rendered dense-fight p99 frame time at or below 16.7 ms on this PC at 1920×1080. Headless simulation timings cannot establish it. A rendered pilot preview works on the RTX 4080; that is not a dense-fight pass or human acceptance. The gallery received static syntax and local-asset checks; browser interaction remains unverified after the earlier browser permission refusal.
