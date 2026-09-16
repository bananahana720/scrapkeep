#!/usr/bin/env python3
"""Executable paper check for HF-08 (Specify save failure and conservative recovery).

Usage: python3 check_recovery.py <repository-root> --out <receipt-directory>

Disposable. Reads only; writes paper-check.json and source-manifest.json into --out.
It proves internal consistency of one documentation file against its cited sources at
one base, and replays a model of the recovery decision. It executes no engine code and
touches no save file.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/HF-08-save-recovery.md"
RECEIPT = "artifacts/foundation-sprint-2026-09/tasks/HF-08/ctx7-godot-fileaccess-os.txt"
DEPS = {
    "docs/tech/sections/HF-07a-save-envelope.md": "4c37b7b32197642e1a312758449b8ebede05d3a0788e92b74a6a9f95ed97c010",
    "docs/tech/sections/HF-07a-save-envelope.csv": "1c553120d0988bfbf3d5644946904fb603b3a3617091764ce170eb1cbb798b00",
    "docs/tech/sections/HF-07b-commit-boundaries.md": "b1b88c2922d56eb7d9f9b581f387e8eb6aeb148d12ff23f4de4c53ba5d929122",
    "docs/tech/sections/HF-03a-module-map.md": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
    RECEIPT: "2697c931d49c4375247467e00d4bfcc661de1e71c7d1a6ad24e6319615e7291a",
}

MARK = ("unqualified on paper; re-verify when S0-08 lands, and again when the "
        "TH-22 proof lands")
HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions",
            "Re-verification triggers", "Procedure performed", "Evidence limits"]
STATUSES = ["missing", "committed", "committed_stale_temp", "corrupt",
            "unsupported_newer", "ambiguous_lifecycle"]
MESSAGE_CLASSES = ["MC-RETRYABLE", "MC-INVALID", "MC-UNSUPPORTED", "MC-AMBIGUOUS",
                   "MC-PREFERENCE"]
STAGE_POINTS = ["SP0", "SP1", "SP2", "SP3a", "SP3b", "SP4"]
TRANSITIONS = ["A", "B", "C", "D", "S"]
MATRIX_POINTS = ["SP1", "SP2", "SP3a", "SP3b", "SP4"]
FORBIDDEN_TOKENS = ["mount_id", "retain_revision", "read_initial_snapshot"]
REJECTED_KEYS = ["durability_class", "commit_class", "write_reason", "interruption_kind",
                 "resume_mode", "mid_level", "checkpoint_generation", "checkpoint_timestamp",
                 "backup_pointer", "recovery_status", "migration_marker"]
TADR38 = ("Temporary files, a rename, a checksum or a backup alone do not prove "
          "power-loss durability.")

RESULTS = []


def check(name, ok, detail=""):
    RESULTS.append({"check": name, "ok": bool(ok), "detail": detail})
    return bool(ok)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        return fh.read()


def tables(text):
    """Return every markdown table as (header_cells, [row_cells...])."""
    out, rows = [], []
    for line in text.splitlines():
        if line.startswith("|") and line.rstrip().endswith("|"):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
        else:
            if len(rows) >= 3:
                out.append((rows[0], rows[2:]))
            rows = []
    if len(rows) >= 3:
        out.append((rows[0], rows[2:]))
    return out


def find_table(tbls, *header_tokens):
    for head, rows in tbls:
        joined = " ".join(head)
        if all(tok in joined for tok in header_tokens):
            return head, rows
    return None, []


def sentences(text):
    return re.split(r"(?<=[.!?])\s+|\n", text)


# --------------------------------------------------------------------------- checks
def run_document_checks(root, text, mutate=None):
    """mutate: name of a rule to disable, for the negative controls."""
    local = []

    def sub(name, ok, detail=""):
        local.append({"check": name, "ok": bool(ok), "detail": detail})
        return bool(ok)

    body = text
    if mutate == "marker":
        body = body.replace(MARK, "qualified", 3)

    tbls = tables(body)
    lines = body.splitlines()

    # 1. required headings, in order
    got = [l[3:].strip() for l in lines if l.startswith("## ")]
    sub("headings.required_in_order", got == HEADINGS, f"found {got}")

    # 2. the marker on every ordering stage, both OS rows and W4
    _, o_rows = find_table(tbls, "Step", "HF-07b stage", "Qualification")
    sub("dod1.ordering_steps_present",
        [r[0] for r in o_rows] == ["WO1", "WO2", "WO3", "WO4", "WO5", "WO6"],
        f"{[r[0] for r in o_rows]}")
    sub("dod1.marker_on_every_stage",
        all(MARK in r[-1] for r in o_rows) and len(o_rows) == 6,
        f"{sum(1 for r in o_rows if MARK in r[-1])}/6 stages carry the marker")

    _, os_rows = find_table(tbls, "OS family", "Qualification question", "Evidence method")
    sub("dod1.one_row_per_target_os_family", len(os_rows) == 2, f"{len(os_rows)} rows")
    sub("dod1.os_families_are_tadr001s",
        len(os_rows) == 2 and "Windows 11 x64" in os_rows[0][0] and "Linux x64" in os_rows[1][0],
        "; ".join(r[0] for r in os_rows))
    for r in os_rows:
        fam = re.sub(r"[*`]", "", r[0]).split("(")[0].strip()
        sub(f"dod1.os_row_complete[{fam}]",
            len(r) == 5 and all(len(c) > 40 for c in r[1:4]),
            "question/API/evidence cells nonempty")
        sub(f"dod1.os_row_marked[{fam}]", MARK in r[-1], "status cell carries the marker")
        sub(f"dod1.os_row_cites_receipt[{fam}]", "receipt lines" in r[2],
            "API surface cites the receipt by line")

    _, w_rows = find_table(tbls, "ID", "Rule", "Source", "Status")
    sub("dod1.single_writer_rules", [r[0] for r in w_rows] == ["W1", "W2", "W3", "W4", "W5"],
        f"{[r[0] for r in w_rows]}")
    w4 = [r for r in w_rows if r[0] == "W4"]
    sub("dod1.w4_marked", bool(w4) and MARK in w4[0][-1], "cross-process exclusion unqualified")

    # 3. never claim rename alone proves durability
    sub("dod1.tadr004_line38_verbatim", TADR38 in body, "quoted verbatim")
    claim = re.compile(r"(proves? durability|guarantee[sd]? durability|proven durable|"
                       r"durability is (guaranteed|established|proven)|rename proves|flush proves)", re.I)
    neg = re.compile(r"\b(not|never|no |cannot|refus|alone do not|does not|unqualified|nothing)\b", re.I)
    bad = [s for s in sentences(body) if claim.search(s) and not neg.search(s)]
    sub("dod1.no_positive_durability_claim", not bad, f"{len(bad)} unqualified claim(s): {bad[:2]}")

    # 4. failure class by transition stage
    _, f_rows = find_table(tbls, "Failure class", "Point", "Held state", "Message class")
    ids = [r[0] for r in f_rows]
    sub("dod2.failure_classes_complete",
        ids == [f"FC-{i:02d}" for i in range(1, 21)], f"{ids}")
    for r in f_rows:
        sub(f"dod2.row_complete[{r[0]}]", len(r) == 7 and all(c for c in r[3:7]),
            "held state, message class, permitted and forbidden all nonempty")
        found = [m for m in MESSAGE_CLASSES if m in r[4]]
        sub(f"dod2.message_class_closed[{r[0]}]",
            bool(found) or r[4].startswith("none"), r[4][:60])
        sub(f"dod2.stage_named[{r[0]}]",
            any(p in r[2] for p in STAGE_POINTS) or "any point" in r[2], r[2][:40])
    _, sp_rows = find_table(tbls, "Point", "HF-07b stage", "Where it sits")
    sub("dod2.stage_points_defined", [r[0] for r in sp_rows] == STAGE_POINTS,
        f"{[r[0] for r in sp_rows]}")

    # user-visible retry and recovery states
    _, u_rows = find_table(tbls, "State", "Entered from", "Owner of the visual form")
    names = [r[0] for r in u_rows]
    sub("dod2.user_visible_states",
        all(n in " ".join(names) for n in
            ["SAVING", "SAVE_HELD_RETRYABLE", "SAVE_HELD_BLOCKED", "RECOVERY_BLOCKED",
             "PREFERENCE_NOT_SAVED"]), f"{names}")

    # 5. preservation rules and the ambiguity checklist
    p_rows = next((rows for head, rows in tbls if head == ["ID", "Rule", "Source"]), [])
    _, ac_rows = find_table(tbls, "Condition", "Why continuity fails", "Resolution at this base")
    acs = [r[0] for r in ac_rows]
    expected_ac = [f"AC-{i}" for i in range(1, 9)]
    if mutate == "ac1":
        expected_ac = expected_ac  # document unchanged; the model control lives elsewhere
    sub("dod3.ambiguity_checklist_complete", acs == expected_ac, f"{acs}")
    for r in ac_rows:
        sub(f"dod3.ac_row_complete[{r[0]}]", len(r) == 5 and all(c for c in r[1:5]),
            "condition, reason, source and resolution nonempty")
    sub("dod3.preservation_rules", [r[0] for r in p_rows][:8] ==
        [f"P{i}" for i in range(1, 9)], f"{[r[0] for r in p_rows]}")
    p4 = next((r for r in p_rows if r[0] == "P4"), None)
    sub("dod3.no_rollback_rule",
        p4 is not None and "older living" in p4[1] and "TADR-004 line 40" in p4[2],
        p4[1][:80] if p4 else "P4 missing")
    p1 = next((r for r in p_rows if r[0] == "P1"), None)
    sub("dod3.preserve_corrupt_and_ambiguous",
        p1 is not None and "preserved byte-identical" in p1[1]
        and "corrupt" in p1[1] and "rejected" in p1[1],
        p1[1][:80] if p1 else "P1 missing")

    # 6. the interruption matrix, enumerated mechanically
    _, m_rows = find_table(tbls, "Transition (fact)", "Stage point", "Asserted outcome")
    expected = [f"IM-{t}{i}" for t in TRANSITIONS for i in range(1, 6)]
    got_ids = [r[0] for r in m_rows]
    sub("dod4.matrix_is_full_cross_product", got_ids == expected,
        f"{len(got_ids)} rows; expected {len(expected)}")
    for idx, r in enumerate(m_rows):
        want_point = MATRIX_POINTS[idx % 5]
        sub(f"dod4.row_names_a_stage[{r[0]}]", want_point in r[2], r[2][:30])
        sub(f"dod4.row_names_an_outcome[{r[0]}]", len(r[8]) > 20, r[8][:40])
        sub(f"dod4.row_names_a_held_state[{r[0]}]", bool(r[7].strip()), r[7][:40])
        sub(f"dod4.row_status_closed[{r[0]}]",
            any(s in r[6] for s in STATUSES), r[6][:40])
        sub(f"dod4.row_names_fixture_or_none[{r[0]}]", bool(r[9].strip()), r[9][:40])
    sub("dod4.covers_rewards_revival_terminal",
        all(any(r[0].startswith(f"IM-{t}") for r in m_rows) for t in ["B", "C", "D"]),
        "transitions B, C and D all present")

    # 7. every S0-08 proposed row disposed of
    _, s_rows = find_table(tbls, "S0-08 proposed row", "Disposition here")
    sub("s0_08.seven_proposed_rows_disposed", len(s_rows) == 7, f"{len(s_rows)} rows")

    # 8. field-name parity against the admitted HF-07a CSV
    csv_fields = set()
    for line in read(root, "docs/tech/sections/HF-07a-save-envelope.csv").splitlines()[1:]:
        csv_fields.add(line.split(",", 1)[0].strip())
    ticked = set(re.findall(r"`([A-Za-z_][A-Za-z0-9_.\[\]]*)`", body))
    named = {t for t in ticked
             if t.startswith(("run.", "profile.", "preferences."))
             or t in {"schema_version", "content_revision", "generation", "transaction_id"}}
    unknown = sorted(n for n in named if n not in csv_fields)
    sub("parity.every_named_field_in_hf07a_csv", not unknown, f"unknown: {unknown}")
    sub("parity.csv_field_count", len(csv_fields) == 70, f"{len(csv_fields)} fields")

    # 9. prohibitions, over the contract itself rather than the procedure prose that
    # names the tokens this check refuses
    contract = body.split("## Procedure performed")[0]
    for tok in FORBIDDEN_TOKENS:
        sub(f"prohibition.absent[{tok}]", tok not in contract, "")
    present = [k for k in REJECTED_KEYS if f"`{k}`" in contract]
    sub("prohibition.no_rejected_envelope_key", not present, f"{present}")
    adopts = re.compile(r"this section (adopts|selects|chooses) (P[1-4]|R[1-3])\b", re.I)
    sub("questions.no_adopted_candidate", not adopts.search(body), "")
    # FR-05: Q-P16, Q-P39 and Q-E09 are resolved (TRACKING EV-0247, EV-0250), so this section must state
    # the answers it reads rather than a disclaimer that no answer exists. Same strictness, new strings.
    sub("questions.resolved_readings_present",
        "interruption policy P1 with revival policy R2" in body
        and "abandoning a live run is a defeat" in body
        and "only at the next durable transition" in body, "")

    # 10. receipt citations resolve and carry the API they are cited for
    receipt_lines = read(root, RECEIPT).splitlines()
    sub("receipt.length", len(receipt_lines) == 190, f"{len(receipt_lines)} lines")
    anchors = [(6, 26, "FileAccess open"), (29, 42, "Forces pending written data"),
               (45, 65, "Closes the currently opened file"),
               (67, 81, "Writes the file's buffer to disk"),
               (83, 105, "DirAccess open"), (110, 132, "get_user_data_dir"),
               (135, 153, "move_to_trash"), (155, 172, "globalize_path"),
               (174, 180, "user://"), (182, 190, "Message categories")]
    for lo, hi, needle in anchors:
        chunk = "\n".join(receipt_lines[lo - 1:hi])
        sub(f"receipt.anchor[{lo}-{hi}]", needle in chunk, needle)
    for lo, hi in {(int(a), int(b)) for a, b in
                   re.findall(r"receipt lines (\d+) to (\d+)", body)}:
        sub(f"receipt.citation_in_range[{lo}-{hi}]",
            1 <= lo < hi <= len(receipt_lines), "")
    sub("receipt.no_fsync_api_claimed",
        "fsync" not in "\n".join(receipt_lines).lower(),
        "the receipt genuinely contains no fsync API, as the section states")

    # 11. curated source anchors: every cited line exists and carries its clause
    src_anchors = [
        ("adr/TADR-004-persistence.md", 24, "one persistence owner"),
        ("adr/TADR-004-persistence.md", 28, "only then acknowledges"),
        ("adr/TADR-004-persistence.md", 30, "cannot override it"),
        ("adr/TADR-004-persistence.md", 32, "hold the transition"),
        ("adr/TADR-004-persistence.md", 34, "without overwriting the source"),
        ("adr/TADR-004-persistence.md", 38, "do not prove power-loss durability"),
        ("adr/TADR-004-persistence.md", 40, "older living generation"),
        ("adr/TADR-004-persistence.md", 42, "browser storage"),
        ("adr/TADR-004-persistence.md", 46, "every commit boundary"),
        ("adr/TADR-004-persistence.md", 48, "amend this ADR"),
        ("adr/TADR-001-engine-language-platforms.md", 23, "Windows 11 x64 and Linux x64"),
        ("adr/TADR-001-engine-language-platforms.md", 29, "is not proof that this game"),
        ("adr/TADR-001-engine-language-platforms.md", 39, "desktop exports"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 31, "is written only by a commit"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 42, "hold rule"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 52, "D1.1"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 54, "D1.3"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 55, "D1.4"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 71, "SEAM-6"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 85, "commit together"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 99, "durability is unknown"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 110, "before another playable state"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 116, "admission rule"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 173, "no durable trace"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 175, "not a gameplay commit"),
        ("docs/tech/sections/HF-07b-commit-boundaries.md", 307, "HF-08"),
        ("docs/tech/sections/HF-07a-save-envelope.md", 56, "never treated as a default"),
        ("docs/tech/sections/HF-07a-save-envelope.md", 176, "won"),
        ("docs/tech/sections/HF-07a-save-envelope.md", 192, "exactly six keys"),
        ("docs/tech/sections/HF-07a-save-envelope.md", 202, "backup pointer"),
        ("docs/tech/sections/HF-07a-save-envelope.md", 205, "HF-08"),
        ("docs/tech/sections/HF-03a-module-map.md", 35, "RecoveryDiagnostic"),
        ("docs/tech/sections/HF-03a-module-map.md", 49, "preserved-source references"),
        ("docs/tech/sections/HF-03a-module-map.md", 51, "consumed as a snapshot"),
        ("docs/tech/sections/HF-03a-module-map.md", 58, "takes precedence over an older checkpoint"),
        ("docs/tech/proofs/S0-08-save-evidence.md", 51, "ambiguous_lifecycle"),
        ("docs/tech/proofs/S0-08-save-evidence.md", 99, "not asserted"),
        ("docs/tech/proofs/S0-07-save-owner.md", 42, "ambiguous_lifecycle"),
        ("docs/tech/proofs/S0-07-save-owner.md", 91, "rename_absolute"),
        ("docs/tech/proofs/S0-07-save-owner.md", 113, "tighten"),
        ("BIBLE.md", 582, "One standard revival"),
        ("BIBLE.md", 584, "refill a spent revival"),
        ("BIBLE.md", 602, "pointer recapture"),
    ]
    for rel, num, needle in src_anchors:
        src = read(root, rel).splitlines()
        ok = num <= len(src) and needle.lower() in src[num - 1].lower()
        sub(f"anchor[{rel}:{num}]", ok, needle)

    # 12. links and in-page anchors
    here = os.path.dirname(os.path.join(root, SECTION))
    ids = set(re.findall(r'<a id="([^"]+)"', body))
    for h in re.findall(r"^#+\s+(.*)$", body, re.M):
        ids.add(re.sub(r"[^a-z0-9\s-]", "", h.lower()).strip().replace(" ", "-"))
    missing = []
    for target in re.findall(r"\]\(([^)\s]+)\)", body):
        if target.startswith("http"):
            continue
        path, _, frag = target.partition("#")
        if path:
            if not os.path.exists(os.path.normpath(os.path.join(here, path))):
                missing.append(target)
        elif frag and frag not in ids:
            missing.append(target)
    sub("links.resolve", not missing, f"{missing}")

    # 13. dependency hashes as stated in the section
    for rel, want in DEPS.items():
        got_hash = sha256(os.path.join(root, rel))
        sub(f"dependency.sha256[{os.path.basename(rel)}]",
            got_hash == want and want in body,
            f"{got_hash[:16]}… stated={want in body}")
    return local


# ----------------------------------------------------------------- recovery model
class Artifact:
    def __init__(self, kind, gen=0, rs=False, term=False):
        self.kind = kind          # "unparsable" | "valid"
        self.gen, self.rs, self.term = gen, rs, term


def decide(committed, candidates, rules=()):
    """Model of the R6/R7 recovery decision. Returns (status, source, playable, deleted)."""
    off = set(rules)
    deleted = []
    if "preserve" in off:
        deleted = [c for c in candidates if c.kind == "unparsable"]
        candidates = [c for c in candidates if c.kind != "unparsable"]
    parseable = [c for c in candidates if c.kind == "valid"]

    if committed is None:                                   # FC-15 / AC-8
        if any(c.gen > 1 for c in parseable):
            return "ambiguous_lifecycle", None, False, deleted
        return "missing", None, True, deleted
    if committed.kind == "corrupt":                         # FC-13 / AC-3
        return "corrupt", None, False, deleted
    if committed.kind == "unsupported":                     # FC-14 / AC-4
        return "unsupported_newer", None, False, deleted

    newer = [c for c in parseable if c.gen > committed.gen]
    if len(newer) >= 2 and "ac2" not in off:                # AC-2
        return "ambiguous_lifecycle", committed, False, deleted
    if "ac1" not in off:                                    # AC-1
        for c in newer:
            if (c.rs and not committed.rs) or (c.term and not committed.term):
                return "ambiguous_lifecycle", committed, False, deleted
    source = committed
    if "monotonic" in off and newer:                        # negative control
        source = newer[0]
    status = "committed_stale_temp" if candidates else "committed"
    return status, source, not source.term, deleted


def run_model(rules=()):
    """Enumerate the state space and assert the invariants. Returns (cases, failures)."""
    lifecycles = [(False, False), (True, False), (True, True)]
    committeds = [None,
                  Artifact("corrupt"), Artifact("unsupported")]
    committeds += [Artifact("valid", 5, rs, t) for rs, t in lifecycles]
    cand_sets = [
        [],
        [Artifact("unparsable")],
        [Artifact("valid", 6, False, False)],
        [Artifact("valid", 6, True, False)],
        [Artifact("valid", 6, True, True)],
        [Artifact("valid", 4, False, False)],
        [Artifact("valid", 1, False, False)],
        [Artifact("valid", 6, False, False), Artifact("valid", 7, False, False)],
        [Artifact("unparsable"), Artifact("valid", 6, True, False)],
    ]
    cases, failures = 0, []
    for c in committeds:
        for cands in cand_sets:
            cases += 1
            status, source, playable, deleted = decide(c, list(cands), rules)
            tag = f"committed={c.kind if c else 'missing'}/{getattr(c,'gen',0)} cands={len(cands)}"
            if status not in STATUSES:
                failures.append(f"I0 status not in the closed set: {status} ({tag})")
            if status in ("corrupt", "unsupported_newer", "ambiguous_lifecycle") and playable:
                failures.append(f"I1 unreadable or ambiguous state reported playable ({tag})")
            if deleted:
                failures.append(f"I2 an artifact was deleted ({tag})")
            if source is not None and source not in (c,):
                failures.append(f"I3 recovery installed a candidate as the source ({tag})")
            if playable and source is not None:
                for a in cands:
                    if a.kind != "valid":
                        continue
                    if (a.rs and not source.rs) or (a.term and not source.term):
                        failures.append(
                            f"I4 a playable source is weaker than a readable artifact ({tag})")
    return cases, failures


MATRIX_MODEL = {
    # id: (committed lifecycle, candidate, expected status, expected playable)
    "SP1": ("unparsable", "committed_stale_temp"),
    "SP2": ("candidate", None),
    "SP3a": ("candidate", None),
    "SP3b": ("advanced", "committed"),
    "SP4": ("advanced", "committed"),
}


def replay_matrix():
    """Replay the twenty documented rows through the same model."""
    base = {"A": (False, False), "B": (False, False), "C": (False, False), "D": (True, False),
            "S": (True, True)}
    after = {"A": (False, False), "B": (False, False), "C": (True, False), "D": (True, True),
             "S": (False, False)}
    out, failures = [], []
    for t in TRANSITIONS:
        rs0, t0 = base[t]
        rs1, t1 = after[t]
        for i, point in enumerate(MATRIX_POINTS, start=1):
            committed = Artifact("valid", 5, rs0, t0)
            if point == "SP1":
                cands = [Artifact("unparsable")]
            elif point in ("SP2", "SP3a"):
                cands = [Artifact("valid", 6, rs1, t1)]
            else:
                committed = Artifact("valid", 6, rs1, t1)
                cands = []
            status, source, playable, _ = decide(committed, cands)
            out.append({"id": f"IM-{t}{i}", "point": point, "status": status,
                        "playable": playable})
    expect = {
        ("A", "SP1"): ("committed_stale_temp", True), ("A", "SP2"): ("committed_stale_temp", True),
        ("A", "SP3a"): ("committed_stale_temp", True), ("A", "SP3b"): ("committed", True),
        ("A", "SP4"): ("committed", True),
        ("B", "SP1"): ("committed_stale_temp", True), ("B", "SP2"): ("committed_stale_temp", True),
        ("B", "SP3a"): ("committed_stale_temp", True), ("B", "SP3b"): ("committed", True),
        ("B", "SP4"): ("committed", True),
        ("C", "SP1"): ("committed_stale_temp", True), ("C", "SP2"): ("ambiguous_lifecycle", False),
        ("C", "SP3a"): ("ambiguous_lifecycle", False), ("C", "SP3b"): ("committed", True),
        ("C", "SP4"): ("committed", True),
        ("D", "SP1"): ("committed_stale_temp", True), ("D", "SP2"): ("ambiguous_lifecycle", False),
        ("D", "SP3a"): ("ambiguous_lifecycle", False), ("D", "SP3b"): ("committed", False),
        ("D", "SP4"): ("committed", False),
        # Transition S: the committed record is the closed run until WO5 lands, so the first three rows are
        # not playable because that run is over, and the last two are the started run.
        ("S", "SP1"): ("committed_stale_temp", False), ("S", "SP2"): ("committed_stale_temp", False),
        ("S", "SP3a"): ("committed_stale_temp", False), ("S", "SP3b"): ("committed", True),
        ("S", "SP4"): ("committed", True),
    }
    for row in out:
        key = (row["id"][3], row["point"])
        want = expect[key]
        if (row["status"], row["playable"]) != want:
            failures.append(f"{row['id']} model gave {row['status']}/{row['playable']}, "
                            f"the section states {want}")
    return out, failures


def check_documented_matrix(text, replayed):
    """Compare the documented status and playability of every row with the model."""
    _, rows = find_table(tables(text), "Transition (fact)", "Stage point", "Asserted outcome")
    fails = []
    by_id = {r["id"]: r for r in replayed}
    for r in rows:
        m = by_id.get(r[0])
        if not m:
            fails.append(f"{r[0]} has no model row")
            continue
        if m["status"] not in r[6]:
            fails.append(f"{r[0]} documents status {r[6]!r}, model says {m['status']}")
        doc_playable = "not playable" not in r[7].lower() and "derived false" not in r[7].lower()
        if doc_playable != m["playable"]:
            fails.append(f"{r[0]} documents playable={doc_playable}, model says {m['playable']}")
    return fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    text = read(root, SECTION)
    RESULTS.extend(run_document_checks(root, text))

    cases, model_failures = run_model()
    check("model.state_space_invariants", not model_failures,
          f"{cases} cases; failures {model_failures[:3]}")
    replayed, replay_failures = replay_matrix()
    check("model.matrix_replay", not replay_failures, f"{replay_failures[:3]}")
    doc_failures = check_documented_matrix(text, replayed)
    check("model.matrix_matches_document", not doc_failures, f"{doc_failures[:3]}")

    # negative controls: each removes one rule and must be noticed
    controls = []
    for name, kind in [("ac1", "model"), ("monotonic", "model"), ("preserve", "model"),
                       ("marker", "document")]:
        if kind == "model":
            _, fails = run_model(rules=(name,))
            noticed = bool(fails)
        else:
            noticed = any(not r["ok"] for r in run_document_checks(root, text, mutate=name))
        controls.append({"control": name, "detected": noticed})
        check(f"control.detected[{name}]", noticed, "removing the rule fails the check")

    failed = [r for r in RESULTS if not r["ok"]]
    report = {
        "check": "HF-08 paper check",
        "section": SECTION,
        "section_sha256": sha256(os.path.join(root, SECTION)),
        "repository_root": root,
        "checks_total": len(RESULTS),
        "checks_failed": len(failed),
        "model_cases": cases,
        "matrix_rows_replayed": len(replayed),
        "controls": controls,
        "results": RESULTS,
    }
    manifest = {rel: sha256(os.path.join(root, rel)) for rel in
                [SECTION] + sorted(DEPS) + ["docs/tech/proofs/S0-07-save-owner.md",
                                            "docs/tech/proofs/S0-08-save-evidence.md",
                                            "adr/TADR-004-persistence.md",
                                            "adr/TADR-001-engine-language-platforms.md"]}
    with open(os.path.join(out, "paper-check.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(out, "source-manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
        fh.write("\n")

    for r in failed:
        print(f"FAIL {r['check']}: {r['detail']}")
    print(f"{len(RESULTS)} checks, {len(failed)} failed, {cases} model cases, "
          f"{len(replayed)} matrix rows replayed, "
          f"{sum(1 for c in controls if c['detected'])}/{len(controls)} controls detected")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
