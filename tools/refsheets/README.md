# Reference sheets through Codex

Andrew asked on 23 Oct for multi-angle reference images before anything is modelled. These two scripts draw them with the Codex image engine (`tools/refsheets/draw.sh` defaults to `gpt-6.2-astra` per [AGENTS.md](../../AGENTS.md) rule 11) and run as many units in parallel as you name.

1. Write a `PROMPTS.md` with a `## Shared preamble` section and one `## <Title>, \`<unit>\`` section per unit (`split.py` requires backticks around `<unit>`). Each unit section names the exact image files to write. The historical rogue prompts (`docs/art/reference/rogues/PROMPTS.md`, in git history) are the worked example: turnaround (front, side, back, three-quarter, top with a 1.84 m scale ball and metre callouts) plus a details sheet.
2. Run `python3 tools/refsheets/split.py <PROMPTS.md> <scratch>/w<N>/<set>` (outside the repo, e.g. `~/scratch/w<N>/<set>`) to write one `PROMPT.md` per unit.
3. Run `tools/refsheets/draw.sh <scratch>/w<N>/<set> <unit> [<unit> ...] -- <approved board> [<style master> ...]` in the background. The rogue set took about 12 minutes for three units, and each unit self-checks and writes `REVIEW.md`.
4. Look at every sheet yourself against the boards and ART-MISTAKES before you use it. Copy the keepers into `docs/art/reference/<set>/<unit>/` as JPEG (`magick in.png -quality 84 out.jpg`), with the unit's `REVIEW.md`.

Before a big batch, probe the login with `codex exec -m gpt-6.2-astra "Reply OK"`. Check Codex CLI auth/quota before launching a batch.

## Keep every view at one scale

Sheets drawn without a per-view scale reference drift: in the first 16-unit batch (23 Oct), every unit's REVIEW.md reported views at different scales. So every preamble now carries this rule:

- Draw the 1.84 m player ball (a see-through Hoberman-lattice sphere) standing on the ground line in **every** view, not only the front.
- Say "same scale as the front view" for each view: the ball is the same size in every panel, and the body keeps its height against it.
- Ask for true orthographic front, side, back and top cameras, with the top looking straight down.

Describe parts as plain machine parts (clamp arm, discharge chute, magnet coil, forward tube). Weapon words got two details sheets refused by the image filter (mag trapper, cannon pilot).
