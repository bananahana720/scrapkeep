# Title intros: rotating anime-style openings

**Status: built 2026-10-17** in `src/presentation/title_intros.gd` (the reel and the pick) and `title_intro_player.gd` (playback on the title stage); test `tests/title_intros_test.gd`; in-game stills on the [title openings page](https://claude.ai/artifact/4BPUR2Qtgqreq8FC4skm1N). Reads with [TONE-BIBLE.md](TONE-BIBLE.md), whose five-beat swing and Scott Pilgrim pillar every intro follows. The storyboard for the first intro is in [storyboards/intro-sable/](storyboards/intro-sable/), and its stills are on the [storyboard page](https://claude.ai/artifact/SP2Rcy3tzwhpwK3hcHAsBk).

## What the player gets

Each launch opens on a short anime-style opening, 30 to 45 seconds, that introduces one thing: a pilot, a world or a boss. Any input skips it. Every intro ends on the same held frame that becomes the main-menu backdrop, so the cut to the menu is invisible. Nothing plays on retry or when a run returns to the title.

## The reel

| Intro | Introduces | Theme | Available |
| --- | --- | --- | --- |
| Sable | the first pilot and the premise | A (sax lead) | always; plays on first launch |
| Rivet, Kest, Tarn, Tally | one pilot each | A | when the pilot is unlocked |
| Spillway Works, the Dig, the Highdraft | one world each, as a travel-poster opening | A | when the world is first reached |
| Admiral Brindle, the Waking, the Mind | one boss each, as a rival's entrance | B (machine lead, sax answering) | after the boss is first met (its arena entered, or beaten) |
| The Cannon | its corny tragic backstory | B | after the ending |

Theme A belongs to the keepers and the worlds. Theme B belongs to the machines: the machine lead calls and the sax answers, which is the boss duel in miniature.

**Rotation rule.** First launch plays Sable. After that, play the unseen available intro furthest along the reel (the reel is in rough progression order, so that is the newest unlock). When all are seen, rotate round-robin in reel order from the last one shown. A boss intro never plays for a boss the player has not met. The silhouette teaser for unmet bosses is not built; an unmet boss simply has no intro yet.

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

## How it is built

1. **Data, not code per intro.** Each row in `title_intros.gd` holds the card, the three captions and the three drawn sound words. Sable plays the storyboarded 11 shots (22 bars, about 41 s); every other row plays the same swing in 8 shots (17 bars, about 32 s). New intros are rows.
2. **Playback.** `title_intro_player.gd` builds a small visual-only set 600 m off the service deck in the title's own world, sets the stage viewport to render every frame, and moves the title camera through the shots on the 129 BPM bar grid. The comic layer (name card, captions, sound words, speed lines, rain on one spot, the logo) is a CanvasLayer at layer 6 over the menu. The last shot cuts back to the deck, so the held frame is the menu backdrop.
3. **When it plays.** Once per launch, on the first title screen. Never for bots, tests or a headless display (`bot_driven`, `test_mode`), never with `--no-intro`, never on retry or when a run returns to the title. Leaving the title stops it.
4. **Skip.** Any key, click, touch or pad button skips to the held frame. While the opening plays, a catcher node sits last under the tree root, where input arrives first, so the skip press never reaches the menu, the workshop or any panel.
5. **Rotation state.** Shown and met ids live in the profile's `seen` list (`title_intro:<id>`, `title_met:<boss>`); the round-robin pointer is the stat `title_intro.last`, which only grows because profile stats merge by max on save. Bosses are marked met on `boss_arena_entered`, in memory only; the run's own save carries it.
6. **Reduced motion.** Cards and captions stay; the camera push, the pop overshoot, the speed-line spin and the rain fall stop.
7. **Music.** When an opening starts, the title stage calls `audio.title_theme(theme)` if the audio node has it (the music side adds it to start take A or B on bar 1). Until then the openings are silent. Theme C on the summary and ending and the key change in the back-up beat belong to the music integration (PR #12).
8. **Finishes.** Set models wear their in-play finishes: the Dig's machine parts take the slot library (`material_slots.gd`), the dam its slot tints, everything else its vertex colours.
9. **Not built yet.** The rollcall panels are a straight shot rather than three tilted panels; the crash inset is a caption rather than a sepia panel; the Cannon row shows the rebuilt pilot without its own backstory panels.
