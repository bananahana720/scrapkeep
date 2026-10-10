# Asset forge

A headless Claude Code agent writes a Blender recipe for an asset, the forge builds it in a
capped sandbox, validates the result, and the agent iterates on the validator's check list and
its own look at the preview sheet. You get a versioned GLB, `.blend`, turntable sheet and
manifest. `promote` moves an accepted version into the core-loop sketch.

Stdlib Python only (no installs). Needs `blender` (5.2 LTS), `bwrap`, `systemd-run --user`,
ImageMagick `montage`, `node` (asset-inspect cross-check) and `claude` (2.1.296 tested).
Every `make` and `revise` spends Claude quota; `run`, `list`, `compare` and `promote` do not.

## Use

```sh
F=tools/asset-forge/forge.py
python3 $F make model --pack core-loop --name scrap_crate "A chunky salvaged supply crate, about 1 m wide"
python3 $F make model --name scrap_crate2 --reference concept.png "match the picture"   # concept picture as target
python3 $F revise --name scrap_crate "add a dented lid"      # new version from the latest; --base v001 to pick
python3 $F run artifacts/local/forge/core-loop/scrap_crate/v002    # rebuild + revalidate, no model call
python3 $F list
python3 $F compare scrap_crate v001 v002                      # side-by-side sheet
python3 $F promote scrap_crate v002                           # --force replaces an earlier promotion
python3 $F pack plan.toml                                     # sequential makes, one contact sheet
```

Flags on `make`, `revise` and `pack`: `--model sonnet` (default), `--category prop|kit|hero`,
`--max-turns 40`, `--budget 3.0` (USD cap for the agent), `--agent-timeout 1800`,
`--timeout 600` (wall clock per Blender run), `--dry-agent` (prepare the version, no model call).
A `pack` plan:

```toml
pack = "core-loop"
style = "Shared style sentence added to every prompt."
[[asset]]
name = "scrap_crate"
prompt = "..."
category = "prop"
reference = "optional/concept.png"
```

Scratch lives under `artifacts/local/forge/<pack>/<asset>/vNNN/` (override with `FORGE_HOME`).
Exit codes of `forge run`: 0 passed, 1 recipe fault or a failing check, 2 harness fault.

## Version directory

| Path | What |
| --- | --- |
| `prompt.md` | the request (a revision's text for `revise`) |
| `params.json` | kind, pack, category, triangle band, slot list and specs, palette (parsed from `palette.gd`), draw-call and size limits. Read-only to the agent. |
| `system_prompt.md` | system brief + kind brief + the pack's style sections |
| `reference/` | copies of `common.py` and example recipes; `previous.png` (revise); `concept.png` (`--reference`) |
| `recipe.py` | the agent's recipe: `build(params) -> root` |
| `out/<asset>.glb`, `out/<asset>.blend` | build outputs |
| `preview/sheet.png` | 8 views: eye level and high, 4 turns each |
| `result.json` | entry measurements, always written |
| `validate.json` | `checks` (`id`, `state` pass/warn/fail/info, `value`, `detail`), `score` 0 to 10, `passed` |
| `manifest.json` | schema 1: sources and files with SHA-256, kind, pack, prompt/concept hash, model requested and used, claude CLI version, parent version, score, exact agent command and sandbox command |
| `agent.json`, `notes.md` | the agent's JSON output and its closing note |

Score: 10 minus 3 per fail and 1 per warn, capped at 4 with any fail and 8 with any warn.

## Layout and packs

- `forge.py` CLI. `forgecore.py` packs, palette, versions, GLB read-back, scoring.
- `packs/<name>.toml`: sketch path, palette source, helper-module dir (`helper_dir`, where
  `common.py` lives), example recipes, role names, triangle bands, size and draw-call limits,
  promote destinations. All paths are relative to the repo root (`FORGE_REPO` overrides the
  root), so another checkout can carry its own pack.
- Colours are never copied: `palette.gd` is parsed, mapped to `common.py` role names by the
  pack, and a test checks `common.py`'s `HEX` mirror has not drifted from it.

## Kind interface

A kind is a directory `kinds/<kind>/`; `forge.py` finds it by name, so a new kind adds a
directory and no edit to `forge.py`. Required files:

| File | Contract |
| --- | --- |
| `kind.toml` | `name`, `runner`, `entry`, `brief`, `validator`, `promoter`, `bands_key` (key into the pack's `bands`, `sizes`, `draw_calls`, `promote` tables), `outputs`, `sheet` |
| `brief.md` | the kind's rules for the agent, appended to the system prompt |
| `entry.py` | runs inside the runner (Blender) with the version dir after `--`. Runs `recipe.py` with `PARAMS`, writes `out/` and `preview/`, and ALWAYS writes `result.json` (`status`: `ok`, `recipe_error`, `harness_error`; `warnings`; `measure`). Exit 1 = recipe fault, 2 = harness fault. Post-steps are wrapped: a failed measurement is a warning. |
| `validate.py` | `validate(vdir, params, result, pack) -> [check]`, stdlib only, run outside the sandbox |
| `promote.py` | `promote(vdir, params, pack, manifest, force) -> [written paths]` |

The `model` kind is the one built so far. Terrain, vfx, sprite and pixel kinds are future work;
`run_blender` in `forge.py` is the one runner and would need a sibling for a non-Blender runner.

## Safety model

Model-written code executes only in `forge run`. The agent can run nothing else.

1. **Agent tools.** `claude -p --restricted --strict-mcp-config --setting-sources ""
   --tools Read,Write,Edit,Bash --permission-mode dontAsk`. `--restricted` confines file tools
   to the version dir, ignores user and project settings (no user hooks, no MCP servers), and
   `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` skips CLAUDE.md files. Allowed: `Read`, `Write`, `Edit`
   and `Bash(python3 <forge.py> run .)`; `Write`/`Edit` of `params.json` are denied.
2. **Bash gate.** Claude Code auto-allows read-only commands like `cat` and `ls` even in
   `dontAsk`, so a `PreToolUse` hook (`bash_gate.py`, passed with `--settings`) denies every
   Bash command that is not exactly the forge run. `ls /` and `cat recipe.py` are denied.
3. **The run sandbox.** `systemd-run --user --scope` caps memory (`MemoryMax=20G`,
   `MemorySwapMax=2G`); a wall-clock timeout kills the scope, and the scope is stopped after
   every run so nothing the recipe spawned outlives it. Inside, `bwrap --unshare-all
   --new-session --clearenv` shows only `/usr`, `/etc` and `/sys` read-only, `/dev/dri` for
   the GPU, the helper, kind and Blender dirs read-only, a tmpfs home and `/tmp`, and one
   writable path: the version dir. No network, and no `/run`, so the user D-Bus, ssh-agent
   and other sockets are unreachable. No caller environment variables (API keys) reach the
   recipe. Without bwrap, `forge run` refuses (harness fault) rather than run unconfined.
   `IPAddressDeny=any` on a user scope was tried and is NOT enforced, which is why bwrap is used.
4. **Links are swept.** Recipe code could plant a symlink in its version dir (say `run.log`
   pointing at `~/.bashrc`) for the unsandboxed forge to write or read through. Every outer
   step first deletes any entry that is not a plain file or directory (`forgecore.sweep`),
   a run that left one is a recipe fault, and outer JSON/text writes go through a temp file
   and a rename, which replaces a link rather than following it.
5. **No trust in the agent's outputs.** After the agent finishes, `make` restores `params.json`
   from memory and does an authoritative `forge run`.

Tests prove each layer: `test_bash_gate_allows_only_the_exact_run`, `test_sweep_*`,
`test_write_json_replaces_a_link_*`, `test_refuses_to_run_without_bwrap`, and the sandbox probe
in `BlenderRuns` (network, user bus, `/run`, env, planted links).

## Stated gaps

- The agent's `Write` can overwrite files inside its own version dir (`recipe.py`, reference
  copies, `result.json`); the final authoritative run regenerates results and the validator
  never trusts the agent's files, but a hand-edited `result.json` would be rewritten, not caught.
- Writes outside the version dir from a recipe succeed inside the sandbox's private tmpfs and
  vanish; they are not an error. Recipes can still read `/usr`, `/etc` and `/sys` (no secrets
  there on this machine) and the bound helper dirs.
- `--max-budget-usd` and `--max-turns` bound spend; with a subscription login the dollar figure
  is notional.
- Floating-part detection uses island bounding boxes (5 mm tolerance), so a gap hidden inside
  a box's footprint is not seen. Non-manifold is a warning by design.
- The preview is eight stills. Passing validation says nothing about human taste, in-engine
  look, collision or performance (`manifest.limits`).
- `bash_gate.py` relies on Claude Code honouring `--settings` hooks under `--restricted`
  (checked on 2.1.296); recheck after CLI upgrades with the Haiku security probe.
