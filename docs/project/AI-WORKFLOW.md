# Scrapkeep in Claude Code and Codex

Both apps use the same project authority and three canonical skills. Claude loads `CLAUDE.md`, which imports `AGENTS.md`; its skill directories link to `.agents/skills`. Shared pstack remains installed once at `/home/andrew/.config/pstack/plugin`.

## Use it

Start a fresh session in this repository after configuration changes.

| Request | Workflow |
| --- | --- |
| "Plan the next Scrapkeep session" | `plan-session` reads the board and discusses unresolved choices. It does not start the proposed sprint. |
| "Implement approved card <ID>" | `scrapkeep-task` checks authorization and prerequisites before assigning isolated work. |
| "Verify this Scrapkeep change" | `scrapkeep-verify` selects checks for the actual artifact and reports evidence limits. |

Claude commands are `/plan-session`, `/scrapkeep-task` and `/scrapkeep-verify`. Codex can select these skills from the request or use `$plan-session`, `$scrapkeep-task` and `$scrapkeep-verify`.

`BIBLE.md` and accepted `adr/` records own direction. `BACKLOG.md` defines tasks. `TRACKING.md` owns live state and answers. `ORCHESTRATOR.md` owns dispatch and admission. A proposed sprint or ready card is not permission to execute it. Keep one coordinator responsible for the board across both apps; handing off the coordinator does not create a second writer.

## Host behavior

Claude pstack roles use pinned Fable 5.1. Exploration and ordinary writes use high effort; coordination, debugging and review use xhigh; explicitly scoped hardest roles use max. The game project disables automatic model switching and fallback chains. Its three agent definitions pin role model/effort, and explorer/reviewer tool lists exclude shell and edits. The coordinator runs executable checks and gives the reviewer their exact receipts.

Codex retains its existing Astra role map. Both maps live under `/home/andrew/.config/pstack/models/`. A prompt does not set runtime model/effort. Verify actual metadata; report unavailable capabilities or substitutions before accepting a lane. This policy does not promise the model used by every internal utility request.

Claude's native worktree may start at the default branch, so check its base and required inputs before edits. If the base differs, stop and launch from a worktree explicitly created at the accepted revision. Never import all uncommitted owner changes as a shortcut. Preserve leases across interruptions until the owner is confirmed stopped and its artifacts inspected.

## Check the installation

```sh
python /home/andrew/.config/pstack/verify.py --project /home/andrew/Projects/test-game-2
python /home/andrew/.config/pstack/test_verify.py
claude plugin details pstack
```

The verifier covers installation, routing and project skill structure. Behavioral receipts and model metadata are separate evidence. `npm run verify` qualifies browser-proof code, not configuration, human game feel or the future native game. Do not run a game build for a documentation-only task. Missing browser tools remain a verification gap.

Migration receipts and restoration instructions are in `artifacts/local/claude-port/REPORT.md`. That file is a delivery receipt, not another task board. Backups and the guarded restoration script are named there. No new plugin bundle, service, permission rule or game feature accompanies this port.

## Source-backed design

- Anthropic's [Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf), pages 5 and 15–16, motivates compact discovery metadata, details loaded on demand, trigger tests and functional tests. We use three narrow game skills instead of copying the whole Codex plugin catalog.
- [Claude Code Advanced Patterns](https://resources.anthropic.com/hubfs/Claude%20Code%20Advanced%20Patterns_%20Subagents,%20MCP,%20and%20Scaling%20to%20Real%20Codebases.pdf), a March 2026 webinar deck, distinguishes project instructions, hooks and MCP, and describes focused subagents and separate worktrees. It is architecture guidance, not a current configuration schema.
- [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) supports loading exact source references as needed. [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) motivates incremental work and durable progress. We adapt that pattern to the existing tracking board rather than adding its example progress files.
- Current [subagent documentation](https://code.claude.com/docs/en/sub-agents) and [model configuration](https://code.claude.com/docs/en/model-config) define supported model/effort fields, worktree defaults and fallback controls. The migration inspected Claude Code 2.1.261 on 6 September 2026. Documentation support does not prove this account can execute a request.
