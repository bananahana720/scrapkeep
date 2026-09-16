#!/usr/bin/env python3
"""HF-07b paper check. Usage: check_boundaries.py <repository-root> --out <receipt-directory>

Checks the HF-07b commit-boundary contract against TADR-004, BIBLE.md, BACKLOG.md, the decision register,
the S0-07 and S0-08 proof pages and the admitted HF-07a, HF-04a, HF-03a and HF-05 sections, then replays
the four tabletop cases through a model of the four-stage protocol under every candidate policy
combination. Writes paper-check.json and source-manifest.json under --out. Exit 0 when every check passes,
1 on a failed check, 2 on an internal error.

It supplies two kinds of coverage `npm run check:docs` cannot: that script reads only .md files, so every
field name this section borrows from docs/tech/sections/HF-07a-save-envelope.csv gets no automated parity
check from it; and no repository script replays a documented protocol. Documentation only. It runs no
build, touches no save file and establishes no engine behaviour.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SECTION = "docs/tech/sections/HF-07b-commit-boundaries.md"
HF07A_MD = "docs/tech/sections/HF-07a-save-envelope.md"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
HF04A_MD = "docs/tech/sections/HF-04a-runtime-lifecycle.md"

HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers",
            "Procedure performed", "Evidence limits"]

TRANSITIONS = {
    "Transition A: level completion": "A",
    "Transition B: reward and offer resolution": "B",
    "Transition C: revival use": "C",
    "Transition D: terminal settlement": "D",
    "Transition S: run start": "S",
}
STAGE_NAMES = ["Stage", "Validate", "Commit", "Acknowledge"]

CASES = {
    "C1: duplicate completion": "C1",
    "C2: revival with an older spatial checkpoint": "C2",
    "C3: terminal defeat": "C3",
    "C4: stable offered-choice restore": "C4",
    "C5: run start after terminal defeat": "C5",
}

INVARIANTS = ["N1", "N2", "N3", "N4", "N5", "N6", "N7"]
GATES = ["D1.1", "D1.2", "D1.3", "D1.4", "D1.5"]
SEAMS = ["SEAM-1", "SEAM-2", "SEAM-3", "SEAM-4", "SEAM-5", "SEAM-6", "SEAM-7"]
INTERRUPTION_POLICIES = ["P1", "P2", "P3", "P4"]
REVIVAL_POLICIES = ["R1", "R2", "R3"]

# Declared dependency bytes. The section states each of these; the check confirms the files match.
DECLARED_SHA = {
    HF07A_MD: "dfcd6a98d2fe8d07f69ff5bb336f563192604ad383a106b05902d9a60ea87d06",
    HF07A_CSV: "96212b0087f2cd971e272078679e39e3ba24417d2ce8d01f92b312e4dc827941",
    HF04A_MD: "cca7c341b0a163b0010e47c948af3d749e74c9a7fb61f475a3d332824215f91a",
    "docs/tech/sections/HF-03a-module-map.md": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
}

# (path, 1-based line, substring that must be on that line) for every load-bearing external citation.
CITATIONS = [
    ("adr/TADR-004-persistence.md", 24, "versioned JSON save aggregate"),
    ("adr/TADR-004-persistence.md", 26, "checkpoint projection retains"),
    ("adr/TADR-004-persistence.md", 28, "only then acknowledges the transition as durable"),
    ("adr/TADR-004-persistence.md", 28, "Duplicate delivery of the same transaction converges"),
    ("adr/TADR-004-persistence.md", 30, "Spending the standard revival commits a new aggregate"),
    ("adr/TADR-004-persistence.md", 30, "Terminal defeat commits that run's closed status"),
    ("adr/TADR-004-persistence.md", 32, "hold the transition and show a recoverable save error"),
    ("adr/TADR-004-persistence.md", 34, "explicit migrations"),
    ("adr/TADR-004-persistence.md", 38, "do not prove power-loss durability"),
    ("adr/TADR-004-persistence.md", 40, "must not silently choose an older living generation"),
    ("adr/TADR-004-persistence.md", 42, "browser storage"),
    ("adr/TADR-004-persistence.md", 46, "Test interruption at every commit boundary"),
    ("BIBLE.md", 578, "A world is a run-region"),
    ("BIBLE.md", 580, "two randomly selected eligible destinations"),
    ("BIBLE.md", 582, "One standard revival is available per run"),
    ("BIBLE.md", 584, "Pausing the dashboard is not itself a completed-level checkpoint"),
    ("BIBLE.md", 586, "Permanent discoveries, learned recipes, options and challenges survive defeat"),
    ("BIBLE.md", 465, "refill a spent revival"),
    ("BIBLE.md", 462, "Recipe knowledge can persist"),
    ("docs/project/DECISION-REGISTER.md", 49, "D26"),
    ("docs/project/DECISION-REGISTER.md", 50, "D27"),
    ("BACKLOG.md", 499, "HF-07b: Specify durable commit boundaries"),
    ("BACKLOG.md", 2726, "Q-E09: Permanent discovery write timing"),
    ("BACKLOG.md", 3020, "Q-P16: Revival and unfinished-level interruption"),
    (HF04A_MD, 24, "Control changes do not advance gameplay time"),
    (HF04A_MD, 48, "never award completion rewards"),
    (HF04A_MD, 50, "persistence completion"),
    (HF04A_MD, 67, "P6: commit and publish"),
    (HF04A_MD, 81, "PendingTransition"),
    (HF04A_MD, 87, "O1: release held physical input"),
    (HF04A_MD, 88, "O2: cancel prepared actions"),
    (HF04A_MD, 89, "O3: solo pause"),
    (HF04A_MD, 90, "O4: resume"),
    (HF04A_MD, 106, "Session owns the transition"),
    (HF04A_MD, 108, "blocks playable replacement"),
    (HF04A_MD, 113, "O4"),
    (HF04A_MD, 172, "T5.1"),
    (HF04A_MD, 173, "T5.2"),
    (HF04A_MD, 176, "T5.5"),
    (HF04A_MD, 178, "T5.7"),
    (HF07A_MD, 24, "path from its document's root"),
    (HF07A_MD, 46, "No numeric field in the aggregate is a float"),
    (HF07A_MD, 56, "never treated as a default"),
    (HF07A_MD, 61, "Derived state is never stored"),
    (HF07A_MD, 63, "A generator seed never replaces a stored outcome"),
    (HF07A_MD, 64, "Array order is fixed"),
    (HF07A_MD, 65, "preferences record holds no gameplay progress"),
    (HF07A_MD, 83, "A terminal run stays present"),
    (HF07A_MD, 162, "may not create a second standard revival"),
    (HF07A_MD, 104, "Reserved for the unfinished-level interruption rule"),
    (HF07A_MD, 174, "revival_spent"),
    (HF07A_MD, 175, "terminal"),
    (HF07A_MD, 192, "exactly six keys"),
    (HF07A_MD, 205, "HF-07b"),
    ("docs/tech/sections/HF-03a-module-map.md", 45, "RunState"),
    ("docs/tech/sections/HF-03a-module-map.md", 49, "SaveTransactionState"),
    ("docs/tech/sections/HF-03a-module-map.md", 58, "takes precedence"),
    ("docs/tech/sections/HF-05-content-admission.md", 27, "must resolve to the same gameplay meaning"),
    ("docs/tech/sections/HF-05-content-admission.md", 56, "EffectiveBuild"),
    ("docs/tech/sections/HF-05-content-admission.md", 58, "Loading preserves actual offered choices"),
    ("docs/tech/proofs/S0-07-save-owner.md", 39, "Only a candidate that returned `OK` is eligible for `commit`"),
    ("docs/tech/proofs/S0-07-save-owner.md", 40, "Refuses with `ERR_UNCONFIGURED`"),
    ("docs/tech/proofs/S0-07-save-owner.md", 41, "Records the transaction only when `commit` has returned `OK`"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 46, "acknowledge refused before commit and recorded after"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 47, "boundary cast restored ints"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 48, "newer_schema_candidate"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 49, "newer_schema_committed"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 50, "interruption_stale"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 51, "ambiguous_lifecycle"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 52, "ERR_ALREADY_EXISTS"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 53, "Terminal generation 6 beats generation 5"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 54, "converged with generation 1"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 66, "acknowledge not yet recorded"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 70, "HF-07b decides whether an acknowledgement leaves a durable trace"),
    ("docs/tech/proofs/S0-08-save-evidence.md", 101, "Automated execution establishes no human feel"),
]

# HF-07a lines 193 to 202 reject these envelope keys. The section must not ask for one.
FORBIDDEN_TOKENS = [
    "durability_class", "commit_class", "write_reason", "interruption_kind", "resume_mode",
    "mid_level_flag", "playable_flag", "checkpoint_generation", "checkpoint_timestamp",
    "acknowledged_at", "acknowledge_record", "migration_marker", "backup_pointer", "recovery_status",
]
# Review notes N2/N3 on HF-07a leave these open; the section must not depend on them.
NON_DEPENDENCIES = ["mount_id"]
# HF-07a carries no row for these three intermediate containers (its review note N3). The section may name
# them only inside the sentence that disclaims the dependency, and nowhere else.
DISCLAIMED_CONTAINERS = ["run.checkpoint.build", "run.checkpoint.equipment", "run.checkpoint.companion"]
DISCLAIMER = "now carry container rows in HF-07a, so every field path this section names resolves there"

FIELD_RE = re.compile(r"`((?:run|profile|preferences)\.[A-Za-z0-9_.\[\]]*|schema_version|content_revision|generation|transaction_id)`")


class Check:
    def __init__(self, root: Path):
        self.root = root
        self.results = []
        self.failed = 0

    def record(self, name, ok, detail=""):
        self.results.append({"check": name, "status": "pass" if ok else "fail", "detail": detail})
        if not ok:
            self.failed += 1
        return ok

    def read(self, rel):
        return (self.root / rel).read_text(encoding="utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def numbered_items(lines, start, end):
    """Return the top-level numbered list items in lines[start:end] as (number, text)."""
    out = []
    for line in lines[start:end]:
        m = re.match(r"^(\d+)\. (.*)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def heading_span(lines, title):
    """Return (start, end) line indices for the block under the heading whose text equals title."""
    start = None
    level = None
    for i, line in enumerate(lines):
        m = re.match(r"^(#{1,6})\s+(.*?)\s*$", line)
        if not m:
            continue
        if start is None and m.group(2) == title:
            start, level = i, len(m.group(1))
        elif start is not None and len(m.group(1)) <= level:
            return start, i
    return (start, len(lines)) if start is not None else (None, None)


# --------------------------------------------------------------------------------------------------
# The protocol model. It models only what the section specifies: the four observables, the four stages,
# the validate gates and the two monotonic flags. It is not a save implementation.
# --------------------------------------------------------------------------------------------------

class HoldError(Exception):
    """A stage failed. The transition is held and nothing durable changed beyond what is stated."""


class Owner:
    def __init__(self):
        # C: the committed aggregate.
        self.C = {
            "generation": 0, "transaction_id": "T0",
            "profile": {"discoveries": [], "recipes": [], "unlocks": []},
            "run": {"run_id": "run-1",
                    "start": {"character_id": "chr-a", "entrance_id": "E0", "rng_state": []},
                    "checkpoint": None, "interruption": None,
                    "lifecycle": {"revival_spent": False, "terminal": False, "outcome": None}},
        }
        self.S = {}           # transaction_id -> candidate
        self.A = set(["T0"])  # acknowledged transaction identities, live only
        self.pending = None   # Session's PendingTransition
        self.playable_released = True
        self.eligible = None  # the one candidate that last validated OK
        self.log = []

    # -- observables -------------------------------------------------------------------------------
    def committed(self):
        return json.loads(json.dumps(self.C))

    def restore(self):
        """What a restore at this instant reads. Playability is derived, never stored."""
        c = self.committed()
        c["derived_playable"] = not c["run"]["lifecycle"]["terminal"]
        return c

    # -- the four stages ---------------------------------------------------------------------------
    def stage(self, txn, mutate, fail=False):
        self.pending = txn
        self.playable_released = False
        cand = self.committed()
        if txn != self.C["transaction_id"]:
            cand["generation"] = self.C["generation"] + 1
        cand["transaction_id"] = txn
        mutate(cand)
        if fail:
            raise HoldError("stage failed: transition held, C unchanged")
        self.S[txn] = cand
        self.log.append(("stage", txn, self.C["generation"]))

    def validate(self, txn, extra=None, fail=False):
        cand = self.S.get(txn)
        if cand is None:
            raise HoldError("validate: no staged candidate")
        if fail:
            raise HoldError("validate failed: transition held, C unchanged")
        # convergence: a candidate carrying the committed transaction_id converges (TADR-004:28)
        if txn == self.C["transaction_id"]:
            self.eligible = ("converged", txn)
            self.log.append(("validate-converged", txn, self.C["generation"]))
            return "converged"
        # D1.4 strictly increasing generation
        if cand["generation"] <= self.C["generation"]:
            self.eligible = None
            raise HoldError("validate rejected: generation not greater than committed")
        # N5: run is never set back to null once it is an object
        if self.C["run"] is not None and cand["run"] is None:
            self.eligible = None
            raise HoldError("validate rejected: run dropped")
        same_run = (self.C["run"] is not None and cand["run"] is not None
                    and cand["run"]["run_id"] == self.C["run"]["run_id"])
        if cand["run"] is not None and not same_run:
            # A differing run_id is admitted only as a Transition S candidate. Anything else is FC-19.
            committed = self.C["run"]
            if committed is not None and not committed["lifecycle"]["terminal"]:
                self.eligible = None
                raise HoldError("validate rejected: FC-19 a differing run_id against a live run")
            start = cand["run"].get("start") or {}
            if not cand["run"]["run_id"] or not start.get("character_id") or not start.get("entrance_id"):
                self.eligible = None
                raise HoldError("validate rejected: a run start carries no populated run.start")
            if cand["run"]["checkpoint"] is not None or cand["run"]["interruption"] is not None:
                self.eligible = None
                raise HoldError("validate rejected: a run start carries a checkpoint or an interruption")
            lc = cand["run"]["lifecycle"]
            if lc["revival_spent"] or lc["terminal"] or lc["outcome"] is not None:
                self.eligible = None
                raise HoldError("validate rejected: a run start carries a lifecycle fact")
        if same_run:
            # monotonic lifecycle flags inside one run (N4, N5)
            for flag in ("revival_spent", "terminal"):
                if self.C["run"]["lifecycle"][flag] and not cand["run"]["lifecycle"][flag]:
                    self.eligible = None
                    raise HoldError("validate rejected: %s weakened" % flag)
            old_lc, new_lc = self.C["run"]["lifecycle"], cand["run"]["lifecycle"]
            if (new_lc["outcome"] is not None) != new_lc["terminal"]:
                self.eligible = None
                raise HoldError("validate rejected: outcome is not present exactly when terminal")
            if new_lc["outcome"] is not None and new_lc["outcome"] not in ("won", "lost"):
                self.eligible = None
                raise HoldError("validate rejected: outcome outside the enumeration")
            if old_lc["outcome"] is not None and new_lc["outcome"] != old_lc["outcome"]:
                self.eligible = None
                raise HoldError("validate rejected: outcome rewritten")
        # N7: the three knowledge sets only grow and stay unique
        for key in ("discoveries", "recipes", "unlocks"):
            before, after = self.C["profile"][key], cand["profile"][key]
            if len(after) != len(set(after)):
                self.eligible = None
                raise HoldError("validate rejected: %s not a set" % key)
            if not set(before) <= set(after):
                self.eligible = None
                raise HoldError("validate rejected: %s shrank" % key)
        ck_old = (self.C["run"] or {}).get("checkpoint")
        ck_new = (cand["run"] or {}).get("checkpoint")
        if ck_old is not None and ck_new is not None:
            # N1: no committed settlement_id may disappear
            old_ids = {s["settlement_id"] for s in ck_old["resolved_rewards"]}
            new_ids = {s["settlement_id"] for s in ck_new["resolved_rewards"]}
            if not old_ids <= new_ids:
                self.eligible = None
                raise HoldError("validate rejected: a committed settlement_id disappeared")
            # N2: a settlement's instance_ids exist as owned instances and are not shared
            seen = []
            for s in ck_new["resolved_rewards"]:
                owned = {o["instance_id"] for o in ck_new["equipment"]["owned"]}
                for iid in s["instance_ids"]:
                    if iid not in owned:
                        self.eligible = None
                        raise HoldError("validate rejected: instance_id with no owned entry")
                    if iid in seen:
                        self.eligible = None
                        raise HoldError("validate rejected: instance_id claimed by two settlements")
                    seen.append(iid)
            # N3: committed option_ids are byte-identical and chosen_option_id is a stored member
            old_offers = {o["offer_id"]: o for o in ck_old["offered_choices"]}
            for o in ck_new["offered_choices"]:
                prev = old_offers.get(o["offer_id"])
                if prev is not None and prev["option_ids"] != o["option_ids"]:
                    self.eligible = None
                    raise HoldError("validate rejected: committed option_ids rerolled")
                if prev is not None and prev["chosen_option_id"] is not None \
                        and prev["chosen_option_id"] != o["chosen_option_id"]:
                    self.eligible = None
                    raise HoldError("validate rejected: chosen_option_id rewritten")
                if o["chosen_option_id"] is not None and o["chosen_option_id"] not in o["option_ids"]:
                    self.eligible = None
                    raise HoldError("validate rejected: chosen_option_id not among option_ids")
        # the interruption record may not hold encounter state, with or without a checkpoint
        interruption = (cand["run"] or {}).get("interruption")
        if interruption is not None and "encounter_state" in interruption:
            self.eligible = None
            raise HoldError("validate rejected: interruption holds encounter state")
        if extra:
            extra(self.C, cand)
        self.eligible = ("ok", txn)
        self.log.append(("validate-ok", txn, cand["generation"]))
        return "ok"

    def commit(self, txn, fail=False):
        # D1.2: only the candidate that last validated OK, matched by transaction_id
        if self.eligible is None or self.eligible[1] != txn:
            raise HoldError("commit refused: candidate did not validate")
        kind = self.eligible[0]
        if fail:
            raise HoldError("commit failed: transition held, C unchanged, candidate preserved")
        if kind == "converged":
            self.S.pop(txn, None)
            self.eligible = None
            self.log.append(("commit-converged", txn, self.C["generation"]))
            return "converged"
        self.C = self.S.pop(txn)
        self.eligible = None
        self.log.append(("commit", txn, self.C["generation"]))
        return "ok"

    def acknowledge(self, txn, fail=False):
        # D1.1: only after commit returned success for this identity
        if self.C["transaction_id"] != txn:
            raise HoldError("acknowledge refused: %s has not committed" % txn)
        if fail:
            raise HoldError("acknowledge failed: transition held, C already durable")
        self.A.add(txn)
        self.pending = None
        self.playable_released = True
        self.log.append(("acknowledge", txn, self.C["generation"]))
        return "ok"

    def transition(self, txn, mutate, extra=None, fail_at=None):
        self.stage(txn, mutate, fail=(fail_at == "stage"))
        self.validate(txn, extra, fail=(fail_at == "validate"))
        self.commit(txn, fail=(fail_at == "commit"))
        self.acknowledge(txn, fail=(fail_at == "acknowledge"))


def new_checkpoint(entrance):
    return {
        "build": {"slots": []},
        "equipment": {"owned": [], "equipped": []},
        "resolved_rewards": [], "offered_choices": [], "route": [],
        "generation_decisions": [], "rng_state": [], "companion": {},
        "device_carry_over": [], "next_entrance": entrance,
    }


def check_invariants(o, state, where):
    """D1 and N1 to N7 against the committed record and the acknowledgement set."""
    fails = []
    c = o.C
    # D1.5: every acknowledged identity is, or once was, a committed transaction at its generation
    for txn in o.A:
        if txn not in state["committed_txns"]:
            fails.append("D1.5 %s acknowledged without a committed generation" % txn)
    fails.extend(state["boundary_fails"])
    state["boundary_fails"] = []
    # N4 / N5 monotonicity inside one run. A run boundary is checked by boundary_fails, not here,
    # because the two runs have separate histories; N6 and N7 below stay save-wide.
    if c["run"] is not None and c["run"]["run_id"] != state["run_id"]:
        fails.extend(check_boundary(c["run"], state))
    else:
        if state["revival_spent_seen"] and not c["run"]["lifecycle"]["revival_spent"]:
            fails.append("N4 revival_spent regressed")
        if state["terminal_seen"] and not c["run"]["lifecycle"]["terminal"]:
            fails.append("N5 terminal regressed")
        if state["terminal_seen"] and o.restore()["derived_playable"]:
            fails.append("N5 a terminal run derived playable")
        lc = c["run"]["lifecycle"]
        if (lc["outcome"] is not None) != lc["terminal"]:
            fails.append("N5 outcome is not present exactly when terminal")
        if lc["outcome"] is not None and lc["outcome"] not in ("won", "lost"):
            fails.append("N5 outcome outside the enumeration")
        if state["outcome_seen"] is not None and lc["outcome"] != state["outcome_seen"]:
            fails.append("N5 outcome rewritten")
    ck = (c["run"] or {}).get("checkpoint")
    if ck is not None:
        ids = [s["settlement_id"] for s in ck["resolved_rewards"]]
        if len(ids) != len(set(ids)):
            fails.append("N1 duplicate settlement_id in the committed record")
        if not set(state["settlements_seen"]) <= set(ids):
            fails.append("N1 a once-committed settlement_id disappeared")
        inst = [i for s in ck["resolved_rewards"] for i in s["instance_ids"]]
        if len(inst) != len(set(inst)):
            fails.append("N2 an instance_id is claimed twice")
        owned = [o2["instance_id"] for o2 in ck["equipment"]["owned"]]
        if len(owned) != len(set(owned)):
            fails.append("N2 duplicate owned instance_id")
        for off in ck["offered_choices"]:
            prev = state["offers_seen"].get(off["offer_id"])
            if prev is not None and prev != off["option_ids"]:
                fails.append("N3 offer %s rerolled" % off["offer_id"])
            if off["chosen_option_id"] is not None and off["chosen_option_id"] not in off["option_ids"]:
                fails.append("N3 chosen_option_id not among option_ids")
    if c["run"] is not None and c["run"].get("interruption") is not None:
        if c["run"]["lifecycle"]["revival_spent"] is False and state["revival_spent_seen"] \
                and c["run"]["run_id"] == state["run_id"]:
            fails.append("N4 interruption cleared revival_spent")
    for key in ("discoveries", "recipes", "unlocks"):
        v = c["profile"][key]
        if len(v) != len(set(v)):
            fails.append("N7 %s holds a second copy" % key)
        if not set(state["knowledge_seen"][key]) <= set(v):
            fails.append("N7 %s lost a learned entry" % key)
    # N6: one committed generation per distinct transaction identity
    gens = [g for (kind, t, g) in o.log if kind == "commit"]
    if len(gens) != len(set(gens)):
        fails.append("N6 two commits share a generation")
    return ["%s: %s" % (where, f) for f in fails]


def check_boundary(run, state):
    """Transition S is the only way a committed run_id changes. These are its durable conditions."""
    fails = []
    if state["run_id"] is not None and not state["terminal_seen"]:
        fails.append("N5 a new run replaced a live run")
    if run["run_id"] in state["run_ids_seen"]:
        # A property of this replay's history, not a durable gate: the aggregate holds one run, so the
        # contract can only compare a candidate with the committed run_id (HF-07b Transition S validate).
        fails.append("replay history: a run_id recurred after its run was replaced")
    if run["checkpoint"] is not None or run.get("interruption") is not None:
        fails.append("S a started run carries a checkpoint or an interruption")
    lc = run["lifecycle"]
    if lc["revival_spent"] or lc["terminal"] or lc["outcome"] is not None:
        fails.append("S a started run carries a lifecycle fact")
    if not (run.get("start") or {}).get("entrance_id"):
        fails.append("S a started run carries no run.start")
    return fails


def observe(o, state):
    state["committed_txns"].add(o.C["transaction_id"])
    if o.C["run"] is not None and o.C["run"]["run_id"] != state["run_id"]:
        state["boundary_fails"].extend(check_boundary(o.C["run"], state))
        state["run_ids_seen"].add(o.C["run"]["run_id"])
        state["run_id"] = o.C["run"]["run_id"]
        state["revival_spent_seen"] = False
        state["terminal_seen"] = False
        state["outcome_seen"] = None
        state["settlements_seen"] = set()
        state["offers_seen"] = {}
    if o.C["run"] is not None:
        if o.C["run"]["lifecycle"]["revival_spent"]:
            state["revival_spent_seen"] = True
        if o.C["run"]["lifecycle"]["terminal"]:
            state["terminal_seen"] = True
        if o.C["run"]["lifecycle"]["outcome"] is not None:
            state["outcome_seen"] = o.C["run"]["lifecycle"]["outcome"]
        ck = o.C["run"].get("checkpoint")
        if ck is not None:
            for s in ck["resolved_rewards"]:
                state["settlements_seen"].add(s["settlement_id"])
            for off in ck["offered_choices"]:
                state["offers_seen"].setdefault(off["offer_id"], off["option_ids"])
    for key in ("discoveries", "recipes", "unlocks"):
        state["knowledge_seen"][key] |= set(o.C["profile"][key])


def fresh_state(o):
    return {"committed_txns": {o.C["transaction_id"]}, "revival_spent_seen": False,
            "terminal_seen": False, "run_id": o.C["run"]["run_id"],
            "run_ids_seen": {o.C["run"]["run_id"]}, "outcome_seen": None, "boundary_fails": [],
            "settlements_seen": set(), "offers_seen": {},
            "knowledge_seen": {"discoveries": set(), "recipes": set(), "unlocks": set()}}


def apply_policy(o, state, interruption, revival, fails, tag):
    """Apply the candidate policy's durable demand, if it has one, and re-check the invariants.

    P1 writes nothing. P2 and P3 may write a non-null run.checkpoint.interruption. P4 is Transition D.
    R1 to R3 write nothing: revival health and placement are encounter values under every answer.
    """
    if interruption in ("P2", "P3"):
        def mutate(c):
            c["run"]["interruption"] = {"policy_supplied_key": "value"}
        try:
            o.transition(tag + "-int", mutate)
        except HoldError:
            return
        observe(o, state)
        fails.extend(check_invariants(o, state, "%s/%s after interruption record" % (tag, interruption)))
        # a policy that tried to clear a lifecycle flag must be rejected at validate
        def bad(c):
            c["run"]["interruption"] = {"resume": "here"}
            c["run"]["lifecycle"]["revival_spent"] = False
            c["run"]["lifecycle"]["terminal"] = False
        if state["revival_spent_seen"] or state["terminal_seen"]:
            try:
                o.transition(tag + "-bad", bad)
                fails.append("%s/%s: a flag-clearing interruption candidate was not rejected" % (tag, interruption))
            except HoldError:
                pass
            fails.extend(check_invariants(o, state, "%s/%s after rejected clear" % (tag, interruption)))
    elif interruption == "P4":
        if o.C["run"]["lifecycle"]["terminal"]:
            return
        def mutate(c):
            c["run"]["lifecycle"]["terminal"] = True
            c["run"]["lifecycle"]["outcome"] = "lost"
        try:
            o.transition(tag + "-term", mutate)
        except HoldError:
            return
        observe(o, state)
        fails.extend(check_invariants(o, state, "%s/%s after terminal interruption" % (tag, interruption)))


# -- the four tabletop cases ------------------------------------------------------------------------

def case_c1(o, state, fails, fail_at=None):
    """C1 duplicate completion: the same level-completion transaction delivered twice."""
    def complete(entrance, txn):
        def mutate(c):
            ck = c["run"]["checkpoint"] or new_checkpoint(entrance)
            ck["next_entrance"] = entrance
            c["run"]["checkpoint"] = ck
        return mutate
    o.transition("T1", complete("E1", "T1"))
    observe(o, state)
    try:
        o.transition("T2", complete("E2", "T2"), fail_at=fail_at)
    except HoldError as exc:
        # the hold rule: L does not release and the transition is not reported as saved
        if o.playable_released and fail_at in ("stage", "validate", "commit"):
            fails.append("C1 hold: playable state released after a %s failure" % fail_at)
        fails.extend(check_invariants(o, state, "C1 held at %s (%s)" % (fail_at, exc)))
        return
    observe(o, state)
    fails.extend(check_invariants(o, state, "C1 after completion"))
    gen_before = o.C["generation"]
    # the same transaction is delivered again and must converge
    o.stage("T2", complete("E2", "T2"))
    o.validate("T2")
    result = o.commit("T2")
    o.acknowledge("T2")
    if result != "converged":
        fails.append("C1 redelivery did not converge")
    if o.C["generation"] != gen_before:
        fails.append("C1 redelivery advanced the generation")
    observe(o, state)
    fails.extend(check_invariants(o, state, "C1 after redelivery"))


def case_c2(o, state, fails, fail_at=None):
    """C2 revival with an older spatial checkpoint."""
    def banked(c):
        ck = new_checkpoint("E3")
        c["run"]["checkpoint"] = ck
    o.transition("T5", banked)
    observe(o, state)
    older = o.committed()
    try:
        o.transition("T6", lambda c: c["run"]["lifecycle"].__setitem__("revival_spent", True), fail_at=fail_at)
    except HoldError as exc:
        if o.playable_released and fail_at in ("stage", "validate", "commit"):
            fails.append("C2 hold: play resumed through an unproven revival write (%s)" % fail_at)
        fails.extend(check_invariants(o, state, "C2 held at %s (%s)" % (fail_at, exc)))
        return
    observe(o, state)
    if o.C["run"]["checkpoint"]["next_entrance"] != older["run"]["checkpoint"]["next_entrance"]:
        fails.append("C2 the revival transition moved the spatial checkpoint")
    fails.extend(check_invariants(o, state, "C2 after revival"))
    # the older living generation is offered and must be refused
    rejected = False
    try:
        o.stage("T-old", lambda c: (c.update({"generation": older["generation"]}),
                                    c["run"]["lifecycle"].__setitem__("revival_spent", False)))
        o.validate("T-old")
    except HoldError:
        rejected = True
    if not rejected:
        fails.append("C2 an older living generation was accepted over a spent revival")
    fails.extend(check_invariants(o, state, "C2 after refusing the older generation"))


def case_c3(o, state, fails, fail_at=None):
    """C3 terminal defeat."""
    def banked(c):
        c["run"]["checkpoint"] = new_checkpoint("E3")
        c["profile"]["discoveries"] = ["disc-a"]
        c["profile"]["recipes"] = ["rec-a"]
        c["profile"]["unlocks"] = ["unl-a"]
    o.transition("T5", banked)
    observe(o, state)
    o.transition("T6", lambda c: c["run"]["lifecycle"].__setitem__("revival_spent", True))
    observe(o, state)
    def close(c):
        c["run"]["lifecycle"]["terminal"] = True
        c["run"]["lifecycle"]["outcome"] = "lost"
    try:
        o.transition("T7", close, fail_at=fail_at)
    except HoldError as exc:
        if o.playable_released and fail_at in ("stage", "validate", "commit"):
            fails.append("C3 hold: another playable state resumed through an unproven terminal write")
        fails.extend(check_invariants(o, state, "C3 held at %s (%s)" % (fail_at, exc)))
        return
    observe(o, state)
    if o.restore()["derived_playable"]:
        fails.append("C3 a closed run restored playable")
    if o.C["run"] is None:
        fails.append("C3 run was dropped instead of closed")
    for key in ("discoveries", "recipes", "unlocks"):
        if not o.C["profile"][key]:
            fails.append("C3 %s did not survive defeat" % key)
    fails.extend(check_invariants(o, state, "C3 after terminal settlement"))
    rejected = False
    try:
        o.stage("T-living", lambda c: (c.update({"generation": o.C["generation"] - 1}),
                                       c["run"]["lifecycle"].__setitem__("terminal", False)))
        o.validate("T-living")
    except HoldError:
        rejected = True
    if not rejected:
        fails.append("C3 an older living generation reopened a terminal run")
    fails.extend(check_invariants(o, state, "C3 after refusing the living generation"))


def case_c4(o, state, fails, fail_at=None):
    """C4 stable offered-choice restore."""
    o.transition("T8", lambda c: c["run"].__setitem__("checkpoint", new_checkpoint("E4")))
    observe(o, state)
    def offer(c):
        c["run"]["checkpoint"]["offered_choices"] = [
            {"offer_id": "F1", "offer_kind": "world-destination",
             "option_ids": ["dest-a", "dest-b"], "chosen_option_id": None}]
    try:
        o.transition("T9", offer, fail_at=fail_at)
    except HoldError as exc:
        fails.extend(check_invariants(o, state, "C4 held at %s (%s)" % (fail_at, exc)))
        return
    observe(o, state)
    restored = o.restore()["run"]["checkpoint"]["offered_choices"][0]
    if restored["option_ids"] != ["dest-a", "dest-b"]:
        fails.append("C4 the restored offer changed its options")
    fails.extend(check_invariants(o, state, "C4 after the offer commits"))
    # a reroll attempt must be rejected
    rejected = False
    try:
        o.stage("T-reroll", lambda c: c["run"]["checkpoint"]["offered_choices"].__setitem__(
            0, {"offer_id": "F1", "offer_kind": "world-destination",
                "option_ids": ["dest-c", "dest-d"], "chosen_option_id": None}))
        o.validate("T-reroll")
    except HoldError:
        rejected = True
    if not rejected:
        fails.append("C4 a rerolled offer was accepted")
    # the player chooses a stored option
    def choose(c):
        c["run"]["checkpoint"]["offered_choices"][0]["chosen_option_id"] = "dest-b"
        c["run"]["checkpoint"]["route"] = [{"sequence": 0, "destination_id": "dest-b", "offer_id": "F1"}]
    o.transition("T10", choose)
    observe(o, state)
    fails.extend(check_invariants(o, state, "C4 after the choice commits"))
    # a choice outside the stored options must be rejected
    rejected = False
    try:
        o.stage("T-bad", lambda c: c["run"]["checkpoint"]["offered_choices"][0].__setitem__(
            "chosen_option_id", "dest-z"))
        o.validate("T-bad")
    except HoldError:
        rejected = True
    if not rejected:
        fails.append("C4 a choice outside the stored options was accepted")
    fails.extend(check_invariants(o, state, "C4 after refusing an invalid choice"))


def new_run(run_id, character, entrance):
    return {"run_id": run_id,
            "start": {"character_id": character, "entrance_id": entrance, "rng_state": []},
            "checkpoint": None, "interruption": None,
            "lifecycle": {"revival_spent": False, "terminal": False, "outcome": None}}


def case_c5(o, state, fails, fail_at=None):
    """C5 run start after terminal defeat, then after a won run."""
    o.transition("T5", lambda c: c["run"].__setitem__("checkpoint", new_checkpoint("E3")))
    observe(o, state)
    o.transition("T6", lambda c: c["run"]["lifecycle"].__setitem__("revival_spent", True))
    observe(o, state)

    def close(c):
        c["run"]["lifecycle"]["terminal"] = True
        c["run"]["lifecycle"]["outcome"] = "lost"
    o.transition("T7", close)
    observe(o, state)
    fails.extend(check_invariants(o, state, "C5 after the terminal close"))
    closed = o.committed()

    try:
        o.transition("T11", lambda c: c.__setitem__("run", new_run("run-2", "chr-b", "E0")),
                     fail_at=fail_at)
    except HoldError as exc:
        if o.playable_released and fail_at in ("stage", "validate", "commit"):
            fails.append("C5 hold: a new run was presented as started after a %s failure" % fail_at)
        if fail_at in ("stage", "validate", "commit"):
            if o.C["run"]["run_id"] != closed["run"]["run_id"] or not o.C["run"]["lifecycle"]["terminal"]:
                fails.append("C5 hold: the committed run changed while the start was held")
        if o.C["transaction_id"] == "T11":
            observe(o, state)  # the commit landed and only the acknowledge failed
        fails.extend(check_invariants(o, state, "C5 held at %s (%s)" % (fail_at, exc)))
        return
    observe(o, state)
    if o.C["run"]["run_id"] != "run-2":
        fails.append("C5 the new run did not become the committed run")
    if o.C["run"]["checkpoint"] is not None or o.C["run"]["interruption"] is not None:
        fails.append("C5 a started run committed a checkpoint or an interruption")
    if not o.restore()["derived_playable"]:
        fails.append("C5 the started run did not restore playable")
    for key in ("discoveries", "recipes", "unlocks"):
        if not set(state["knowledge_seen"][key]) <= set(o.C["profile"][key]):
            fails.append("C5 %s did not survive the run boundary" % key)
    fails.extend(check_invariants(o, state, "C5 after the run start"))

    # a start over the live run is refused, whatever identity it carries
    for txn, rid in (("T12", "run-3"), ("T13", "run-1")):
        rejected = False
        try:
            o.stage(txn, lambda c, r=rid: c.__setitem__("run", new_run(r, "chr-c", "E0")))
            o.validate(txn)
        except HoldError:
            rejected = True
        if not rejected:
            fails.append("C5 a run start was admitted over a live run (%s)" % rid)
    fails.extend(check_invariants(o, state, "C5 after refusing a start over a live run"))

    # the same admission rule covers a won run, and a closed identity is never reused
    def win(c):
        c["run"]["lifecycle"]["terminal"] = True
        c["run"]["lifecycle"]["outcome"] = "won"
    o.transition("T14", win)
    observe(o, state)
    if o.restore()["derived_playable"]:
        fails.append("C5 a won run restored playable")
    fails.extend(check_invariants(o, state, "C5 after the victory close"))
    rejected = False
    try:
        o.stage("T15", lambda c: c.__setitem__("run", new_run("run-2", "chr-d", "E0")))
        o.validate("T15")
    except HoldError:
        rejected = True
    if not rejected:
        fails.append("C5 a run start carrying the committed run_id was admitted")
    o.transition("T16", lambda c: c.__setitem__("run", new_run("run-4", "chr-d", "E0")))
    observe(o, state)
    if not o.restore()["derived_playable"]:
        fails.append("C5 a run started after a won run did not restore playable")
    fails.extend(check_invariants(o, state, "C5 after a run start over a won run"))


CASE_FNS = {"C1": case_c1, "C2": case_c2, "C3": case_c3, "C4": case_c4, "C5": case_c5}


def replay(check):
    """Replay every tabletop case under every candidate policy combination and failure injection."""
    fails = []
    runs = 0
    for interruption in INTERRUPTION_POLICIES:
        for revival in REVIVAL_POLICIES:
            for case in ("C1", "C2", "C3", "C4", "C5"):
                for fail_at in (None, "stage", "validate", "commit", "acknowledge"):
                    o = Owner()
                    state = fresh_state(o)
                    tag = "%s/%s/%s/%s" % (case, interruption, revival, fail_at or "clean")
                    local = []
                    try:
                        CASE_FNS[case](o, state, local, fail_at=fail_at)
                        apply_policy(o, state, interruption, revival, local, tag)
                    except HoldError as exc:
                        local.append("%s: unexpected hold %s" % (tag, exc))
                    except Exception as exc:  # noqa: BLE001 - surfaced as a failed check
                        local.append("%s: model error %r" % (tag, exc))
                    fails.extend("%s :: %s" % (tag, f) for f in local)
                    runs += 1
    check.record("model replay: %d runs over %d policy combinations" % (runs, len(INTERRUPTION_POLICIES) * len(REVIVAL_POLICIES)),
                 not fails, "; ".join(fails[:12]))
    return runs, fails


def self_test(check):
    """Negative controls. A checker that cannot fail proves nothing, so each control removes one gate the
    section specifies and asserts the replay notices. The model is restored after each control."""
    controls = []

    def run_once(case, interruption="P2", revival="R1"):
        o, fails = Owner(), []
        state = fresh_state(o)
        try:
            CASE_FNS[case](o, state, fails, fail_at=None)
            apply_policy(o, state, interruption, revival, fails, "selftest")
        except HoldError as exc:
            fails.append("unexpected hold %s" % exc)
        except Exception as exc:  # noqa: BLE001
            fails.append("model error %r" % exc)
        return fails

    original_validate, original_ack = Owner.validate, Owner.acknowledge

    def no_monotonic(self, txn, extra=None, fail=False):
        cand = self.S.get(txn)
        if cand is not None and txn != self.C["transaction_id"] and cand["generation"] > self.C["generation"]:
            self.eligible = ("ok", txn)
            return "ok"
        return original_validate(self, txn, extra, fail)

    def no_generation_gate(self, txn, extra=None, fail=False):
        cand = self.S.get(txn)
        if cand is not None and txn != self.C["transaction_id"]:
            self.eligible = ("ok", txn)
            return "ok"
        return original_validate(self, txn, extra, fail)

    def ack_without_commit(self, txn, fail=False):
        self.A.add(txn)
        self.pending = None
        self.playable_released = True
        return "ok"

    for name, target, patch, case in [
        ("N4/N5 monotonicity gate removed", "validate", no_monotonic, "C2"),
        ("D1.4 generation gate removed", "validate", no_generation_gate, "C3"),
    ]:
        setattr(Owner, target, patch)
        try:
            found = run_once(case)
        finally:
            setattr(Owner, "validate", original_validate)
            setattr(Owner, "acknowledge", original_ack)
        controls.append({"control": name, "case": case, "detected": bool(found), "sample": found[:2]})
        check.record("negative control detects %s" % name, bool(found),
                     "no failure reported" if not found else found[0])

    # D1.1 needs its own probe: on the specified protocol a commit failure never reaches acknowledge, so
    # the control has to attempt the acknowledge the gate is there to refuse.
    def probe_ack():
        o, fails = Owner(), []
        state = fresh_state(o)
        o.stage("T1", lambda c: c["run"].__setitem__("checkpoint", new_checkpoint("E1")))
        o.validate("T1")
        try:
            o.commit("T1", fail=True)
        except HoldError:
            pass
        try:
            o.acknowledge("T1")
        except HoldError:
            pass
        fails.extend(check_invariants(o, state, "probe: acknowledge after a failed commit"))
        if o.playable_released:
            fails.append("probe: playable state released after a failed commit")
        return fails

    baseline = probe_ack()
    check.record("D1.1 refuses an acknowledge after a failed commit", not baseline,
                 "; ".join(baseline[:2]))
    setattr(Owner, "acknowledge", ack_without_commit)
    try:
        found = probe_ack()
    finally:
        setattr(Owner, "acknowledge", original_ack)
    controls.append({"control": "D1.1 acknowledge gate removed", "case": "probe",
                     "detected": bool(found), "sample": found[:2]})
    check.record("negative control detects D1.1 acknowledge gate removed", bool(found),
                 "no failure reported" if not found else found[0])
    return controls


def main():
    ap = argparse.ArgumentParser(description="HF-07b commit-boundary paper check")
    ap.add_argument("root", help="repository root holding docs/tech/sections/")
    ap.add_argument("--out", required=True, help="directory for paper-check.json and source-manifest.json")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    check = Check(root)

    if not (root / SECTION).is_file():
        print("missing section: %s" % SECTION, file=sys.stderr)
        return 2
    text = check.read(SECTION)
    lines = text.split("\n")

    # 1. required headings
    present = {re.sub(r"^#{1,6}\s+", "", l).strip() for l in lines if l.startswith("#")}
    for h in HEADINGS:
        check.record("heading: %s" % h, h in present)

    # 2. declared dependency bytes match the files, and are stated in the section
    for rel, digest in DECLARED_SHA.items():
        p = root / rel
        actual = sha256(p) if p.is_file() else "missing"
        check.record("dependency bytes: %s" % rel, actual == digest,
                     "declared %s actual %s" % (digest, actual))
        if rel in (HF07A_MD, HF07A_CSV, HF04A_MD, "docs/tech/sections/HF-03a-module-map.md"):
            check.record("section states %s SHA256" % rel, digest in text)

    # 3. every cited line exists and carries the clause it is cited for
    cache = {}
    bad = []
    for rel, lineno, needle in CITATIONS:
        if rel not in cache:
            p = root / rel
            cache[rel] = p.read_text(encoding="utf-8").split("\n") if p.is_file() else None
        src = cache[rel]
        if src is None:
            bad.append("%s missing" % rel)
        elif lineno > len(src):
            bad.append("%s:%d out of range" % (rel, lineno))
        elif needle not in src[lineno - 1]:
            bad.append("%s:%d lacks %r" % (rel, lineno, needle))
    check.record("citation anchors: %d checked" % len(CITATIONS), not bad, "; ".join(bad[:8]))

    # 4. the four transitions, each with a four-item numbered stage list in order
    for title, tid in TRANSITIONS.items():
        start, end = heading_span(lines, title)
        if not check.record("transition heading: %s" % title, start is not None):
            continue
        items = numbered_items(lines, start, end)
        ok = [n for n, _ in items] == [1, 2, 3, 4]
        check.record("transition %s has a four-item numbered stage list" % tid, ok,
                     "numbers %s" % [n for n, _ in items])
        if not ok:
            continue
        for idx, name in enumerate(STAGE_NAMES):
            body = items[idx][1]
            check.record("transition %s stage %d is %s" % (tid, idx + 1, name),
                         body.startswith("**%s.**" % name), body[:60])
            check.record("transition %s stage %d names before and after" % (tid, idx + 1),
                         "*Before" in body and "*After" in body or "*Before and after:*" in body,
                         body[:80])

    # 5. observables, gates, seams, invariants, policies
    for token in ["`C`", "`S`", "`A`", "`L`"]:
        check.record("observable %s defined" % token, text.count(token) >= 3)
    for g in GATES:
        check.record("gate %s present" % g, ("| %s |" % g) in text)
    for s in SEAMS:
        check.record("seam %s present" % s, ("| %s |" % s) in text)
    for n in INVARIANTS:
        check.record("invariant %s present" % n, ("| %s |" % n) in text)
    for p in INTERRUPTION_POLICIES + REVIVAL_POLICIES:
        check.record("policy %s present" % p, ("| %s |" % p) in text)
    # FR-05 re-pins the three labelling checks: Q-P16, Q-P39 and Q-E09 are resolved at TRACKING
    # EV-0247 and EV-0250, so the section must now carry the adopted answers explicitly and mark the
    # candidates it rejected as retained history. The strictness is unchanged; the expected strings are.
    for adopted in ("| P1 |", "| R2 |"):
        row = [l for l in lines if l.startswith(adopted)]
        check.record("policy %s marked adopted" % adopted.strip("| "),
                     bool(row) and "**Adopted**" in row[0], row[:1])
    for rejected in ("| P2 |", "| P3 |", "| P4 |", "| R1 |", "| R3 |"):
        row = [l for l in lines if l.startswith(rejected)]
        check.record("policy %s marked rejected and retained" % rejected.strip("| "),
                     bool(row) and "Rejected, retained as history" in row[0], row[:1])
    check.record("Q-E09 adopted rule stated", "commit only at the next durable transition" in text
                 and "no immediate discovery transition" in text)
    check.record("Q-P39 abandonment ordering stated",
                 "two transactions and two generations" in text
                 and "no candidate may both close a run and start another" in text)
    # No question that is still open may be answered here: Q-P32's bounds and the revival health value
    # in particular. The three resolved answers are required above rather than forbidden.
    open_answer = re.findall(r"Q-(?:P32|P12|P14|P15|P37) is (?:now )?(?:answered|resolved)"
                             r"|this section sets the (?:bound|health value)"
                             r"|the revival health value is \d", text)
    check.record("no answer to a question that is still open", not open_answer, "%s" % open_answer[:3])

    # 6. the invariant-by-policy matrix has a filled cell for every invariant and policy column
    m_start = text.find("### The invariants under the adopted policy and every candidate it replaced")
    m_end = text.find("### Two decisions this card owns")
    matrix = text[m_start:m_end] if m_start > 0 and m_end > m_start else ""
    for n in INVARIANTS:
        row = [l for l in matrix.split("\n") if l.startswith("| %s |" % n)]
        cells = [c.strip() for c in row[0].strip("|").split("|")] if row else []
        check.record("matrix row %s covers P1 to P4 and R1 to R3" % n,
                     len(cells) == 6 and all(cells), "cells %d" % len(cells))

    # 7. the four tabletop cases as step tables
    for title, cid in CASES.items():
        start, end = heading_span(lines, title)
        if not check.record("tabletop case heading: %s" % title, start is not None):
            continue
        block = "\n".join(lines[start:end])
        header = [l for l in block.split("\n") if l.startswith("| Step |")]
        check.record("case %s is a step table" % cid, bool(header), header[:1])
        if header:
            cols = [c.strip() for c in header[0].strip("|").split("|")]
            for want in ("Step", "Stage", "Action"):
                check.record("case %s table has a %s column" % (cid, want), want in cols)
            check.record("case %s table names the committed record after each step" % cid,
                         any("`C` after" in c for c in cols), cols)
            check.record("case %s table names the invariant checked" % cid,
                         any("Invariant" in c for c in cols), cols)
        rows = [l for l in block.split("\n") if re.match(r"^\| %s\.\d" % cid, l)]
        check.record("case %s has at least six step rows" % cid, len(rows) >= 6, "rows %d" % len(rows))
        check.record("case %s states its result under every candidate policy" % cid,
                     "Under every candidate policy" in block)

    # 8. every field name the section mentions exists in the admitted HF-07a CSV.
    #    check:docs reads only .md files, so this is the only parity coverage the CSV gets.
    csv_path = root / HF07A_CSV
    known = set()
    with csv_path.open(encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            known.add(row["field"])
    check.record("HF-07a CSV holds 70 fields", len(known) == 70, "found %d" % len(known))
    # The disclaimer sentence is excluded from the resolution check and checked separately below.
    disclaimer_line = next((l for l in lines if DISCLAIMER in l), "")
    check.record("section disclaims the three unrowed containers", bool(disclaimer_line))
    body = text.replace(disclaimer_line, "") if disclaimer_line else text
    mentioned = set()
    for m in FIELD_RE.finditer(body):
        name = m.group(1)
        if name.endswith("[]"):
            name = name[:-2]
        mentioned.add(name)
    unknown = sorted(n for n in mentioned if n not in known)
    check.record("every field name resolves in the HF-07a CSV (%d mentioned)" % len(mentioned),
                 not unknown, "unknown: %s" % unknown[:8])
    for required in ["run.interruption", "run.lifecycle.revival_spent", "run.lifecycle.terminal",
                     "run.checkpoint.resolved_rewards", "run.checkpoint.offered_choices",
                     "run.checkpoint.next_entrance", "generation", "transaction_id",
                     "schema_version", "content_revision"]:
        check.record("uses HF-07a field %s" % required, required in mentioned)

    # 9. the section asks for no rejected envelope key and depends on no open shape
    for token in FORBIDDEN_TOKENS:
        check.record("no rejected envelope key %s" % token, token not in text)
    for token in NON_DEPENDENCIES:
        check.record("no dependency on %s" % token.strip("`"), token not in text)
    for token in DISCLAIMED_CONTAINERS:
        occurrences = len(re.findall(re.escape("`%s`" % token), text))
        in_disclaimer = len(re.findall(re.escape("`%s`" % token), disclaimer_line))
        check.record("container %s named only in the disclaimer" % token,
                     occurrences > 0 and occurrences == in_disclaimer,
                     "%d total, %d in the disclaimer" % (occurrences, in_disclaimer))
    check.record("acknowledgement decision stated",
                 "Acknowledgement leaves no durable trace" in text and "S0-08" in text)
    check.record("preferences write decision stated",
                 "A preferences write is not a gameplay commit" in text)
    check.record("S0-08 re-verify trigger reconciled",
                 "S0-08 reconciliation" in text and "without executing anything" in text)
    check.record("evidence limits refuse implementation claims",
                 "A specified stage is not an implemented stage" in text)

    # 10. replay the model, then prove the replay can fail
    runs, replay_fails = replay(check)
    controls = self_test(check)

    manifest = {}
    for rel in sorted(set(list(DECLARED_SHA) + [SECTION] + [c[0] for c in CITATIONS])):
        p = root / rel
        manifest[rel] = sha256(p) if p.is_file() else "missing"

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    report = {
        "check": "HF-07b commit boundaries",
        "generated_utc": stamp,
        "root": str(root),
        "section": SECTION,
        "section_sha256": sha256(root / SECTION),
        "checks": len(check.results),
        "failed": check.failed,
        "model_runs": runs,
        "model_failures": replay_fails,
        "negative_controls": controls,
        "results": check.results,
        "limits": ("Documentation only. This replays a model of the specified protocol, not the protocol. "
                   "It runs no build, opens no save file and establishes no engine behaviour."),
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (out / "source-manifest.json").write_text(
        json.dumps({"generated_utc": stamp, "root": str(root), "sha256": manifest}, indent=2) + "\n",
        encoding="utf-8")
    for r in check.results:
        if r["status"] == "fail":
            print("FAIL %s :: %s" % (r["check"], r["detail"]))
    print("HF-07b paper check: %d checks, %d failed, %d model runs" % (len(check.results), check.failed, runs))
    print("receipts: %s" % out)
    return 1 if check.failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 - internal error exit code
        print("internal error: %r" % exc, file=sys.stderr)
        sys.exit(2)
