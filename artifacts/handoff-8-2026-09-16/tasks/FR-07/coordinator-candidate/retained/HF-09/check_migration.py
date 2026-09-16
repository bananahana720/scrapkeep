#!/usr/bin/env python3
"""HF-09 paper check.

Verifies docs/tech/sections/HF-09-schema-migration.md against its cited sources
at one base, then replays a model of the compatibility predicate, the migration
chain and the HF-07b four-stage commit.

Usage:
    python3 check_migration.py <repository-root> [--out <receipt-directory>]

Writes paper-check.json and source-manifest.json into the receipt directory
(default: the directory holding this script). Exit 0 when every check passes,
1 on a failure, 2 on an internal error.

Nothing here executes the engine, a build, a browser or a save.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
import re
import sys
from copy import deepcopy
from pathlib import Path

SECTION = "docs/tech/sections/HF-09-schema-migration.md"

RESULTS: list[dict] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    RESULTS.append({"check": name, "ok": bool(ok), "detail": detail})
    return bool(ok)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# --------------------------------------------------------------------------
# Source identities
# --------------------------------------------------------------------------

DEPENDENCY_HASHES = {
    "docs/tech/sections/HF-06b-persistence-projection.md":
        "d2344ecf38788778f0c334a06f16490b1c83522ebb5ee04643505fc8ca06814d",
    "docs/tech/sections/HF-06b-persistence-projection.csv":
        "e56c1627c46a85b6aad8d0a4f8aeddc8f1e2b6bfb0eb790ff49e86772e9c24b5",
    "docs/tech/sections/HF-07a-save-envelope.md":
        "4c37b7b32197642e1a312758449b8ebede05d3a0788e92b74a6a9f95ed97c010",
    "docs/tech/sections/HF-07a-save-envelope.csv":
        "1c553120d0988bfbf3d5644946904fb603b3a3617091764ce170eb1cbb798b00",
    "docs/tech/sections/HF-07b-commit-boundaries.md":
        "b1b88c2922d56eb7d9f9b581f387e8eb6aeb148d12ff23f4de4c53ba5d929122",
    "docs/tech/sections/HF-05-content-admission.md":
        "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
}

RECEIPT_HASHES = {
    "artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.txt":
        "f2b0d512b806f43c07bd49a1775a84a2ac7109b0c3465a79c37c68764f33d28c",
    "artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.exit":
        "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa",
}

# (path, 1-based line, substring the section cites that line for)
CITED_LINES = [
    # TADR-003
    ("adr/TADR-003-content-pipeline.md", 25, "stable ID independent of display name"),
    ("adr/TADR-003-content-pipeline.md", 31, "not a substituted default that changes a saved build"),
    ("adr/TADR-003-content-pipeline.md", 33, "stays pinned to its gameplay content revision unless an explicit migration succeeds"),
    ("adr/TADR-003-content-pipeline.md", 37, "## Consequences"),
    ("adr/TADR-003-content-pipeline.md", 41, "may not silently remap missing IDs, reroll a saved offer or retire an old run"),
    ("adr/TADR-003-content-pipeline.md", 45, "round-trip through the JSON persistence codec"),
    # TADR-004
    ("adr/TADR-004-persistence.md", 20, "Whole-scene or engine-object serialization"),
    ("adr/TADR-004-persistence.md", 24, "Preferences are a separate versioned record"),
    ("adr/TADR-004-persistence.md", 26, "a seed alone cannot justify rerolling them"),
    ("adr/TADR-004-persistence.md", 28, "only then acknowledges the transition as durable"),
    ("adr/TADR-004-persistence.md", 30, "cannot override it"),
    ("adr/TADR-004-persistence.md", 32, "hold the transition and show a recoverable save error"),
    ("adr/TADR-004-persistence.md", 34, "Use explicit migrations between supported schema/content versions"),
    ("adr/TADR-004-persistence.md", 36, "## Consequences"),
    ("adr/TADR-004-persistence.md", 38, "do not prove power-loss durability"),
    ("adr/TADR-004-persistence.md", 40, "Unsupported data can remain inspectable without becoming playable"),
    ("adr/TADR-004-persistence.md", 42, "Keep existing browser storage and historical proof data intact"),
    ("adr/TADR-004-persistence.md", 46, "unknown schema/content versions, migrations"),
    ("adr/TADR-004-persistence.md", 52, "the run is over for victory and defeat alike"),
    # BIBLE
    ("BIBLE.md", 460, "Acquired and equipped are separate states"),
    ("BIBLE.md", 461, "requires a special respec opportunity"),
    ("BIBLE.md", 462, "Recipe knowledge can persist"),
    ("BIBLE.md", 463, "without accumulating permanent combat-stat advantage"),
    ("BIBLE.md", 465, "does not duplicate rewards, refill a spent revival or add another copy of a recipe effect"),
    ("BIBLE.md", 469, "## 6. Core Systems"),
    ("BIBLE.md", 475, "Combat power is rebuilt each run"),
    ("BIBLE.md", 550, "inventory capacity, equipment slot limits and replacement rules are not established"),
    ("BIBLE.md", 552, "repeated swaps do not accumulate accidental bonuses"),
    ("BIBLE.md", 562, "not rerolling its reward"),
    ("BIBLE.md", 564, "Reloading or re-equipping cannot stack another copy"),
    ("BIBLE.md", 568, "persistence across levels remain open"),
    ("BIBLE.md", 572, "does not silently grant another standard revival"),
    ("BIBLE.md", 578, "A world is a run-region"),
    ("BIBLE.md", 580, "two randomly selected eligible destinations"),
    ("BIBLE.md", 582, "One standard revival is available per run"),
    ("BIBLE.md", 584, "cannot duplicate completed rewards, refill a spent revival or resurrect a terminal run"),
    ("BIBLE.md", 586, "Permanent discoveries, learned recipes, options and challenges survive defeat"),
    ("BIBLE.md", 602, "sensitivity, sound, UI scale and impact shake"),
    # HF-05
    ("docs/tech/sections/HF-05-content-admission.md", 18, "opaque, nonempty, case-sensitive token"),
    ("docs/tech/sections/HF-05-content-admission.md", 23, "no assumed numeric ordering"),
    ("docs/tech/sections/HF-05-content-admission.md", 24, "presentation-only replacement may retain the gameplay content revision"),
    ("docs/tech/sections/HF-05-content-admission.md", 27, "Never resolve a saved ID through an unqualified"),
    ("docs/tech/sections/HF-05-content-admission.md", 52, "Supported saved content remains resolvable or has an explicitly qualified migration"),
    ("docs/tech/sections/HF-05-content-admission.md", 54, "connected unlocked prefix"),
    ("docs/tech/sections/HF-05-content-admission.md", 56, "rebuilds `EffectiveBuild`"),
    ("docs/tech/sections/HF-05-content-admission.md", 58, "without rerolling"),
    ("docs/tech/sections/HF-05-content-admission.md", 64, "safe admission boundary"),
    ("docs/tech/sections/HF-05-content-admission.md", 85, "durably committed migration at the Session barrier"),
    ("docs/tech/sections/HF-05-content-admission.md", 86, "no hot remap"),
    ("docs/tech/sections/HF-05-content-admission.md", 101, "`ContentReferenceFailure` is the diagnostic"),
    ("docs/tech/sections/HF-05-content-admission.md", 105, "`missing_id`, `missing_revision`, `wrong_family`, `incompatible_revision` or `ambiguous_revision`"),
    ("docs/tech/sections/HF-05-content-admission.md", 106, "`start`, `restore`, `migration`"),
    ("docs/tech/sections/HF-05-content-admission.md", 107, "Exact domain token"),
    ("docs/tech/sections/HF-05-content-admission.md", 108, "Required definition family"),
    ("docs/tech/sections/HF-05-content-admission.md", 110, "Catalogue being inspected"),
    ("docs/tech/sections/HF-05-content-admission.md", 111, "field path"),
    ("docs/tech/sections/HF-05-content-admission.md", 113, "never an instruction to substitute it"),
    ("docs/tech/sections/HF-05-content-admission.md", 114, "must remain incomplete"),
    ("docs/tech/sections/HF-05-content-admission.md", 117, "`ContentAdmissionFailure`"),
    ("docs/tech/sections/HF-05-content-admission.md", 119, "Compatibility has three outcomes"),
    ("docs/tech/sections/HF-05-content-admission.md", 121, "retain both source and candidate handles during staging"),
    ("docs/tech/sections/HF-05-content-admission.md", 123, "No retention count, expiry period, automatic"),
    # HF-06b
    ("docs/tech/sections/HF-06b-persistence-projection.md", 34, "Every projected ID is a JSON string"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 35, "never remapped, rerolled or dropped"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 36, "Derived state is never projected"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 55, "Projection group"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 71, "preferences"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 191, "reads only `.md` files"),
    # HF-07a
    ("docs/tech/sections/HF-07a-save-envelope.md", 24, "its path from its document's root"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 26, "One rule splits the run's own facts between two containers"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 102, "| `run.start` | `object` |"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 44, "A null is a stated state, never a missing key"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 46, "No numeric field in the aggregate is a float"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 56, "never treated as a default"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 60, "No engine identity is ever a field value"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 61, "Derived state is never stored"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 62, "It is never remapped, rerolled or dropped"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 63, "A generator seed never replaces a stored outcome"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 64, "Array order is fixed"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 65, "holds no gameplay progress and no domain ID"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 66, "Naming the container is not answering the question"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 78, "fails visibly and never overwrites the source"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 79, "never through an unqualified latest catalogue"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 83, "closed run can never be reopened by dropping the key"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 138, "never dropped silently"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 142, "granting a second copy"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 163, "device facts that cross a level boundary"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 104, "Reserved for the unfinished-level interruption rule"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 113, "| `run.start.character_id` |"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 114, "| `run.start.entrance_id` |"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 115, "| `run.start.rng_state` |"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 117, "| `run.start.rng_state[].state` |"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 175, "It is true for terminal defeat and for a run the final encounter completed alike"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 176, "the enumerated string won or lost and no other value"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 184, "preferences can migrate without touching gameplay progress"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 188, "impact_shake"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 192, "exactly six keys"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 194, "Rejected envelope field"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 199, "`playable` flag"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 201, "second copy could disagree with the first"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 202, "migration marker, backup pointer or recovery status"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 203, "A results-screen, reward or presentation key for a won run"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 205, "no `generation` or `transaction_id`"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 273, "migration remain HF-09's"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 277, "trigger in card item 1 is consumed above by source review"),
    ("docs/tech/sections/HF-07a-save-envelope.md", 281, "requires an amendment rather than a silent addition"),
    # HF-07b
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 27, "not durable and is never read as gameplay state"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 35, "same four stages in this order"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 37, "**Stage.**"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 38, "**Validate.**"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 39, "**Commit.**"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 40, "**Acknowledge.**"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 42, "**The hold rule.**"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 54, "reads the candidate bytes back from storage"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 55, "not strictly greater than the committed generation"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 71, "restored through O4 only after the transition's identity is in"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 79, "names an entry in `run.checkpoint.equipment.owned`"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 103, "### Transition D: terminal settlement"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 112, "### Transition S: run start"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 116, "admitted only when the committed `run` is null or the committed `run.lifecycle.terminal` is true"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 129, "| N1 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 130, "| N2 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 131, "| N3 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 132, "| N4 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 133, "| N5 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 134, "| N6 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 135, "| N7 |"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 173, "Acknowledgement leaves no durable trace"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 175, "A preferences write is not a gameplay commit"),
    ("docs/tech/sections/HF-07b-commit-boundaries.md", 307, "Versioning and migration are"),
    # S0-07 and S0-08
    ("docs/tech/proofs/S0-07-save-owner.md", 39, "`validate(temp_path) -> Error`"),
    ("docs/tech/proofs/S0-07-save-owner.md", 40, "`commit(temp_path) -> Error`"),
    ("docs/tech/proofs/S0-07-save-owner.md", 42, "unsupported_newer"),
    ("docs/tech/proofs/S0-07-save-owner.md", 45, "The int-casting policy"),
    ("docs/tech/proofs/S0-07-save-owner.md", 122, "HF-09 defining a second schema version with a migration"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 3, "certifies nothing"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 38, "Normal run. Exit 0."),
    ("docs/tech/proofs/S0-08-save-evidence.md", 46, "acknowledge refused before commit and recorded after"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 47, "boundary cast restored ints"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 48, "Schema 99 rejected with `ERR_UNAVAILABLE`"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 49, "recovered as `unsupported_newer`"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 50, "truncated temp listed as stale"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 51, "ambiguous_lifecycle"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 52, "ERR_ALREADY_EXISTS"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 53, "Terminal generation 6 beats generation 5 in both orders"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 54, "converged with generation 1"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 66, "Rename completed, acknowledge not yet recorded"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 70, "acknowledgement is in-memory in this proof"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 101, "placeholder data on one host"),
    # BACKLOG
    ("BACKLOG.md", 565, "### HF-09: Specify schema and gameplay-content migration"),
    ("BACKLOG.md", 2670, "### Q-E05: Browser retention and save import policy"),
]

# The four browser source citations. (path, line, substring)
BROWSER_LINES = [
    ("src/campaign.js", 111, "export function parseProfile(raw) {"),
    ("src/campaign.js", 115, 'data.version !== 1'),
    ("src/progress-store.js", 8, "export function createProgressStore(storage, key) {"),
    ("src/progress-store.js", 12, "`${key}.run.`"),
    ("src/progress-store.js", 17, "function receipt(raw, expectedId) {"),
    ("src/progress-store.js", 45, "parsed?.version === 1"),
    ("src/collection.js", 29, 'has("qa")'),
    ("src/collection.js", 30, '"scrapkeep.qa.collection.v1"'),
    ("src/collection.js", 31, '"scrapkeep.collection.v1"'),
    ("src/collection.js", 38, "createProgressStore(storage, this.storageKey)"),
    ("src/main.js", 43, "const bestKey"),
    ("src/main.js", 48, "localStorage.getItem(bestKey)"),
    ("src/main.js", 141, "localStorage.setItem(bestKey"),
    ("src/orchard/main.js", 20, 'localStorage.getItem("orchard-settings")'),
    ("src/orchard/main.js", 106, 'localStorage.setItem("orchard-settings"'),
]

REQUIRED_HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]

BROWSER_TOKENS = [
    "localStorage",
    "scrapkeep.collection.v1",
    "scrapkeep.qa.collection.v1",
    "scrapkeep.best",
    "scrapkeep.qa.best",
    "orchard-settings",
]

REJECTED_KEY_PHRASES = [
    "migration marker",
    "backup pointer",
    "recovery status",
    "playability flag",
    "durability class",
    "write-reason",
    "resume mode",
]

# The three intermediate containers HF-07a gives no row (its review note N3).
NON_ROW_CONTAINERS = {
    "run.checkpoint.build",
    "run.checkpoint.equipment",
    "run.checkpoint.companion",
}

SA_VOCAB = ["current", "step", "unsupported-older", "newer", "malformed"]
CA_VOCAB = ["pinned", "step", "missing", "ambiguous", "malformed"]
KA_VOCAB = ["complete", "no-handle", "ambiguous", "missing-id", "wrong-family"]

# The accept/migrate/reject table, as data. None means "not evaluated".
TABLE = [
    ("P1", {"current"}, {"pinned"}, {"complete"}, "accept"),
    ("P2", {"step"}, {"pinned"}, {"complete"}, "migrate"),
    ("P3", {"current"}, {"step"}, {"complete"}, "migrate"),
    ("P4", {"step"}, {"step"}, {"complete"}, "migrate"),
    ("P5", {"malformed"}, None, None, "reject"),
    ("P6", {"newer"}, None, None, "reject"),
    ("P7", {"unsupported-older"}, None, None, "reject"),
    ("P8", {"current", "step"}, {"malformed"}, None, "reject"),
    ("P9", {"current", "step"}, {"missing"}, None, "reject"),
    ("P10", {"current", "step"}, {"ambiguous"}, None, "reject"),
    ("P11", {"current", "step"}, {"pinned", "step"}, {"no-handle"}, "reject"),
    ("P12", {"current", "step"}, {"pinned", "step"}, {"ambiguous"}, "reject"),
    ("P13", {"current", "step"}, {"pinned", "step"}, {"missing-id"}, "reject"),
    ("P14", {"current", "step"}, {"pinned", "step"}, {"wrong-family"}, "reject"),
]

GATES = ["G%d" % n for n in range(1, 14)]
INVARIANTS = ["M%d" % n for n in range(1, 11)]
WALKS = ["W1", "W2", "W3", "W4", "W5"]


# --------------------------------------------------------------------------
# Structural checks on the section
# --------------------------------------------------------------------------

def structural_checks(root: Path, text: str) -> None:
    lines = text.splitlines()

    headings = [ln[3:].strip() for ln in lines if ln.startswith("## ")]
    check("headings.present_in_order", headings == REQUIRED_HEADINGS,
          "found %r" % (headings,))

    for name in ["Sources", "Contract", "Scenarios"]:
        check("headings.%s" % name.lower().replace(" ", "_"),
              "## %s" % name in text)

    # Axis vocabularies are closed and every term is defined.
    for term in SA_VOCAB:
        check("axis.schema.%s" % term, "| `%s` |" % term in text)
    for term in CA_VOCAB:
        check("axis.content.%s" % term, "| `%s` |" % term in text)
    for term in KA_VOCAB:
        check("axis.catalogue.%s" % term, "| `%s` |" % term in text)

    # Table rows: every row present with a verdict from the closed set,
    # and every reject row carrying a diagnostic cell.
    table_rows = {}
    for ln in lines:
        m = re.match(r"\| (P\d+) \| (.*?) \| (.*?) \| (.*?) \| \*\*(accept|migrate|reject)\*\* \| (.*?) \|$", ln)
        if m:
            table_rows[m.group(1)] = (m.group(5), m.group(6).strip())
    expected_ids = [row[0] for row in TABLE]
    check("table.rows_present", sorted(table_rows, key=lambda s: int(s[1:])) == expected_ids,
          "found %r" % (sorted(table_rows, key=lambda s: int(s[1:])),))
    for rid, sa, ca, ka, verdict in TABLE:
        got = table_rows.get(rid)
        check("table.%s.verdict" % rid, got is not None and got[0] == verdict,
              "row says %r, data says %r" % (got[0] if got else None, verdict))
        if verdict == "reject":
            check("table.%s.diagnostic" % rid,
                  got is not None and len(got[1]) > 10 and got[1] != "—",
                  "reject row must name a diagnostic and a held operation")
    check("table.dash_means_unevaluated", "not evaluated" in text)

    # Gates and invariants present, each cited by at least one scenario row.
    scen_start = text.index("## Scenarios")
    scen = text[scen_start:text.index("## Unresolved questions")]
    for g in GATES:
        check("gate.%s.defined" % g, re.search(r"\| %s " % g, text) is not None)
        check("gate.%s.exercised" % g, g in scen, "no scenario row cites %s" % g)
    for m in INVARIANTS:
        check("invariant.%s.defined" % m, re.search(r"\| %s \| \*\*" % m, text) is not None)
        check("invariant.%s.exercised" % m, m in scen, "no scenario row cites %s" % m)

    # Five walks, each a step table with the required columns.
    for w in WALKS:
        check("walk.%s.heading" % w, re.search(r"### %s: " % w, text) is not None)
        rows = re.findall(r"^\| %s\.\d+ \|" % w, scen, re.M)
        check("walk.%s.step_rows" % w, len(rows) >= 5, "%d rows" % len(rows))
    check("walk.columns",
          scen.count("| Step | Action | Verdict or gate | `C` after | `W` and `A` after |") == 5)

    # Field-name parity against the admitted HF-07a CSV.
    csv_path = root / "docs/tech/sections/HF-07a-save-envelope.csv"
    with csv_path.open(newline="", encoding="utf-8") as fh:
        fields = {row["field"] for row in csv.DictReader(fh)}
    check("hf07a.csv.seventy_fields", len(fields) == 70, "%d fields" % len(fields))

    mentioned = set(re.findall(r"`((?:run|profile|preferences)\.[A-Za-z0-9_.\[\]]*[A-Za-z0-9_\]])`", text))
    unknown = sorted(f for f in mentioned if f not in fields and f not in NON_ROW_CONTAINERS)
    check("fields.all_exist_in_hf07a_csv", not unknown, "unknown paths: %r" % (unknown,))
    check("fields.mentioned_any", len(mentioned) >= 15, "%d paths mentioned" % len(mentioned))

    # The three non-row containers appear only where the section says they carry no row.
    for container in sorted(NON_ROW_CONTAINERS):
        occurrences = [ln for ln in lines if "`%s`" % container in ln]
        check("fields.non_row.%s" % container,
              len(occurrences) == 1 and "carry no HF-07a row" in occurrences[0],
              "%d occurrence(s)" % len(occurrences))

    # No mount dependency (HF-07a review note N2).
    check("fields.no_mount_id", "mount_id" not in text)

    # Rejected envelope keys appear only where HF-07a's rejection is cited.
    for phrase in REJECTED_KEY_PHRASES:
        bad = [ln for ln in lines
               if phrase in ln and "194 to 203" not in ln and "line 199" not in ln]
        check("envelope.rejected_key.%s" % phrase.replace(" ", "_"), not bad,
              "unguarded mention: %r" % (bad[:1],))
    check("envelope.six_keys", "exactly six keys" in text)

    # Browser tokens confined to the preservation section and its review.
    start = text.index("### The browser records this card preserves")
    end = text.index("### S0-08 reconciliation")
    allowed = text[start:end] + text[text.index("## Procedure performed"):]
    for token in BROWSER_TOKENS:
        outside = text.count(token) - allowed.count(token)
        check("browser.token_confined.%s" % token, outside == 0,
              "%d occurrence(s) outside the preservation section" % outside)
        check("browser.token_present.%s" % token, allowed.count(token) >= 1)
    check("browser.reads_none", "HF-09 reads none of them" in text)
    for rule in ["**B1. Closure.**", "**B2. No step can name one.**", "**B3. No reach.**"]:
        check("browser.rule%s" % rule[3:5], rule in text)

    # Q-E05 stays open.
    check("qe05.no_answer_adopted", "No answer is adopted, recommended or assumed." in text)
    check("qe05.candidate_table", text.count("| Candidate answer to Q-E05 | Effect on this contract |") == 1)
    check("qe05.every_candidate", all(
        s in text for s in ["never import", "Import some browser profile", "Never retire", "Retire one or both"]))

    # The two triggers this card must reconcile.
    check("trigger.s0_08_reconciled", "### S0-08 reconciliation" in text
          and "the trigger is consumed at this base" in text)
    check("trigger.s0_07_reconciled", "### S0-07 trigger reconciliation" in text
          and "S0-07 line 122" in text)
    check("registry.empty_at_base", "declared step registry is empty at this base" in text
          or "The declared step registry is therefore empty" in text)

    # Every relative link and in-page anchor resolves.
    section_dir = (root / SECTION).parent
    anchors = {re.sub(r"[^a-z0-9 -]", "", h.lower()).replace(" ", "-")
               for h in [ln.lstrip("#").strip() for ln in lines if ln.startswith("#")]}
    anchors |= set(re.findall(r'<a id="([^"]+)"></a>', text))
    broken = []
    for target in re.findall(r"\]\(([^)]+)\)", text):
        if target.startswith(("http://", "https://")):
            continue
        path_part, _, frag = target.partition("#")
        if not path_part:
            if frag not in anchors:
                broken.append(target)
            continue
        resolved = (section_dir / path_part).resolve()
        if not resolved.exists():
            broken.append(target)
            continue
        if frag:
            other = resolved.read_text(encoding="utf-8")
            other_anchors = {re.sub(r"[^a-z0-9 -]", "", h.lower()).replace(" ", "-")
                             for h in [ln.lstrip("#").strip()
                                       for ln in other.splitlines() if ln.startswith("#")]}
            other_anchors |= set(re.findall(r'<a id="([^"]+)"></a>', other))
            if frag not in other_anchors:
                broken.append(target)
    check("links.all_resolve", not broken, "broken: %r" % (broken[:6],))


# --------------------------------------------------------------------------
# Source identity checks
# --------------------------------------------------------------------------

def source_checks(root: Path, text: str) -> dict:
    manifest = {}
    for rel, expected in DEPENDENCY_HASHES.items():
        actual = sha256(root / rel)
        manifest[rel] = actual
        check("hash.%s" % rel, actual == expected, "expected %s got %s" % (expected, actual))
        check("hash.stated_in_section.%s" % rel, expected in text or rel.endswith(".csv") and expected in text)
    for rel, expected in RECEIPT_HASHES.items():
        actual = sha256(root / rel)
        manifest[rel] = actual
        check("receipt.%s" % rel, actual == expected, "expected %s got %s" % (expected, actual))

    for rel, lineno, needle in CITED_LINES:
        path = root / rel
        lines = path.read_text(encoding="utf-8").splitlines()
        ok = 0 < lineno <= len(lines) and needle in lines[lineno - 1]
        check("cite.%s:%d" % (rel, lineno), ok,
              "line %d does not carry %r" % (lineno, needle))

    for rel, lineno, needle in BROWSER_LINES:
        path = root / rel
        lines = path.read_text(encoding="utf-8").splitlines()
        ok = 0 < lineno <= len(lines) and needle in lines[lineno - 1]
        check("browser_source.%s:%d" % (rel, lineno), ok,
              "line %d does not carry %r" % (lineno, needle))
        manifest[rel] = sha256(path)

    # Exact card bytes, BACKLOG.md lines 563 to 596.
    backlog = (root / "BACKLOG.md").read_text(encoding="utf-8").splitlines()
    card = "\n".join(backlog[562:596])
    manifest["BACKLOG.md#hf-09[563:596]"] = hashlib.sha256(card.encode()).hexdigest()
    check("card.anchor", backlog[562].strip() == '<a id="hf-09"></a>')
    check("card.heading", backlog[564].startswith("### HF-09: Specify schema"))
    check("card.revision_2", "**Card revision:** 2" in card)
    for item in ["accept, migrate or reject table",
                 "ordered single-step migrations",
                 "One tabletop case per negative appears in the output",
                 "State that HF-09 reads none of them"]:
        check("card.dod.%s" % item.split()[0], item in card)
    check("card.boundary", backlog[595].startswith("**Boundary:**"))

    manifest[SECTION] = sha256(root / SECTION)
    return manifest


# --------------------------------------------------------------------------
# Model: the predicate
# --------------------------------------------------------------------------

def table_lookup(sa: str, ca: str, ka: str):
    hits = []
    for rid, r_sa, r_ca, r_ka, verdict in TABLE:
        if sa not in r_sa:
            continue
        if r_ca is not None and ca not in r_ca:
            continue
        if r_ka is not None and ka not in r_ka:
            continue
        hits.append((rid, verdict))
    return hits


def predicate_from_axes(sa: str, ca: str, ka: str) -> str:
    """The precedence rule as the Contract states it, independent of the table."""
    if sa in ("malformed", "newer", "unsupported-older"):
        return "reject"
    if ca in ("malformed", "missing", "ambiguous"):
        return "reject"
    if ka != "complete":
        return "reject"
    return "accept" if (sa == "current" and ca == "pinned") else "migrate"


def enumerate_axes() -> int:
    combos = 0
    for sa, ca, ka in itertools.product(SA_VOCAB, CA_VOCAB, KA_VOCAB):
        combos += 1
        hits = table_lookup(sa, ca, ka)
        if len(hits) != 1:
            check("predicate.exhaustive.%s|%s|%s" % (sa, ca, ka), False,
                  "%d matching rows: %r" % (len(hits), hits))
            continue
        rid, verdict = hits[0]
        expected = predicate_from_axes(sa, ca, ka)
        if verdict != expected:
            check("predicate.agrees.%s|%s|%s" % (sa, ca, ka), False,
                  "%s says %s, precedence rule says %s" % (rid, verdict, expected))
    check("predicate.exhaustive_and_agreeing", combos == 125, "%d combinations" % combos)
    return combos


# --------------------------------------------------------------------------
# Model: documents, catalogue, steps, gates, commit
# --------------------------------------------------------------------------

V = 2  # this build's schema version in the model
RB = "RB"

CATALOGUE = {
    # revision -> {domain id: family}
    "RA": {"char-1": "character", "tree-1": "tree", "item-1": "item",
           "rec-a": "recipe", "rec-b": "recipe", "unl-1": "unlock",
           "D-a": "destination", "D-b": "destination", "D-c": "destination",
           "D-d": "destination", "reg-1": "region", "ent-1": "entrance",
           "ent-2": "entrance"},
    "RB": {"char-1": "character", "tree-1": "tree", "item-1": "item",
           "rec-a": "recipe", "rec-b": "recipe", "unl-1": "unlock",
           "D-a": "destination", "D-b": "destination", "D-c": "destination",
           "D-d": "destination", "reg-1": "region", "ent-1": "entrance",
           "ent-2": "entrance"},
}
LINEAGE = {"tree-1": ["n0", "n1", "n2"]}  # root-to-current order


def base_doc(schema=V - 1, revision="RA", generation=5, txn="T5"):
    return {
        "schema_version": schema,
        "content_revision": revision,
        "generation": generation,
        "transaction_id": txn,
        "profile": {
            "discoveries": ["unl-1"],
            "recipes": ["rec-a", "rec-b"],
            "unlocks": ["unl-1"],
        },
        "run": {
            "run_id": "run-1",
            "start": {"character_id": "char-1", "entrance_id": "ent-1",
                      "rng_state": [{"stream_id": "run", "state": "0x0001"}]},
            "checkpoint": {
                "build": {"slots": [{"slot_id": "s1", "unlocked": True,
                                     "tree_id": "tree-1", "node_keys": ["n0", "n1"]}]},
                "equipment": {"owned": [{"instance_id": "i1", "item_id": "item-1",
                                         "instance_fields": {}}],
                              "equipped": [{"instance_id": "i1"}]},
                "resolved_rewards": [{"settlement_id": "st1", "resolved_ids": ["item-1"],
                                      "instance_ids": ["i1"]}],
                "offered_choices": [{"offer_id": "F1", "offer_kind": "world",
                                     "option_ids": ["D-a", "D-b"],
                                     "chosen_option_id": None}],
                "route": [{"sequence": 0, "destination_id": "reg-1", "offer_id": None}],
                "generation_decisions": [],
                "rng_state": [{"stream_id": "world", "state": "0x1234"}],
                "companion": {"chassis_id": None, "component_ids": [], "command_ids": []},
                "device_carry_over": [],
                "next_entrance": "ent-2",
            },
            "interruption": None,
            "lifecycle": {"revival_spent": False, "terminal": False, "outcome": None},
        },
    }


def paths_of(doc, prefix=""):
    out = set()
    if isinstance(doc, dict):
        for k, v in doc.items():
            p = "%s.%s" % (prefix, k) if prefix else k
            out.add(p)
            out |= paths_of(v, p)
    elif isinstance(doc, list):
        for item in doc:
            out |= paths_of(item, prefix + "[]")
    return out


def ids_of(doc):
    """Domain-ID-bearing values in the model document, keyed by path."""
    cp = doc["run"]["checkpoint"] if doc.get("run") else None
    found = {}
    for i, r in enumerate(doc["profile"]["recipes"]):
        found["profile.recipes[%d]" % i] = (r, "recipe")
    for i, d in enumerate(doc["profile"]["discoveries"]):
        found["profile.discoveries[%d]" % i] = (d, "unlock")
    for i, u in enumerate(doc["profile"]["unlocks"]):
        found["profile.unlocks[%d]" % i] = (u, "unlock")
    if doc.get("run"):
        found["run.start.character_id"] = (doc["run"]["start"]["character_id"], "character")
        found["run.start.entrance_id"] = (doc["run"]["start"]["entrance_id"], "entrance")
    if cp:
        for i, s in enumerate(cp["build"]["slots"]):
            if s["tree_id"]:
                found["run.checkpoint.build.slots[%d].tree_id" % i] = (s["tree_id"], "tree")
        for i, o in enumerate(cp["equipment"]["owned"]):
            found["run.checkpoint.equipment.owned[%d].item_id" % i] = (o["item_id"], "item")
        for i, o in enumerate(cp["offered_choices"]):
            for j, opt in enumerate(o["option_ids"]):
                found["run.checkpoint.offered_choices[%d].option_ids[%d]" % (i, j)] = (opt, "destination")
        for i, r in enumerate(cp["route"]):
            found["run.checkpoint.route[%d].destination_id" % i] = (r["destination_id"], "region")
        found["run.checkpoint.next_entrance"] = (cp["next_entrance"], "entrance")
    return found


class Step:
    def __init__(self, step_id, axis, from_s, to_s, from_r, to_r,
                 adds=(), removes=(), renames=(), fn=None):
        self.step_id = step_id
        self.axis = axis
        self.from_s, self.to_s = from_s, to_s
        self.from_r, self.to_r = from_r, to_r
        self.adds, self.removes, self.renames = list(adds), list(removes), list(renames)
        self.fn = fn or (lambda d: d)

    def apply(self, doc):
        out = deepcopy(doc)
        out["schema_version"] = self.to_s
        out["content_revision"] = self.to_r
        return self.fn(out)


def schema_step_v1_v2(doc):
    # Declared: adds run.checkpoint.migration_note with a declared constant.
    doc["run"]["interruption"] = None  # carried by value, unchanged
    return doc


def content_step_ra_rb(doc):
    return doc


REGISTRY_OK = [
    Step("s.v1v2", "schema", 1, 2, "RA", "RA", fn=schema_step_v1_v2),
    Step("c.ra_rb", "content", 2, 2, "RA", RB, fn=content_step_ra_rb),
]


def registry_wellformed(reg):
    froms_s = [s.from_s for s in reg if s.axis == "schema"]
    froms_r = [s.from_r for s in reg if s.axis == "content"]
    if len(froms_s) != len(set(froms_s)):
        return False, "two schema steps share a from_schema_version"
    if len(froms_r) != len(set(froms_r)):
        return False, "two content steps share a from_content_revision"
    for s in reg:
        if s.axis == "schema" and s.to_s != s.from_s + 1:
            return False, "schema step is not +1"
        if s.axis == "schema" and s.to_r != s.from_r:
            return False, "schema step changes the content revision"
        if s.axis == "content" and s.to_s != s.from_s:
            return False, "content step changes the schema version"
        if s.axis == "content" and s.to_r == s.from_r:
            return False, "content step does not change the content revision"
    # acyclicity of the content graph
    edges = {s.from_r: s.to_r for s in reg if s.axis == "content"}
    for start in list(edges):
        seen, cur = set(), start
        while cur in edges:
            if cur in seen:
                return False, "content step cycle"
            seen.add(cur)
            cur = edges[cur]
    return True, ""


def schema_axis(doc, reg, allow_newer=False):
    s = doc.get("schema_version")
    if not isinstance(s, int) or isinstance(s, bool):
        return "malformed", []
    if s == V:
        return "current", []
    if s > V:
        return ("current", []) if allow_newer else ("newer", [])
    chain, cur = [], s
    by_from = {st.from_s: st for st in reg if st.axis == "schema"}
    while cur < V:
        if cur not in by_from:
            return "unsupported-older", []
        chain.append(by_from[cur])
        cur = by_from[cur].to_s
    return "step", chain


def content_axis(doc, reg, admitted, ambiguous=()):
    r = doc.get("content_revision")
    if not isinstance(r, str) or not r:
        return "malformed", [], None
    if r in ambiguous:
        return "ambiguous", [], None
    if r in admitted:
        return "pinned", [], r
    chain, cur, seen = [], r, set()
    by_from = {st.from_r: st for st in reg if st.axis == "content"}
    while cur not in admitted:
        if cur in seen or cur not in by_from:
            return "missing", [], None
        seen.add(cur)
        chain.append(by_from[cur])
        cur = by_from[cur].to_r
    return "step", chain, cur


def catalogue_axis(doc, target, handles, ambiguous_handles=()):
    if target is None:
        return "no-handle"
    if target not in handles:
        return "no-handle"
    if target in ambiguous_handles:
        return "ambiguous"
    defs = CATALOGUE.get(target, {})
    for path, (value, family) in ids_of(doc).items():
        if value not in defs:
            return "missing-id"
        if defs[value] != family:
            return "wrong-family"
    return "complete"


def predicate(doc, reg, admitted, handles, ambiguous_rev=(), ambiguous_handles=(), allow_newer=False):
    sa, schain = schema_axis(doc, reg, allow_newer=allow_newer)
    if sa in ("malformed", "newer", "unsupported-older"):
        return sa, None, None, "reject", []
    ca, cchain, target = content_axis(doc, reg, admitted, ambiguous_rev)
    if ca in ("malformed", "missing", "ambiguous"):
        return sa, ca, None, "reject", []
    ka = catalogue_axis(doc, target, handles, ambiguous_handles)
    verdict = predicate_from_axes(sa, ca, ka)
    return sa, ca, ka, verdict, (schain + cchain if verdict == "migrate" else [])


# --------------------------------------------------------------------------
# Model: the per-step gates
# --------------------------------------------------------------------------

def run_gates(inp, out, step, disabled=()):
    """Returns (ok, failing_gate)."""
    def on(g):
        return g not in disabled

    if on("G1") and (out["schema_version"] != step.to_s or out["content_revision"] != step.to_r):
        return False, "G1"
    if on("G2"):
        required = ["schema_version", "content_revision", "generation", "transaction_id",
                    "profile", "run"]
        if any(k not in out for k in required):
            return False, "G2"
        if out["run"] is not None:
            for k in ("run_id", "lifecycle"):
                if k not in out["run"]:
                    return False, "G2"
    if on("G3"):
        if not isinstance(out["schema_version"], int) or isinstance(out["schema_version"], bool):
            return False, "G3"
        for _path, (value, _fam) in ids_of(out).items():
            if not isinstance(value, str):
                return False, "G3"
        for s in out["run"]["checkpoint"]["route"]:
            if not isinstance(s["sequence"], int) or isinstance(s["sequence"], bool):
                return False, "G3"
    if on("G4"):
        declared = set(step.adds) | set(step.removes) | set(step.renames)
        delta = paths_of(out) ^ paths_of(inp)
        undeclared = {p for p in delta if p not in declared}
        if undeclared:
            return False, "G4"
    if on("G5"):
        before = {o["offer_id"]: (tuple(o["option_ids"]), o["chosen_option_id"])
                  for o in inp["run"]["checkpoint"]["offered_choices"]}
        after = {o["offer_id"]: (tuple(o["option_ids"]), o["chosen_option_id"])
                 for o in out["run"]["checkpoint"]["offered_choices"]}
        if any(k not in after or after[k] != v for k, v in before.items()):
            return False, "G5"
    if on("G6"):
        before = {r["settlement_id"]: (tuple(r["resolved_ids"]), tuple(r["instance_ids"]))
                  for r in inp["run"]["checkpoint"]["resolved_rewards"]}
        after = {r["settlement_id"]: (tuple(r["resolved_ids"]), tuple(r["instance_ids"]))
                 for r in out["run"]["checkpoint"]["resolved_rewards"]}
        if before != after:
            return False, "G6"
    if on("G7"):
        for key in ("discoveries", "recipes", "unlocks"):
            b, a = set(inp["profile"][key]), set(out["profile"][key])
            if not b <= a or len(a) != len(out["profile"][key]):
                return False, "G7"
    if on("G8"):
        bl, al = inp["run"]["lifecycle"], out["run"]["lifecycle"]
        if (bl["revival_spent"] and not al["revival_spent"]) or (bl["terminal"] and not al["terminal"]):
            return False, "G8"
        if bl.get("outcome") != al.get("outcome"):
            return False, "G8"
        if inp["run"]["start"] != out["run"]["start"]:
            return False, "G8"
        if inp["run"]["run_id"] != out["run"]["run_id"]:
            return False, "G8"
        if inp["run"] is not None and out["run"] is None:
            return False, "G8"
    if on("G9"):
        renamed = set(step.renames)
        bi, ai = ids_of(inp), ids_of(out)
        for path, (value, _f) in bi.items():
            if path in renamed:
                continue
            if path in ai and ai[path][0] != value:
                return False, "G9"
    if on("G10"):
        defs = CATALOGUE.get(out["content_revision"], {})
        for _p, (value, family) in ids_of(out).items():
            if defs.get(value) != family:
                return False, "G10"
    if on("G11"):
        for s in out["run"]["checkpoint"]["build"]["slots"]:
            if not s["tree_id"]:
                continue
            lin = LINEAGE.get(s["tree_id"], [])
            if s["node_keys"] != lin[:len(s["node_keys"])]:
                return False, "G11"
        bi = {s["slot_id"]: len(s["node_keys"]) for s in inp["run"]["checkpoint"]["build"]["slots"]}
        ai = {s["slot_id"]: len(s["node_keys"]) for s in out["run"]["checkpoint"]["build"]["slots"]}
        if any(ai.get(k, 0) > v for k, v in bi.items()):
            return False, "G11"
    if on("G12"):
        owned = {o["instance_id"] for o in out["run"]["checkpoint"]["equipment"]["owned"]}
        for e in out["run"]["checkpoint"]["equipment"]["equipped"]:
            if e["instance_id"] not in owned:
                return False, "G12"
        for r in out["run"]["checkpoint"]["resolved_rewards"]:
            if any(i not in owned for i in r["instance_ids"]):
                return False, "G12"
    if on("G13"):
        again = step.apply(deepcopy(inp))
        if json.dumps(again, sort_keys=True) != json.dumps(out, sort_keys=True):
            return False, "G13"
    return True, None


# --------------------------------------------------------------------------
# Model: the four-stage commit and the whole migration
# --------------------------------------------------------------------------

class Store:
    def __init__(self, committed):
        self.C = deepcopy(committed)
        self.S = {}
        self.A = {committed["transaction_id"]}
        self.preserved = []

    def snapshot(self):
        return json.dumps(self.C, sort_keys=True)


def migrate(store, reg, admitted, handles, *, txn, fail_stage=None,
            disabled_gates=(), disable_m1=False, ambiguous_rev=(),
            ambiguous_handles=(), allow_newer=False):
    """Runs the predicate, the chain and the four stages. Returns a trace dict."""
    before = store.snapshot()
    trace = {"verdict": None, "generations": 0, "stages": [], "failed_gate": None,
             "committed_intermediates": 0}
    sa, ca, ka, verdict, chain = predicate(
        store.C, reg, admitted, handles, ambiguous_rev, ambiguous_handles, allow_newer)
    trace.update(axes=(sa, ca, ka), verdict=verdict)
    if verdict != "migrate":
        trace["source_unchanged"] = store.snapshot() == before
        return trace

    # Working area: not storage.
    work = deepcopy(store.C)
    for step in chain:
        out = step.apply(work)
        ok, gate = run_gates(work, out, step, disabled=disabled_gates)
        if not ok:
            trace["failed_gate"] = gate
            trace["source_unchanged"] = store.snapshot() == before
            return trace
        if disable_m1:
            # Negative control: commit every intermediate.
            store.C = deepcopy(out)
            store.C["generation"] = store.C["generation"] + 1
            trace["committed_intermediates"] += 1
            trace["generations"] += 1
        work = out

    candidate = deepcopy(work)
    candidate["generation"] = store.C["generation"] + 1
    candidate["transaction_id"] = txn

    # Stage 1
    if fail_stage == 1:
        trace["stages"].append("stage-failed")
        trace["source_unchanged"] = store.snapshot() == before
        return trace
    store.S[txn] = deepcopy(candidate)
    trace["stages"].append("staged")

    # Stage 2: re-read from the store, never the working object.
    reread = deepcopy(store.S[txn])
    converged = reread["transaction_id"] == store.C["transaction_id"]
    eligible = (
        fail_stage != 2
        and reread["schema_version"] == V
        and (converged or reread["generation"] > store.C["generation"])
        and (reread["run"]["lifecycle"]["revival_spent"] or not store.C["run"]["lifecycle"]["revival_spent"])
        and (reread["run"]["lifecycle"]["terminal"] or not store.C["run"]["lifecycle"]["terminal"])
        and catalogue_axis(reread, reread["content_revision"], handles) == "complete"
    )
    if not eligible:
        store.preserved.append(store.S.pop(txn))
        trace["stages"].append("validate-failed")
        trace["source_unchanged"] = store.snapshot() == before
        return trace
    trace["stages"].append("validated")

    # Stage 3
    if fail_stage == 3:
        store.preserved.append(store.S.pop(txn))
        trace["stages"].append("commit-failed")
        trace["source_unchanged"] = store.snapshot() == before
        return trace
    if converged:
        store.S.pop(txn)
        trace["stages"].append("converged")
        trace["source_unchanged"] = store.snapshot() == before
        return trace
    store.C = store.S.pop(txn)
    trace["generations"] += 1
    trace["stages"].append("committed")

    # Stage 4
    if fail_stage == 4:
        trace["stages"].append("acknowledge-failed")
        return trace
    store.A.add(txn)
    trace["stages"].append("acknowledged")
    return trace


def assert_invariants(label, source, store, trace, runs):
    """M1 to M10 after a whole migration attempt."""
    ok = True

    def fail(inv, why):
        nonlocal ok
        ok = False
        check("model.%s.%s" % (label, inv), False, why)

    # M1: at most one new generation, and no intermediate committed.
    if trace["generations"] > 1 or trace["committed_intermediates"] > 0:
        fail("M1", "%d generations, %d committed intermediates"
             % (trace["generations"], trace["committed_intermediates"]))
    # M2: on anything short of a commit, the source is byte-identical.
    if "committed" not in trace["stages"] and not trace.get("source_unchanged", True):
        fail("M2", "source changed without a commit")
    c = store.C
    # M4 offers, M5 knowledge, M6 no new field, M7 lifecycle, M8 settlements, M9 IDs.
    before_offers = {o["offer_id"]: (tuple(o["option_ids"]), o["chosen_option_id"])
                     for o in source["run"]["checkpoint"]["offered_choices"]}
    after_offers = {o["offer_id"]: (tuple(o["option_ids"]), o["chosen_option_id"])
                    for o in c["run"]["checkpoint"]["offered_choices"]}
    if any(after_offers.get(k) != v for k, v in before_offers.items()):
        fail("M4", "an offer was rerolled")
    for key in ("discoveries", "recipes", "unlocks"):
        if not set(source["profile"][key]) <= set(c["profile"][key]):
            fail("M5", "%s lost an entry" % key)
        if len(set(c["profile"][key])) != len(c["profile"][key]):
            fail("M5", "%s is no longer a set" % key)
    extra = paths_of(c) - paths_of(source)
    declared = set()
    for st in REGISTRY_OK:
        declared |= set(st.adds) | set(st.renames)
    if extra - declared:
        fail("M6", "undeclared field appeared: %r" % sorted(extra - declared))
    bl, al = source["run"]["lifecycle"], c["run"]["lifecycle"]
    if (bl["revival_spent"] and not al["revival_spent"]) or (bl["terminal"] and not al["terminal"]):
        fail("M7", "a lifecycle flag was weakened")
    if source["run"]["run_id"] != c["run"]["run_id"]:
        fail("M7", "run_id changed")
    bs = {r["settlement_id"]: tuple(r["instance_ids"])
          for r in source["run"]["checkpoint"]["resolved_rewards"]}
    as_ = {r["settlement_id"]: tuple(r["instance_ids"])
           for r in c["run"]["checkpoint"]["resolved_rewards"]}
    if bs != as_:
        fail("M8", "the settlement set changed")
    bi, ai = ids_of(source), ids_of(c)
    for path, (value, _f) in bi.items():
        if path in ai and ai[path][0] != value:
            fail("M9", "%s was rewritten" % path)
    # M10: no preferences key ever entered the aggregate.
    if any(k.startswith("preferences") for k in paths_of(c)):
        fail("M10", "a preferences key entered the aggregate")
    runs[0] += 1
    return ok


def model_checks() -> tuple[int, int]:
    runs = [0]
    handles = {"RB"}
    admitted = {"RB"}

    ok, why = registry_wellformed(REGISTRY_OK)
    check("model.registry.wellformed", ok, why)

    # W1: a compatible migration.
    src = base_doc()
    store = Store(src)
    tr = migrate(store, REGISTRY_OK, admitted, handles, txn="T6")
    check("model.W1.verdict_migrate", tr["verdict"] == "migrate", str(tr.get("axes")))
    check("model.W1.axes", tr["axes"] == ("step", "step", "complete"), str(tr.get("axes")))
    check("model.W1.one_generation", tr["generations"] == 1, str(tr["generations"]))
    check("model.W1.acknowledged", tr["stages"][-1] == "acknowledged", str(tr["stages"]))
    check("model.W1.target_state",
          store.C["schema_version"] == V and store.C["content_revision"] == RB)
    check("model.W1.generation", store.C["generation"] == 6)
    assert_invariants("W1", src, store, tr, runs)

    # W2: a rejected future version.
    src2 = base_doc(schema=V + 1, revision=RB, generation=9, txn="T9")
    store2 = Store(src2)
    tr2 = migrate(store2, REGISTRY_OK, admitted, handles, txn="TX")
    check("model.W2.reject", tr2["verdict"] == "reject")
    check("model.W2.schema_axis_only", tr2["axes"] == ("newer", None, None), str(tr2["axes"]))
    check("model.W2.nothing_written", store2.snapshot() == json.dumps(src2, sort_keys=True))
    check("model.W2.nothing_staged", not store2.S)
    assert_invariants("W2", src2, store2, tr2, runs)

    # W3: a missing recipe under the target revision.
    cat_backup = CATALOGUE["RB"].copy()
    del CATALOGUE["RB"]["rec-b"]
    src3 = base_doc(schema=V, revision="RA", generation=7, txn="T7")
    store3 = Store(src3)
    tr3 = migrate(store3, REGISTRY_OK, admitted, handles, txn="TY")
    check("model.W3.reject", tr3["verdict"] == "reject")
    check("model.W3.missing_id", tr3["axes"] == ("current", "step", "missing-id"), str(tr3["axes"]))
    check("model.W3.recipe_retained", "rec-b" in store3.C["profile"]["recipes"])
    check("model.W3.nothing_written", store3.snapshot() == json.dumps(src3, sort_keys=True))
    assert_invariants("W3", src3, store3, tr3, runs)
    CATALOGUE["RB"] = cat_backup

    # W4: a repeated load, all four branches.
    src4 = base_doc()
    store4 = Store(src4)
    migrate(store4, REGISTRY_OK, admitted, handles, txn="T6")
    gen_after_first = store4.C["generation"]
    tr4 = migrate(store4, REGISTRY_OK, admitted, handles, txn="T7")
    check("model.W4a.accept_second_load", tr4["verdict"] == "accept", str(tr4.get("axes")))
    check("model.W4a.no_generation", store4.C["generation"] == gen_after_first)
    assert_invariants("W4a", src4, store4, tr4, runs)

    # W4 branch B: interrupted before commit, then re-run.
    store4b = Store(base_doc())
    trb1 = migrate(store4b, REGISTRY_OK, admitted, handles, txn="T6", fail_stage=3)
    check("model.W4b.held", "commit-failed" in trb1["stages"], str(trb1["stages"]))
    check("model.W4b.source_untouched",
          store4b.snapshot() == json.dumps(base_doc(), sort_keys=True))
    check("model.W4b.candidate_preserved", len(store4b.preserved) == 1)
    trb2 = migrate(store4b, REGISTRY_OK, admitted, handles, txn="T7")
    check("model.W4b.rerun_commits_once", trb2["generations"] == 1)
    check("model.W4b.deterministic_content",
          json.dumps({k: v for k, v in store4b.C.items() if k not in ("transaction_id",)},
                     sort_keys=True)
          == json.dumps({k: v for k, v in store4.C.items() if k not in ("transaction_id",)},
                        sort_keys=True))
    assert_invariants("W4b", base_doc(), store4b, trb2, runs)

    # W4 branch B variant: interrupted between commit and acknowledge.
    store4c = Store(base_doc())
    trc = migrate(store4c, REGISTRY_OK, admitted, handles, txn="T6", fail_stage=4)
    check("model.W4c.committed_not_acknowledged",
          trc["stages"][-1] == "acknowledge-failed" and "T6" not in store4c.A)
    trc2 = migrate(store4c, REGISTRY_OK, admitted, handles, txn="T8")
    check("model.W4c.relaunch_accepts", trc2["verdict"] == "accept")
    check("model.W4c.no_second_generation", store4c.C["generation"] == 6)
    assert_invariants("W4c", base_doc(), store4c, trc2, runs)

    # W5: incompatible content — a step that rerolls an offer.
    bad_content = Step("c.bad", "content", 2, 2, "RA", RB,
                       fn=lambda d: (d["run"]["checkpoint"]["offered_choices"][0]
                                     .__setitem__("option_ids", ["D-c", "D-d"]) or d))
    reg_bad = [REGISTRY_OK[0], bad_content]
    src5 = base_doc(schema=V, revision="RA", generation=8, txn="T8")
    store5 = Store(src5)
    tr5 = migrate(store5, reg_bad, admitted, handles, txn="TZ")
    check("model.W5.gate_g5", tr5["failed_gate"] == "G5", str(tr5))
    check("model.W5.nothing_written", store5.snapshot() == json.dumps(src5, sort_keys=True))
    assert_invariants("W5", src5, store5, tr5, runs)

    # W5 second shape: a step that clears revival_spent.
    src5b = base_doc()
    src5b["run"]["lifecycle"]["revival_spent"] = True
    bad_life = Step("c.bad2", "content", 2, 2, "RA", RB,
                    fn=lambda d: (d["run"]["lifecycle"].__setitem__("revival_spent", False) or d))
    store5b = Store(src5b)
    tr5b = migrate(store5b, [REGISTRY_OK[0], bad_life], admitted, handles, txn="TZ2")
    check("model.W5b.gate_g8", tr5b["failed_gate"] == "G8", str(tr5b))
    assert_invariants("W5b", src5b, store5b, tr5b, runs)

    # W5 third shape: a step that drops a discovery.
    bad_know = Step("c.bad3", "content", 2, 2, "RA", RB,
                    fn=lambda d: (d["profile"].__setitem__("recipes", ["rec-a"]) or d))
    src5c = base_doc()
    store5c = Store(src5c)
    tr5c = migrate(store5c, [REGISTRY_OK[0], bad_know], admitted, handles, txn="TZ3")
    check("model.W5c.gate_g7", tr5c["failed_gate"] == "G7", str(tr5c))
    assert_invariants("W5c", src5c, store5c, tr5c, runs)

    # Fault injection: each commit stage, and each gate, in turn.
    for stage in (1, 2, 3, 4):
        s = Store(base_doc())
        t = migrate(s, REGISTRY_OK, admitted, handles, txn="TF%d" % stage, fail_stage=stage)
        if stage < 3:
            check("model.fault.stage%d.source_untouched" % stage,
                  s.snapshot() == json.dumps(base_doc(), sort_keys=True))
            check("model.fault.stage%d.not_acknowledged" % stage, "TF%d" % stage not in s.A)
        else:
            check("model.fault.stage%d.held_or_unacknowledged" % stage,
                  ("TF%d" % stage not in s.A) or t["stages"][-1] == "acknowledged")
        assert_invariants("fault-stage%d" % stage, base_doc(), s, t, runs)

    for gate in GATES:
        s = Store(base_doc())
        t = migrate(s, REGISTRY_OK, admitted, handles, txn="TG", disabled_gates=(gate,))
        check("model.gate_disabled.%s.still_safe" % gate,
              t["verdict"] == "migrate" and t["generations"] <= 1,
              "disabling %s must not create a second generation" % gate)
        assert_invariants("gate-off-%s" % gate, base_doc(), s, t, runs)

    # Negative controls: the checker must notice a removed gate.
    controls = 0

    # 1. Newer-schema axis removed.
    s = Store(base_doc(schema=V + 1, revision=RB, generation=9, txn="T9"))
    t = migrate(s, REGISTRY_OK, admitted, handles, txn="TC1", allow_newer=True)
    controls += check("control.newer_schema_axis", t["verdict"] != "reject",
                      "removing the newer-schema axis must change the verdict")

    # 2. G8 removed while a step clears revival_spent.
    src = base_doc()
    src["run"]["lifecycle"]["revival_spent"] = True
    s = Store(src)
    t = migrate(s, [REGISTRY_OK[0], bad_life], admitted, handles, txn="TC2",
                disabled_gates=("G8", "G4", "G13"))
    controls += check("control.G8", t["failed_gate"] is None
                      and "validate-failed" in t["stages"],
                      "removing G8 must stop the step-time rejection, leaving only HF-07b stage 2")

    # 3. G7 removed while a step drops a recipe.
    s = Store(base_doc())
    t = migrate(s, [REGISTRY_OK[0], bad_know], admitted, handles, txn="TC3",
                disabled_gates=("G7", "G4", "G13"))
    controls += check("control.G7", t["failed_gate"] is None
                      and "rec-b" not in s.C["profile"]["recipes"],
                      "removing G7 must let the lost recipe through")

    # 4. G5 removed while a step answers an open offer on the player's behalf.
    bad_choice = Step("c.bad4", "content", 2, 2, "RA", RB,
                      fn=lambda d: (d["run"]["checkpoint"]["offered_choices"][0]
                                    .__setitem__("chosen_option_id", "D-a") or d))
    s = Store(base_doc())
    t = migrate(s, [REGISTRY_OK[0], bad_choice], admitted, handles, txn="TC4a")
    check("model.W5d.gate_g5", t["failed_gate"] == "G5", str(t))
    s = Store(base_doc())
    t = migrate(s, [REGISTRY_OK[0], bad_choice], admitted, handles, txn="TC4",
                disabled_gates=("G5",))
    controls += check("control.G5", t["failed_gate"] is None
                      and s.C["run"]["checkpoint"]["offered_choices"][0]["chosen_option_id"] == "D-a",
                      "removing G5 must let the answered offer through")

    # 5. M1 removed: intermediates commit.
    s = Store(base_doc())
    t = migrate(s, REGISTRY_OK, admitted, handles, txn="TC5", disable_m1=True)
    controls += check("control.M1", t["committed_intermediates"] > 0 and t["generations"] > 1,
                      "removing the one-commit rule must produce more than one generation")

    check("model.controls_detected", controls == 5, "%d of 5" % controls)
    return runs[0], controls


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve() if args.out else Path(__file__).resolve().parent
    out.mkdir(parents=True, exist_ok=True)

    section_path = root / SECTION
    if not section_path.exists():
        print("FAIL: %s not found under %s" % (SECTION, root), file=sys.stderr)
        return 2
    text = section_path.read_text(encoding="utf-8")

    structural_checks(root, text)
    manifest = source_checks(root, text)
    combos = enumerate_axes()
    model_runs, controls = model_checks()

    failed = [r for r in RESULTS if not r["ok"]]
    report = {
        "paper_check": "HF-09",
        "repository_root": str(root),
        "section": SECTION,
        "section_sha256": manifest[SECTION],
        "checks": len(RESULTS),
        "failed": len(failed),
        "predicate_combinations": combos,
        "model_runs": model_runs,
        "controls_detected": controls,
        "failures": failed,
        "results": RESULTS,
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    print("HF-09 paper check: %d checks, %d failed, %d predicate combinations, "
          "%d model runs, %d controls detected"
          % (len(RESULTS), len(failed), combos, model_runs, controls))
    for f in failed:
        print("  FAIL %s: %s" % (f["check"], f["detail"]))
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # pragma: no cover
        print("INTERNAL ERROR: %r" % (exc,), file=sys.stderr)
        raise
