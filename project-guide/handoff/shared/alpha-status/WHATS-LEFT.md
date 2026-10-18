# What's left for the alpha

Written 2026-10-17 22:10Z by the thread "What's left for the alpha". Read against cand/alpha-w16 2fce8953, main cf63e622, open PRs #12-#75 (fetched heads of #20, #31, #40, #53, #55, #66-#68), the thread list at 22:04Z, the intent scorecard (alpha-status/intent-check/results/w16-2fce8953.md), the ambition map and the register. Read-only; nothing built. Placeholders and item tiers/actives are left out (their own threads).

## The headline

All six "never started" systems now have PRs (SQ2 #15, SG2 #16, SI6+SG15 #13, SR10 #36, SI3 #52). What is still truly unstarted is mostly presentation and authored content: the walkable camp, the title intros, five of six parks' authored passes, and Highdraft sound identity. The longest wait is not unstarted work but admission: about 60 draft PRs open, the machine stalled since 19:42Z (the "Cloud staging candidate" thread is on it).

## Unstarted units, Pareto order

| # | Unit | Sitting area | Where | Done-check | Depends on | Move |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | CAMP-HUB: build the walkable hub-ring camp scene from #31's 34 models; Moss stall = shop, lockers = paint and cosmetics, settings console, jukebox (#55), pet pen, launch gate = pilot select | Progression across runs; Look | Cloud | Main menu "Camp" opens the scene; every station opens its menu (smoke test); scorecard "Camp: level files" not empty; 0 camp placeholders; independent reviewer | #31 models; rebase on #55 and #66 (both edit camp_menu.gd) | Pull forward from wave 19 |
| 2 | ALPHA-RC dry run: run #39 alpha:rc on stage/alpha-w16 now, publish the go/no-go page | Every criterion | Cloud | One real alpha:rc run; "not run" rows listed; page published | #39; stage candidate | Pull forward from wave 21 |
| 3 | Park authored passes, one thread per park: dam, flume, pit, sinkhole, islands (crown already has one). Each removes its scorecard filler: dam's 25 identical domes, flume's 79 grind rows in a row, pit's 56 bench banks plus its failing landmark sight check and missing rope moment before the brood, sinkhole's 16 identical zip cables and 9 geysers (give each a job), islands' 285 hoodoo anchor fields, 11% society and no "fire from the line" lesson | Stage and world design; Look; Clarity (islands) | Cloud (bake and GPU stills check on PC) | Intent scorecard re-run: no park under half the median authored rows, filler line gone, sight check true; traversal bot rides each park end to end; Fable reviewer | Rebase each on its open PRs: dam and pit #40; flume and sinkhole #68, #29; islands #38, #67 | Pull wave 18-19 dressing forward; design and row plan start now |
| 4 | TITLE-INTROS: build the rotating title intros #20 designed (first launch Sable opening; pilots and worlds on theme A; each met boss on theme B; theme C on summary and ending; title C take 1) in title_stage.gd | Look; Sound and music | Cloud | Test picks the right intro per profile state; stills page; reviewer | #20 design; #12 picks | Unscheduled, start now |
| 5 | HIGHDRAFT-SOUND: own cue rows for the Mind's quote, the wrong note, the Fleet anvil and the boiler (now aliases of generic sounds); music layers for the crown's alcove, hoodoo forest and toppled route | Sound and music | Cloud rows; PC renders if new audio | Audio gate cue presence passes; Highdraft distinct event sounds above 9 | #12, #27; tell "Crown park authored pass" (working) to avoid overlap | Start now |
| 6 | LORE-TOPUP: about 8 more field notes each for the flume (7) and the crown (8) to match the other parks (14-17) | Progression (collect over runs) | Cloud | Count check per park; dry crew-log voice review | Push onto #53 or a follow-up; its thread is resolved | Start now (small) |
| 7 | RED-TEAM-W16 merge: run the crash harvest and merge over the five finished blocks (sweep-b0..b4), publish the phone page, send blockers as cards | Stability | Cloud | sweep-merged/ and crash-harvest/ exist under redteam/w16 | #42; coax "Set up the per-wave red team" (idle since 19:56Z) | Stalled, not new |
| 8 | HELP-REFRESH: help page and controls diagram cover wall grip, jam fields, cast times, radio dial, relay stakes, SPIL-9 "next ram", actives | Clarity | Cloud | First-timer audit (#49) shows 0 misses for these verbs | #61, #65, #66, #36, #45 merged | Push back to wave 20 |
| 9 | ACHIEVEMENTS-REFRESH: achievements for specials, radio caches and legends, the three rescues, relay stakes, sets, overpowered payoffs | Progression across runs | Cloud | Every new content family has at least one achievement; save round trip test | Content PRs merged | Push back to wave 20 |
| 10 | FLASH-COMFORT: the existing reduced_motion setting also tames the new effects (#47, #50, #51); default if Q7 stays "Reduce flashes toggle" | Clarity; Look | Cloud | Test: every new flash or shake reads the setting | Effects PRs merged; design question 7 | Push back to wave 20 |
| 11 | PERF-NIGHT: MangoHud route per park on the idle 4080 | Frames in budget | PC | sketch:frametime exit per park | Machine back from its Allow prompt; parks dressed | Keep wave 20; first read as soon as the machine is back |
| 12 | RADIO-RENDERS: the 81 takes from music/radio/RENDER-BRIEF.md | Sound and music; zero placeholders | PC (ACE-Step) | Audio gate counts 0 missing radio takes | #66; music RC thread is blocked on input | Start pass 1 (7 takes) now; see card |

## Stalled threads to coax (not new units)

- "Set up the per-wave red team": wave 16 harvest and merge not done (unit 7).
- "Compose Scrapkeep's music and sounds": blocked on input; it owns radio renders (unit 12).
- "Stage 1 hitch": blocked; #70 (S1-HITCH) may already close it.
- "/astack:a-mode": blocked on input since 21:54Z.
- Design questions page: Andrew is answering now (feel check "Wave 19 feel check", cast "Cast on the move" at 22:07Z). Questions 8, 11, 13 and 14 would each become a unit if their recommended option stands (secrets, comic page, camp line, light over a run); pick them up once the page settles.

## Checked and covered (no unit needed)

Landmark models and placement (#26, #28), sinkhole bowl (#29), isle tip (#38), crown pass (#67), world scenery on all six parks (#68, fixes scorecard gap 6), AppImage launch now plays the six parks (#40, fixes scorecard gap 1), the Waking's attacks (#74), Highdraft and Dig rosters (#64, #69, #71, #72), Tally's isle rescue (#67), relay stakes (#36), pilot paint and 13 earned cosmetics (merged to the candidate), settings with volumes, quality and reduced motion, help and achievements pages, boss final-phase hype (in #12).

## Card only Andrew can decide

Question: What ships if the 4080 can't render all 81 radio takes before wave 20?
- Ship what's rendered (recommended): the catalogue shrinks to the takes that exist; nothing missing counts as a placeholder.
- Hold for all 81: the sitting waits until every take is rendered.
- Fewer stations: cut to four stations so every one is full.
Reason: the 4080 also runs the gate and PERF-NIGHT, so the full set may not fit before wave 20, and an empty slot would block zero placeholders.
