# 0001: Preserve two playable browser entries

Date: 2026-09-05. Status: accepted for the first proof, recorded retrospectively.

## Context and decision

The existing yard already implements an expedition and collection loop. The new camera and combat require a separate proof without losing that baseline. Build both `index.html` and `orchard.html` in the existing Three.js/Vite project and link between them. Share installed libraries; keep distinct game behavior explicit.

## Consequences and revisit trigger

Both paths require their own gameplay checks. Similar controls and UI should not be merged before their behavior agrees. This decision avoids an engine migration during the proof; it does not select a commercial PC/mobile engine. Revisit when the next approved production scope makes consolidation or another delivery runtime necessary.

Evidence: [Vite entries](../../vite.config.js), [first-build contract](../FIRST-BUILD-CONTRACT.md), [verification](../FIRST-BUILD-VERIFICATION.md).

## Amendment 2026-09-06

The lead-capture server under `server/` is frozen legacy evidence. Under recommendation 9 of the [AI-first audit](../../artifacts/ai-first-audit-2026-09-06/AI-FIRST-AUDIT-2026-09-06.md) it is removed from the default `npm run verify` and `npm test` paths; `scripts/check-build.mjs` now serves `dist/` with its own static handler and asserts that `/api/config` returns 404. Its tests moved to `tests/legacy/leads.test.js` and still run through `npm run test:leads`; `npm run test:leads:browser` is unchanged. Both browser entries remain preserved as separate proofs. The server is not deleted and its behaviour is not changed.
