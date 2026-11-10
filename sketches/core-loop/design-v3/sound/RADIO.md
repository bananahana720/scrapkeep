# The pilot's radio

Andrew asked for this on 2026-10-17 (20:02Z): a radio on the pilot's HUD, always there while you roll, with stations, auto, track changes, playlists and an off switch, like driving in GTA or Cyberpunk. Music becomes a core reason the game is special. The tracks are collectibles, and harder challenges and stranger places give bigger tracks.

The catalogue is [assets/radio/catalogue.json](../../assets/radio/catalogue.json). The render job is [radio_takes.py](radio_takes.py). The music thread's brief is `music/radio/RENDER-BRIEF.md` in the project files.

## The one sentence

The house band follows you live by default, and everything you find out in the world is the same band replaying its own tunes however it felt that night, on seven stations you can flip between mid-roll.

## The HUD radio

| Control | Keyboard | Pad | What it does |
| --- | --- | --- | --- |
| Next station | `.` | none yet (D-pad down fires the active) | Turns the dial one station on, Radio Off included |
| Previous station | `,` | (none) | Turns the dial back one station |
| Skip track | `/` | none yet (L3 is a rebind target) | Next track on this station or mixtape |
| Pin track | `;` | (mixtape page) | The track on air plays through bosses and Wardens, until a boss's final phase |
| Off | dial to Off, or the pause menu's Radio row (V) | dial to Off, or the pause menu | Music bus silent |

Every radio key is an InputMap action in `bindings.gd` (`cl_radio_next`, `cl_radio_prev`, `cl_radio_skip`, `cl_radio_pin`), so a rebinding page can reach them.

- **The chip** (`src/ui/radio_dial.gd`) sits in the top band's right corner whenever a run is in play. A knob's needle points at the station, the call sign is in the station's colour, the track name runs under it, and four meter bars are the band's own kick, bass, keys and lead layers, so you can watch the music follow your speed and combo. On a change it swells for about two and a half seconds with the station's name and blurb, stamps a drawn KSSHT! on the turn (the tone bible's comic-book sound words), then settles back.
- **Off silences only the music.** Hit sounds, stingers and the musical answers on the next beat stay on. They live on the effects bus.
- **The dial order** is Radio Off, KEEP Live, Auto Scan, the seven content stations, Your Mixtape. Stations with nothing found yet stay on the dial and read "No signal yet" followed by the blank-sleeve hint of their first unfound take, so an empty station is a tease that points you somewhere. The score plays under it.

## The rules

1. **KEEP Live is the default.** It is the adaptive score itself: drums follow speed, the sax enters with combo, hit sounds land within 5 ms, answers on the next beat.
2. **Found tracks still play with you.** A radio track plays through the same band, so the band's parameters still drive it. Where a take has stems (drums, bass, other), speed lifts the drums and combo opens the lead layer, as the score does.
3. **Bosses and Wardens keep their own score** (Brindle, the Waking, the Mind with the hype rule's Eurodance finals, and every Warden's build and unseal drop) unless you pin a track. A pinned track plays through Wardens and a boss's earlier phases. A boss's final phase always takes the air, the Eurodance final where there is one, even over a pin; the pin plays again after the fight. Beating a boss always plays its victory.
4. **A tune you have not heard yet always cuts in.** When a stage, landmark, event or boss has a tune you have not found, the radio steps aside for it, and the chip reads "New signal. Listen in." It holds the score until that moment moves on (the next stage, the moment ending) or you touch a radio key. So the radio never stops you collecting.
5. **Auto Scan** picks found tracks that fit the world you are in, and steps aside for every moment (landmarks, events, fights), like a DJ watching the room.
6. **Harder challenges and stranger places award bigger tracks.** See the tiers below.
7. **A find premieres.** A take you just found drops in on its own station for one airing (unless the radio is off), then the dial goes back where it was. The HUD's record plate announces it as a New B-side, New take or Legendary take.
8. **The radio rides the run.** Stage hits, launches and landing drops sound on the radio track: after a launch the track drops back in on the landing. Minibosses, champions and events do not interrupt a station (Auto steps aside for them). A death or the end of a run hands the music back to the score.

How it works: a radio track is a needle drop on the same band the score uses (the jukebox's `spin`), with the run's own parameters still driving it, so every hit and musical answer lands on the radio track's beat and key. While the radio holds, the stage, moment, champion and miniboss cues leave the band alone (`audio.gd` `radio_hold`). Every jukebox record also airs on a station (the catalogue's `records` map), so the tunes you hear in play stock the radio too.

## Mixtapes

A camp page on R, next to Moss's jukebox (`src/ui/radio_page.gd`).

- Up to 6 mixtapes of up to 20 tracks each, named by Moss (Night Shift, Overtime, Ballast, Long Haul, Spare Parts, Last Call).
- The crate on the left is every found take and jukebox record, by station. Space adds the focused track to the tape; on a tape track it takes it off. Comma and period move a tape track up and down. 1 to 6 pick a tape, N starts one, X shuffles it, T puts the radio on Your Mixtape. R or Esc goes back and saves.
- Your Mixtape is a station on the dial. It plays your current tape in order. Skip moves along it.

## Collecting

| Tier | Length | How wild | Where it lives |
| --- | --- | --- | --- |
| B-side | about 85 s | close to the original (cover strength about 0.56) | simple firsts: hearing a tune, a stage clear, a Warden |
| Take | about 135 s | a real reinterpretation (about 0.46) | hidden caches, events won, bosses beaten |
| Legend | 3 to 4 min | wild, with hard switch-ups, ending with everything locked together (about 0.34) | the hardest challenges and the strangest places |

**Signal caches** (`src/world/radio_cache.gd`) are small antenna masts with a dish, a blinking lamp and a pulsing ring; you collect one by rolling up to it while the run is in play (a ball that rolls into one under the summary or after a death finds nothing, and the cache stays). The park-dressing threads place them at the spots below. Each spot is chosen so reaching it is a skill test that fits its park.

| Park | Spot | Track | Tier |
| --- | --- | --- | --- |
| Spillway top shelf (park_dam) | dam crest walkway, above the sluice gates | Top Shelf, Trio | take |
| | inside the pump house under the dam | Piston Flip | take |
| | the foot of the spillway chute, past the falls | The Dam Breaks | legend |
| Cable Reach (park_flume) | the longest cable span's midpoint | Cable Reach, Liquid | b-side |
| | the gauge house under the first pylon | Gauge House Groove | b-side |
| | the cap of the penstock tower | Brindle's Bolero | legend |
| Dig upper bench (park_pit) | the headframe's winch house | Headframe, Dubbed | take |
| | behind the cracked wall | Pickaxe Flip | take |
| | the top bench rim, facing west | Dust Devil Western | take |
| | the bottom of the headframe shaft | Headframe, Full Depth | legend |
| Dig deep works (park_sinkhole) | the bowl's drain grate | Sinkhole Trip | take |
| | the shut door on the gallery ring | Drain Dub | b-side |
| | the ledge under the lip, reached by carving the bowl | Cave-In Version | legend |
| Highdraft islands (park_islands) | under the hanging isle's tip | Hanging Isle, Liquid | take |
| | among the kite anchors on the far island | Kite Chime Waltz | b-side |
| | the highest kite tether, above the cloud deck | Highdraft, First Light | legend |
| Highdraft crown (park_crown) | the spire's lowest bell frame | Crown, Last Call | take |
| | the spire's 30 m waist, outside | Crown Spire, Fusion | take |
| | the rope bridge between the two highest islands | Crown Footwork | take |

The camp has no place to roll around in yet, so its two takes are earned instead: Lights On, Twelve Ways (legend) when Moss's ledger balances and its trophy goes up, and The Course, Drumline (b-side) for finishing a movement course in a park. When the camp hub ring (PR #31) becomes a space you can roll in, move both back to Signal caches: under the trophy wall, and behind the course's finish arch.

**Challenges and moments.** The other 60 tracks come from play: every Warden broken, every event type won, all three bosses (beaten, phased, adapted), streaks such as 150 machines in world one or five synergies in one run, a clean win, and hearing each jukebox tune for the first time. The legends from challenges:

| Legend | Station | How you earn it |
| --- | --- | --- |
| The Mind, Modal | Moss's Back Room | beat the Mind |
| The Mind, Overclock | Furnace FM | survive the Mind's last phase |
| Brindle, Afterburner | Furnace FM | break 150 machines in world one in one run |
| Everything at Once | Updraft 107 | win a run |
| Hanging by a Thread | Updraft 107 | thirty near misses over the islands |
| Scrapyard Sample Suite | The Chop Shop | five synergies in one run |
| The Waking, Heavy Machinery | The Chop Shop | skid through six machines at once in the Dig |
| The Well-Oiled Machine | Local 9 | win a run without retrying a stage |

## The catalogue

81 takes on seven content stations, deliberately more than the alpha needs. 34 b-sides, 33 takes, 14 legends. By world: camp and any-world 22, Spillway 20, the Dig 20, the Highdraft 19.

| Station | Lane | B-sides | Takes | Legends |
| --- | --- | --- | --- | --- |
| Moss's Back Room (BACK 88.1) | piano trio, big band, bebop, ballad, second line, swing | 6 | 5 | 1 |
| Furnace FM (HEAT 101.3) | electro house, Eurodance, 808, big room, electro swing | 3 | 6 | 3 |
| Low Shaft Radio (SHFT 94.7) | dub, trip-hop, half-time, lo-fi | 5 | 5 | 1 |
| Updraft 107 (LIFT 107.7) | liquid drum and bass, fusion, layered neo-soul, progressive house | 4 | 4 | 3 |
| The Chop Shop (CHOP 92.3) | chopped machine foley, soul chop, industrial hip-hop, boom-bap | 6 | 4 | 3 |
| Lost Property (LOST 86.5) | chiptune, bossa, desert western, brass band, Bolero build, fugue, theme and variations, field holler, waltz | 7 | 3 | 2 |
| Local 9 Percussion Union (BEAT 97.1) | mambo, batucada, cumbia, jungle, footwork, drumline | 3 | 6 | 1 |

How the catalogue follows Andrew's taste (17 Oct, 15:59Z and 20:02Z):

- **Every take covers a current pick.** The ACE-Step cover keeps the pick's melody and beat. Nothing is a new theme exercise. A jazz band playing a standard however it feels that night.
- **Switch-ups near the end.** Every legend has a hard switch (a fake ending, a one-beat silence, a key change up) and ends with everything locked together like a well-oiled machine.
- **Percussion carries the energy, with machines in the groove.** Every row names its machine and found sounds as percussion: pistons, cannon hits, steam, electro whirs, sluice gates, mine bells, cage chains, propellers.
- **Little tastes to listen for.** 20 rows hide a sound worth catching (Easter egg in the row's form line), such as the cowbell that is a sluice wheel, or the clock that skips on beat three.
- **Rooted in the areas.** The Spillway gets water and sluice gates, the Dig gets mine bells and drills, the Highdraft gets wind, rope and bells. Traditional and classical forms (second line, field holler, Bolero, fugue, theme and variations, Southwest brass) come in where they fit a place.
- **Never East Asian colour** and never the word "anime" in a caption, per the sound bible.

## The render plan

Renders run on Andrew's 4080 through the music Remote Control thread. ACE-Step stays on his PC.

1. **One take per station first**, so every station plays something: `radio_takes.py <folder> --first`.
2. **Then all legends**: `--tier legend`.
3. **Then the rest**, ten at a time (`--limit 10`) until none is left. A take already in `radio_renders.json` is skipped, so batches resume after a stop and never render a take twice. Andrew tapped "Hold for all 81" (22:13:51Z): the sitting waits until every take is rendered. The budget and overnight schedule are in the shared render brief, `music/radio/RENDER-BRIEF.md`.

Per take: the parent pick is stretched to the take's tempo with Rubber Band and looped to the take's length, covered in final mode at the row's strength with seeds 5101 and 5102, split with htdemucs_6s, and mastered by `evolve.py` (`--light` for b-sides, `--spice` otherwise). The stems feed the band's layers, so speed and combo keep working on the radio. The music thread picks the better seed of each take (Andrew, card 22:28:36Z: he is not asked per take; he hears the picks at his sitting). The pick is packaged whole (`pack --whole`) at `assets/music_ace/<id>/manifest.json`, and the game finds it by id with no MusicRows row. Until then, the radio plays the take's parent tune as a stand-in.

## Placement still to do

Cache spots are named here but have no coordinates yet. `assets/radio/cache_spots.json` maps a take id to `[x, y, z]`; the park-dressing work fills it in at the spots above, and a take with no entry has no cache in the world. Until then the 19 cache takes cannot be found in play; the other 62 can.

## Andrew's rulings (cards, 17 Oct)

1. **Wordless vocals: radio only** (20:52:33Z). The six wordless-vocal takes keep voices as texture, never words; the score stays vocal-free. The render job includes them by default.
2. **Wardens take the air** (20:52:37Z) like bosses, unless a track is pinned.
3. **The finale wins** (20:52:55Z). A boss's final phase takes the air even from a pinned track; the pin plays again after the fight.
4. **Hold for all 81** (22:13:51Z). The sitting waits until every take is rendered.
5. **The music thread picks** (22:28:36Z) the better render of each pair, for all 81.

## Ideas parked for later

- A cache you are near bleeds a few bars of its take through static, getting clearer as you close in.
- Moss as the late-night DJ between tracks on the Back Room, in drawn captions (no voice).
- A station that only comes in at the top of the Highdraft.
