#!/usr/bin/env python3
"""Paper check for the DRAFT-ASSETS staged card drafts and rationale."""
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
    "TH-03": "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md",
    "TH-05": "docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md",
    "TH-06": "docs/tech/sections/TH-06-encounters-waves-and-enemies.md",
    "TH-13": "docs/tech/sections/TH-13-chaos-outcomes.md",
    "TH-15": "docs/tech/sections/TH-15-physics-query-contract.md",
    "TH-16": "docs/tech/sections/TH-16-rendering-integration.md",
    "TH-19": "docs/tech/sections/TH-19-asset-import-export.md",
}
ROW = r"[A-Z]{2,3}-\d+[a-z]?"
SEP = r"(?:,\s+and\s+|,\s+|\s+and\s+|\s+to\s+)"
SECTION_KEYS = r"(?!(?:NQ-\d|ART-\d|SND-\d|PD-0[13]|TH-(?:02|03|05|06|13|15|16|19))\b)"
GROUP = re.compile(
    r"\b(" + "|".join(re.escape(k) for k in SECTIONS) + r")\s+(" + ROW + r"(?:" + SEP + SECTION_KEYS + ROW + r")*)"
)
ROW_TOKEN = re.compile(r"\b" + ROW + r"\b")
CARD_HEADING = re.compile(r"^###\s+([A-Z][A-Z0-9]*-[A-Z0-9]+[a-z]?):\s")
ANCHOR = re.compile(r'^<a id="([^"]+)"></a>$')
QID = re.compile(r"\bQ-[EP]\d+\b")
DRAFT_CARD = re.compile(r"\b(?:NQ|ART|SND)-\d+\b")
LINK = re.compile(r"\[([^\]]+)\]\(#([^)]+)\)")


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
        cards.append(
            {"id": match.group(1), "line": index + 1, "anchor": anchor, "body": "\n".join(body_lines)}
        )
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


def bare_numbers(body):
    masked = body
    masked = blank(masked, r"`[^`\n]*`")
    masked = blank(masked, r"\]\([^)]*\)")
    masked = blank(masked, r"^\d+\.\s", re.M)
    masked = blank(masked, r"\*\*Card revision:\*\*\s*\d+")
    masked = blank(masked, r"\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+[a-z]?\b")
    masked = blank(masked, r"\b[A-Z]+\d+[a-z]?\b")
    masked = blank(masked, r"\blines?\s+\d+(?:" + SEP + r"\d+)*")
    masked = blank(masked, r"\bitems?\s+\d+(?:" + SEP + r"\d+)*")
    masked = blank(masked, r"§\s*\d+(?:\.\d+)*\.?")
    masked = blank(masked, r"\bContext7\b")
    masked = blank(masked, r"\bSeam \d+\b")
    found = []
    for match in re.finditer(r"\d+(?:\.\d+)*", masked):
        after = body[match.end() : match.end() + 40]
        paren = after.find("(")
        tied = False
        if paren >= 0:
            close = body.find(")", match.end() + paren)
            group = body[match.end() + paren : close + 1] if close >= 0 else ""
            tied = bool(re.search(r"\blines?\s+\d+", group))
        if not tied:
            found.append(match.group(0))
    return found


def check(root, cards_path, rationale_path):
    failures = []
    counts = {"cards": 0, "fields": 0, "row_citations": 0, "question_ids": 0, "dependency_links": 0}
    rows = section_rows(root)
    anchors, headings = backlog_ids(root)
    text = cards_path.read_text(encoding="utf-8")
    cards = parse_cards(text)
    draft_ids = {c["id"] for c in cards}
    draft_anchors = {c["anchor"] for c in cards if c["anchor"]}
    known_ids = headings | draft_ids
    derived_block, derived_shape = {}, {}
    drafting = set(re.findall(r"^\| (DQ-\d+) \|", rationale_path.read_text(encoding="utf-8"), flags=re.M))
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
        for label, target in LINK.findall(deps):
            counts["dependency_links"] += 1
            if target not in anchors and target not in draft_anchors:
                failures.append(("dependency", cid, "dependency #%s exists in neither BACKLOG nor the draft" % target))
            if label.lower() != target:
                failures.append(("dependency", cid, "link text %s does not match #%s" % (label, target)))
        if not LINK.findall(deps) and "None" not in deps:
            failures.append(("dependency", cid, "Dependencies field names neither a card nor None"))
        blocking = field_segment(body, "Blocking questions", ["Registered non-blocking questions"])
        shaping = field_segment(body, "Registered non-blocking questions", [])
        for segment, bucket in ((blocking, derived_block), (shaping, derived_shape)):
            for label, target in LINK.findall(segment):
                if not label.startswith("Q-"):
                    failures.append(("question", cid, "question field links non-question %s" % label))
                    continue
                bucket.setdefault(label, set()).add(cid)
        overlap = {l for l, _ in LINK.findall(blocking)} & {l for l, _ in LINK.findall(shaping)}
        if overlap:
            failures.append(("question", cid, "question both blocking and non-blocking: %s" % sorted(overlap)))
        for qid in QID.findall(body):
            counts["question_ids"] += 1
            if qid not in headings:
                failures.append(("question", cid, "%s is not a BACKLOG question" % qid))
        for other in set(re.findall(r"\b(?:NQ|ART|SND|TH|SC|PD|HF)-\d+[a-z]?\b", body)):
            if other not in known_ids:
                failures.append(("card-id", cid, "%s exists in neither BACKLOG nor the draft" % other))
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
            prefix = body[max(0, token.start() - 1) : token.start()]
            if prefix == "`":
                continue
            failures.append(("row", cid, "unscoped row ID %s" % value))
        for number in bare_numbers(body):
            failures.append(("number", cid, "bare number %s not tied to a source line" % number))
    rationale = rationale_path.read_text(encoding="utf-8")
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
            failures.append(("register", qid, "Blocks column %s differs from cards %s" % (sorted(register[qid][0]), sorted(derived_block.get(qid, set())))))
        if register[qid][1] != derived_shape.get(qid, set()):
            failures.append(("register", qid, "Shapes column %s differs from cards %s" % (sorted(register[qid][1]), sorted(derived_shape.get(qid, set())))))
    for qid in register:
        if qid not in derived_block and qid not in derived_shape:
            failures.append(("register", qid, "register lists a question no card cites in a question field"))
    order = rationale.split("## Gating question register")[0]
    for cid in sorted(draft_ids):
        if not re.search(r"\b" + re.escape(cid) + r"\b", order):
            failures.append(("order", cid, "card absent from the dependency map"))
    return failures, counts, derived_block, derived_shape


def mutate(src_cards, src_rat, dest, name):
    cards = src_cards.read_text(encoding="utf-8")
    rat = src_rat.read_text(encoding="utf-8")

    def once(text, old, new):
        if old not in text:
            raise SystemExit("negative control %s: pattern not found: %r" % (name, old))
        return text.replace(old, new, 1)

    if name == "missing-field":
        cards = once(cards, "**Boundary:** No change to `.gitignore`", "No change to `.gitignore`")
    elif name == "size-L":
        cards = once(cards, "**Owner:** Tooling · **Size:** M", "**Owner:** Tooling · **Size:** L")
    elif name == "absent-row":
        cards = once(cards, "PD-01 AC-01, AC-02, AC-05", "PD-01 AC-99, AC-02, AC-05")
    elif name == "absent-question":
        cards = once(cards, "**Blocking questions:** [Q-P32](#q-p32) (camera distance", "**Blocking questions:** [Q-P99](#q-p99) (camera distance")
    elif name == "absent-dependency":
        cards = once(cards, "**Dependencies:** [ART-03](#art-03). **Blocking questions:** [Q-P32]", "**Dependencies:** [ART-03](#art-03), [ART-99](#art-99). **Blocking questions:** [Q-P32]")
    elif name == "bare-number":
        cards = once(cards, "3. A list of parts proposed as moving or stable", "3. Keep the mesh under 5000 triangles. A list of parts proposed as moving or stable")
    elif name == "missing-anchor":
        cards = once(cards, '<a id="art-04"></a>\n', "")
    elif name == "unscoped-row":
        cards = once(cards, "No production asset, no integration", "No production asset (RR-05), no integration")
    elif name == "duplicate-register-row":
        match = re.search(r"^\| \[Q-P32\]\(#q-p32\) \|.*$", rat, flags=re.M)
        if not match:
            raise SystemExit("negative control %s: register row not found" % name)
        rat = rat.replace(match.group(0), match.group(0) + "\n" + match.group(0), 1)
    else:
        raise SystemExit("unknown control " + name)
    out_cards = dest / "cards.md"
    out_rat = dest / "rationale.md"
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
    "missing-anchor": "anchor",
    "unscoped-row": "row",
    "duplicate-register-row": "register",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--cards", required=True)
    parser.add_argument("--rationale", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--emit-register", action="store_true")
    args = parser.parse_args()
    root, out = Path(args.root), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    cards_path, rat_path = Path(args.cards), Path(args.rationale)
    failures, counts, block, shape = check(root, cards_path, rat_path)
    if args.emit_register:
        for qid in sorted(set(block) | set(shape), key=lambda q: (q[2], int(q[3:]))):
            print("%s\tblocks=%s\tshapes=%s" % (qid, ", ".join(sorted(block.get(qid, []), key=lambda c: (c.split("-")[0], int(c.split("-")[1])))), ", ".join(sorted(shape.get(qid, []), key=lambda c: (c.split("-")[0], int(c.split("-")[1]))))))
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
        c_fail, _, _, _ = check(root, c_path, r_path)
        caught = [f for f in c_fail if f[0] == rule and f not in failures]
        detected = bool(caught)
        report["controls"][name] = {"expected_rule": rule, "detected": detected, "failures": [list(f) for f in c_fail]}
        print("control %s: %s (%s)" % (name, "detected" if detected else "MISSED", caught[0][2] if caught else "no %s failure" % rule))
        ok = ok and detected
    shutil.rmtree(work)
    (out / "check-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("result: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
