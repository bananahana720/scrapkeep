# Expedition verification

This pass turns the existing rolling-turret game into a finite expedition and an optional figurine-interest signup flow. The delivered build remains local.

## Verified behavior

- `npm test`: 43 passing tests covering combat, terminal states, progression, challenge parsing, cross-tab run receipts, consent, persistence, and server error paths. Output: [retention-tests.txt](../artifacts/retention-tests.txt).
- `npm run build`: production build passes. The existing Three.js vendor chunk exceeds Vite's 500 kB warning threshold. Output: [retention-build.txt](../artifacts/retention-build.txt).
- `npm run test:browser`: 20 checks exercise movement, abilities, pause, restart, combat, upgrade selection, defeat, victory, mastery, figurine selection, contact-input keyboard isolation, and duplicate settlement. The replay uses explicit late-wave fixtures for terminal UI checks. Output: [browser-tests.json](../artifacts/browser-tests.json).
- `npm run test:leads:browser`: 13 checks run against the built production game and a temporary real server. These cover opt-ins, a durable email/SMS write, duplicates, network errors, challenge navigation, the in-game target, daily reset, phone layout, and exclusion of QA controls. Output: [lead-browser-tests.json](../artifacts/lead-browser-tests.json).
- A separate CUA interaction ran the 20-check replay on the in-app browser with normal effects. Manual interactions selected Rivet, moved the ball, activated dash and overclock, opened the collection, and submitted a synthetic email and phone. The server held one record with both channels and the scavenger interest. No messages were sent.
- Mobile checks used a 390 × 844 viewport. The collection scrolls, inputs remain inside the viewport, and results retain mastery/unlock feedback. An inherited footer offset caused 2 px of horizontal overflow during testing; the final production replay passes after the fix.

## Pacing evidence

The [input-only probe](../tests/expedition-balance.mjs) changes movement, ability, risk, and upgrade choices. It does not inject weapons, teleport the hero, alter enemy health, or force wave completion. Fifteen runs cover three classes, safe and risky play, idle failure, and three seeds. Complete results: [expedition-balance.json](../artifacts/expedition-balance.json).

| Hero, seed 745 | Safe expedition | Hazard throughout | Idle failure |
| --- | --- | --- | --- |
| Pip | Victory, 915.3 seconds | Victory, 959.4 seconds | Wave 4, 173.6 seconds |
| Rivet | Victory, 926.2 seconds | Defeat on wave 15, 896.3 seconds | Wave 4, 231.9 seconds |
| Moss | Victory, 914.8 seconds | Defeat on wave 15, 1000.3 seconds | Wave 4, 204.3 seconds |

These are simulation seconds and exclude human upgrade decisions. Three successful class expeditions support an intended 45–60 minute arc. They do not prove that people enjoy the game or stay that long. A human playtest should check first-run comprehension, return for a second class, progression interest, challenge sharing, and signup completion before treating the retention target as established.

## Review and corrections

Independent review used `gpt-6-astra` at xhigh effort and ended `PASS+NOTES` after corrections. The reviewer reproduced stale-tab mastery loss, then reran the reproduction after separate run receipts were added. Both classes retained their XP. The review also corrected delayed consent configuration, daily-versus-friend routing, a level-up copy mismatch, and mobile reward visibility.

Headless Chromium uses SwiftShader and the game's reduced-effects mode. Early fixed-delay assertions failed on slow software rendering. The replay now waits for observable game conditions and records incomplete replays as failures. The separate in-app browser replay passed with normal effects. These checks do not establish performance on every phone or GPU.

The scoped record of this run is [RETENTION-BUILD.md](RETENTION-BUILD.md) and [decisions.tsv](decisions.tsv). It is a session digest, not a complete transcript.

## Product and operating limits

The hero art is a game concept rather than a photo or print-ready model of the sold figurines. Actual brand, shop URL, and privacy URL use configuration in [.env.example](../.env.example). Those details were not supplied during the build.

Capture stores leads privately on this server. It does not send messages or sync a CRM. The store supports one process and requires stale-lock recovery after an unclean shutdown. Hosting, a messaging provider, unsubscribe handling, and the final public privacy details remain before operating a public campaign. See [LEAD-CAPTURE.md](LEAD-CAPTURE.md).

Shared scores are informal client-side challenges. There is no competitive leaderboard or prize verification. Links created on localhost require public hosting to work for friends elsewhere.

Mastery survives completed runs and leaving/restarting through the interface. Reloading an unfinished expedition loses that run. Storage failures preserve mastery for the current visit and report the limitation. No signup gates gameplay, mastery, or field-card downloads.

## Screenshots

- [Title screen](../artifacts/expedition-menu.png)
- [Figurine collection and signup](../artifacts/figurine-collection.png)
- [Phone collection](../artifacts/figurine-mobile.png)
- [Phone title screen](../artifacts/expedition-mobile-menu.png)
- [Three procedural hero models](../artifacts/hero-preview.png)
