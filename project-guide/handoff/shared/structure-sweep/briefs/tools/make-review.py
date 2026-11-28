"""Write the brief for the independent review of one structure-sweep unit.

Usage:
  python3 -I make-review.py <unit> <pull request> <branch> <head SHA> <base SHA> <gate tip SHA> <writer brief file> [extra checks file]

The three SHAs are full 40-character SHAs. <base SHA> is the commit the unit's
diff is read against (the integration tip the unit last merged, or its base
commit). <gate tip SHA> is the current pushed tip of origin/entropy/gate.
"What the unit was asked to do" is copied from the writer brief, so the reviewer
judges against the same words the writer was given and nothing is retyped. For a
unit whose writer brief predates this folder, pass an earlier review brief of
the unit instead; its "What the unit was asked to do" section is copied.
Safe to rerun: it overwrites the one file it writes, review-<unit>-<head7>.md,
beside the writer briefs.
"""
import pathlib
import re
import sys

unit, pr, branch, head, base, gate, brief = sys.argv[1:8]
extra = pathlib.Path(sys.argv[8]).read_text().strip() if len(sys.argv) > 8 else ""
extra = extra.replace("HEAD_SHA", head).replace("BASE_SHA", base).replace("GATE_SHA", gate)
for sha in (head, base, gate):
    assert re.fullmatch(r"[0-9a-f]{40}", sha), f"not a full SHA: {sha}"

text = pathlib.Path(brief).read_text()
asked = re.search(r"^## The unit\n(.*?)(?=^## (Checks|Hand in|Report)\b)", text, re.S | re.M) or re.search(
    r"^## What the unit was asked to do\n(.*?)(?=^Rules that bind every unit|^## )", text, re.S | re.M
)
assert asked, f"{brief} has neither a '## The unit' section followed by '## Checks' nor a review brief's '## What the unit was asked to do'"
asked = re.sub(r"^## ", "### ", asked.group(1).strip(), flags=re.M)

TEMPLATE = """You are the independent reviewer of one pull request in the Scrapkeep repository (GitHub `bananahana720/scrapkeep`). Scrapkeep is a Godot 4.7.2 GDScript game under `sketches/core-loop` with a Node toolchain under `scripts/`. You did not write this change and you have not seen the writer's reasoning. Judge the diff against what the unit was asked to do, below.

## Hard limits

- Write nothing. Use read-only git only (`git fetch`, `git show`, `git diff`, `git log`, `git grep <pattern> <commit> -- <path>`, `git ls-tree`, `git merge-tree`). Do not check out, switch, stash, commit, push, edit a file, comment on the pull request or start a sub-agent. Other sessions share this checkout.
- Do not run Godot, `npm run sketch:fast` or any test. The coordinator runs them when it merges. Read the code.
- On this Mac `git grep -E` does not honour `\\b`; write patterns without it.

## What to review

Pull request {pr} (https://github.com/bananahana720/scrapkeep/pull/{pr}), unit {unit}, branch `origin/{branch}`, head `{head}`. Run `git fetch origin` and check that `git rev-parse origin/{branch}` prints that head; if it does not, say so and review what is there. The unit's own change is `git diff {base} {head}`; if the head contains merges of the integration branch, read the unit's change as `git diff {gate}...{head}` and `git log --first-parent {base}..{head}` so that other units' landed work is not judged as this unit's. The integration branch is `origin/entropy/gate`, now at `{gate}`.

## What the unit was asked to do

The words below are the writer's instructions, copied unchanged. Lines that tell the writer how to set up or what to run are not for you; the description of the change and "Done looks like" are what you judge against.

{asked}

Rules that bind every unit: when a new call or a new home replaces an old one, every caller moves in the same commit and the old one is deleted, with no forwarding copy left behind; no code comment is added (only tool-read lines and engine quirk notes are allowed); no test is deleted or weakened, and a test changes only to follow a moved or renamed call; no `package.json` is edited unless the instructions above say Andrew approved it; every new `.gd` file has a tracked `.gd.uid` beside it; `scripts/sketch-lint.baseline.json` gains no entry.

## What to check, at least

1. **Behaviour is unchanged.** For every moved or renamed function the body is the same; for every new call, compare what each caller read or did before with what it gets now, for every input: same value, same object (not a copy) where the caller keeps or mutates it, same order of side effects and signals.
2. **No caller was missed.** For each old name, search the head for remaining uses in `src/`, `tests/`, `tools/`, `scripts/`, `.tscn` and `.tres` files and string calls (`call("name"`, `has_method("name"`, `Callable(x, "name")`, `get("name")`), including uses through an alias (a `const X := preload(...)` under another name) or `load("...")` at run time. A missed caller is a blocking issue because it fails only at run time.
3. **Names.** A new public name does not collide with a member of the same class, a subclass, a parent or a test double, and does not shadow a local variable or parameter in a way that changes meaning.
4. **Nothing is left behind and nothing is forced.** No forwarding copy, no dead code the change orphaned, no new layer that only passes calls through, no file split whose new file calls back into its parent for most of its work. Where the writer left an item with a reason, say whether the reason holds.
5. **The guard** (if the unit adds or extends one) fails on the old form, cannot pass by matching nothing (check its patterns against the head), and its allowed lists can only shrink. For every check, guard or tool the unit adds, name each way it could report a pass without having checked: an input that does not exist or is misspelt, a read that failed (a file, a git call, a fetch), an empty list. One that passes in any of those cases is a blocking issue; it must fail and say why.
6. **Formal models.** `.agents/skills/scrapkeep-verify-formal/SKILL.md` lists the files covered by a formal model. The models were not run. Say exactly which lines of covered files this unit changed and whether any of them changes how the modelled state is read, stepped, held or ended.
7. **Scope.** List every file the unit changed outside the area its instructions name, and whether a rename or a moved path forces each.
8. **Fit with the integration branch.** Run `git merge-tree --write-tree {gate} {head}` (it writes no branch and touches no file in the checkout) and report any conflict. Look for a caller of an old name that exists at `{gate}` but not in the unit's diff, because a clean merge would leave it broken, and for a name this unit uses that a landed unit moved.
{extra}
## Report

Lead with `VERDICT: PASS` or `VERDICT: FAIL`. Then, apart from each other: blocking issues (each with the file, the function or a `git grep` pattern that finds it, and what is wrong), and notes (things that do not block). For each note that is a small fix, say whether the coordinator can apply it while merging without another review. End with a receipt: your model and effort, the commits you checked, your method, and what you did not do. Write for a reader who has not seen this brief: plain words, full file paths, no shorthand.
"""

out = pathlib.Path(brief).resolve().parent / f"review-{unit.lower()}-{head[:7]}.md"
out.write_text(TEMPLATE.format(unit=unit, pr=pr, branch=branch, head=head, base=base, gate=gate, asked=asked, extra=(extra + "\n\n") if extra else ""))
print(out.name, len(out.read_text().split()), "words")
