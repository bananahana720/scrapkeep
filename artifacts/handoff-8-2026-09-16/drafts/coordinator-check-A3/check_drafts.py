#!/usr/bin/env python3
"""Paper check for the DRAFT-ASSETS staged card drafts and rationale (attempt A3)."""
import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

FIELDS = [
    "Card revision",
    "Owner",
    "Size",
    "Lane",
    "Source and inputs",
    "Dependencies",
    "Blocking questions",
    "Files touched",
    "Definition of done",
    "Verification and evidence",
    "Boundary",
]
SECTIONS = {
    "PD-01": "docs/product/sections/PD-01-art-acceptance.md",
    "PD-03": "docs/product/sections/PD-03-sound-feel-events.md",
    "TH-02": "docs/tech/sections/TH-02-movement-camera-and-active-aim.md",
    "TH-04": "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md",
    "TH-03": "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md",
    "TH-05": "docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md",
    "TH-06": "docs/tech/sections/TH-06-encounters-waves-and-enemies.md",
    "TH-13": "docs/tech/sections/TH-13-chaos-outcomes.md",
    "TH-15": "docs/tech/sections/TH-15-physics-query-contract.md",
    "TH-16": "docs/tech/sections/TH-16-rendering-integration.md",
    "TH-19": "docs/tech/sections/TH-19-asset-import-export.md",
}
NATIVE_GATE = "Q-E01 native slice and Andrew's production authorization"
CONCEPT_GATE = "EV-0423 decision 1"
ROW = r"[A-Z]{2,3}-\d+[a-z]?"
SEP = r"(?:,\s+and\s+|,\s+|\s+and\s+|\s+to\s+)"
NOT_KEY = r"(?!(?:NQ-\d|ART-\d|SND-\d|PD-0[13]|TH-(?:02|03|04|05|06|13|15|16|19))\b)"
GROUP = re.compile(
    r"\b(" + "|".join(re.escape(k) for k in SECTIONS) + r")\s+(" + ROW + r"(?:" + SEP + NOT_KEY + ROW + r")*)"
)
ROW_TOKEN = re.compile(r"\b" + ROW + r"\b")
CARD_HEADING = re.compile(r"^###\s+([A-Z][A-Z0-9]*-[A-Z0-9]+[a-z]?):\s")
PROPOSED_Q = re.compile(r"^###\s+(Q-[EP]\d+) \(proposed\):", re.M)
ANCHOR = re.compile(r'^<a id="([^"]+)"></a>$')
QID = re.compile(r"\bQ-[EP]\d+\b")
DRAFT_CARD = re.compile(r"\b(?:NQ|ART|SND)-\d+\b")
LINK = re.compile(r"\[([^\]]+)\]\(#([^)]+)\)")
PATH_TOKEN = re.compile(r"`([^`\s]*/[^`\s]*)`")


def write_paths(files):
    return [p for p in PATH_TOKEN.findall(files) if not p.startswith("artifacts/local/tasks/")]


def paths_overlap(a, b):
    left = [c for c in a.split("/") if c not in ("", "**")]
    right = [c for c in b.split("/") if c not in ("", "**")]
    for x, y in zip(left, right):
        if x == y or "*" in x or "*" in y or x.startswith("<") or y.startswith("<"):
            continue
        return False
    return True


def section_rows(root):
    rows = {}
    for key, rel in SECTIONS.items():
        text = (root / rel).read_text(encoding="utf-8")
        rows[key] = set(re.findall(r"^\| (" + ROW + r") \|", text, flags=re.M)) | set(
            re.findall(r"^\| ([A-Z]{2}-\d) \|", text, flags=re.M)
        )
    return rows


def backlog_ids(root):
    text = (root / "BACKLOG.md").read_text(encoding="utf-8")
    anchors = set(re.findall(r'<a id="([^"]+)"></a>', text))
    headings = set(re.findall(r"^###\s+([A-Z][A-Z0-9]*-[A-Z0-9]+[a-z]?):", text, flags=re.M))
    return anchors, headings


def parse_cards(text):
    lines = text.split("\n")
    cards = []
    for index, line in enumerate(lines):
        match = CARD_HEADING.match(line)
        if not match:
            continue
        prev = index - 1
        while prev >= 0 and not lines[prev].strip():
            prev -= 1
        anchor = ANCHOR.match(lines[prev]).group(1) if prev >= 0 and ANCHOR.match(lines[prev]) else None
        end = index + 1
        while end < len(lines) and not re.match(r"^(##\s|###\s)", lines[end]):
            end += 1
        body_lines = lines[index + 1 : end]
        while body_lines and (not body_lines[-1].strip() or ANCHOR.match(body_lines[-1].strip())):
            body_lines.pop()
        cards.append({"id": match.group(1), "line": index + 1, "anchor": anchor, "body": "\n".join(body_lines)})
    return cards


def field_segment(body, field, following):
    start = body.find("**" + field + ":**")
    if start < 0:
        return ""
    start += len(field) + 5
    ends = [body.find("**" + f + ":**", start) for f in following]
    ends = [e for e in ends if e >= 0]
    newline = body.find("\n", start)
    if newline >= 0:
        ends.append(newline)
    return body[start : min(ends)] if ends else body[start:]


def blank(text, pattern, flags=0):
    return re.sub(pattern, lambda m: " " * len(m.group(0)), text, flags=flags)


def resolve_tie(root, receipts, group, number):
    """A number is tied only when the parenthesis directly after it cites a file line containing it."""
    cite = re.search(r"`?([A-Za-z0-9_.\-/]+\.(?:txt|md))`?\s+line\s+(\d+)", group)
    if not cite:
        return False
    name, line = cite.group(1), int(cite.group(2))
    for base in (receipts, root):
        path = base / name
        if path.is_file():
            content = path.read_text(encoding="utf-8").split("\n")
            return 0 < line <= len(content) and number in content[line - 1]
    return False


def bare_numbers(root, receipts, body):
    masked = body
    masked = blank(masked, r"`[^`\n]*`")
    masked = blank(masked, r"\]\([^)]*\)")
    masked = blank(masked, r"^\d+\.\s", re.M)
    masked = blank(masked, r"\*\*Card revision:\*\*\s*\d+")
    masked = blank(masked, r"\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+[a-z]?\b")
    masked = blank(masked, r"\b[A-Z]+\d+[a-z]?\b")
    masked = blank(masked, r"\blines?\s+\d+(?:" + SEP + r"\d+)*")
    masked = blank(masked, r"\bitems?\s+\d+(?:" + SEP + r"\d+)*")
    masked = blank(masked, r"\bdecisions?\s+\d+(?:" + SEP + r"\d+)*")
    masked = blank(masked, r"§\s*\d+(?:\.\d+)*\.?")
    masked = blank(masked, r"\bContext7\b")
    masked = blank(masked, r"\bSeam \d+\b")
    masked = blank(masked, r"\bexits? [01]\b")
    found = []
    for match in re.finditer(r"\d+(?:\.\d+)*", masked):
        after = body[match.end() : match.end() + 2]
        tied = False
        if "(" in after:
            open_at = body.index("(", match.end())
            close = body.find(")", open_at)
            tied = close > 0 and resolve_tie(root, receipts, body[open_at : close + 1], match.group(0))
        if not tied:
            found.append(match.group(0))
    return found


def rationale_order(rationale):
    """Position of each subject card: the index of the first map row whose card cell names it."""
    order = {}
    head = rationale.split("## Gating question register")[0]
    for index, line in enumerate(head.split("\n")):
        match = re.match(r"^\| (\d+[a-z]?) \| ([^|]*) \|", line)
        if not match:
            continue
        for cid in DRAFT_CARD.findall(match.group(2)):
            order.setdefault(cid, index)
    return order, head


def check(root, cards_path, rationale_path, receipts):
    failures = []
    counts = {"cards": 0, "fields": 0, "row_citations": 0, "question_ids": 0, "dependency_links": 0, "body_references": 0}
    rows = section_rows(root)
    anchors, headings = backlog_ids(root)
    text = cards_path.read_text(encoding="utf-8")
    rationale = rationale_path.read_text(encoding="utf-8")
    cards = parse_cards(text)
    proposed = set(PROPOSED_Q.findall(text))
    proposed_anchors = {q.lower() for q in proposed}
    draft_ids = {c["id"] for c in cards}
    draft_anchors = {c["anchor"] for c in cards if c["anchor"]}
    known_ids = headings | draft_ids
    drafting = set(re.findall(r"^\| (DQ-\d+) \|", rationale, flags=re.M))
    derived_block, derived_shape, deps_of, writes_of = {}, {}, {}, {}
    if not cards:
        failures.append(("cards", "none", "no card headings parsed"))
    for card in cards:
        cid, body = card["id"], card["body"]
        counts["cards"] += 1
        if card["anchor"] != cid.lower():
            failures.append(("anchor", cid, "preceding anchor %r, expected %r" % (card["anchor"], cid.lower())))
        for field in FIELDS:
            if "**" + field + ":**" in body:
                counts["fields"] += 1
            else:
                failures.append(("field", cid, "missing **%s:**" % field))
        size = re.search(r"\*\*Size:\*\*\s*([A-Z]+)", body)
        if not size or size.group(1) not in ("S", "M"):
            failures.append(("size", cid, "size %s is not S or M" % (size.group(1) if size else None)))
        deps = field_segment(body, "Dependencies", ["Blocking questions"])
        deps_of[cid] = set()
        for label, target in LINK.findall(deps):
            counts["dependency_links"] += 1
            if target not in anchors and target not in draft_anchors:
                failures.append(("dependency", cid, "dependency #%s exists in neither BACKLOG nor the draft" % target))
            if label.lower() != target:
                failures.append(("link-text", cid, "link text %s does not match #%s" % (label, target)))
            deps_of[cid].add(label)
        if not LINK.findall(deps) and "None" not in deps:
            failures.append(("dependency", cid, "Dependencies field names neither a card nor None"))
        blocking = field_segment(body, "Blocking questions", ["Registered non-blocking questions"])
        shaping = field_segment(body, "Registered non-blocking questions", [])
        for segment, bucket in ((blocking, derived_block), (shaping, derived_shape)):
            for label, target in LINK.findall(segment):
                if not label.startswith("Q-"):
                    failures.append(("question", cid, "question field links non-question %s" % label))
                    continue
                if target not in anchors and target not in proposed_anchors:
                    failures.append(("question", cid, "question anchor #%s is not defined" % target))
                if label.lower() != target:
                    failures.append(("link-text", cid, "link text %s does not match #%s" % (label, target)))
                bucket.setdefault(label, set()).add(cid)
        overlap = {l for l, _ in LINK.findall(blocking)} & {l for l, _ in LINK.findall(shaping)}
        if overlap:
            failures.append(("overlap", cid, "question both blocking and non-blocking: %s" % sorted(overlap)))
        for qid in QID.findall(body):
            counts["question_ids"] += 1
            if qid not in headings and qid not in proposed:
                failures.append(("question", cid, "%s is neither a BACKLOG question nor a proposed entry" % qid))
        for other in set(re.findall(r"\b(?:NQ|ART|SND|TH|SC|PD|HF|FR)-\d+[a-z]?\b", body)):
            if other not in known_ids:
                failures.append(("card-id", cid, "%s exists in neither BACKLOG nor the draft" % other))
        lane = re.search(r"\*\*Lane:\*\*\s*([^\n]*)", body)
        lane = lane.group(1) if lane else ""
        blocking_q = {l for l, _ in LINK.findall(blocking)}
        if "native stage" in lane and (NATIVE_GATE not in blocking or "Q-E01" not in blocking_q):
            failures.append(("gate", cid, "native-stage card lacks Q-E01 and the named authorization gate"))
        if "concept stage" in lane and CONCEPT_GATE not in blocking:
            failures.append(("gate", cid, "concept-stage card lacks the EV-0423 decision 1 gate"))
        if "stage" not in lane and cid.startswith(("ART", "SND")):
            failures.append(("gate", cid, "production card names no concept or native stage"))
        files = field_segment(body, "Files touched", [])
        writes = write_paths(files)
        writes_of[cid] = writes
        if cid.startswith("ART") and any(p.startswith("source-assets/") for p in writes):
            if "native stage" in lane and "Q-P26" not in blocking_q:
                failures.append(("q-p26", cid, "native-stage card writes source-assets but Q-P26 is not blocking"))
            if "concept stage" in lane and "EV-0447 decision 1" not in blocking:
                failures.append(("q-p26", cid, "concept-stage blockout writes source-assets without the EV-0447 decision 1 list and locations"))
        if any(p.startswith("native/") for p in writes) and "native" not in lane:
            failures.append(("lane-files", cid, "writes native paths but its Lane is not a native lane"))
        if "concept stage" in lane and any("<" in p for p in writes):
            failures.append(("placeholder", cid, "concept-stage card offered for the next sprint leases a placeholder path"))
        covered = []
        for group in GROUP.finditer(body):
            section = group.group(1)
            for row in ROW_TOKEN.findall(group.group(2)):
                counts["row_citations"] += 1
                if row not in rows[section]:
                    failures.append(("row", cid, "%s %s is not a row of %s" % (section, row, SECTIONS[section])))
            covered.append((group.start(2), group.end(2)))
        for token in ROW_TOKEN.finditer(body):
            if any(s <= token.start() < e for s, e in covered):
                continue
            value = token.group(0)
            if value in known_ids or value in SECTIONS or re.match(r"^(EV|AD)-\d+$", value):
                continue
            if value.startswith("DQ-"):
                if value not in drafting:
                    failures.append(("drafting", cid, "%s is not defined in the rationale" % value))
                continue
            if body[max(0, token.start() - 1) : token.start()] == "`":
                continue
            failures.append(("row", cid, "unscoped row ID %s" % value))
        for number in bare_numbers(root, receipts, body):
            failures.append(("number", cid, "bare number %s not tied to the source line it cites" % number))
    graph = {cid: {d for d in deps if d in draft_ids} for cid, deps in deps_of.items()}
    descendants = {cid: set() for cid in graph}
    for cid in graph:
        stack = [cid]
        while stack:
            node = stack.pop()
            for other, deps in graph.items():
                if node in deps and other not in descendants[cid]:
                    descendants[cid].add(other)
                    stack.append(other)
    state = {}

    def visit(node, trail):
        state[node] = "open"
        for dep in sorted(graph.get(node, ())):
            if state.get(dep) == "open":
                failures.append(("cycle", node, "dependency cycle through %s" % " -> ".join(trail + [dep])))
            elif dep not in state:
                visit(dep, trail + [dep])
        state[node] = "done"

    for node in sorted(graph):
        if node not in state:
            visit(node, [node])
    ids = sorted(graph)
    for i, first in enumerate(ids):
        for second in ids[i + 1 :]:
            if second in descendants[first] or first in descendants[second]:
                continue
            for a in writes_of.get(first, []):
                for b in writes_of.get(second, []):
                    if paths_overlap(a, b):
                        failures.append(("write-set", first, "write set %s overlaps %s of concurrently runnable %s" % (a, b, second)))
    counts["concurrent_pairs"] = sum(1 for i, f in enumerate(ids) for s in ids[i + 1 :] if s not in descendants[f] and f not in descendants[s])
    for card in cards:
        cid, body = card["id"], card["body"]
        deps_field_start = body.find("**Dependencies:**")
        deps_field_end = body.find("\n", deps_field_start)
        scan = body[:deps_field_start] + body[deps_field_end:] if deps_field_start >= 0 else body
        for match in DRAFT_CARD.finditer(scan):
            other = match.group(0)
            if other == cid or other not in draft_ids:
                continue
            counts["body_references"] += 1
            follow = scan[match.end() : match.end() + 8]
            if re.match(r"\s+(items?|source)\b", follow):
                continue
            if re.search(r"\b[Aa]s\s+$", scan[max(0, match.start() - 4) : match.start()]):
                continue
            if other in deps_of[cid] or other in descendants[cid]:
                continue
            failures.append(("body-dependency", cid, "body names %s, which is neither a dependency nor downstream" % other))
    register = {}
    for line in rationale.split("\n"):
        match = re.match(r"^\| \[(Q-[EP]\d+)\]\(#q-[ep]\d+\) \|(.*)$", line)
        if not match:
            continue
        cells = [c.strip() for c in match.group(2).split("|")]
        qid = match.group(1)
        if qid in register:
            failures.append(("register", qid, "question listed more than once"))
        register[qid] = (
            set(DRAFT_CARD.findall(cells[1])) if len(cells) > 1 else set(),
            set(DRAFT_CARD.findall(cells[2])) if len(cells) > 2 else set(),
        )
    for qid in sorted(set(derived_block) | set(derived_shape)):
        if qid not in register:
            failures.append(("register", qid, "gating question missing from the rationale register"))
            continue
        if register[qid][0] != derived_block.get(qid, set()):
            failures.append(("register-column", qid, "Blocks column %s differs from cards %s" % (sorted(register[qid][0]), sorted(derived_block.get(qid, set())))))
        if register[qid][1] != derived_shape.get(qid, set()):
            failures.append(("register-column", qid, "Shapes column %s differs from cards %s" % (sorted(register[qid][1]), sorted(derived_shape.get(qid, set())))))
    for qid in register:
        if qid not in derived_block and qid not in derived_shape:
            failures.append(("register", qid, "register lists a question no card cites in a question field"))
    order, head = rationale_order(rationale)
    for cid in sorted(draft_ids):
        if cid not in order:
            failures.append(("order", cid, "card is not the subject of a dependency-map row"))
            continue
        for dep in sorted(graph.get(cid, ())):
            if dep in order and order[dep] >= order[cid]:
                failures.append(("order", cid, "%s depends on %s, which the map places at or after it" % (cid, dep)))
    return failures, counts, derived_block, derived_shape


def once(text, old, new, name):
    if old not in text:
        raise SystemExit("negative control %s: pattern not found: %r" % (name, old))
    return text.replace(old, new, 1)


def mutate(src_cards, src_rat, dest, name):
    cards = src_cards.read_text(encoding="utf-8")
    rat = src_rat.read_text(encoding="utf-8")
    if name == "missing-field":
        cards = once(cards, "**Boundary:** No change to export presets", "No change to export presets", name)
    elif name == "size-L":
        cards = once(cards, "**Owner:** Tooling with Verification · **Size:** M", "**Owner:** Tooling with Verification · **Size:** L", name)
    elif name == "absent-row":
        cards = once(cards, "PD-01 AC-01, AC-02, AC-05", "PD-01 AC-99, AC-02, AC-05", name)
    elif name == "absent-question":
        cards = once(cards, "**Blocking questions:** [Q-P25](#q-p25). Gate", "**Blocking questions:** [Q-P99](#q-p99). Gate", name)
    elif name == "absent-dependency":
        cards = once(cards, "**Dependencies:** [ART-03](#art-03). **Blocking questions:** None.", "**Dependencies:** [ART-03](#art-03), [ART-99](#art-99). **Blocking questions:** None.", name)
    elif name == "bare-number":
        cards = once(cards, "3. A list of parts proposed as moving or stable", "3. Keep the mesh under 5000 triangles. A list of parts proposed as moving or stable", name)
    elif name == "number-near-unrelated-citation":
        cards = once(cards, "3. A list of parts proposed as moving or stable", "3. Keep the mesh under 5000 triangles (BIBLE.md line 719). A list of parts proposed as moving or stable", name)
    elif name == "missing-anchor":
        cards = once(cards, '<a id="art-04"></a>\n', "", name)
    elif name == "unscoped-row":
        cards = once(cards, "No production asset is admitted, and no candidate", "No production asset is admitted (RR-05), and no candidate", name)
    elif name == "duplicate-register-row":
        match = re.search(r"^\| \[Q-P32\]\(#q-p32\) \|.*$", rat, flags=re.M)
        rat = rat.replace(match.group(0), match.group(0) + "\n" + match.group(0), 1)
    elif name == "register-column-mismatch":
        match = re.search(r"^\| \[Q-P31\]\(#q-p31\) \|.*$", rat, flags=re.M)
        rat = rat.replace(match.group(0), match.group(0).replace("SND-01, ", "", 1), 1)
    elif name == "order":
        rat = once(rat, "| 18 | ART-14 ", "| 07 | ART-14 ", name)
        lines = rat.split("\n")
        idx = next(i for i, l in enumerate(lines) if l.startswith("| 07 | ART-14 "))
        row = lines.pop(idx)
        target = next(i for i, l in enumerate(lines) if l.startswith("| 1 | ART-01 "))
        lines.insert(target, row)
        rat = "\n".join(lines)
    elif name == "card-id":
        cards = once(cards, "No rig, clip, runtime input or import. No species", "No rig, clip, runtime input or import, which ART-98 owns. No species", name)
    elif name == "undefined-dq":
        cards = once(cards, "(sheets, prompt records, paintovers, captions and provenance records; DQ-01)", "(sheets, prompt records, paintovers, captions and provenance records; DQ-99)", name)
    elif name == "link-text-mismatch":
        cards = once(cards, "**Dependencies:** [ART-03](#art-03). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32) (the native", "**Dependencies:** [ART-03](#art-02). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32) (the native", name)
    elif name == "blocking-overlap":
        cards = once(cards, "**Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P10](#q-p10), [Q-P22](#q-p22).", "**Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P10](#q-p10), [Q-P22](#q-p22), [Q-P27](#q-p27).", name)
    elif name == "body-dependency":
        cards = once(cards, "**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04), [ART-06](#art-06).", "**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04).", name)
    elif name == "cycle":
        cards = once(cards, "**Dependencies:** [ART-03](#art-03), [ART-04](#art-04), [ART-05](#art-05). **Blocking questions:** [Q-E01]", "**Dependencies:** [ART-03](#art-03), [ART-04](#art-04), [ART-05](#art-05), [ART-09](#art-09). **Blocking questions:** [Q-E01]", name)
    elif name == "missing-native-gate":
        cards = once(cards, "**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).", "**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27).", name)
    elif name == "q-p26-not-blocking":
        cards = once(cards, "**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27).", "**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P27](#q-p27).", name)
    elif name == "concept-blockout-without-list":
        cards = once(cards, "**Blocking questions:** [Q-P23](#q-p23). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1;", "**Blocking questions:** [Q-P23](#q-p23). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1;", name)
    elif name == "lane-mismatch":
        cards = once(cards, "**Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage\n\n**Source and inputs:**\n\n- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01 to OC-05", "**Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage\n\n**Source and inputs:**\n\n- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01 to OC-05", name)
    elif name == "write-set-overlap":
        cards = once(cards, "`source-assets/fuse/audio/ultimate/**`", "`source-assets/fuse/audio/field_miscast/**`", name)
    elif name == "placeholder-path":
        cards = once(cards, "**Files touched:** `docs/art/production/iron_orchard_enemies/**` (DQ-01)", "**Files touched:** `docs/art/production/<enemy_unit>/**` (DQ-01)", name)
    else:
        raise SystemExit("unknown control " + name)
    out_cards, out_rat = dest / "cards.md", dest / "rationale.md"
    out_cards.write_text(cards, encoding="utf-8")
    out_rat.write_text(rat, encoding="utf-8")
    return out_cards, out_rat


CONTROLS = {
    "missing-field": "field",
    "size-L": "size",
    "absent-row": "row",
    "absent-question": "question",
    "absent-dependency": "dependency",
    "bare-number": "number",
    "number-near-unrelated-citation": "number",
    "missing-anchor": "anchor",
    "unscoped-row": "row",
    "duplicate-register-row": "register",
    "register-column-mismatch": "register-column",
    "order": "order",
    "card-id": "card-id",
    "undefined-dq": "drafting",
    "link-text-mismatch": "link-text",
    "blocking-overlap": "overlap",
    "body-dependency": "body-dependency",
    "cycle": "cycle",
    "missing-native-gate": "gate",
    "q-p26-not-blocking": "q-p26",
    "concept-blockout-without-list": "q-p26",
    "lane-mismatch": "lane-files",
    "write-set-overlap": "write-set",
    "placeholder-path": "placeholder",
}


def sort_card(c):
    prefix, number = c.split("-")
    return (prefix, int(number))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--cards", required=True)
    parser.add_argument("--rationale", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--receipts", default="artifacts/handoff-8-2026-09-16/drafts/ctx7")
    parser.add_argument("--emit-register", action="store_true")
    args = parser.parse_args()
    root, out = Path(args.root), Path(args.out)
    receipts = Path(args.receipts) if Path(args.receipts).is_absolute() else root / args.receipts
    out.mkdir(parents=True, exist_ok=True)
    cards_path, rat_path = Path(args.cards), Path(args.rationale)
    failures, counts, block, shape = check(root, cards_path, rat_path, receipts)
    if args.emit_register:
        for qid in sorted(set(block) | set(shape), key=lambda q: (q[2], int(q[3:]))):
            print("%s\tblocks=%s\tshapes=%s" % (qid, ", ".join(sorted(block.get(qid, []), key=sort_card)), ", ".join(sorted(shape.get(qid, []), key=sort_card))))
        return 0
    report = {"positive": {"counts": counts, "failures": [list(f) for f in failures]}, "controls": {}}
    ok = not failures
    for f in failures:
        print("POSITIVE FAIL [%s] %s: %s" % f)
    print("positive: %s %s" % ("PASS" if not failures else "FAIL", json.dumps(counts)))
    work = Path(tempfile.mkdtemp(prefix="controls-", dir=out))
    for name, rule in CONTROLS.items():
        dest = work / name
        dest.mkdir()
        c_path, r_path = mutate(cards_path, rat_path, dest, name)
        c_fail, _, _, _ = check(root, c_path, r_path, receipts)
        caught = [f for f in c_fail if f[0] == rule and f not in failures]
        report["controls"][name] = {"expected_rule": rule, "detected": bool(caught), "failures": [list(f) for f in c_fail]}
        print("control %s: %s (%s)" % (name, "detected" if caught else "MISSED", caught[0][2] if caught else "no new %s failure" % rule))
        ok = ok and bool(caught)
    shutil.rmtree(work)
    (out / "check-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("result: %s (%d controls)" % ("PASS" if ok else "FAIL", len(CONTROLS)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
