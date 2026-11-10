import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import {
  applyTags,
  buildRequest,
  cacheKey,
  loadVocab,
  redact,
  tagVerdicts,
} from "../scripts/lab/verdict-tags.mjs";
import { openVerdictCache } from "../scripts/lab/verdict-cache.mjs";
import { validateVerdicts } from "../scripts/lab/verdicts.mjs";
import { shallowClone } from "./preconditions.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REAL_FILE = path.join(root, "docs/playtests/verdicts.ndjson");
const REAL_LOG = path.join(root, "docs/playtests/PLAYTEST-LOG.md");
const VOCAB_FILE = path.join(root, "scripts/lab/verdict-tags.json");

function deepFreeze(value) {
  if (value !== null && typeof value === "object") {
    for (const inner of Object.values(value)) {
      deepFreeze(inner);
    }
    Object.freeze(value);
  }
  return value;
}

async function realRecords() {
  const text = await readFile(REAL_FILE, "utf8");
  return text
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map((line) => JSON.parse(line));
}

// The tagging-behaviour tests need a hand label per record. New playtest
// entries arrive unlabelled, and "an entry with no hand label is never filled"
// covers those separately.
async function labelledRecords(vocab) {
  return (await realRecords()).filter((record) => vocab.hand_labels.entries[String(record.entry)]);
}

async function scratch(t) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-verdict-tags-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

// A fake Jev: answers every Noul from a table keyed by entry quote and tag,
// optionally skewed by question order, and records each request it saw.
function fakeJev(table, { skew = 0, model = "jev-test-1.0.0" } = {}) {
  const seen = [];
  const call = async (request) => {
    seen.push(request);
    const ids = Object.keys(request.questions);
    const answers = {};
    ids.forEach((id, index) => {
      const base = table[request.state.verdict]?.[id] ?? 0.1;
      // Earlier questions drift up by `skew`, so forward and reverse differ.
      const shifted = base + (index < ids.length / 2 ? skew : -skew);
      answers[id] = { type: "noul", noul: Math.min(1, Math.max(0, shifted)) };
    });
    return { answers, model, usage: { input_tokens: 100, output_tokens: 7 } };
  };
  return { call, seen };
}

function tableFromLabels(records, vocab, flips = {}) {
  const table = {};
  for (const record of records) {
    const labels = vocab.hand_labels.entries[String(record.entry)];
    table[record.quote] = {};
    for (const tag of vocab.tags) {
      const hand = labels[tag.id];
      const flipped = flips[record.entry]?.includes(tag.id) ? !hand : hand;
      table[record.quote][tag.id] = flipped ? 0.9 : 0.1;
    }
  }
  return table;
}

test("the vocabulary is fixed: 5 to 8 unique tags, each a complete Noul", () => {
  const vocab = loadVocab(VOCAB_FILE);
  assert.ok(vocab.tags.length >= 5 && vocab.tags.length <= 8, `${vocab.tags.length} tags`);
  const ids = vocab.tags.map((tag) => tag.id);
  assert.equal(new Set(ids).size, ids.length, "tag ids are unique");
  for (const tag of vocab.tags) {
    assert.match(tag.id, /^[a-z_]+$/);
    assert.ok(tag.instructions.includes("`verdict`"), `${tag.id} names the state field`);
    assert.equal(typeof tag.criteria.true, "string");
    assert.equal(typeof tag.criteria.false, "string");
  }
  assert.equal(vocab.decision.yes_at_or_above, 0.5);
  assert.match(vocab.sha, /^[0-9a-f]{64}$/);
});

test("entries 1 and 2 carry a boolean hand label for every tag", () => {
  const vocab = loadVocab(VOCAB_FILE);
  for (const entry of ["1", "2"]) {
    const labels = vocab.hand_labels.entries[entry];
    assert.ok(labels, `entry ${entry} is hand-labelled`);
    assert.deepEqual(Object.keys(labels).sort(), vocab.tags.map((tag) => tag.id).sort());
    for (const value of Object.values(labels)) {
      assert.equal(typeof value, "boolean");
    }
  }
});

test("redaction masks secrets and one-time codes and leaves the real quotes alone", async () => {
  const leaked = redact(
    "key TYPESAFE_API_KEY=abc123def456 then Bearer sk-live-0123456789abcdefghijABCDEFGHIJ " +
      "mail me at someone@example.com, code 482913",
  );
  assert.equal(leaked.redactions, 4);
  assert.doesNotMatch(leaked.text, /abc123def456|sk-live|someone@example\.com|482913/);

  for (const record of await realRecords()) {
    const clean = redact(record.quote);
    assert.equal(clean.text, record.quote);
    assert.equal(clean.redactions, 0);
  }
});

test("a request holds one Noul per tag, in fixed forward or exact reverse order", () => {
  const vocab = loadVocab(VOCAB_FILE);
  const ids = vocab.tags.map((tag) => tag.id);
  const forward = buildRequest("some words", vocab, "forward");
  const reverse = buildRequest("some words", vocab, "reverse");

  assert.equal(forward.model, "jev-latest");
  assert.deepEqual(forward.state, { verdict: "some words" });
  assert.deepEqual(Object.keys(forward.questions), ids);
  assert.deepEqual(Object.keys(reverse.questions), [...ids].reverse());
  for (const tag of vocab.tags) {
    assert.deepEqual(forward.questions[tag.id], {
      type: "noul",
      instructions: tag.instructions,
      criteria: tag.criteria,
    });
  }
  assert.notEqual(cacheKey(forward), cacheKey(reverse));
  assert.match(cacheKey(forward), /^[0-9a-f]{64}$/);
  assert.equal(JSON.stringify(forward).includes("Bearer"), false);
});

test("the request carries the redacted quote, never the raw one", () => {
  const vocab = loadVocab(VOCAB_FILE);
  const request = buildRequest("fun, reach me at someone@example.com", vocab, "forward");
  assert.doesNotMatch(request.state.verdict, /someone@example\.com/);
});

test("entries that reproduce their hand labels get tags; a disagreement leaves tags empty and is reported", async (t) => {
  const vocab = deepFreeze(loadVocab(VOCAB_FILE));
  const records = await labelledRecords(vocab);
  const table = tableFromLabels(records, vocab, { 2: ["pacing"] });
  const jev = fakeJev(table);
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));

  const run = await tagVerdicts({ records, vocab, call: jev.call, cache });

  assert.equal(jev.seen.length, 4, "two orders for each of two entries");
  const one = run.entries.find((result) => result.entry === 1);
  const two = run.entries.find((result) => result.entry === 2);

  assert.equal(one.outcome, "reproduced");
  assert.deepEqual(one.tags, ["level_shape", "exploration"]);
  assert.deepEqual(one.disagreements, []);

  assert.equal(two.outcome, "disagrees");
  assert.equal(two.tags, undefined);
  assert.equal(two.disagreements.length, 1);
  const [miss] = two.disagreements;
  assert.equal(miss.id, "pacing");
  assert.equal(miss.hand, false);
  assert.equal(miss.jev, true);
  assert.equal(miss.forward, 0.9);
  assert.equal(miss.reverse, 0.9);
  assert.equal(miss.mean, 0.9);

  // Every tag reports both orders and the mean, agreeing or not.
  assert.equal(two.per_tag.length, vocab.tags.length);
  assert.deepEqual(run.usage, { input_tokens: 400, output_tokens: 28 });
  assert.deepEqual(run.models, ["jev-test-1.0.0"]);
});

test("forward and reverse are averaged and their gap is reported per tag", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = (await realRecords()).filter((record) => record.entry === 1);
  const jev = fakeJev(tableFromLabels(records, vocab), { skew: 0.05 });
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));

  const run = await tagVerdicts({ records, vocab, call: jev.call, cache });
  const [result] = run.entries;
  const first = result.per_tag.find((row) => row.id === vocab.tags[0].id);
  // First tag is early in forward order (+skew) and late in reverse (-skew).
  assert.ok(Math.abs(first.forward - 0.15) < 1e-9);
  assert.ok(Math.abs(first.reverse - 0.05) < 1e-9);
  assert.ok(Math.abs(first.mean - 0.1) < 1e-9);
  assert.ok(Math.abs(first.order_gap - 0.1) < 1e-9);
  assert.ok(Math.abs(run.max_order_gap - 0.1) < 1e-9);
});

test("a second run is served from the cache and makes no calls", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = await labelledRecords(vocab);
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));
  const first = fakeJev(tableFromLabels(records, vocab));
  await tagVerdicts({ records, vocab, call: first.call, cache });

  const second = fakeJev(tableFromLabels(records, vocab));
  const run = await tagVerdicts({ records, vocab, call: second.call, cache });
  assert.equal(second.seen.length, 0);
  assert.equal(run.calls, 0);
  assert.equal(run.cache_hits, 4);
  assert.ok(run.entries.every((result) => result.outcome === "reproduced"));
});

test("the call cap stops live calls and the capped entry falls back untouched", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = await labelledRecords(vocab);
  const jev = fakeJev(tableFromLabels(records, vocab));
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));

  const run = await tagVerdicts({ records, vocab, call: jev.call, cache, maxCalls: 3 });
  assert.equal(jev.seen.length, 3);
  const two = run.entries.find((result) => result.entry === 2);
  assert.equal(two.outcome, "fallback");
  assert.match(two.reason, /cap of 3/);
  assert.equal(two.tags, undefined);
});

test("a Jev failure or no caller falls back: tags untouched, reason given", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = await labelledRecords(vocab);
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));

  const failing = async () => {
    throw new Error("Jev 503: unavailable");
  };
  const broken = await tagVerdicts({ records, vocab, call: failing, cache });
  assert.ok(broken.entries.every((result) => result.outcome === "fallback"));
  assert.match(broken.entries[0].reason, /Jev 503/);

  const offline = await tagVerdicts({ records, vocab, call: null, cache });
  assert.ok(offline.entries.every((result) => result.outcome === "fallback"));
  assert.match(offline.entries[0].reason, /no live call/);
});

test("a malformed answer falls back instead of guessing", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = (await realRecords()).filter((record) => record.entry === 1);
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));
  const bad = async () => ({ answers: {}, model: "jev-x", usage: { input_tokens: 1, output_tokens: 1 } });
  const run = await tagVerdicts({ records, vocab, call: bad, cache });
  assert.equal(run.entries[0].outcome, "fallback");
  assert.match(run.entries[0].reason, /no Noul/);
});

test("an entry with no hand label is never filled", async (t) => {
  const vocab = loadVocab(VOCAB_FILE);
  const records = [{ entry: 3, build_sha: "0".repeat(40), anchor: "x#y", quote: "\"it rolls\"", tags: [] }];
  const jev = fakeJev({});
  const cache = openVerdictCache(path.join(await scratch(t), "cache"));
  const run = await tagVerdicts({ records, vocab, call: jev.call, cache });
  assert.equal(jev.seen.length, 0);
  assert.equal(run.entries[0].outcome, "unlabelled");
  assert.equal(run.entries[0].tags, undefined);
});

test("applyTags changes only the tags of reproduced entries and the file still validates", { skip: shallowClone }, async (t) => {
  const original = await readFile(REAL_FILE, "utf8");
  const run = {
    entries: [
      { entry: 1, outcome: "reproduced", tags: ["level_shape", "exploration"] },
      { entry: 2, outcome: "disagrees" },
    ],
  };
  const next = applyTags(original, run);
  const before = original.split("\n").filter(Boolean).map((line) => JSON.parse(line));
  const after = next.split("\n").filter(Boolean).map((line) => JSON.parse(line));

  assert.equal(after.length, before.length);
  for (let i = 0; i < before.length; i += 1) {
    const { tags: oldTags, ...oldRest } = before[i];
    const { tags: newTags, ...newRest } = after[i];
    assert.deepEqual(newRest, oldRest, "every field but tags is identical");
    assert.deepEqual(Object.keys(after[i]), Object.keys(before[i]), "field order kept");
    if (before[i].entry === 1) {
      assert.deepEqual(newTags, ["level_shape", "exploration"]);
    } else {
      assert.deepEqual(newTags, oldTags);
    }
  }
  assert.equal(next.endsWith("\n"), original.endsWith("\n"));

  const dir = await scratch(t);
  const file = path.join(dir, "verdicts.ndjson");
  await writeFile(file, next);
  const { ok, problems } = validateVerdicts({ file, log: REAL_LOG, git: root });
  assert.deepEqual(problems, []);
  assert.equal(ok, true);
});

test("the real file's tags are vocabulary ids equal to the hand labels' yes set", async () => {
  const vocab = loadVocab(VOCAB_FILE);
  const ids = vocab.tags.map((tag) => tag.id);
  for (const record of await realRecords()) {
    if (record.tags.length === 0) {
      continue;
    }
    const labels = vocab.hand_labels.entries[String(record.entry)];
    assert.ok(labels, `entry ${record.entry} has tags but no hand label`);
    assert.deepEqual(
      record.tags,
      ids.filter((id) => labels[id] === true),
      `entry ${record.entry} tags match its hand labels in vocabulary order`,
    );
  }
});

test("nothing on the gate path imports the tagger", async () => {
  for (const file of ["scripts/verify.mjs", "scripts/lab/gate.mjs", "scripts/lab/verdicts.mjs"]) {
    const text = await readFile(path.join(root, file), "utf8");
    assert.doesNotMatch(text, /verdict-tags/, `${file} must not wait on Jev`);
  }
});
