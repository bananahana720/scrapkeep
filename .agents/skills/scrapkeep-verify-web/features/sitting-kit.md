# Sitting Kit

The page Andrew marks his playtest sitting on. It names the build, shows a row of eleven numbered area buttons with a count ("0 of 11 marked"), and for each area three verdicts (Accept, Accept with fixes, Not yet), a Try list, the rulings that apply, the coordinator calls he may Keep or Veto, and a notes box. Everything saves as he clicks, to the PC through the server and to the browser.

## Sub-features

- `SK-1` The page names the checkout's commit (from `/api/build`).
- `SK-2` A verdict colours the area and its numbered button and raises the count.
- `SK-3` Notes, Try ticks and Keep or Veto choices are kept.
- `SK-4` Marks are written to the server's verdicts file and survive a reload.
- `SK-5` Show Markdown prints the summary: verdict table, fix notes, vetoed calls.
- `SK-6` Clear all marks asks first, then empties the page and the file.
- `SK-7` Copy as Markdown, Download JSON, the sound toggle and the light or dark switch.

## How to get to it (user POV)

- `npm run sitting-kit`, then open `http://localhost:8765/`.
- Or open `project-guide/handoff/sitting-kit/index.html` as a plain file (saves in the browser only).

## Driving it with Playwright

Preconditions: baseline (the skill's own kit server on 8799, with its scratch verdicts file).

- **SK-1 to SK-6:** `node .agents/skills/scrapkeep-verify-web/features/drive/sitting-kit.mjs sitting-kit`. Expect exit 0 and "9 of 9 checks held, 0 page error(s)".
- **SK-2:** click `#pips button` number 3, then `.vbtn[data-v="notyet"]` in the third `section.area`. The area and the button carry `data-v="notyet"` and `#gate` reads "1 of 11 marked".
- **SK-3:** fill the area's `textarea`, tick its first checkbox, click `button[data-choice="veto"]` in area 2; the button's `aria-pressed` is `true`.
- **SK-4:** wait for `#save` to carry `data-state="pc"`, read `artifacts/local/verify-web/run/verdicts.json` for the note, reload, and read the count and the note again.
- **SK-5:** click `#print`; `#out` (the region labelled "Markdown export") holds "Not yet" and the note.
- **SK-6:** click `#reset` (it then reads "Press again to clear every mark and note"), click it again; the page reloads at "0 of 11 marked" and the file no longer holds the note.
- **SK-7:** not driven by the script. Add `#copy` (needs clipboard permission in the browser context), `#download` (wait for the download event), `#sound` and `#theme` when a change touches them.
- **The plain file:** open the `file://` path with a new script when a change touches saving; `#save` then stays `data-state="local"`.

## Gotchas

- The verdict radio inputs lie over their labels: click the `.vbtn` box, not the `label`.
- The row of area buttons sticks to the top. Bring a control to the middle of the view before clicking it (the script's `press`).
- The server refuses a write from another origin and a Host header that is not localhost or 127.0.0.1, so drive it by one of those names.
- The page's build text and its areas come from `project-guide/handoff/sitting-kit/areas.js`, refreshed by hand at a wave close. On 13 November 2026 it still described the wave 24 build; stale words there are content drift for the page's owner, not a failed drive.
- The `uat` runner scenario beside the page (`uat-scenario.txt`) checks the same flows with a model at the controls; this script is the deterministic one.
