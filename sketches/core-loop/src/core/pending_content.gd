extends RefCounted

# Content a shipping zone still owes. The release gate (tests/release_gate_placeholder_test.gd)
# fails while any list here is non-empty and a default-table row still uses it.

# 2026-10-04 (wave 9): the Dig and Highdraft are greybox zones that get their side content and
# activity sites in wave 10 (the deep-Dig and Highdraft-crown map units remove them from this list).
# 2026-10-04 (wave 10): both landed their side content (deep-Dig and Highdraft-crown units).
const SIDE_CONTENT_PENDING: Array = []
