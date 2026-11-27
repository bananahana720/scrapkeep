# TADR-012. No new script dependency loops in the sketch

Status: **Proposed (checked by lint on the branch `entropy/gate`).** Written during the structure sweep Andrew asked for on 27 November 2026 ([STRUCTURE-SWEEP.md](../project-guide/handoff/STRUCTURE-SWEEP.md)). The rule runs in `npm run sketch:lint` as L16 from pull request 1288. It reaches `main` when the Gate lands that branch; Andrew can overturn it.

Date: 27 November 2026. Applies to the light play lane only (`sketches/core-loop/src`). It does not change [TADR-002](TADR-002-runtime-model.md), which owns the module boundaries of the native game.

Paths below are under `sketches/core-loop/` unless they start with `adr/`, `scripts/` or `project-guide/`.

## Context

**Most of the game's code sits in one loop.** A script depends on another when it names that script's `res://src/...gd` path or uses the class name the other script declares. Measured on commit `e91cb3bab`, `src/` has 617 script files and 2,908 such dependencies. 192 of the files sit in 8 loops, where each file in a loop reaches every other file in it by following dependencies. One loop holds 169 files across `world`, `presentation`, `combat`, `boss`, `core`, `build` and `ui`. The others hold 7, 6, 2, 2, 2, 2 and 2 files.

**A loop costs every change inside it.** No file in a loop can be loaded alone, so a test of one loads all of them, a change to one can break any other, and two writers working in the loop cannot be given files that are independent. The sweep's aim of many writers working at once depends on the loops getting smaller.

**The directories are not layers.** `src/core` names files in every other directory (116 file pairs), so no rule of the form "this directory may not load that one" can be switched on today without hundreds of exceptions, and choosing the order of the layers is a design decision Andrew has not made.

**Nothing stopped a loop from growing.** The lint rules L6 to L10 keep a few named modules apart. No check looked at the dependency graph as a whole.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Forbid a file from joining a loop, with a list of the files already in one that may only shrink | **Chosen** | Needs no layer order. Fails the change that makes things worse and passes everything else. The list is the work left to do, in a form a machine reads |
| Forbid upward dependencies between directories in a chosen layer order | Rejected for now | The best order of the nine directories still leaves 329 file pairs pointing up, and picking the order waits on Andrew. Can be added on top of L16 once he picks one |
| Record the size of each loop and fail when a loop grows | Rejected | A loop has no stable name: cutting one dependency can split it in two, and adding one can join two. A per-file list stays meaningful through both |
| Leave it to the reviewer | Rejected | Review alone did not stop a 169-file loop forming, and the sweep asks for a check behind each rule |
| Build the graph from Godot's own script loader | Rejected | It needs an engine start for a lint that runs before every push in under a second. Reading the text finds the same loops for the forms the code uses |

## Decision

1. **The graph.** `buildScriptGraph` in `scripts/sketch-lint.mjs` reads every `.gd` file under `src/`. File A depends on file B when A contains the exact string `"res://src/<path of B>"`, or when A uses, outside strings and comments, the name B declares with `class_name`. A file never depends on itself.
2. **The loops.** `stronglyConnectedComponents` finds every group of two or more files that all reach each other. It does not recurse, so a long chain of files cannot overflow the stack.
3. **The rule.** L16 reports every file that is in a loop. `scripts/sketch-lint.baseline.json` lists the 192 files that were in one on 27 November 2026. A file in a loop that is not on the list fails the lint. A file on the list that is no longer in a loop also fails the lint until its line is removed, so the list cannot go stale and can only shrink.
4. **Shrinking the list** is how a loop-cutting unit proves itself: its pull request removes lines from the `L16` list and adds none.

## Consequences

- A new script that would join a loop fails `npm run sketch:lint`, which `npm run sketch:fast` also runs. The writer breaks the dependency, usually by passing the value in or by moving the shared piece to the module that owns it.
- **Accepted limit: a new dependency between two files already on the list passes.** So does a change that joins two existing loops into one. The rule stops the loops taking in new files; it does not stop them tightening.
- **Accepted limit: a path built at run time is not seen.** One exists: `src/combat/warden.gd` formats `"res://src/combat/warden_%s.gd"`. Counting it would put four more files in the large loop.
- The rule reads text, so a `class_name` that matched a common word would create false dependencies. The 23 declared today are all distinct names; a reviewer of a new `class_name` should keep that true.
- The lint's run time rose from about 760 ms to about 810 ms on the Mac Studio.

## Later qualification and reconsideration

- When Andrew picks a layer order for the directories, add the direction rule on top of this one and record it here.
- When the list is short enough to read, replace it with the named loops that remain and a reason for each, or delete the rule's list and forbid loops outright.
- If the code starts building script paths at run time in more places, the graph needs a registry of those paths or a reading from the engine.
