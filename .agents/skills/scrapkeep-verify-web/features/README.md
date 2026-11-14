# Web verification map

This directory is the maintained source for verifying Scrapkeep's browser pages. Read this index before driving a page, then use the matching feature file as the recipe. Every drive under `drive/` passed on stage `stage/alpha-w40` at 6d4320b8 on 13 November 2026, in a cloud box.

## Baseline preconditions

- Run from the repository root with `W=.agents/skills/scrapkeep-verify-web`.
- `$W/scripts/web.sh start`, then `$W/scripts/web.sh doctor` exits 0.
- The kit starts with no marks (its scratch verdicts file does not exist) and each drive opens a fresh browser with empty local storage.
- Never drive a server this run did not start: not `npm run dev` on 5173, not Andrew's kit on 8765.

## Driving conventions

- Handles are ids and data attributes; a picture is taken before and after the press that matters.
- A drive ends by putting the page back as it found it (the kit drive clears its marks).
- Wait on what the page shows (`waitForFunction`, a locator), not on a fixed time, except to let a 3D scene draw.

## Proof and skip reporting

- A proof is the pictures and `rows.json`, plus the server's file for the kit.
- Name the feature file and the sub-feature ids covered with every receipt.
- A path not reached is reported with the failing check and its `FAILED` picture.
- Limits: headless software-rendered Chromium, one viewport, no sound, no feel.

## Feature entry contract

Each feature file has an H1, one paragraph on what the user sees, then four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with Playwright`, `Gotchas`.

## Features

- [Sitting Kit](./sitting-kit.md): mark areas, notes, vetoes, saved to the PC, export, clear.
- [The yard](./yard.md): the start screen, How to play, a hero, the start of an expedition.
- [The Iron Orchard](./orchard.md): the entry card and the first seconds inside.

Not mapped: the frozen lead-capture server (`npm run server`, `server/README.md`; its own tests are `npm run test:leads` and `npm run test:leads:browser`), and the pages published as claude.ai artifacts, which are not served from this repository.
