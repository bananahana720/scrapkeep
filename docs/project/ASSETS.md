# Asset and tool provenance

This is an inventory of the current local prototype, inspected 5 September 2026. It does not select a source-code license or claim a completed distribution review.

| Material | Source and ownership record | Current handling |
| --- | --- | --- |
| Orchard meshes, articulation, environment and sound | [models](../../src/orchard/models.js), [scene](../../src/orchard/scene.js), [audio/input](../../src/orchard/main.js), authored during this project | Source is canonical; no imported rig or animation clip |
| Baseline procedural art and sound | `src/art.js`, `src/world.js`, `src/audio.js` | Existing baseline implementation |
| Eight concept images in docs/art | [art direction](../ART-DIRECTION.md), [study 01](../CONCEPT-STUDY-01.md), [study 02](../CONCEPT-STUDY-02.md), [study 03](../CONCEPT-STUDY-03.md), [prompt files](../art-prompts/) | Generated design references; retain original names and distinguish studies from playable captures |
| Andrew's notebook photos | [transcription and source record](../HANDWRITTEN-NOTES.md) | Research under docs/discovery; not public runtime assets |
| Three.js | Locked npm package; local package metadata declares MIT; full text at `node_modules/three/LICENSE` | Runtime dependency |
| Barlow Condensed, DM Sans, IBM Plex Mono | Locked @fontsource packages; each local package declares OFL-1.1 and includes LICENSE | Local bundled font files |
| Vite, Playwright, Prettier | Locked development dependencies | Existing local tooling; this closeout adds no packages |

Before distribution, perform the release inventory and notice task recorded as [T04](SOURCE-DISPOSITIONS.md#historical-identifiers) in the source dispositions, carried by [Q-E06](../../BACKLOG.md#q-e06). Package license declarations are evidence about installed packages, not a license grant for the whole project. No repository-wide LICENSE has been selected here.

For a new asset, record its local source or upstream URL, creator/provider, license evidence, transformations and actual use before admission. Preserve editable originals outside generated `dist/`. Record scale/axes and animation details for imported 3D assets. Paid tools, automatic downloads and remote publishing are separate decisions.

Public runtime content is copied into the Vite build. The concept images now live under `docs/art/`, outside the served tree, so they no longer add build weight; decide which belong in a distribution package during T04 rather than deleting the research history in housekeeping.

## Comps study posture (10 October 2026)

Commercial games Andrew owns (Risk of Rain 2, The Binding of Isaac: Rebirth, Gunfire Reborn, Roboquest) are studied, never mined. The research pack under `sketches/core-loop/design-v3/research/comps/` may hold mechanics, formulas, tuning numbers and structure written in our own words, production budgets measured from asset metadata (counts and sizes, nothing exported), and provenance notes that point at a free upstream source (a CC0 texture library, an OFL font, an MIT library) to be fetched from the original under its own license through the admission rule above. No model, texture, audio clip, music, code text, character or level layout from those games enters this repository or any Scrapkeep build, none is used as an image-generation seed, and no name from them is used as a Scrapkeep name (names appear in the notes only as evidence labels). Study copies live outside the repository and are deleted when the notes are accepted. See [CS-01](../../BACKLOG.md#cs-01). Study copies made outside the repository are deleted when their card is accepted, with one recorded exception: Andrew keeps the Roboquest install clone as a private modding archive under `~/Projects/roboquest-mod/` (his decision, 11 October 2026, TRACKING CS-03-A1); it sits outside the Scrapkeep pipeline, nothing here reads it, and it is never distributed.
