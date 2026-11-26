"""Split a PROMPTS.md into one PROMPT.md per unit for draw.sh.

python3 split.py <PROMPTS.md> <work dir>
PROMPTS.md has a "## Shared preamble" section and one "## <Title>, `<unit>`" section per
unit (see docs/art/reference/rogues/PROMPTS.md). Each unit's PROMPT.md is the preamble,
its own section and the closing self-check line.
"""
import os
import re
import sys

CHECK = ("Use your image generation tool for every image. Check each image against the spec "
         "(part list, colours, canon marks, dimensions) and regenerate a view that misses. Write "
         "a short REVIEW.md listing what you checked and any remaining deviation.")

if len(sys.argv) != 3:
    print("usage: python3 split.py <PROMPTS.md> <work dir>", file=sys.stderr)
    sys.exit(2)

with open(sys.argv[1], encoding="utf8") as fh:
    text = fh.read()
work = sys.argv[2]
sections = re.split(r"\n## ", text)
pre_section = next((s for s in sections if s.startswith("Shared preamble")), None)
if pre_section is None or "\n" not in pre_section:
    raise SystemExit("split.py: missing '## Shared preamble' section in " + sys.argv[1])
pre = pre_section.split("\n", 1)[1].strip()
count = 0
for s in sections:
    m = re.search(r"`([a-z0-9_]+)`\s*$", s.splitlines()[0])
    if not m:
        continue
    d = os.path.join(work, m.group(1))
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "PROMPT.md"), "w", encoding="utf8") as f:
        f.write(pre + "\n\n## " + s.strip() + "\n\n" + CHECK + "\n")
    print(d)
    count += 1
if count == 0:
    raise SystemExit("split.py: no '## <Title>, `<unit>`' sections found in " + sys.argv[1])
