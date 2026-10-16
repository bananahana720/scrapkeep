# Tone bible

**Status: DRAFT, written 2026-10-16 from Andrew's direction in the project chat. Nothing here changes game code.** Every writer, artist, animator and composer reads this page once before a creative task. It sits above the approved lore voice ([LORE-TONE-SAMPLE.md](LORE-TONE-SAMPLE.md)), the cast ([PILOTS.md](PILOTS.md), `docs/CHARACTER-BIBLE.md`), the story spine ([SOUND-STORY.md](../SOUND-STORY.md) section 1) and the sound bible (`SOUND-BIBLE.md`, PR #12). Where they disagree on *feel*, this page wins. Where they disagree on *facts*, they win.

## The one sentence

Scrapkeep is a playground that films itself like the last episode of an anime: huge, earnest, melodramatic framing, and then a wink, because the game loves having fun and wants you to smile.

Andrew's words: carefree, experimental, melodramatic scene framing and cinematography, like anime openings. Real swings into intensity, despair, anger and sadness, where the sadness knows it is a little corny. Presentation in an anime and comic-book style, with **Scott Pilgrim** as the touchstone: melodrama that satirises its own genre and tells backstory with a wink.

**What "anime" means here.** We borrow the genre's structure and clichés, never its regional dress. The tropes we use: the cold-open fanfare, the team roll call, the low-angle hero shot, the rival stare-down, the freeze-frame name card, the transformation or power-up sequence, the sad break with one instrument, and the key-change finale. Everything they are dressed in stays Scrapkeep's own: steampunk and cyberpunk machinery, house pulse, jazz harmony and a sax lead. No East Asian instrumentation, scales, lettering or visual motifs.

## Four pillars

1. **Mean it, then wink.** Every big beat is played straight first: full camera push, full music, full stakes. The undercut comes one beat *after* the payoff, never instead of it. A joke that kills the moment before it lands is a mistake; a joke that lands after it is the house style.
2. **Comic book on top of the world** (the Scott Pilgrim pillar). The game knows it is a game and decorates itself. Intro cards with stats freeze the frame when someone important arrives. Sound effects appear as drawn words (KLANG, FWOOSH, *ping*). Backstory arrives in three flat comic panels with a narrator caption. Score pop-ups and "+1" jokes treat life as a game inside the game. Earnest melodrama gets undercut by a self-aware caption.
3. **The swing.** Feelings go to the edges and come back. Hype crashes into despair, anger or loss, holds it long enough to feel real, then the game snaps back to play. Sadness is allowed to be corny on purpose: rain falling on one character only, a slow-motion paper ledger drifting down, a sax note held one bar too long.
4. **Deadpan words, loud pictures.** The approved crew-log voice stays dry: short work notes with a quiet wrong thing underneath. The *framing* carries the melodrama. A screaming camera over a calm caption is funnier and sadder than a screaming caption. Brindle never raises his voice; the camera does it for him.

## The swing, as a beat map

Use this shape for intros, boss arrivals, the run summary and the ending. Each beat is short; the whole loop can fit in 20 seconds.

| Beat | What it feels like | Typical tools |
| --- | --- | --- |
| Hype | "Here we go." | speed lines, low-angle hero shot, kick drum enters, title card slam |
| Collision | the stakes arrive | smash cut, rival's intro card, music drops to bass only |
| Crash | despair, anger or loss | colour drains, slow motion, held close-up, a lone sax line, rain on one spot |
| Wink | the game admits it is a game | a caption ("This is the sad part."), a prop gag, a sound effect word |
| Back up | play resumes, bigger | hard cut on the downbeat, full band, colour returns warmer than before |

## Do and don't

| Area | Do | Don't |
| --- | --- | --- |
| **Camera** | Low angles for heroes, Dutch tilt for villains, whip pans between rivals, a 2-frame zoom-punch on impact, a slow push-in on any sad face. Hold one wide "postcard" of each world before the action. | Shake the camera during input-critical play. Cut the player's camera away mid-run. Use cinematic letterbox on retry. |
| **Cuts** | Cut on the beat (129 BPM house grid, 172 BPM in-run). Smash cut from loud to quiet. Use split-screen panels for face-offs and a freeze frame for every intro card. | Fade to black between gags. Hold any shot longer than its joke. Play anything unskippable. |
| **UI motion** | Cards slam in with 3 frames of overshoot, ink-stamp on, and leave by sliding off on a diagonal. Panels have thick ink borders, halftone shading and a slight tilt. Menu moves tick on the grid. | Ease everything the same way. Let a decoration cover a telegraph, a reticle or a health read. Animate text the player must read in combat. |
| **Text voice** | Crew logs stay dry (approved 2026-10-04). Intro cards are fake-serious stat lines: "RIVET. Mole. Eyesight: theoretical. Has never missed." Captions narrate like a tired comic-book narrator: "Meanwhile.", "Tragic, right?", "Moss packed a spare." | Exclamation marks in lore. Swearing or cruelty. Jokes about the player failing. Memes or real-world brand references that will age. |
| **Enemy moments** | Machines are workers, not monsters, so a downed machine gets a tiny "shift over" gag (a clock-out stamp, a sigh of steam). Elites get a mini intro card with one deadpan stat. | Gore or suffering. Mocking a machine for dying. Intro cards on ordinary enemies; they would bury the boss cards. |
| **Boss moments** | Every boss arrival is a full Scott Pilgrim entrance: freeze, name card with three stats, a one-line threat, then the fight. Phase changes get a 1-second comic panel. The defeat is a melodramatic collapse played straight, then a wink. | Make a boss evil. Brindle is sincere and wrong, the Waking is woken, the Mind is lonely. Let a cutscene run inside a phase; the posture rule owns phase timing. |
| **Music cues** | Title theme A (sax lead) for pilots and worlds; title theme B (machine lead, sax answering) for bosses and the Fleet, so the machine calls and the keepers answer. Boss fights are call-and-response duels, the game's "bass battle": the boss states, the pilot's motif answers. Sad beats get one sax line over a held chord, then the kick comes back. Cinematic finales take the anime key change: the last chorus lifts a whole step before the hook lands (title intros and the ending only; in-run keys stay as `harmony.gd` sets them). | Vocals. East Asian instruments or pentatonic "oriental" colour. A long intro on retry. Silence during play longer than a bar. A sad cue that never resolves; every crash resolves home to D. |

## The cast under this tone

| Who | Their melodrama | Their wink |
| --- | --- | --- |
| **Sable**, fox | the hot-blooded hero: always launching, always faster, sure this is her episode | leaves a scene so fast the intro card has to chase her |
| **Rivet**, mole | the stoic who never misses and never sees | the visor flips up to show tiny proud eyes, the rarest face in the roster |
| **Kest**, kestrel | the one who measures every load and is learning to commit | hovers through a whole dramatic pause, then commits all at once: BOOM |
| **Tarn**, tiger | the gentle giant | is calm and kind while the machine does the snarling |
| **Tally**, pack rat | the accountant hero, Brindle's rival ledger | stamps "PAID" on things that exploded |
| **The Cannon** | the corniest tragedy in the game: the Mind's gun that remembered the fox | the backstory panels are drawn in sad sepia with a caption that admits it |
| **Moss** | the provisioner who packs what you forgot | every crisis ends with Moss holding the spare part |
| **Admiral Brindle**, badger | an admiral in a stadium-sized war machine who sincerely believes in the arithmetic | is the size of two paws, and rounds every number up on his own intro card |
| **The Waking, the Mind** | ancient, enormous, wronged | the Mind's intro card has a "LIKES" line, and the only entry is the player |

## Guardrails

Readability beats style. No decoration crosses a telegraph, a hit read or the HUD, and gameplay frames stay within the 60 fps budget. Every cinematic is skippable with any input and never replays on retry. Everyone is a worker or a keeper, nobody is evil, and every gag is kind.
