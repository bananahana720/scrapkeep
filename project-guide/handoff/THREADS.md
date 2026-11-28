# Roles and who owns what

Since ruling `eb` (16 Nov) and ruling `ep` (25 Nov), one local session on the Mac Studio coordinates and gates in flat `main` mode (`STATE.md` holds live status). Legacy `claude.ai` project threads (`ruling dh`), PC-as-Gate (`ruling ds`), and nightly `2:00` housekeeping are retired in git history.

- **Worker routing and model assignments:** [AGENTS.md](../../AGENTS.md) rule 11 is the sole owner of who runs coordination, 3D/UI units, code/research/test/review units, optional Astra/Sol QA passes, and fallback definitions.
- **Role authority limits and concurrency:** [ORCHESTRATOR.md](../../ORCHESTRATOR.md#roles-and-concurrency).
- **Finish every to-do before going idle** (ruling `dn`, [AGENTS.md](../../AGENTS.md) rule 1).
- **Gate steps:** [GATE.md](GATE.md), with scripts under `scripts/gate/`.
