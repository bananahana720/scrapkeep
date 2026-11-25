# SCRAPKEEP

Scrapkeep: Godot alpha in `sketches/core-loop`, 3 worlds. Start at [AGENTS.md](AGENTS.md) and [START-HERE.md](project-guide/handoff/START-HERE.md).

**The game in one line** (Andrew, 9 November 2026, ruling cj): A crew of loose cannons, bulls in the Foreman's china shop, take their world back from a machine that believes life can be run perfectly. What every place, system, enemy and item means under that line is in the [Story map](sketches/core-loop/design-v3/STORY-MAP.md).

A greasy junkyard adventure in a steam-cyberpunk universe. Pilots drive electromagnetic mechs that collect metal, grow, and recycle scrap into evolving weapons and skills across Southwest-inspired landscapes.

## Start here

- [AGENTS.md](AGENTS.md): project instructions for every agent session.
- [Start here](project-guide/handoff/START-HERE.md): who owns what, and where to go for each kind of work.
- [Roadmap](project-guide/handoff/ROADMAP.md), [wave state](project-guide/handoff/STATE.md) and [rulings](project-guide/handoff/DECISIONS.md): live coordination for the alpha.
- [Art & Game Bible](BIBLE.md): earlier product and visual reference (being replaced in Phase 2).
- [Engineering ADRs](adr/README.md): accepted production architecture.
- [Backlog](BACKLOG.md), [Orchestrator](ORCHESTRATOR.md) and [Tracking](TRACKING.md): task definitions, operating rules and historical heavy-lane board.

The game is a Godot sketch with typed GDScript at `sketches/core-loop`: three worlds of two stages each. Andrew plays a world 1 sitting first, then one full-alpha sitting.

## Preserved browser proofs

The two browser games remain as preserved proofs, not the current direction. They stay separate until consolidation is approved, and their tests do not qualify the Godot game.

| Entry | Scope | Status |
| --- | --- | --- |
| `/orchard.html` | The Iron Orchard lightning caster playtest: mouse-look shooting, double jump and rebounds, lightning abilities, three waves, rewards, and a paused equipment dashboard | Preserved proof |
| `/` | Original 15-wave tower-defense expedition, hero classes, collection, and optional figurine signup | Preserved baseline |

The [first-build contract](docs/FIRST-BUILD-CONTRACT.md) and [first-build verification record](docs/FIRST-BUILD-VERIFICATION.md) preserve historical evidence from the earlier proof.

## Developer and project navigation

[Developer guide](CONTRIBUTING.md) · [Start here](project-guide/handoff/START-HERE.md) · [Current backlog](BACKLOG.md) · [Engineering ADRs](adr/README.md)

Run `npm run verify` for local structural, automated and built-entry checks. Browser verification remains a separate step described in the developer guide.

## Run the preserved proofs locally

Requires Node.js 20.19+ or 22.12+ and a browser with WebGL 2.

```bash
npm ci
npm run build
npm start
```

Open [the orchard](http://127.0.0.1:8787/orchard.html) or [the original yard](http://127.0.0.1:8787/). This serves both built entries and the baseline capture API together. For development, run `npm run server` and `npm run dev` in separate terminals. The default development orchard address is [http://127.0.0.1:5173/orchard.html](http://127.0.0.1:5173/orchard.html); use the address printed by Vite if that port is occupied.

Set your brand, store URL, privacy URL, and storage location through `.env.example`. To load a saved `.env`, run `node --env-file=.env server/index.js`. Contact capture writes to private local storage. It does not send email or SMS or sync a CRM. See [the capture setup](docs/LEAD-CAPTURE.md).

## Iron Orchard controls (preserved proof)

Mouse movement controls the view; WASD rolls relative to it. Hold left mouse for repeat lightning bolts and right mouse for focused aim. Hold and release Q for a ground strike or E for a conductor. Space jumps, including one additional air jump; Shift bursts and Ctrl brakes. R activates a charged ultimate. I opens the dashboard; Escape cancels targeting or pauses. Restart is in the menu.

Snipcart closes inward. Spreadleg pushes its feet outward. The Pruner arm uses a tall close sweep or a low rolling offcut at distance. Attacks commit their geometry, including height. Descending onto smaller enemies rebounds; compatible lightning chains and Echo can amplify body impacts, conductors and the companion.

Clear three waves, choosing a reward and reconfiguring between fights. Final victory requires defeating all remaining workers and the Pruner. Additional classes, a full expedition, co-op, permanent progression, and a complete multi-arm boss remain later work.

Difficulty, handling and readability remain Andrew's playtest questions. Automated replays and staged fixtures provide separate evidence.

## Original yard (preserved baseline)

Historical build and research notes from the September proofs live in git history.
