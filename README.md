# SCRAPKEEP

Scrapkeep: Godot alpha in `sketches/core-loop`, 3 worlds. Start at [AGENTS.md](AGENTS.md) and [docs/project/README.md](docs/project/README.md).

A greasy junkyard adventure in a steam-cyberpunk universe. Pilots drive electromagnetic mechs that collect metal, grow, and recycle scrap into evolving weapons and skills across Southwest-inspired landscapes.

## Start here

- [AGENTS.md](AGENTS.md): project instructions for every agent session.
- [Project desk](docs/project/README.md): the map of current and historical records.
- [Alpha board](project-guide/coord/GRAPH.md) and [rulings](project-guide/handoff/DECISIONS.md): live coordination for waves 17 to 21.
- [Art & Game Bible](BIBLE.md): approved product and visual reference.
- [Engineering ADRs](adr/README.md): accepted production architecture.
- [Backlog](BACKLOG.md), [Orchestrator](ORCHESTRATOR.md) and [Tracking](TRACKING.md): task definitions, operating rules and the heavy-lane board.

The game is a Godot sketch with typed GDScript at `sketches/core-loop`: three worlds of two stages each. Andrew plays once, at the end of wave 21.

## Preserved browser proofs

The two browser games remain as preserved proofs, not the current direction. They stay separate until consolidation is approved, and their tests do not qualify the Godot game.

| Entry | Scope | Status |
| --- | --- | --- |
| `/orchard.html` | The Iron Orchard lightning caster playtest: mouse-look shooting, double jump and rebounds, lightning abilities, three waves, rewards, and a paused equipment dashboard | Preserved proof |
| `/` | Original 15-wave tower-defense expedition, hero classes, collection, and optional figurine signup | Preserved baseline |

The [Increment 01 contract](docs/project/INCREMENT-01-lightning-playtest.md) and [play guide](docs/LIGHTNING-PLAYGUIDE.md) describe the orchard. The [first-build verification record](docs/FIRST-BUILD-VERIFICATION.md) preserves historical evidence from the earlier proof.

The [design desk](docs/DESIGN-INDEX.md) connects the current build to accepted direction, research, concept art, and the broader proposals.

## Developer and project navigation

[Developer guide](CONTRIBUTING.md) · [Project desk](docs/project/README.md) · [Requirements](docs/project/REQUIREMENTS.md) · [Current backlog](BACKLOG.md) · [Browser implementation ADRs](docs/adr/README.md)

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

See the [full controls and mechanics](docs/LIGHTNING-PLAYGUIDE.md) and [integration contract](docs/project/INCREMENT-01-lightning-playtest.md). Difficulty, handling and readability remain Andrew's playtest questions. Automated replays and staged fixtures provide separate evidence.

## Original yard (preserved baseline)

The preserved baseline has its own [controls, progression and verification guide](docs/BASELINE-GUIDE.md). Historical build and research notes remain under `docs/`; the project desk identifies which records are current.
