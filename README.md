# Scrapkeep

Scrapkeep has two playable entries. The Iron Orchard is the lightning caster playtest: a rolling hero, three waves, and equipment that changes how attacks combine. The original yard remains available as the baseline demo.

| Entry | Scope | Status |
| --- | --- | --- |
| `/orchard.html` | Mouse-look shooting, double jump and rebounds, lightning abilities, three waves, rewards, and a paused equipment dashboard | Playable; technical checks passed, human playtest next |
| `/` | Original 15-wave tower-defense expedition, hero classes, collection, and optional figurine signup | Preserved baseline |

Andrew approved [Increment 01](docs/project/INCREMENT-01-lightning-playtest.md) on 5 September 2026. Its [play guide](docs/LIGHTNING-PLAYGUIDE.md) describes current orchard controls and mechanics. The [first-build verification record](docs/FIRST-BUILD-VERIFICATION.md) preserves historical evidence from the earlier proof.

The [design desk](docs/DESIGN-INDEX.md) connects the current build to accepted direction, research, concept art, and the broader proposals.

## Developer and project navigation

[Developer guide](CONTRIBUTING.md) · [Project desk and status](docs/project/README.md) · [Requirements](docs/project/REQUIREMENTS.md) · [Backlog](docs/project/BACKLOG.md) · [Architecture decisions](docs/adr/README.md)

Run `npm run verify` for local structural, automated and built-entry checks. Browser verification remains a separate step described in the developer guide.

## Play locally

Requires Node.js 20.19+ or 22.12+ and a browser with WebGL 2.

```bash
npm ci
npm run build
npm start
```

Open [the orchard](http://127.0.0.1:8787/orchard.html) or [the original yard](http://127.0.0.1:8787/). This serves both built entries and the baseline capture API together. For development, run `npm run server` and `npm run dev` in separate terminals. The default development orchard address is [http://127.0.0.1:5173/orchard.html](http://127.0.0.1:5173/orchard.html); use the address printed by Vite if that port is occupied.

Set your brand, store URL, privacy URL, and storage location through `.env.example`. To load a saved `.env`, run `node --env-file=.env server/index.js`. Contact capture writes to private local storage. It does not send email or SMS or sync a CRM. See [the capture setup](docs/LEAD-CAPTURE.md).

## Iron Orchard lightning playtest

Mouse movement controls the view; WASD rolls relative to it. Hold left mouse for repeat lightning bolts and right mouse for focused aim. Hold and release Q for a ground strike or E for a conductor. Space jumps, including one additional air jump; Shift bursts and Ctrl brakes. R activates a charged ultimate. I opens the dashboard; Escape cancels targeting or pauses. Restart is in the menu.

Snipcart closes inward. Spreadleg pushes its feet outward. The Pruner arm uses a tall close sweep or a low rolling offcut at distance. Attacks commit their geometry, including height. Descending onto smaller enemies rebounds; compatible lightning chains and Echo can amplify body impacts, conductors and the companion.

Clear three waves, choosing a reward and reconfiguring between fights. Final victory requires defeating all remaining workers and the Pruner. Additional classes, a full expedition, co-op, permanent progression, and a complete multi-arm boss remain later work.

See the [full controls and mechanics](docs/LIGHTNING-PLAYGUIDE.md) and [integration contract](docs/project/INCREMENT-01-lightning-playtest.md). Difficulty, handling and readability remain Andrew's playtest questions. Automated replays and staged fixtures provide separate evidence.

## Original yard

The preserved baseline has its own [controls, progression and verification guide](docs/BASELINE-GUIDE.md). Historical build and research notes remain under `docs/`; the project desk identifies which records are current.
