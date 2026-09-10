# Original yard baseline

Moved from the project README during the 5 September 2026 closeout. These controls and behaviors apply to `/`. The orchard has its own [play guide](FIRST-BUILD-PLAYGUIDE.md).

Everything below describes the preserved `/` demo rather than the orchard encounter.

The original yard is a 3D rolling tower defense with 15-wave expeditions, three collectible hero classes, permanent mastery, and optional figurine email and SMS signup. Scenery snaps onto the ball as outward-facing turrets.

### Baseline controls

| Action              | Control                                    |
| ------------------- | ------------------------------------------ |
| Roll                | WASD or arrow keys, relative to the screen |
| Move toward a point | Hold the left mouse button on the yard     |
| Dash and ram        | Space                                      |
| Class ability       | E                                          |
| Pause / resume      | Escape or P                                |
| Instant restart     | R                                          |
| Choose an upgrade   | 1, 2 or 3                                  |
| Toggle sound        | M                                          |

Touch devices have a joystick and tap buttons. Pausing, changing class and restarting are also available in the interface.

Roll over loose machinery and plants to collect them. Every collected piece becomes a visible turret. At 24 turrets, additional scrap improves existing weapons. Rolling charges the weapons up to +25% fire rate; stationary reload drops to 35%. Collecting scrap also restores charge.

Enemies follow the marked maze to the reactor. From wave 3, some enter through a second gate on the lower lane. Every fifth wave includes a heavy. Clear a wave to receive most of your score, a small core repair and one of three upgrade choices. Kills give XP and each level adds 4% damage for that run. The best score stays in local browser storage, including when you instantly restart.

- **Pip, the scavenger:** speed, pickup reach and an active scrap vacuum / blast.
- **Rivet, the engineer:** damage, reload and a six-second overclock.
- **Moss, the warden:** extra core integrity, slowing shots and an area freeze.

### Baseline expedition and collection

Three sectors lead to named bosses at waves 5, 10, and 15. Defending against the final wave wins the expedition. Between waves, choose a general upgrade or one of four weapon specializations. Specializations have three ranks, and general upgrades have caps.

The optional hazardous route adds 80% enemy health and 25% movement speed for 50% more wave-clear points. A breach-free wave adds 250 points from wave 2. Kill streaks also increase score.

Each cleared wave earns 10 permanent class mastery when a run finishes or you leave it through the interface. Victory adds 50. At 150 mastery, that hero earns a field-card blueprint. Mastery grants titles and collectible cards without changing combat power. Separate run receipts preserve progress across browser tabs and prevent duplicate rewards. Reloading during an unfinished expedition loses that run. If storage is unavailable, earned mastery remains in memory for the visit.

The results screen creates a friend challenge with the same seed and hero, plus your score to beat. Daily yards use the UTC date. Challenge scores are informal client-side targets, with no server leaderboard or prize verification. Localhost links become useful outside this machine only after hosting at a public address.

The field collection connects all three classes to their physical figurine interests. Artwork is a character concept, not a photo or print-ready model of the actual product. Downloadable SVG cards and all game progression are available without signup. Email and SMS have separate unchecked permissions.

Successful input-only patrols take about 15–17 simulation minutes, excluding upgrade decisions. Playing all three classes is the intended 45–60 minute arc. Human enjoyment and retention still require playtesting.

### Baseline build and verification

```bash
npm run build
npm test
npm run test:expedition
node tests/lead-browser.mjs
```

With the development server running, `npm run test:browser` runs the browser replay using `/usr/bin/chromium`. Set `CHROMIUM_PATH` if Chromium is elsewhere. The same replay can be run interactively at `http://localhost:5173/?qa`, using **Run regression replay**. QA uses separate best-score and mastery storage. The scripted replay uses the real reduced-effects setting and SwiftShader for headless portability. Its assertions wait for gameplay conditions instead of assuming a hardware frame rate.

The QA-only **Combat stress scene** deliberately creates 24 turrets, 45 durable enemies and automated movement. It is a rendering benchmark, not an earned run. **Concept comparison scene**, **Freeze combat frame** and **Arsenal detail view** provide repeatable visual inspections of the actual geometry. QA controls are excluded from production builds.

For a Vite production preview with the API already running:

```bash
npm run build
npm run preview
```

### Baseline art and implementation

Vite, Three.js, WebGL 2, local fonts and synthesized Web Audio. No paid services or network assets are needed at runtime. Static scenery is merged into vertex-colored opaque and emissive batches; bullets, particles and enemy health bars use instanced rendering. Device pixel ratio is capped at 1.65. GTAO contact shading, filtered shadows, bloom and multisample antialiasing complete the scene. The FX toggle disables postprocessing and shadows and caps pixel ratio at 1 for slower devices. Phones start with reduced effects. Gameplay advances at a fixed 60 Hz with bounded catch-up.

The two generated concepts are in `docs/art/`. Prompts and the visual iteration notes are in `docs/ART-DIRECTION.md`. The actual game uses 3D geometry rather than a flattened concept background.

See [the baseline retention verification record](RETENTION-VERIFICATION.md) for this expedition pass. `docs/VERIFICATION.md` records the earlier baseline. This is a separate experiment from the 3D-printing hub and Homehub.
