# Scrapkeep in Claude Code

Claude Code is the only host. It loads `CLAUDE.md`, which imports `AGENTS.md`; the five canonical skill directories link to `.agents/skills`. Shared A stack remains installed once at `/home/andrew/.config/astack/plugin`. The A stack runtime contract is `/home/andrew/.config/astack/runtime.md`; the skills and `AGENTS.md` refer to it by role and this file records its path once. The Codex lane retired on 17 October 2026.

## Use it

Start a fresh session in this repository after configuration changes.

| Request | Workflow |
| --- | --- |
| "Plan the next Scrapkeep session" | `plan-session` reads the board and discusses unresolved choices. It does not start the proposed sprint. |
| "Implement approved card <ID>" | `scrapkeep-task` checks authorization and prerequisites before assigning isolated work. Its numbered procedure links the ORCHESTRATOR and TRACKING sections that own each rule. |
| "Verify this Scrapkeep change" | `scrapkeep-verify` selects checks for the actual artifact and reports evidence limits. |
| "Add a scenario to the lab" or "gate this run against the pin" | `scrapkeep-lab` runs, extends, gates or ports the headless Godot lab and says what a gate exit means. |
| "Block out this pocket in mojulo" or "set up mojulo in the cloud" | `scrapkeep-blockout` builds mojulo recipes, exports lit glb, proves them with the ball in headless Godot and carries the mojulo gotchas and cloud setup. |
| "Show this working in the running game" | `scrapkeep-verify-game` launches the Godot game from source, plays it with real keys and clicks from a step file, and keeps pictures, step rows and the save files as proof. Its feature map covers launch and menus, starting a run, settings, pause, save and continue, and a whole run by the repo's bot. |
| "Check the build Andrew will install" | `scrapkeep-verify-build` cuts or names a packed Linux build, checks it is this checkout's commit and plays it with the same driver: cold launch, first run, the sitting launch. The package and installer rows need the PC. |
| "Check the Sitting Kit page" or a preserved browser proof | `scrapkeep-verify-web` serves the pages on ports of its own and drives them in headless Chromium: the Sitting Kit, the yard and the Iron Orchard. |
| "Model-check the run flow" or a change to `flow.gd` or the launch swipe | `scrapkeep-verify-formal` checks a TLA+ model of a run and its launch swipe against every order of death, retry, new run, quit and Continue, shows each rule failing on a broken variant, and replays a break on the real game before it is called a bug. |
| "Design or evaluate a model decision inside the game loop" | `reactive-model-loop` covers controls, blind corpora, pre-registration, caching and cost fields for a fast model deciding inside a running system. It is portable and names nothing from this repository. |

Claude commands are `/plan-session`, `/scrapkeep-task`, `/scrapkeep-verify`, `/scrapkeep-lab`, `/scrapkeep-blockout`, `/scrapkeep-verify-game`, `/scrapkeep-verify-build`, `/scrapkeep-verify-web`, `/scrapkeep-verify-formal` and `/reactive-model-loop`. [The skills README](../../.agents/skills/README.md) says when a new skill is warranted and gives the template.

`BIBLE.md` and accepted `adr/` records own direction. `BACKLOG.md` defines tasks. `TRACKING.md` owns heavy-lane state and answers; alpha waves 17 to 21 run from [GRAPH.md](../../project-guide/coord/GRAPH.md) and GitHub issue #241. `ORCHESTRATOR.md` owns dispatch and admission. A proposed sprint or ready card is not permission to execute it. Keep one coordinator responsible for the board; handing off the coordinator does not create a second writer.

## Host behavior

The six project agent definitions under `.claude/agents/` own model and effort pins; [AGENTS.md](../../AGENTS.md) summarizes them and ORCHESTRATOR names each role. Read the frontmatter for the current values. The coordinator session is the model Andrew selects in the app, at the effort he selects. The coordinator picks the definition by the unit's difficulty: fully specified edits and lookups take the low-cost Sonnet definitions, routine review and the acceptance gate take Opus, and candidates whose acceptance turns on Bible, ADR or contract judgement take the Fable reviewer. Explorer and reviewer tool lists exclude shell and edits. Reviewers read the packet acceptance and the coordinator's receipts, never the writer's brief.

The game project disables automatic model switching and fallback chains. Runtime evidence for effort is the `CLAUDE_EFFORT` environment variable; a writer reads it with `env | grep CLAUDE_EFFORT`, and a read-only agent reports it only if the host exposes it. `.claude/settings.json` sets the documented top-level `"effortLevel"` key to high. Confirm by reading `CLAUDE_EFFORT` in a fresh coordinator session.

The same settings file makes approval gates mechanical. `permissions.deny` blocks force pushes, `npm publish` and `gh repo delete`; `permissions.ask` prompts for `git push`, `gh repo`, `gh api`, `npm install`, `npm i` and `npm uninstall`. The coordinator pushes reviewed work and answers the prompt; `npm ci` from the lockfile stays unrestricted.

A prompt does not set runtime model/effort. Verify actual metadata; report unavailable capabilities or substitutions before accepting a lane. This policy does not promise the model used by every internal utility request.

Writers no longer self-isolate. The coordinator creates each writer's worktree at the recorded base with `scripts/new-worktree.sh <task-id> <base-sha>`, which exits nonzero when HEAD differs, and names the path, branch and base SHA in the packet. The writer's first command verifies that identity and stops on a mismatch. Never import all uncommitted owner changes as a shortcut. Preserve leases across interruptions until the owner is confirmed stopped and its artifacts inspected.

## Check the installation

```sh
python /home/andrew/.config/astack/verify.py --project /home/andrew/Projects/scrapkeep
python /home/andrew/.config/astack/test_verify.py
claude plugin details astack
npm run check:project
npm run check:docs
npm run check:scope -- <base> <candidate> [--no-build]
```

The A stack verifier's project section checks that `CLAUDE.md` imports `AGENTS.md`, that each of the five `.claude/skills` entries is a symlink resolving to its `.agents/skills` body, that each skill's frontmatter is discoverable, and that no skill names an obsolete planning file. It also checks that this repository's `reactive-model-loop` matches the canonical pstack plugin copy. Run it and read its output; do not rely on a recorded list of failures. `npm run check:skills` checks all five skills: frontmatter, the `.claude/skills` link, cited paths, commands and event ids, and the lesson ledgers. `npm run check:project` checks required files, package/lock metadata and local file links. `npm run check:docs` adds anchors, BACKLOG card completeness and the TRACKING event sequence. `npm run check:scope` classifies changed paths between two commits and prints the commands that scope requires. `npm run verify` qualifies browser-proof code, not configuration, human game feel or the future native game. `check:godot` is reserved until the engineering handoff. Do not run a game build for a documentation-only task. Missing browser tools remain a verification gap.

The Claude port's migration receipts were disposable and lived under the gitignored `artifacts/local/`. The tracked evidence for the current configuration is the accepted audit under `artifacts/ai-first-audit-2026-09-06/`. No new plugin bundle, service or game feature accompanies this configuration; the permission rules above are the only gates added.

## Source-backed design

- Anthropic's [Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf), pages 5 and 15–16, motivates compact discovery metadata, details loaded on demand, trigger tests and functional tests. We use five narrow skills instead of a broad plugin catalog.
- [Claude Code Advanced Patterns](https://resources.anthropic.com/hubfs/Claude%20Code%20Advanced%20Patterns_%20Subagents,%20MCP,%20and%20Scaling%20to%20Real%20Codebases.pdf), a March 2026 webinar deck, distinguishes project instructions, hooks and MCP, and describes focused subagents and separate worktrees. It is architecture guidance, not a current configuration schema.
- [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) supports loading exact source references as needed. [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) motivates incremental work and durable progress. We adapt that pattern to the existing tracking board rather than adding its example progress files.
- Current [subagent documentation](https://code.claude.com/docs/en/sub-agents) and [model configuration](https://code.claude.com/docs/en/model-config) define supported model/effort fields, worktree defaults and fallback controls. The migration inspected Claude Code 2.1.261 on 6 September 2026. Documentation support does not prove this account can execute a request.

## Sprint handback

When the selected sprint exhausts its work, run [sprint-close](prompts/sprint-close.md). The [operating manual](../../ORCHESTRATOR.md#sprint-closure) owns the closure rules. A next-sprint proposal stays awaiting_review.
