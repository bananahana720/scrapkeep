# Art Reference Sheets with Gemini & Antigravity

The legacy Codex batch script `tools/refsheets/draw.sh` (updated to `gpt-6.2-astra` per `AGENTS.md` Rule 11) is superseded in Antigravity by `image-generator` and `gemini-api-cli`, while keeping the repository's prompt-splitting and scale discipline intact.

## Procedure

1. Author `<set>/PROMPTS.md` with `## Shared preamble` and one ``## <Title>, `<unit>` `` section per unit (`tools/refsheets/split.py` requires backticks around `<unit>` per `tools/refsheets/README.md`).
2. Split into per-unit `<work_dir>/<unit>/PROMPT.md` files with `python3 tools/refsheets/split.py <PROMPTS.md> <work_dir>`.
3. Generate turnaround and detail sheets using Antigravity's `image-generator` subagent (or `gemini-api-cli` image generation) in parallel, passing approved style boards as references.
4. Enforce the scale and filter rules from `tools/refsheets/README.md`:
   - Draw the 1.84 m player ball (see-through Hoberman-lattice sphere) on the ground line in **every** orthographic panel (front, side, back, three-quarter, top).
   - Specify "same scale as the front view" in every panel prompt so height stays locked to the ball.
   - Use plain machine-part words (`clamp arm`, `discharge chute`, `magnet coil`, `forward tube`) rather than weapon nouns that trigger image safety filters.
5. Open every generated sheet via `read_file` and compare against `project-guide/handoff/ART-MISTAKES.md` and `sketches/core-loop/design-v3/TONE-BIBLE.md` before promoting JPEG copies into `docs/art/reference/`.
