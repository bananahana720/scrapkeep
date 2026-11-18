# Deep-modules sweep, after each promotion

Andrew, 8 Nov 2026: after every promotion to main, sweep the newly promoted code so modules get deeper and interfaces simpler (Ousterhout, *A Philosophy of Software Design*). The first full sweep ran on wave 32; its findings page is linked from the w32 board (#627).

The sweep changes structure, never behaviour. No gameplay, tuning, timing, signal-order, RNG-draw-order or save-format change rides on it, and the bands must not move.

## The Gate lane's promotion step

The Gate lane runs this as the last step of every scripted promotion, right after the stage PR merges to main and before it cuts the next stage (coordinator, 8 Nov: a promotion step, no clock routine):

```bash
git fetch origin main && git checkout --detach origin/main
node scripts/deep-sweep.mjs --out artifacts/local/deep-sweep-w<N>.md
cp artifacts/local/deep-sweep-w<N>.md /mnt/project-files/gate/deep-sweep-w<N>.md
```

Then it posts the report's header and counts on the new wave's board issue with a link to the shared copy, and tells the coordinator, who opens one sweep thread per promotion that has leads. A report with zero leads closes the step. The step never holds a promotion or the next stage cut.

## Steps for the sweep thread

1. On the promoted main, run `node scripts/deep-sweep.mjs --out artifacts/local/deep-sweep-w<N>.md`. With no `--base` it compares the promotion merge against main before it. It lists leads, not defects:
   - D1 a new public function whose whole body forwards its own parameters to one other call;
   - D2 new code that touches another object's underscore member (`boss._phase`, `w.get("_state")`, or through a chain, `game.flow.warden._age`), read in `tools/` as well as `src/`;
   - D3 a new function with six or more parameters, or three or more bools;
   - D4 a snake_case string key on a new line that three or more `src/` files spell (a leaked schema);
   - D5 a file over 1500 lines that grew by 100 or more.
2. Read each lead in the code. Keep it only if a caller would stop needing to know something after the change. Drop leads that are Godot idiom (`_ready`, `_process`, signal callbacks), test seams already named in a test, or data-row keys that a schema module already owns.
3. Rank the keepers by payoff (what callers stop knowing, times how often the code changes; world 1 first) against risk (physics timing, frame order, RNG draw order, signal order, save format, anything a bot band or posture test reads is high risk).
4. Ship the top few as small PRs on the next stage, one seam per PR, claimed on the board. Each PR: the focused tests of the files it touches, `npm run sketch:fast -- --base stage/alpha-w<N+1>`, and an independent reviewer who checks it is behaviour-preserving. High-risk leads go to the owning lane instead.
5. Post the ranked list on the board, and the leads left open, so the next sweep does not re-read them.

## Patterns that pay here

- Fold a pass-through into its caller, or give it a reason to exist (a default, a guard, a unit change).
- Replace a reach-in with one public method on the owner that says what the caller wants, not what the owner holds.
- Give a string key repeated across files one owner (a `const` on the schema module) and read it from there.
- Replace a run of bool parameters with one options dictionary or a named enum, only where callers pass more than two.
- Split a giant file only along a seam that already exists (a group of functions that share private state nobody else reads).

Leave alone: the invariant and state-machine guards from #616-#625, and the boss.gd content pin in `tests/boss_pickup_asset_test.gd` (re-pin it in the same PR if boss.gd logic moves).
