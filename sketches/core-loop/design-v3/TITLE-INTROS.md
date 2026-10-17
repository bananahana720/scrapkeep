# Title intros: rotating anime-style openings

**Status: DRAFT, written 2026-10-16. Nothing here changes game code.** Reads with [TONE-BIBLE.md](TONE-BIBLE.md), whose five-beat swing and Scott Pilgrim pillar every intro follows. The storyboard for the first intro is in [storyboards/intro-sable/](storyboards/intro-sable/), and its stills are on the [storyboard page](https://claude.ai/artifact/SP2Rcy3tzwhpwK3hcHAsBk).

## What the player gets

Each launch opens on a short anime-style opening, 30 to 45 seconds, that introduces one thing: a pilot, a world or a boss. Any input skips it. Every intro ends on the same held frame that becomes the main-menu backdrop, so the cut to the menu is invisible. Nothing plays on retry or when a run returns to the title.

## The reel

| Intro | Introduces | Theme | Available |
| --- | --- | --- | --- |
| Sable | the first pilot and the premise | A (sax lead) | always; plays on first launch |
| Rivet, Kest, Tarn, Tally | one pilot each | A | when the pilot is unlocked |
| Spillway Works, the Dig, the Highdraft | one world each, as a travel-poster opening | A | when the world is first reached |
| Admiral Brindle, the Waking, the Mind | one boss each, as a rival's entrance | B (machine lead, sax answering) | after the boss is first met; before that, a silhouette teaser with "???" stats |
| The Cannon | its corny tragic backstory | B | after the ending |

Theme A belongs to the keepers and the worlds. Theme B belongs to the machines: the machine lead calls and the sax answers, which is the boss duel in miniature.

**Rotation rule.** First launch plays Sable. After that, play the newest unlocked intro the player has not seen. When all are seen, rotate round-robin, starting from the world the player last ran in. A boss intro never plays for a boss the player has not met, and the teaser never shows the boss's real model.

## The shape every intro shares

Every intro uses the tone bible's five beats on the 129 BPM grid (one bar is 1.86 s), about 22 bars in total:

1. **Hype** (about 10 bars): a world postcard, a low-angle hero shot, then the freeze-frame name card with three deadpan stats.
2. **Collision** (about 3 bars): smash cut, music drops to bass, the rival or threat gets its own card.
3. **Crash** (about 3 bars): colour drains, one sax line, a sepia comic-panel backstory with a narrator caption.
4. **Wink** (about 2 bars): the gag that admits it is a game, usually Moss with a spare.
5. **Back up** (about 4 bars, then hold): the key change, full band, and the title slams on the downbeat.

Every name card holds three stats. One is true, one is deadpan, one is a joke at the subject's own expense. Example: "SABLE. Fox, pylon engineer. Top speed: yes. Brakes: rumoured."

## Storyboard: Sable's intro, 11 shots, about 41 seconds

| # | Time | Bars | Beat | Shot | On screen | Music |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0:00 | 2 | Hype | Postcard: the Spillway dam at dawn, low from the water; a tiny ball on the crest | Caption: "Spillway Works. Dawn. Probably a Tuesday." An arrow points at the ball: "her." | Theme A sax pickup alone |
| 2 | 0:04 | 2 | Hype | Low-angle hero shot, backlit, Dutch tilt; speed lines | Drawn word: VRRRM | Kick enters on the downbeat |
| 3 | 0:07 | 2 | Hype | Freeze frame: Sable mid-cheer, ink-stamped name card | "SABLE. Fox, pylon engineer. Top speed: yes. Brakes: rumoured." | Band hit, then a held chord |
| 4 | 0:11 | 2 | Hype | The ball launches over three chasers, which tumble | Drawn words: FWOOSH, KLANG; a "+1" pops off a chaser | Full groove, sax hook |
| 5 | 0:15 | 2 | Hype | Roll call: three tilted comic panels, Rivet, Kest, Tarn | One line each: "Never misses." "Still deciding." "Very gentle. Machine isn't." | Brass answers, one per panel |
| 6 | 0:19 | 1 | Collision | Smash cut: Brindle's war machine looms, hard Dutch tilt; Sable tiny in front | Red flash; no text | Everything drops to bass |
| 7 | 0:20 | 2 | Collision | Freeze frame: Brindle on his scooter, name card | "ADMIRAL BRINDLE. Badger, Furnace Fleet. Height: two paws. Iron: twelve hundred tons (rounded up)." | Theme B's machine lead quotes the hook |
| 8 | 0:24 | 3 | Crash | Rain falls on one spot only; Sable alone in the light. An inset sepia panel shows a figure in silhouette | Caption: "This is the sad part." Inset caption: "Someone out there remembers her. (Later.)" | One sax line over a held chord |
| 9 | 0:30 | 2 | Wink | Moss's hover barge sails into the rain, lamps on | Caption: "Moss packed a spare." Drawn word: *ping* | Kick returns on the barge's lamp |
| 10 | 0:34 | 2 | Back up | The Highdraft: floating islands and the Mind's hand; Sable launches upward | Speed lines; colour back, warmer | The key change, up a whole step |
| 11 | 0:37 | 2, then hold | Back up | The crew lined up on the deck at sunset; SCRAPKEEP slams in | Logo stamp; "Press any key" blinks on the beat | Hook lands; the loop continues under the menu |

The silhouette in shot 8 is the Cannon, which unlocks after the ending. The first intro teases it and never names it, so the first launch spoils nothing.

## Port notes for the wave coordinator

These touch files the coordinator owns, so they are notes, not edits.

1. **Intro player.** `src/presentation/title_stage.gd` builds one static deck in a SubViewport with `UPDATE_DISABLED` (around line 41). An intro needs the viewport set to `UPDATE_ALWAYS` while it plays, then back to disabled on the held frame. Drive shots from a data table (camera pose, models, overlay, length in bars) rather than code per intro, so new intros are rows.
2. **Overlays.** Name cards, captions and drawn words are Control nodes on the existing `TitleBackdrop` CanvasLayer, using `src/ui/ui_fonts.gd`. `tests/pol_ui_title_readability_test.gd` must still pass on the held frame.
3. **Rotation state.** Store seen intros and unlocks in the same profile save that holds achievements. The rule above needs: seen ids, unlocked pilots, worlds reached, bosses met, ending seen.
4. **Skip.** Any key or pad button jumps to the held frame. Route pad input through the existing `_pad_enters_title` check in `src/ui/screens.gd` so one press skips and does not also confirm a menu item.
5. **First-run prologue.** `screens.gd` has a first-run prologue (`_prologue_due`, around line 323). Recommended order: the Sable intro, then the menu, then the prologue when the player presses Play.
6. **Music.** Theme A and B use whichever takes Andrew picks in the music thread. The intro starts the theme at bar 1, and the key change in shot 10 is in the arrangement, not in `harmony.gd`.
7. **Budget.** The reel shows at most two pilot balls in shots 1 to 10 and five in shot 11, all models the title deck already loads or the bosses already ship. Shot 10 loads the Highdraft islands and the Mind warden; measure the frame time on the held frame and on shot 10 against the 60 fps budget.
