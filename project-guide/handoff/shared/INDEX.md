# Scrapkeep library

Start here. Every living page, doc and file in the project, by area. Updated 2026-10-17 20:00 UTC by the "Project library and lessons learned" thread.

## Open these first

| Page | What it is |
| --- | --- |
| [Scrapkeep Library](https://claude.ai/artifact/LQF6h696vYdtJee3soD2Pi) | Phone start page: the game, where each wave stands, every page marked current, reference or out of date |
| [Decisions register](https://claude.ai/code/artifact/e209a132-0f39-416d-a116-3be4e9df8de9) | Every ruling Andrew has made, by topic, with date, source and what it replaced. Check before deciding anything |
| [Lessons and ways of working](https://claude.ai/code/artifact/95d92907-5cfe-4290-b303-d465baccedde) | How this project runs: taps vs typed lines, cards, cloud gate, known cloud false fails, permission prompts |
| [Sitting Kit](https://claude.ai/artifact/HxmWTSrJf1vifhjXXPW1qT) | Where Andrew marks the 11 areas at his playtest sitting |

The Library page lists every other published page. Keep it current: its source is [project-guide/library-page.html](project-guide/library-page.html); republish to the same link.

## Project guide (threads read these)

- [project-guide/DECISIONS.md](project-guide/DECISIONS.md): thread copy of the decisions register. Changes with the Claude Doc.
- [project-guide/LESSONS.md](project-guide/LESSONS.md): thread copy of the lessons doc.
- [project-guide/RECONCILE.md](project-guide/RECONCILE.md): conflicts between older records and the register; folded into the register 17 Oct 20:15Z.
- Page sources for republishing: [library-page.html](project-guide/library-page.html) (Scrapkeep Library), [sitting-kit-page.html](project-guide/sitting-kit-page.html) (Sitting Kit, v2 with play-check prompts).

## Direction

- [tone/TONE-BIBLE.md](tone/TONE-BIBLE.md): the creative tone for every beat of the game. Read before any creative work.
- [music/SOUND-BIBLE.md](music/SOUND-BIBLE.md): how Scrapkeep sounds.
- [music/MIX-CHECK.md](music/MIX-CHECK.md): mix and master pass/fail for every current take.
- [music/INTEGRATION.md](music/INTEGRATION.md): how music and sound effects plug into the running game.
- [music/AUDIO-GATE.md](music/AUDIO-GATE.md): the audio check in the placeholder gate.
- The music docs are mirrors; the source of truth is on the music PR (#12).
- [ways-of-working/rieseberg-ambition-article.md](ways-of-working/rieseberg-ambition-article.md): the article behind "How we work: ambition", including the speed pillar. The adopted version lives in the project instructions.

## Alpha status

- [alpha-status/queued-cards.md](alpha-status/queued-cards.md): decision cards waiting for a free slot (survives coordinator restarts).
- [alpha-status/ambition-map.md](alpha-status/ambition-map.md): hard target per facet, waves 16 to 21, and the units that cover them.
- [alpha-status/grill-alpha-scope-2026-10-16.md](alpha-status/grill-alpha-scope-2026-10-16.md): settled scope decisions from 16 Oct.
- [alpha-status/placeholder-burndown.md](alpha-status/placeholder-burndown.md): the wave 15 placeholder count (1,442) and who clears what. Data in burndown-data/.
- [alpha-status/briefs/](alpha-status/briefs/): build briefs (poles and flails).
- [alpha-status/first-timer/](alpha-status/first-timer/): teach-before-require audit runs, before and after the fix.
- [alpha-status/wire-or-cut/](alpha-status/wire-or-cut/): patch for the 41 registry and 10 attack rows.

## Testing (owned by their threads; link, don't edit)

- [gate/](gate/): cloud gate receipts, integration bundles and bot shards. Shard steps: [gate/BOT-SHARDS.md](gate/BOT-SHARDS.md).
- [redteam/](redteam/): red team findings by wave (w15, w16).

## Music and sound files

| Folder | What is in it |
| --- | --- |
| [music/title/](music/title/) | Title themes A (sax noir), B (machine lead), C and C2 (show opening) |
| [music/worlds/](music/worlds/) | Roaming music and world loops for Spillway, the Dig and the Highdraft |
| [music/fights/](music/fights/) | Boss themes and combat hype loops |
| [music/camp-and-endings/](music/camp-and-endings/) | Camp, run summary (win and loss) and ending |
| [music/sound-effects/](music/sound-effects/) | Event WAVs, plus the event reel with its timestamp list |

Takes come in pairs (s2501 and s2502 and so on); the Soundtrack page marks which one is picked.

## Art

- [pilot-paint/](pilot-paint/): before and after stills for Sable and Tally paint.

## Tools and uploads

- [astack-sync/](astack-sync/): A stack plugin packages synced from Andrew's machine.
- uploads/hearth/: files attached in project chat, named by ID. Do not move these. Notes on them: [.notes/inputs.md](.notes/inputs.md).

## Archive

Superseded files, kept rather than deleted. Nothing here is current.

- [archive/alpha-status/](archive/alpha-status/): the 16 Oct alpha gap report (read at cd46b12), replaced by the ambition map and wave plan.
- [archive/ways-of-working/](archive/ways-of-working/): the ambition draft, now in the project instructions.
- [archive/music/](archive/music/): earlier sound bibles and integration notes, replaced by the music PR versions.

## Where new files go

Put new files in the area folder above, never the root. Start a new folder only for a new area, and add it to this index. Move superseded drafts to `archive/` instead of deleting them. Re-read a shared file just before changing it.
