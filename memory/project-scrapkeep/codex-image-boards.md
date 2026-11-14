---
name: codex-image-boards
description: "Codex stays only as the concept-board image engine (gpt-6-astra on Plus); the Codex code lane retired 2026-10-17; login, tier and cleanup lessons"
metadata:
  node_type: memory
  type: reference
  originSessionId: 99053a69-80bd-4be5-8d1c-7c0c8c13e9bc
  modified: 2026-10-22T19:40:20.056Z
---

**Status:** Andrew retired the Codex code lane on 2026-10-17 at 20:02, and Claude does all code and asset work. Codex survives only as the picture engine for concept boards: `~/scratch/w18/boards/v2/run.sh` runs `codex exec -m gpt-6-astra` with the four style refs. Astra draws the intricate subjects, and FLUX handles quick, simple prop boards.

**Login:** Astra needs the Plus login, which Andrew has had since 2026-10-10. A free login answers only gpt-6-luna, with an error that blames the account type. Diagnose with one probe (`codex exec -m gpt-6-astra "Reply OK"`), then grep the newest `~/.codex/sessions` rollout for `plan_type`. If it says `free`, ask Andrew to run `codex login`.

**Tier:** the config default is `service_tier = "priority"`, which burns usage fast. On 2026-10-06, eight parallel units spent the whole allowance in about two hours. Pass `-c service_tier='"default"'` for bulk image work, and check the remaining usage first.

**Cleanup lessons (wave 13):** Astra's in-place edit re-renders the whole frame and usually breaks something you asked it to keep.
1. Fix colour in code with a masked ImageMagick hue shift through a feathered mask. Blue 215° to green #9dff3c is `-modulate 100,100,30`, and brass to dark iron is `-modulate 62,12,100`. The old script is gone; wave 13 to 16 scratch was deleted on 2026-10-22, and its scripts and notes are in `~/scratch/archive-w13-w16-text-2026-10-22.tar.gz`.
2. Give each call one subject, with a box, a change and a keep list.
3. The coordinator judges candidates on a contact sheet (`magick montage`), because Astra rejects its own good retries over tiny pixel shifts.
4. Composite disjoint fixes in code.
5. For a picture with three or more misses, regenerating from scratch with the locked masters as references beats editing.
6. Pass `base-hero.png` as a reference, or the 2 m scale ball drifts.

**Fidelity bar (Andrew, 2026-10-02):** "I would love to get to this level of visual fidelity". The image-generated Dig keyframes are the look the game is judged against. Related: [[art-purpose-before-making]], [[pc-gpu-rules]].
