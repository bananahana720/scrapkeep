# Research for the set director

Background for the DJ who mixes the score to play ([SOUND-BIBLE.md](../SOUND-BIBLE.md), "The DJ at the decks"; ruling di). Andrew asked on 12 November 2026 for Roboquest's music design and public references to be studied. These notes keep principles only: no melody, stem or sample from any game here is used. Researched from public pages on 12 November 2026; each claim links its source, and anything inferred says so.

## Roboquest

- **Who and what.** Noisecream (Dmitry Rusecky) wrote the score; the Steam soundtrack has 33 tracks "sorted by order of appearance", with variants such as "Journey (Slow)" and "Metal Hero (Remix)" ([Steam](https://store.steampowered.com/app/1400490/Roboquest_Soundtrack/)). In his own words: "low-tuned guitars, rough synthesizers, dance rhythms of drum parts… mixed with a choir and orchestra", a "heroic punk rampage" ([dev blog, 27 Nov 2023](https://steamcommunity.com/games/692890/announcements/detail/3859083885030692297)). Made in Unreal Engine 4 by RyseUp Studios.
- **What players report, not confirmed by the studio:** the final boss's music shifts at its phase 2, and players hear the score as drum and bass ([comments](https://steamcommunity.com/app/692890/eventcomments/4036976577925640114/)). From the track list, the score looks mostly like one track a level, played whole.
- **Not public:** middleware, intensity layers, or any rule for fights against exploring. Do not claim Roboquest layers stems.
- **What to take:** drive (drum-led, high tempo), a heroic hook, a genre mix that stays danceable, and boss music that turns at a phase. Scrapkeep already has the last as Brindle's three phases and the hype rule.

## Adaptive music practice

| Source | The rule worth taking | Where Scrapkeep uses it |
| --- | --- | --- |
| Left 4 Dead's director ([GDC 2009](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf)) | One intensity number that rises with damage and nearby kills; build, hold the peak, fade, then a forced relax. Distinct music before a big threat arrives | The director's one energy and four moods; release after a peak; the bass swap before a set piece |
| Mike Morasky on Left 4 Dead ([interview](https://www.audiogang.org/interview-with-valves-mike-morasky/)) | Each layer means one game fact | The drums follow speed, the lead opens with threat and the chain (INTEGRATION section 2) |
| Metal: Hellsinger ([Game Developer](https://gamedeveloper.com/design/shredding-for-satan-how-i-metal-hellsinger-i-designed-fps-harmonies-in-hell)) | The most recognisable layer is the reward for playing well; layer changes are delayed and smoothed | The lead is whole on the drop; June's peak book carries the hook up an octave |
| Elias ([Game Developer](https://www.gamedeveloper.com/audio/composing-adaptive-music-for-games-advanced-concepts-in-elias)) | Each track has its own agility: the melody moves every four bars, the drums every bar. Stingers start early so their hit lands on the downbeat | June answers once a phrase; trims move on the bar |
| FMOD ([parameters](https://d1s9dnlmdewoh1.cloudfront.net/2.02/studio/parameters-reference.html)) | Rise fast, fall slowly | A mood climbs on the next bar and falls after two |
| Hades ([Laced Records](https://www.lacedrecords.com/blogs/blog/how-rock-band-influenced-hades-soundtrack), [Hades II modding wiki](https://sgg-modding.github.io/Hades2ModWiki/docs/creating-mods/audio/adding-dynamic-music)) | Thin the band to bass after a fight; boss phases are numbered sections switched on the beat | The Warden's break and home; Brindle's phases |
| Winifred Phillips ([GDC 2021, horizontal](https://www.gamedeveloper.com/audio/horizontal-resequencing-and-dynamic-transitions-for-game-music-composers-from-spyder-to-sackboy-gdc-2021-), [vertical](https://www.gamedeveloper.com/blogs/pure-vertical-layering-for-game-music-composers-from-spyder-to-sackboy-gdc-2021-)) | Vary segments so a player cannot predict them; let the music rest sometimes | June's books walked in order, never twice the same; the breath |
| Celeste ([Game Audio Lookout](https://medium.com/game-audio-lookout/enhancing-gameplay-with-music-in-celeste-5da210bbc602)) | Silence before a confrontation; after a chase the music fades away rather than cutting | The bass swap; the release bars |
| Rez and Tetris Effect ([oral history](https://gamedeveloper.com/audio/oral-history-of-i-rez-i-recounts-a-marriage-of-game-and-music)) | Quantize the player's musical answers to the grid | Already the rule: music on the grid, sound on the frame |
| Sayonara Wild Hearts ([Simogo](https://simogo.com/work/sayonara-wild-hearts/daniel-about-sayonara-wild-hearts/)) | Music and play take turns to lead | Call and response: the lead steps back for June |
| Michael Sweet, *Writing Interactive Music for Video Games*, chapter 10 | A transition matrix covering every pair of sections, with ending stingers | The recorded band's manifest joins and the Warden form |

Godot 4.3 and later also ship `AudioStreamInteractive` (section changes on the next beat or bar, with fades and filler clips) and `AudioStreamSynchronized` (stems in sync). Scrapkeep's own sequencer already does both with measured costs, so these stay a note, not a migration.

## Samples a commercial game may ship

| Source | Terms | Use here |
| --- | --- | --- |
| Freesound ([FAQ](https://freesound.org/help/faq/)) | CC0: free, no credit. CC BY: free with a credit line. CC BY-NC and Sampling+: not for a commercial game | Search with the CC0 filter only |
| Sonniss GDC bundles | Royalty-free, no credit, embedded in a larger work only; read the licence PDF in the bundle | Sound effects, not music |
| Looperman ([terms](https://www.looperman.com/help/terms)) | Loops are royalty-free inside a derivative work; acapellas are personal use only; uploads are user-submitted, so their source is a risk | Avoid unless a loop's source is clear |
| Splice ([licensing FAQ](https://intercom.help/splice-b7a2d5b83f2e/en/articles/8652642-splice-sounds-licensing-faq)) | Commercial use, no credit; never shipped "in isolation" | Paid service: needs Andrew's go-ahead first |
| Kenney ([support](https://kenney.nl/support)) | CC0 | Free UI and effect sounds |

Any sample that ships gets a row in the asset ledger with its source and licence before it is merged.
