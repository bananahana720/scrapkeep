# Scrapkeep

Scrapkeep now has two playable entries. The Iron Orchard is the authorized first proof of the expanded rolling-combat direction. The original yard remains available as the baseline demo.

| Entry | Scope | Status |
| --- | --- | --- |
| `/orchard.html` | Close third-person rolling, aimed charge-release pulses, committed machine attacks, earned mechanisms, and one optional companion | Playable; build and integration checks passed |
| `/` | Original 15-wave tower-defense expedition, hero classes, collection, and optional figurine signup | Preserved baseline |

The user approved the orchard build and its session goal on 5 September 2026. That authorization covers the bounded first proof, not the complete expanded game. The [play guide](docs/FIRST-BUILD-PLAYGUIDE.md) describes current orchard controls and mechanics. The [first-build verification record](docs/FIRST-BUILD-VERIFICATION.md) owns acceptance results and remaining limits.

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

## Iron Orchard first playable

WASD rolls relative to the camera. Mouse movement or the arrow keys changes aim. Hold F or the left mouse button to charge a pulse, then release to fire. Space bursts, Shift brakes, and E deploys Shear Buddy after a Shear Linkage is earned. Escape or P pauses; R starts a fresh run.

Snipcart closes inward. Spreadleg pushes its feet outward. The Grand Pruner arm uses a close sweep or a rolling offcut at distance. Each attack announces and locks its path. Ordinary attacks always damage live machines, while an exposed housing rewards a recovery counter. Collected Shear and Brace parts alter the ball's appearance and behavior.

The encounter ends when the single Pruner arm is dismantled. Workers and companion deployment are optional. Classes, a full expedition, co-op, permanent progression, and a complete multi-arm boss remain later work.

See the [full controls and mechanics](docs/FIRST-BUILD-PLAYGUIDE.md), [integration contract](docs/FIRST-BUILD-CONTRACT.md), and [build-team record](docs/FIRST-BUILD-SWARM.md). Build and integration verification passed. Difficulty and human handling remain playtest questions; the verification record distinguishes ordinary input replays from staged fixtures.

## Original yard

The preserved baseline has its own [controls, progression and verification guide](docs/BASELINE-GUIDE.md). Historical build and research notes remain under `docs/`; the project desk identifies which records are current.
