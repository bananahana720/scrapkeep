---
name: openverse-asset-source
description: "Openverse API (api.openverse.org/v1) as a free image and audio source; Scrapkeep ships only CC0 from it, other licences are reference only"
metadata:
  node_type: memory
  type: reference
  originSessionId: 02600e86-9e5b-4a9f-ad09-73a1ae74c4e2
  modified: 2026-10-15T20:14:19.601Z
---

Andrew pointed at https://api.openverse.org/v1/ on 2026-10-15 as optional, "not necessary if we're set or have better assets".

Tested the same day: anonymous search works at `/v1/audio/?q=...` and `/v1/images/?q=...`. The `license=cc0` and `license_type=commercial,modification` filters work. Each result carries `license`, `source` (audio is mostly Freesound, images mostly Flickr and Wikimedia), `filetype`, `duration` and a ready-made `attribution` line. Search is noisy: "arizona mesa" returned photos of the city of Mesa. There are no 3D models.

**How to apply:**
- Ship only CC0 from it. CC-BY needs a credits line per asset. CC-BY-SA and any NC or ND licence stay reference-only. TADR-003 wants source and licence recorded per asset, and the attribution field gives that.
- Best fits:
  - reference boards for the park dressing pass and storyboards (Arizona landform muse, see [[scrapkeep-design-principles]]);
  - raw CC0 foley layers if Andrew's play notes say hits feel thin.
- Music stays ACE-Step, and the look stays code-coloured and procedural ([[codex-image-boards]]), so it does not replace either.
