# Lead-capture server (frozen)

Frozen legacy evidence since 6 September 2026 under audit recommendation 9. The default `npm run verify` and `npm test` paths no longer start or test this server; `scripts/check-build.mjs` serves `dist/` on its own. Run `npm run test:leads` for the stored-record tests in `tests/legacy/leads.test.js`, `npm run test:leads:browser` for the built signup check, and `npm run server` to start it locally. Reference: [docs/LEAD-CAPTURE.md](../docs/LEAD-CAPTURE.md) and ADR 0001 (`docs/adr/0001-two-playable-entries.md`, archived in git history).
