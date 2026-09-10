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

Before distribution, perform the release inventory and notice task in [T04](BACKLOG.md). Package license declarations are evidence about installed packages, not a license grant for the whole project. No repository-wide LICENSE has been selected here.

For a new asset, record its local source or upstream URL, creator/provider, license evidence, transformations and actual use before admission. Preserve editable originals outside generated `dist/`. Record scale/axes and animation details for imported 3D assets. Paid tools, automatic downloads and remote publishing are separate decisions.

Public runtime content is copied into the Vite build. The concept images now live under `docs/art/`, outside the served tree, so they no longer add build weight; decide which belong in a distribution package during T04 rather than deleting the research history in housekeeping.
