# Judge note: PC film of stage/alpha-w42 at 88a75e7b (15 Nov 2026)

Film: first-timer persona, whole world 1 run, seed 1, filmed on the RTX 4080 inside headless gamescope, 134 pictures.

The 134 pictures are not in the repo (29 MB). They are on the PC under `~/scratch/w42-pc/film-88a75e7b/`. To film again: `node scripts/redteam/eye.mjs --persona=first-timer --film=whole --gpu --out=<dir>`.
Readers: three fresh agents (Opus 5.5), each given one part under a neutral path with only the pictures and the brief.
Their answers, unedited: READ-part1-001-045.md, READ-part2-046-098.md, READ-part3-099-134.md.

## Control: caught, so the read counts

A second film with the objective plate not drawn (128 pictures) went to a fourth reader who was
told nothing. On the clean film the part 1 reader quoted the objective on every picture that had one ("Find the Warden
1297m", "Break the yard crew", "Break the clamp crews", "Ride the water sheet up"). The control reader quoted none,
answered "cannot tell" for what to do on 020, 033, 035 to 037, 040, 043 and 045, and worked out the goal only from the
Warden bar and the green beam. Its answer: READ-control-001-045.md.

## Findings, from disagreement between a reader and the game's row (SHEET.md)

| Row | Verdict | Pictures | Reader against the game |
| --- | --- | --- | --- |
| PF-16 warnings | still present, major | 038-043, 046-051, 099-104, 106-111, 118-123 | 043: game says lobber 24, reader named "Dome Lightning" and an orange orb. 051: game says chaser 18, reader named "Powerhouse Boiler" and saw no chaser. 104: brindle_slag 36, reader says nothing warned and the fixed red ring read as floor paint. 111: same source, ring seen but same red as everything. 123: brindle_charge 36, clear only from 121. |
| PF-26 hit words | still present, major | 020, 023, 072, 075, 087, 091-095, 100, 107, 115, 130 | Words and numbers over the ball, targets and reticle; KACHUNK through a paused menu; CLANK over the victory title. |
| PF-22 reward gates | still present, major | 054-058, 085-089 | Speech box over a gate's text, list changes 085 to 086, the taken part is never confirmed. |
| PF-06 camera | still present, regrade check to major | 018, 028, 038-042, 045, 124 | Against the dam Warden with the ball out of sight; inside Brindle's hull after a charge. |
| PF-19 post-Brindle | still present, minor | 129, 130 | HUD vanishes; CLANK over the title; Tarn card with no context. |
| new: stray text | minor | 010, 026 | "Taken" one letter per line down a card; a damage number over the line under the reward cards. |
| new: two Warden names | minor | 029, 046, 069, 077 | Radio track names "Shelf Warden" and "Reach Warden" beside the boss bar's "Reactor Warden" and "Meltdown Warden". |
| new: event toast names no place | minor, part of PF-16 | 037-039, 048-052 | "Dome Lightning incoming" vanishes before the hit; "Powerhouse Boiler incoming" stays after it. |
| control film only | watch | control 033, 035, 036, 040 | The screen goes one flat orange or pink and the ball is lost. Not seen on the clean film's run; one run each. |

## Read clearly by every reader

The controls beside the ball, the objective line with its distance, the boss bar and step hint, the bracketed
weak-point tags, the upgrade picks, and that the area was won.

## What this pass cannot say

Sound is not read. One seed and one pilot. The readers are models, not people. The hazard landing added in PR 1057
shows on 105 and 112 (a solid red disc and ring at the strike); the reader read it as danger after the hit, not as a
help before it.
