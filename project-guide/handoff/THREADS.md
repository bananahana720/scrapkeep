# Roles and who owns what

Since ruling `eb` (16 Nov) and ruling `ep` (25 Nov), one local session on the Mac Studio coordinates and gates in flat `main` mode, assigning units under [AGENTS.md](../../AGENTS.md) rule 11 (`ruling ej`, widened 21 Nov). Legacy `claude.ai` project threads (`ruling dh`), PC-as-Gate (`ruling ds`), and nightly `2:00` housekeeping are retired in git history.

| Role | Where / Model | What it does |
| --- | --- | --- |
| Coordinator & Gate | Mac Studio local session (`claude-fable-5-2` or active coordinator under `ruling ep`) | Talks to Andrew, plans work, dispatches workers in isolated worktrees, integrates reviewed PRs onto `main`, runs gates and [STATE.md](STATE.md) updates |
| 3D & UI Writer | `claude-opus-5-5` (high effort) | Meshes, map and park geometry, placement, blockout, look and lighting, UI screens, HUD and controls, and stills |
| Code, Research, Test & Formal Writer | `gemini-4-neon` (high effort) | Game code, research, tests, formal models, band reads, gate runs, re-pins and records |
| Independent Reviewer | Fresh `gemini-4-neon` (high effort) | Rule 4/11 read-only diff review for every unit (3D and UI included); receives diff and acceptance criteria, never writer reasoning |
| Promise Card & QA Helpers | `gpt-6.2-astra` / `gpt-6.2-sol` (rulings `ec`, `ee`) | Promise-card subtasks, QA passes, concept art, model drafts, and non-admitting second review opinions |

**Finish every to-do before going idle** (ruling `dn`, [AGENTS.md](../../AGENTS.md) rule 1).

**Gate steps.** The recipe is [GATE.md](GATE.md), with scripts under `scripts/gate/`.
