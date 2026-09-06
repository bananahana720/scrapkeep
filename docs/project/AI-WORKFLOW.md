# Scrapkeep in Claude Code and Codex

Both apps use the same project authority and three canonical skills. Claude loads `CLAUDE.md`, which imports `AGENTS.md`; its skill directories link to `.agents/skills`. Shared pstack remains installed once at `/home/andrew/.config/pstack/plugin`. The pstack runtime contract is `/home/andrew/.config/pstack/runtime.md`; the skills and `AGENTS.md` refer to it by role and this file records its path once.

## Use it

Start a fresh session in this repository after configuration changes.

| Request | Workflow |
| --- | --- |
| "Plan the next Scrapkeep session" | `plan-session` reads the board and discusses unresolved choices. It does not start the proposed sprint. |
| "Implement approved card <ID>" | `scrapkeep-task` checks authorization and prerequisites before assigning isolated work. Its numbered procedure links the ORCHESTRATOR and TRACKING sections that own each rule. |
| "Verify this Scrapkeep change" | `scrapkeep-verify` selects checks for the actual artifact and reports evidence limits. |

Claude commands are `/plan-session`, `/scrapkeep-task` and `/scrapkeep-verify`. Codex can select these skills from the request or use `$plan-session`, `$scrapkeep-task` and `$scrapkeep-verify`.

`BIBLE.md` and accepted `adr/` records own direction. `BACKLOG.md` defines tasks. `TRACKING.md` owns live state and answers. `ORCHESTRATOR.md` owns dispatch and admission. A proposed sprint or ready card is not permission to execute it. Keep one coordinator responsible for the board across both apps; handing off the coordinator does not create a second writer.

## Host behavior

Claude pstack roles use pinned Fable 5.1 at four effort tiers. Six project agent definitions under `.claude/agents/` pin the model and one effort each. `scrapkeep-writer-low` runs at low, `scrapkeep-writer-medium` and `scrapkeep-reviewer-medium` at medium, `scrapkeep-writer` and `scrapkeep-explorer` at high, and `scrapkeep-reviewer` at xhigh. The coordinator session runs at xhigh. The coordinator assigns each unit's effort by its importance and difficulty; a mechanical fully specified edit takes low, a bounded prepare-stage unit takes medium, design judgement takes high, and review of consequential candidates takes xhigh. Explorer and reviewer tool lists exclude shell and edits. Reviewers read the packet acceptance and the coordinator's receipts, never the writer's brief.

The game project disables automatic model switching and fallback chains. Runtime evidence for effort is the `CLAUDE_EFFORT` environment variable; a writer reads it with `env | grep CLAUDE_EFFORT`, and a read-only agent reports it only if the host exposes it. The coordinator observed `CLAUDE_EFFORT=high` while `.claude/settings.json` keyed xhigh under an undocumented `modelSettings` entry. On 6 September 2026 the settings file was corrected to the documented top-level `"effortLevel": "xhigh"` key, per the settings reference fetched through Context7. Confirm the fix by reading `CLAUDE_EFFORT` in a fresh coordinator session.

The same settings file makes approval gates mechanical. `permissions.deny` blocks force pushes, `npm publish` and `gh repo delete`; `permissions.ask` prompts for `git push`, `gh repo`, `gh api`, `npm install`, `npm i` and `npm uninstall`. The coordinator pushes reviewed work and answers the prompt; `npm ci` from the lockfile stays unrestricted.

Codex retains its existing Astra role map. Both maps live under `/home/andrew/.config/pstack/models/`. A prompt does not set runtime model/effort. Verify actual metadata; report unavailable capabilities or substitutions before accepting a lane. This policy does not promise the model used by every internal utility request.

Writers no longer self-isolate. The coordinator creates each writer's worktree at the recorded base with `scripts/new-worktree.sh <task-id> <base-sha>`, which exits nonzero when HEAD differs, and names the path, branch and base SHA in the packet. The writer's first command verifies that identity and stops on a mismatch. Never import all uncommitted owner changes as a shortcut. Preserve leases across interruptions until the owner is confirmed stopped and its artifacts inspected.

## Check the installation

```sh
python /home/andrew/.config/pstack/verify.py --project /home/andrew/Projects/scrapkeep
python /home/andrew/.config/pstack/test_verify.py
claude plugin details pstack
npm run check:project
npm run check:docs
npm run check:scope -- <base> <candidate> [--no-build]
```

The pstack verifier's project section checks that `CLAUDE.md` imports `AGENTS.md`, that each of the three `.claude/skills` entries is a symlink resolving to its `.agents/skills` body, that each skill's frontmatter is discoverable, and that no skill names an obsolete planning file. Its settings and agent checks (`verify.py:140-177`) still encode the earlier three-tier design with `isolation: worktree` and read the removed `modelSettings` key, so they fail on the current definitions until pstack updates the verifier; that update is Andrew's shared-setup change, not a project edit. `npm run check:project` checks required files, package/lock metadata and local file links. `npm run check:docs` adds anchors, BACKLOG card completeness and the TRACKING event sequence. `npm run check:scope` classifies changed paths between two commits and prints the commands that scope requires. `npm run verify` qualifies browser-proof code, not configuration, human game feel or the future native game. `check:godot` is reserved until the engineering handoff. Do not run a game build for a documentation-only task. Missing browser tools remain a verification gap.

The Claude port's migration receipts were disposable and lived under the gitignored `artifacts/local/`. The tracked evidence for the current configuration is the accepted audit under `artifacts/ai-first-audit-2026-09-06/`. No new plugin bundle, service or game feature accompanies this configuration; the permission rules above are the only gates added.

## Source-backed design

- Anthropic's [Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf), pages 5 and 15–16, motivates compact discovery metadata, details loaded on demand, trigger tests and functional tests. We use three narrow game skills instead of copying the whole Codex plugin catalog.
- [Claude Code Advanced Patterns](https://resources.anthropic.com/hubfs/Claude%20Code%20Advanced%20Patterns_%20Subagents,%20MCP,%20and%20Scaling%20to%20Real%20Codebases.pdf), a March 2026 webinar deck, distinguishes project instructions, hooks and MCP, and describes focused subagents and separate worktrees. It is architecture guidance, not a current configuration schema.
- [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) supports loading exact source references as needed. [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) motivates incremental work and durable progress. We adapt that pattern to the existing tracking board rather than adding its example progress files.
- Current [subagent documentation](https://code.claude.com/docs/en/sub-agents) and [model configuration](https://code.claude.com/docs/en/model-config) define supported model/effort fields, worktree defaults and fallback controls. The migration inspected Claude Code 2.1.261 on 6 September 2026. Documentation support does not prove this account can execute a request.
