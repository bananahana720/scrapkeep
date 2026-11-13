# The UI audit loop

Andrew, 13 Nov 2026: he asked what UI and UX best practice carries over to the game, and for "a formal verification loop so we can audit and improve the game ... from a learning sort of format". This page is the loop. It is the home for how the game's UI is audited; the rules for words and screen structure stay in [LEGIBILITY.md](../LEGIBILITY.md) section 13, and the sizes and colours in `src/ui/ui_tokens.gd`.

```
1 Principles ──▶ 2 Check ──▶ 3 Findings ledger ──▶ 4 Fix ──▶ 5 Lesson
      ▲                                                          │
      └──────── a repeated finding becomes a guard ◀─────────────┘
```

| Step | What it is | Where it lives |
| --- | --- | --- |
| 1 Principles | The principles in rank order. Each names its source, whether it is a published standard ("established") or our own reading of genre practice ("inferred"), the checks that hold it, and what no check holds yet | [principles.json](principles.json) |
| 2 Check | `npm run sketch:ui-audit` checks the list and the ledger without the engine. Add `-- --run` to run every headless test the list names through `sketch:smoke` (so it imports the project first and leaves a receipt) and print a score per principle | [scripts/ui-audit.mjs](../../../../scripts/ui-audit.mjs) |
| 3 Findings ledger | One row per measured miss: the principle, a class (a short name for the kind of miss), where, the evidence, a state and a guard | [UI-FINDINGS.tsv](../../../../project-guide/handoff/UI-FINDINGS.tsv) |
| 4 Fix | A normal pull request on the open stage. The row's state becomes `fixed`, or `accepted` when Andrew rules it stays | The pull request |
| 5 Lesson | A class with two or more rows must name a guard: a test, a tool or an npm script that fails on that kind of miss. `sketch:ui-audit` fails with "lesson owed" until one row of the class names it. The guard is then added to the principle's checks | The guard column, then principles.json |

## Three kinds of check

- **Automatic.** A headless test or a lint. Runs in a cloud session in minutes and on every pull request through `npm run sketch:fast`.
- **Stills.** A capture tool that needs a display. Menus can be captured in a cloud session (`tools/ui_capture.gd` under xvfb; about 2.5 minutes a window size). Fights, real lighting, flash rate and input delay need Andrew's PC, which the wave board thread drives ([DEVICES.md](../../../../project-guide/handoff/DEVICES.md)). `npm run sketch:ui-audit -- --ingest <dir>` turns the `*.audit.txt` files `ui_capture` writes into candidate ledger rows; it prints them and writes nothing.
- **Fresh eyes.** Three or more reviewers who are given only the still, reported as a count ([SIGHT-PERSONA.md](../SIGHT-PERSONA.md) section 7 has the method). One reading of a picture is noise. Feel is Andrew's, at the sitting; no automated check counts as his acceptance.

## Running an audit

1. `npm run sketch:ui-audit -- --run`. A red test is a regression: fix it or file it.
2. Capture stills for the screens in scope and ingest the audit files.
3. For each principle with a gap, measure it by hand on the stills and add a row for each miss.
4. For each new row, look for the class in the ledger first. If it is there, this is a repeat, and the guard is owed in the same pull request as the row.
5. Report the score per principle and the open rows. A UI finding never holds a promotion (the rule for play findings, ruling cn, read across to this ledger; an assumption Andrew can overturn).

## Adding a guard

Pick the strongest that fits: a state the code cannot express, then a test or lint that fails, then one shared helper, then a runtime check. A guard that starts red on today's game holds the line instead: it lists today's misses as rows that must shrink (the `KNOWN` rows in `colour_meanings.gd`, the `CLOSE` rows in `tests/colour_cvd_test.gd`, the `CAPTION_USES` ceiling in `tests/ui_text_floor_test.gd`). Every guard carries a planted bad case for the thing it measures, so it is known to fail when it should.

## Limits

The contrast, colour and size checks read tokens and palette constants, not drawn pixels, so text or a mark drawn outside `src/ui` with its own size or colour is not seen. The ceiling on the smallest type step counts the text `UiTokens.CAPTION`, so a size reached through `UiTokens.type_step()` or through another name for the preload is not counted. The lesson rule checks that a guard exists, not that it fails on that class; the reviewer of the row checks that. The floor of 20 in `colour_cvd_test.gd` is ours, not a standard. The Steam Deck figures (9 px minimum, 12 px recommended at 1280x800) were read from a summary of Valve's compatibility page on 13 Nov 2026, not quoted from it; the Xbox figure (18 px at 1080p for PC) was read from the guideline itself.
