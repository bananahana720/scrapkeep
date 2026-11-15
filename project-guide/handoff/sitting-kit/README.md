# Sitting Kit

The page where Andrew marks the 11 areas at the full-alpha sitting (older records call it "wave 21") (DECISIONS.md section 1: "Verdicts are recorded on the Sitting Kit page"). Each area has a verdict control (Accept, Accept with fixes, Not yet), a "Try" list with where to look, the rulings that apply, the coordinator calls he may veto, and a notes box. Verdicts, ticks, vetoes and notes save as he clicks.

## Run

```bash
npm run sitting-kit
```

Open `http://localhost:8765/`. The server binds to 127.0.0.1 only. Verdicts save to `artifacts/local/sitting-kit/verdicts.json` (gitignored) and to the browser's local storage; opening `index.html` as a plain file works too and saves in the browser only. `--port <n>` and `--verdicts <file>` change the port and the file.

The page's Export section copies a Markdown summary (verdict table, fix notes as card lines, vetoed calls, Try lines done) or downloads the JSON.

## Files

| File | What |
| --- | --- |
| `index.html` | The page. One `VERDICTS` table drives the words, colour, shape and chime of each verdict. |
| `areas.js` | The content: the 11 areas, each with its sources. Refresh it at each wave close from DECISIONS.md, the veto list and `shared/alpha-status/sitting-watch-list.md`. |
| `serve.mjs`, `serve.test.mjs` | The localhost server and its node tests (`npm test`). |
| `uat-scenario.txt` | The scenario the `uat` runner uses to check the page's flows. |

## Gate rule on the page

Eleven areas marked and none "Not yet" reads as accepted. Any "Accept with fixes" line in a note becomes a card for the wave coordinator.
