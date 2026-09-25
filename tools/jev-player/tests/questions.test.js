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
