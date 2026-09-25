// Offline tests for the versioned question sets. A question set is part of the
// instrument: new wording has to arrive as a new pinned file, never as an edit.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildQuestions,
  CONFIDENCE_FLOOR,
  GATE_VERSION,
  instrumentIdentity,
  INTENTS,
  loadQuestionSet,
  QUESTIONS_DIR,
} from "../decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const index = JSON.parse(
  readFileSync(path.join(QUESTIONS_DIR, "INDEX.json"), "utf8"),
);
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const allOptions = Object.entries(INTENTS).map(([id, why]) => ({ id, why }));

test("every published question file matches the sha256 pinned in INDEX.json", () => {
  for (const [version, entry] of Object.entries(index)) {
    const bytes = readFileSync(path.join(QUESTIONS_DIR, entry.file));
    assert.equal(
      sha256(bytes),
      entry.sha256,
      `${entry.file} changed after publication; new wording needs a new file`,
    );
    assert.equal(JSON.parse(bytes).version, version);
  }
});

test("no question file sits in questions/ without a pin", () => {
  const pinned = new Set(Object.values(index).map((entry) => entry.file));
  const files = readdirSync(QUESTIONS_DIR).filter(
    (name) => name.endsWith(".json") && name !== "INDEX.json",
  );
  assert.ok(files.length > 0);
  for (const name of files) {
    assert.ok(pinned.has(name), `${name} is not pinned in INDEX.json`);
  }
});

test("q1-original is retracted as leading and carries every field", () => {
  const q1 = loadQuestionSet("q1-original");
  assert.equal(q1.version, "q1-original");
  assert.equal(q1.status, "retracted-leading");
  for (const field of ["intent", "danger", "greedy", "rationale"]) {
    assert.ok(q1[field] !== undefined, `q1 lacks ${field}`);
  }
  assert.equal(q1.sha, index["q1-original"].sha256);
});

test("a question file whose bytes drift from its pin refuses to load", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "jev-questions-"));
  const original = readFileSync(
    path.join(QUESTIONS_DIR, "q1-original.json"),
    "utf8",
  );
  writeFileSync(
    path.join(dir, "q1-original.json"),
    original.replace("roguelite", "rogue-lite"),
  );
  writeFileSync(path.join(dir, "INDEX.json"), JSON.stringify(index));
  assert.throws(() => loadQuestionSet("q1-original", dir), /sha256/);
});

test("an unpinned version refuses to load", () => {
  assert.throws(() => loadQuestionSet("q9-unpublished"), /not pinned/);
});

test("q1 builds exactly the questions the pre-versioning code sent (prompt snapshot)", () => {
  const snapshot = readFileSync(
    path.join(here, "fixtures", "q1-built.json"),
    "utf8",
  );
  const built = buildQuestions(allOptions, loadQuestionSet("q1-original"));
  assert.equal(JSON.stringify(built, null, 2) + "\n", snapshot);
  assert.equal(
    JSON.stringify(buildQuestions(allOptions), null, 2) + "\n",
    snapshot,
  );
});

// One built-prompt snapshot per pinned set, so a new set cannot land without one.
const SNAPSHOTS = {
  "q1-original": "q1-built.json",
  "q2-neutral": "q2-built.json",
};

test("every pinned question set has a built-prompt snapshot", () => {
  assert.deepEqual(Object.keys(SNAPSHOTS).sort(), Object.keys(index).sort());
});

test("q2 builds exactly its pinned prompt (prompt snapshot)", () => {
  const snapshot = readFileSync(
    path.join(here, "fixtures", SNAPSHOTS["q2-neutral"]),
    "utf8",
  );
  const built = buildQuestions(allOptions, loadQuestionSet("q2-neutral"));
  assert.equal(JSON.stringify(built, null, 2) + "\n", snapshot);
});

test("q2-neutral is a pinned candidate with every field and the q1 question types", () => {
  const q2 = loadQuestionSet("q2-neutral");
  assert.equal(q2.version, "q2-neutral");
  assert.equal(q2.status, "candidate");
  for (const field of ["intent", "danger", "greedy", "rationale"]) {
    assert.ok(q2[field] !== undefined, `q2 lacks ${field}`);
  }
  assert.equal(q2.sha, index["q2-neutral"].sha256);
  assert.equal(q2.intent.type, "choice");
  assert.equal(q2.danger.type, "score");
  assert.equal(q2.danger.criteria.length, 3);
  assert.equal(q2.greedy.type, "noul");
  for (const field of ["intent", "danger", "greedy"]) {
    assert.equal(typeof q2.rationale[field], "string");
  }
});

// A lexical guard only: it catches the known valuation phrases and their
// relatives, not every way a sentence can lead.
test("q2-neutral's asked text states rules without valuing any option", () => {
  const q2 = loadQuestionSet("q2-neutral");
  const asked = JSON.stringify([q2.intent, q2.danger, q2.greedy]).toLowerCase();
  for (const phrase of [
    "worth",
    "costs you",
    "bought nothing",
    "never free",
    "best",
    "better",
    "should",
    "waste",
    "cheap",
    "expensive",
    "valu",
    "optimi",
    "free to",
    "matters",
    "makes combat possible",
    "cost more",
  ]) {
    assert.ok(!asked.includes(phrase), `q2 asks with "${phrase}"`);
  }
});

test("instrumentIdentity names the question sha, model, floor and gate version", () => {
  const identity = instrumentIdentity();
  assert.deepEqual(Object.keys(identity).sort(), [
    "confidence_floor",
    "gate_version",
    "model",
    "questions_sha",
  ]);
  assert.equal(identity.questions_sha, index["q1-original"].sha256);
  assert.equal(identity.confidence_floor, CONFIDENCE_FLOOR);
  assert.equal(identity.gate_version, GATE_VERSION);
  assert.equal(typeof identity.model, "string");
});
