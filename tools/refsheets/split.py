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

text = open(sys.argv[1]).read()
work = sys.argv[2]
sections = re.split(r"\n## ", text)
pre = next(s for s in sections if s.startswith("Shared preamble")).split("\n", 1)[1].strip()
for s in sections:
    m = re.search(r"`([a-z0-9_]+)`\s*$", s.splitlines()[0])
    if not m:
        continue
    d = os.path.join(work, m.group(1))
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "PROMPT.md"), "w") as f:
        f.write(pre + "\n\n## " + s.strip() + "\n\n" + CHECK + "\n")
    print(d)
