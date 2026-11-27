# Project skills

Each directory here is one skill that Antigravity loads natively from `.agents/skills/` and Claude Code reaches through a symlink in `.claude/skills/`. This page says when to add a skill and how to write one.

| Skill | Kind | Use it to |
| --- | --- | --- |
| `plan-session` | project | plan the next scope or discuss unresolved decisions |
| `scrapkeep-task` | project | execute an authorized card with isolated work, review and admission |
| `scrapkeep-verify` | project | choose and run the checks that qualify an artifact |
| `scrapkeep-blockout` | project | build mojulo blockout pieces and heroes, export them and prove them with the ball |
| `scrapkeep-verify-game` | project | play the launched game from a step file and keep the proof a feature works |
| `scrapkeep-verify-build` | project | check and play the packed Linux build Andrew installs |
| `scrapkeep-verify-web` | project | drive the Sitting Kit and the two preserved browser proofs in a real browser |
| `scrapkeep-verify-formal` | project | model-check the run flow and launch swipe under every interruption |
| `scrapkeep-gemini-workflows` | project | orchestrate Antigravity `run_workflow` pipelines, Gemini tier routing, and card batches |
| `scrapkeep-visual-review` | project | run Gemini multimodal UI audits, blind `eye.mjs` film reads, and reference sheets |
| `scrapkeep-dev-console` | project | drive the dev console CLI lever, warm File-Mailbox sessions, recipes, and silent offscreen sheets |
| `reactive-model-loop` | portable | design and evaluate a fast model that decides inside a running system |

`reactive-model-loop` is a portable skill with no project-specific paths or rules; `scripts/check-skills.mjs` enforces that portability boundary.

The three `scrapkeep-verify-*` skills each maintain a `features/` map (one file per player-facing feature) and helper scripts under `scripts/`; audit each map directly against source and the running app when features change. `scrapkeep-verify` picks which checks qualify a diff; these three show a feature working.

## Decide whether it is a skill

Add a skill only when all three hold:

- A fresh agent would search for its trigger, and no existing description covers that trigger.
- It needs at least two references of its own.
- It has a distinct owner or reviewer tier.

Otherwise, add a section or a reference to the closest skill.

## Name it

- A project skill is `scrapkeep-<noun>`.
- A portable skill is a plain noun phrase with no project word in it, and it names no repository path, card id, event id, engine or stage.
- The directory name equals the frontmatter `name`.

## Write the trigger

The `description` is one or two sentences. Name the artifacts the skill acts on and the verbs, then say "Use for" or "Use when", then name by skill what it leaves to others. Before committing, test it with three prompts: one it should catch, one near miss, and one that belongs to another skill.

## Place the files

1. Write the body at `.agents/skills/<name>/SKILL.md` and keep it at 120 lines or fewer after the frontmatter.
2. Put detail under `.agents/skills/<name>/references/`.
3. Link it for Claude: `ln -s ../../.agents/skills/<name> .claude/skills/<name>`.
4. Register it on the skills line of `AGENTS.md`.
5. Start `.agents/skills/<name>/references/lessons.md` with the lesson format below, even if it has one lesson.
6. Run `npm run check:skills` and fix every finding before the coordinator commits.

## Write lessons

A lesson is one bullet in `.agents/skills/<name>/references/lessons.md`. Its status is `established`, `provisional` or `retracted`. A new lesson starts as `provisional` unless a second independent run or review, or a recorded ruling, supports it. A retracted lesson keeps its text and fills `Overturned by`, and the rule line that cited it changes in the same commit. Every change adds a row to the file's `## Changelog`.

A rule line in `.agents/skills/<name>/SKILL.md` ends with the lesson id it rests on, for example `(SKL-07)`. A rule with no lesson says "(design choice)".

## Template

Copy this into a new `.agents/skills/<name>/SKILL.md`. There is no template directory, because a skill loader would list it as a skill.

```markdown
---
name: <name>
description: "<Verb> <artifacts> ... Use for <requests>; <neighbour work> stays in <other-skill>."
---

# <Title as a task>

Resolve this skill directory through symlinks, then run `git -C <resolved-skill-directory> rev-parse --show-toplevel` to identify the repository root. Read `AGENTS.md` and `project-guide/handoff/START-HERE.md`. Use root-relative source paths below. The linked Claude skill resolves to this same body.

<One paragraph: what this skill owns and which skills own the neighbouring work.>

## Procedure

1. <Step. Cite the lesson it rests on (XXX-01) or say "(design choice)".>
2. <Step.>

## Lessons and updates

[references/lessons.md](references/lessons.md) holds XXX-01 onward. Status is `established`, `provisional` or `retracted`. When a result overturns a lesson, retract it, fill `Overturned by`, change the rule line above in the same commit, and add a changelog row.

## Host adapter

- Antigravity: `/<name>` (see `GEMINI.md` for Gemini model tiers and `.agents/agents/`).
- Claude Code: `/<name>`.
- Report the actual model and runtime effort/tier metadata or their absence.
```

Lesson format for `.agents/skills/<name>/references/lessons.md`:

```markdown
- **XXX-01** · status: provisional · since: YYYY-MM-DD · origin: <where it came from>
  <The rule, in one or two sentences.>
  Evidence: <EV-nnnn; path:line of the review, result or source>.
  Overturned by: —
```
