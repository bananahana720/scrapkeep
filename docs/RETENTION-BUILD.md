# Scrapkeep expedition build

## Checklist

- [x] Read pstack Principles and runtime; inspect the existing game.
- [x] Capture the original sources in `/tmp/scrapkeep-retention-baseline` and run baseline checks.
- [x] Build a 15-wave expedition with changing sectors, bosses, optional risk and build choices.
- [x] Add class mastery, named collectible heroes and reproducible friend challenges.
- [x] Add optional email/SMS capture backed by durable server storage and explicit consent.
- [x] Verify simulation, real browser flows, mobile layout, production build and lead persistence.
- [x] Obtain independent Astra review and record remaining deployment/product details.

## Definition of done

A player can select a distinct hero, play a complete expedition with failure and victory, choose upgrades and risk, retain earned class mastery, and share a link that recreates the same seed and class. The field collection connects those heroes to physical figurines. Contact submission succeeds only after durable server storage, requires channel-specific consent, survives server restart, and is optional for all play and rewards.

The intended engagement span is 30–60 minutes across multiple expeditions, class mastery and score challenges. Simulation pacing and working features are checkable here. Human retention is an unverified product hypothesis.

## Workflow and scope

This is a local source folder without a Git repository. The original is preserved; delegates work in isolated staging copies and the parent applies reviewed files. No repository creation or deployment is part of this pass.

The parent owns UI and integration. Astra at high effort owns the simulation/progression, a second Astra owns lead storage, and a third owns procedural hero art. A fresh Astra reviews the integrated result. The decision log is `docs/decisions.tsv`.

The baseline has 14 passing simulation tests and a passing production build. A patrol policy reaches wave 8 in about 202–205 simulation seconds; stationary policies fail in 174–285 seconds. These measurements explain the focus on pacing and variety.

## Documentation grounding

- Context7 `/mrdoob/three.js`: Group and nested Mesh composition, https://github.com/mrdoob/three.js/blob/dev/docs/pages/Group.html.
- Context7 `/vitejs/vite`: API proxy and preview inheritance, https://vite.dev/config/server-options.html#server-proxy.
- Modern Web Guidance `autofill-sign-up-form` and `accessible-error-announcement`: native form semantics, autofill, mobile input types, and errors announced after interaction.

Pstack's model-the-domain principle puts progression and challenge rules in a pure campaign module. Prove-it-works requires actual lead persistence and browser interaction, beyond a successful build.

## Delivery

The completed evidence and remaining public-campaign details are in [RETENTION-VERIFICATION.md](RETENTION-VERIFICATION.md). The local production game runs at http://127.0.0.1:8787.
