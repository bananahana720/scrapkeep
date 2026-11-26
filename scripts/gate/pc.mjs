// A whole promotion gate on one PC, as one resumable command.
//
//   node scripts/gate/pc.mjs plan --wave 35 --head <sha> [--root <dir>] [--base <dir>] [--persona <id>] [--budget n] [--no-weekly]
//   node scripts/gate/pc.mjs run  <the same flags> [--redo <step id>]... [--tally]
//   add --scoped a_test,b_test for the wave gate (ruling cy): the node suite, the three test windows and one scoped
//   shard of those bot-tier tests plus world1_run_test, run by name; the bot blocks, the weekly sweep, the bands and
//   the red team wait for the release gate, and --tally runs tally.mjs --wave. --scoped-from <fast receipt.json> adds
//   the bot shards a `sketch:fast` receipt for the stage diff names (selection.bot_shards).
//
// `plan` prints the steps in order with their Godot-process weights and creates nothing. `run` admits steps
// against the budget, gives each its own worktree, slot pool and scratch data home, compares the band runs
// with the last gated head's receipts (--base), and writes <root>/w<N>-<head8>-gate-plan.md for
// scripts/gate/tally.mjs. Receipts go to <root>/w<N>-<head8>/<step id>/; a step.json there marks a step done.
// Run it from a checkout of the head: the lists are counted there and every step runs that head's own
// scripts. It never edits that checkout. project-guide/handoff/GATE.md, "Running shards on one PC", is the recipe.

import { spawn, spawnSync } from "node:child_process";
import { closeSync, copyFileSync, cpSync, existsSync, mkdirSync, openSync, readFileSync, readdirSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";
import { fileURLToPath } from "node:url";

import { chunks, gateLists, namedPool, testName } from "./shard.mjs";
import { checkImportStamp, writeImportStamp } from "../import-stamp.mjs";
import { userDataEnv } from "../godot-home.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SKETCH = "sketches/core-loop";
export const BANDS_FILE = path.join(root, "scripts", "gate", "bands.json");
const BOT_BLOCK = 5;
const TEST_WINDOWS = 3;
const SLOT_POOL = 4;

// The load a step puts on the machine, in busy threads, read against `defaultBudget`. Measured on a 32-thread PC:
// a test window's two lanes hold a 1-minute load of about 5, one bot test at a time about 8 (wave 41 gate, e2770d85).
export const WEIGHTS = {
  tests: 6, // a test shard with two lanes: measured load about 5
  bots: 8, // a bot test starts up to 8 children
  scoped: 16, // the wave gate's bot shard runs two bot lanes of about 8 each
  "weekly-tests": 6, // the same shard, on the weekly list
  "weekly-bots": 8, // the same bot shard, on the weekly list
  "bands-A": 8, // one test at a time, but its bot tests start up to 8 children
  "bands-B": 12, // challenge --jobs=12 (PR 786 PC timing: 642 s against 1075 s at 6, same verdicts)
  "bands-C": 12, // bot smoke tests start up to 8 children, then the rungs at --jobs=12
  node: 2, // the node suite starts a few Godot tests at a time
  redteam: 8, // --slots=8; exclusive, because its frame-time readings need a quiet machine
  retime: 2, // one test at a time; exclusive, because a retime needs a quiet machine
  compare: 0, // reads files
  "plan-file": 0, // reads files
};

// Busy threads the gate may hold at once: every thread but four. Until 15 Nov 2026 it was half the threads, and the
// wave 41 gate's bot shard, the longest step, waited 34 minutes for the test windows while the PC sat at load 8 of 32.
export function defaultBudget(threads = os.availableParallelism()) {
  return Math.max(1, threads - 4);
}

// The wave gate's scoped shard always plays world 1 through (GATE.md, "The wave gate and the release gate", step 2).
export const SCOPED_ALWAYS = ["world1_run_test"];

// The bot shards a sketch:fast receipt names for its diff (scripts/sketch-fast.mjs, selection.bot_shards), as test names.
export function receiptBotShards(receipt) {
  const shards = receipt?.selection?.bot_shards;
  if (!Array.isArray(shards)) throw new Error("the fast receipt has no selection.bot_shards list");
  return shards.map(testName);
}

// The scoped shard's names: the asked ones and SCOPED_ALWAYS that are bot tests (on the bot list or the weekly bot
// list, shard.mjs namedPool), in sorted order. A non-bot name is left out, because the three windows run the whole
// non-bot list; a name on no list is refused.
export function scopedNames(asked, lists) {
  const bots = namedPool(lists, { bots: true, weekly: false });
  const tests = new Set(namedPool(lists, { bots: false, weekly: false }));
  const want = new Set([...asked, ...SCOPED_ALWAYS].map(testName).filter(Boolean));
  const unknown = [...want].filter((name) => !bots.includes(name) && !tests.has(name));
  if (unknown.length > 0) throw new Error(`--scoped names tests on no gate list: ${unknown.join(", ")}`);
  return bots.filter((name) => want.has(name));
}

// ---- plan ----

// Every band test must exist, match its --bots flag, and not sit on the weekly list.
export function checkBands(bands, lists) {
  const problems = [];
  const entries = [...bands.A.map((entry) => ["A", entry]), ...bands.C_smoke.map((entry) => ["C_smoke", entry])];
  for (const [key, entry] of entries) {
    const bot = Boolean(entry.bots);
    const weekly = [...lists.weekly.tests, ...lists.weekly.bots];
    if (weekly.includes(entry.test)) problems.push(`${key}: ${entry.test} is on the weekly list`);
    else if (!(bot ? lists.bots : lists.tests).includes(entry.test)) problems.push(`${key}: ${entry.test} is not a ${bot ? "bot" : "non-bot"} test in the gate lists`);
  }
  return problems;
}

export function loadBands(lists, file = BANDS_FILE) {
  const bands = JSON.parse(readFileSync(file, "utf8"));
  for (const key of ["A", "C_smoke", "B", "C_rungs"]) if (!bands[key]) throw new Error(`${file} has no "${key}"`);
  const problems = checkBands(bands, lists);
  if (problems.length > 0) throw new Error(`${file}: ${problems.join("; ")}`);
  return bands;
}

const windowOf = (first, last) => `${first}-${last}`;

// Ordered steps. `weekly` is the weekly lists or null. Exclusive steps come last among the Godot steps, then the
// two barrier steps that read every receipt.
// With `scoped` (an array of bot test names) it is the wave gate: the windows, one scoped shard, the node suite and the
// plan file, and nothing a release gate adds.
export function gatePlan({ wave, head, lists, weekly = null, bands, persona = null, scoped = null }) {
  const head8 = head.slice(0, 8);
  const steps = [];
  const add = (id, kind, extra = {}) => steps.push({ id, kind, weight: WEIGHTS[kind === "shard" ? extra.weightKey : kind], exclusive: false, out: id, needsBase: false, ...extra });
  // The wave gate's bot shard is its longest step, so it starts first and the windows fill the room beside it.
  if (scoped) add("scoped", "shard", { weightKey: "scoped", row: "scoped", args: ["--bots", scopedNames(scoped, lists).join(","), "--lanes", "2"], names: scopedNames(scoped, lists) });
  const size = Math.ceil(lists.tests.length / TEST_WINDOWS);
  for (let first = 1; first <= lists.tests.length; first += size) {
    const last = Math.min(first + size - 1, lists.tests.length);
    add(`tests-${windowOf(first, last)}`, "shard", { weightKey: "tests", row: `tests ${windowOf(first, last)}`, args: ["--tests", windowOf(first, last)] });
  }
  const addWeekly = () => {
    if (weekly?.tests.length > 0) add("weekly-tests", "shard", { weightKey: "weekly-tests", row: "weekly sweep", args: ["--weekly", "--tests", windowOf(1, weekly.tests.length)] });
    if (weekly?.bots.length > 0) add("weekly-bots", "shard", { weightKey: "weekly-bots", row: "weekly sweep", args: ["--weekly", "--bots", windowOf(1, weekly.bots.length)] });
  };
  if (scoped) {
    addWeekly();
    add("node", "node", { row: "node tests" });
    add("plan-file", "plan-file", { barrier: true });
    return steps.map((step) => ({ ...step, wave, head8 }));
  }
  chunks(lists.bots, BOT_BLOCK).forEach((block, index) => {
    const first = index * BOT_BLOCK + 1;
    add(`bots-${index + 1}`, "shard", { weightKey: "bots", row: `bots ${index + 1}`, args: ["--bots", windowOf(first, first + block.length - 1)] });
  });
  addWeekly();
  for (const band of ["A", "B", "C"]) add(`bands-${band}`, `bands-${band}`, { row: `bands ${band}`, needsBase: true, bands });
  add("node", "node", { row: "node tests" });
  if (persona) add("redteam", "redteam", { row: `red team ${persona}`, exclusive: true, persona });
  add("compare", "compare", { barrier: true, needsBase: true, bands });
  add("plan-file", "plan-file", { barrier: true });
  return steps.map((step) => ({ ...step, wave, head8 }));
}

export function formatPlan(steps, budget) {
  const lines = [`Budget ${budget} busy threads. Steps start in this order; a step waits until its weight fits, and a lighter step behind it may start in the gap when it cannot delay it.`];
  steps.forEach((step, index) => lines.push(`${String(index + 1).padStart(3)}  ${step.id.padEnd(18)} weight ${String(step.weight).padStart(2)}${step.exclusive ? "  exclusive: runs with nothing else" : step.barrier ? "  after every other step" : ""}${step.names ? `  ${step.names.join(" ")}` : ""}`));
  lines.push("A retime step (exclusive, weight 2) is added at run time for each shard that comes back INCONCLUSIVE.");
  return lines.join("\n");
}

// ---- scheduler ----

// The spare weight a later step may take while `head` waits, without ever delaying it. The head starts once
// some set of running steps has finished and freed `need`. A step started in the gap must leave room for
// the head after ANY such set finishes, so the spare is the smallest freed total that reaches `need`, less `need`.
// (Wave 35 gate, 10 Nov: two windows at 6 ran, the third at 6 waited, and a 2-weight step sat behind it with 4 idle.)
export function spareWhileWaiting(runningWeights, headWeight, budget) {
  const used = runningWeights.reduce((sum, weight) => sum + weight, 0);
  const need = used + headWeight - budget;
  if (need <= 0) return 0;
  let least = Infinity;
  for (let mask = 1; mask < 1 << runningWeights.length; mask++) {
    let freed = 0;
    for (let i = 0; i < runningWeights.length; i++) if (mask & (1 << i)) freed += runningWeights[i];
    if (freed >= need && freed < least) least = freed;
  }
  return least === Infinity ? 0 : least - need;
}

// Starts steps in plan order, never above `budget` busy threads. A step that does not fit waits at the
// head of the queue; a later ordinary step may start in the gap only when it cannot delay that head
// (`spareWhileWaiting`), so none is starved. Exclusive and barrier steps run with nothing else and nothing
// passes them; a step heavier than the budget runs alone. `isDone(step)` returns a truthy value (or { exit })
// for a finished step, which is skipped. `onExit(step, exit)` may return steps to add before the first barrier.
// Returns a Map of step id to exit.
export async function runPlan(steps, { budget, start, isDone = () => null, onExit = () => [] }) {
  const queue = [...steps];
  const exits = new Map();
  const running = new Set();
  let used = 0;
  let alone = false;
  const finish = (step, exit) => {
    exits.set(step.id, exit);
    const more = onExit(step, exit) ?? [];
    const at = queue.findIndex((entry) => entry.barrier);
    queue.splice(at < 0 ? queue.length : at, 0, ...more);
  };
  const racers = new Map();
  const solo = (step) => step.exclusive || step.barrier || step.weight > budget;
  // The first ordinary step behind a waiting head that fits the spare and the budget now. It never looks past a solo step.
  const gapStep = (head) => {
    const spare = Math.min(spareWhileWaiting([...running].map((entry) => entry.weight), head.weight, budget), budget - used);
    for (let at = 1; at < queue.length && !solo(queue[at]); at++) if (queue[at].weight <= spare) return at;
    return -1;
  };
  while (queue.length > 0 || running.size > 0) {
    while (queue.length > 0) {
      let at = 0;
      let step = queue[0];
      const done = await isDone(step);
      if (done) {
        queue.shift();
        finish(step, typeof done === "object" && typeof done.exit === "number" ? done.exit : 0);
        continue;
      }
      const soloStep = step.exclusive || step.barrier;
      if (alone || (soloStep && running.size > 0)) break;
      if (running.size > 0 && used + step.weight > budget) {
        if (solo(step)) break;
        at = gapStep(step);
        if (at < 0) break;
        step = queue[at];
        const stepDone = await isDone(step);
        if (stepDone) {
          queue.splice(at, 1);
          finish(step, typeof stepDone === "object" && typeof stepDone.exit === "number" ? stepDone.exit : 0);
          continue;
        }
      }
      queue.splice(at, 1);
      running.add(step);
      used += step.weight;
      alone = soloStep || step.weight > budget;
      const racer = Promise.resolve()
        .then(() => start(step))
        .catch((error) => {
          console.error(`pc: ${step.id} failed to start: ${error?.message ?? error}`);
          return 70;
        })
        .then((exit) => {
          running.delete(step);
          used -= step.weight;
          alone = false;
          racers.delete(step);
          finish(step, exit);
        });
      racers.set(step, racer);
    }
    if (racers.size > 0) await Promise.race(racers.values());
    else if (queue.length > 0) throw new Error(`the scheduler is stuck at ${queue[0].id}`);
  }
  return exits;
}

// ---- compare ----

// `fairness` (the bot record's F1 to F3 numbers, wave 36 unit measure) is a measurement, not an outcome: it reads what the
// simulation already published and moves nothing, so a head that adds or refines it must not read as a differing run.
// It is one key on purpose: its parts (`first_hit_s`, `stop_tax`, `telegraph_share`) would also hide the stage notes' own
// `first_hit_s` if listed here, because the strip below is by name at any depth.
const IGNORED = new Set(["fairness", "wall_seconds", "wallS", "qa", "label", "commit", "key", "id", "log", "comic_page", "started_at", "ended_at", "rerun"]);

function strip(value) {
  if (Array.isArray(value)) return value.map(strip);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).filter(([key]) => !IGNORED.has(key)).map(([key, inner]) => [key, strip(inner)]));
  return value;
}

function differences(a, b, at, out) {
  const plain = (value) => value && typeof value === "object" && !Array.isArray(value);
  if (plain(a) && plain(b)) {
    for (const key of [...new Set([...Object.keys(a), ...Object.keys(b)])].sort()) differences(a[key] ?? null, b[key] ?? null, `${at}/${key}`, out);
  } else if (!isDeepStrictEqual(a ?? null, b ?? null)) out.push({ path: at, base: a, head: b });
}

function readRuns(text) {
  const runs = new Map();
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    const run = JSON.parse(line);
    runs.set(JSON.stringify([run.cell ?? null, run.band ?? null, run.build ?? null, run.seed ?? null, run.attempt ?? null]), run);
  }
  return runs;
}

// Runs of two challenge runs.ndjson files, run for run. code 0 identical, 1 some differ, 3 a side is empty or the run sets differ.
export function compareRuns(baseText, headText) {
  const base = readRuns(baseText);
  const head = readRuns(headText);
  const onlyBase = [...base.keys()].filter((key) => !head.has(key)).length;
  const onlyHead = [...head.keys()].filter((key) => !base.has(key)).length;
  if (base.size === 0 || head.size === 0 || onlyBase > 0 || onlyHead > 0) {
    return { code: 3, identical: 0, differing: 0, diffs: [], summary: `base ${base.size} runs, head ${head.size} runs; run sets differ or empty: only base ${onlyBase}, only head ${onlyHead}` };
  }
  const diffs = [];
  for (const key of [...base.keys()].sort()) {
    const found = [];
    differences(strip(base.get(key)), strip(head.get(key)), "", found);
    if (found.length > 0) diffs.push({ key, fields: found });
  }
  const identical = base.size - diffs.length;
  return { code: diffs.length > 0 ? 1 : 0, identical, differing: diffs.length, diffs, summary: `${base.size} runs, identical ${identical}, differing ${diffs.length}` };
}

// The `->` lines of a smoke log in C order with wall seconds removed, so two heads compare line for line.
export function sortedLines(logText) {
  return logText
    .split("\n")
    .filter((line) => line.includes("->"))
    .map((line) => line.replace(/\b\d+(?:\.\d+)? s wall\b/g, "N s wall").replace(/\bwall[= ]\d+(?:\.\d+)?s?\b/g, "wall").replace(/\b\d+(?:\.\d+)?s\b/g, "Ns").trimEnd())
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}

export function compareLines(baseText, headText) {
  const base = sortedLines(baseText);
  const head = sortedLines(headText);
  const remove = (from, drop) => {
    const left = [...drop];
    return from.filter((line) => {
      const at = left.indexOf(line);
      if (at < 0) return true;
      left.splice(at, 1);
      return false;
    });
  };
  const onlyBase = remove(base, head);
  const onlyHead = remove(head, base);
  return { code: onlyBase.length + onlyHead.length > 0 ? 1 : 0, onlyBase, onlyHead, summary: `${base.length} lines, ${onlyBase.length} only in base, ${onlyHead.length} only in head` };
}

// Each band against the base. `read(side, relativePath)` returns text or null. With no base, every band reads null.
export function compareBands(read, bands, hasBase) {
  const result = { base: hasBase, A: { identical: null, notes: [] }, B: { identical: null, notes: [] }, C: { identical: null, notes: [] } };
  if (!hasBase) return result;
  const settle = (band) => {
    result[band].identical = result[band].notes.every((note) => note.ok);
  };
  const smoke = (band, dir, prefix, tests) => {
    for (const { test } of tests) {
      const label = `${band === "A" ? "bands A" : "bands C smoke"} ${test}`;
      const [bl, hl, be, he] = [read("base", `${dir}/${prefix}${test}.lines`), read("head", `${dir}/${prefix}${test}.lines`), read("base", `${dir}/${prefix}${test}.exit`), read("head", `${dir}/${prefix}${test}.exit`)];
      if (bl === null || hl === null) result[band].notes.push({ ok: false, text: `${label}: ${bl === null ? "the base has no result" : "the head has no result"}` });
      else {
        const lines = compareLines(bl, hl);
        const exitMoved = (be ?? "").trim() !== (he ?? "").trim();
        const ok = lines.code === 0 && !exitMoved;
        const first = [...lines.onlyBase.slice(0, 2).map((line) => `base: ${line}`), ...lines.onlyHead.slice(0, 2).map((line) => `head: ${line}`)].join(" | ");
        result[band].notes.push({ ok, text: `${label}: ${ok ? "identical" : `${exitMoved ? `exit ${(be ?? "").trim()} to ${(he ?? "").trim()}; ` : ""}${lines.summary}${first ? `; ${first}` : ""}`}` });
      }
    }
    settle(band);
  };
  const runs = (label, rel, band) => {
    const [b, h] = [read("base", rel), read("head", rel)];
    if (b === null || h === null) {
      result[band].notes.push({ ok: false, text: `${label}: ${b === null ? "the base has no runs.ndjson" : "the head has no runs.ndjson"}` });
      return;
    }
    const compared = compareRuns(b, h);
    const first = compared.diffs.slice(0, 3).map((diff) => `${diff.key} ${diff.fields.slice(0, 3).map((field) => `${field.path}: base ${String(field.base).slice(0, 40)}, head ${String(field.head).slice(0, 40)}`).join("; ")}`);
    result[band].notes.push({ ok: compared.code === 0, text: `${label}: ${compared.summary}${first.length ? `; first: ${first.join(" || ")}` : ""}` });
  };
  smoke("A", "bands-A", "", bands.A);
  runs("bands B", "bands-B/runs.ndjson", "B");
  settle("B");
  smoke("C", "bands-C", "smoke-", bands.C_smoke);
  for (const { tier } of bands.C_rungs.tiers) runs(`bands C rung ${tier}`, `bands-C/t${tier}-runs.ndjson`, "C");
  settle("C");
  return result;
}

export function renderCompare(compare, basePath) {
  const lines = ["# Band comparison with the last gated head", ""];
  if (!compare.base) return [...lines, "No base: `--base` was not given, so nothing was compared. The band rows read \"no base\".", ""].join("\n");
  lines.push(`Base receipts: ${basePath}. Ignored fields: wall time, the play watch, label, commit, key, id, log, comic page, start and end times, rerun.`, "");
  for (const band of ["A", "B", "C"]) {
    lines.push(`## Bands ${band}: ${compare[band].identical ? "identical" : "moved"}`, "", ...compare[band].notes.map((note) => `- ${note.text}`), "");
  }
  return lines.join("\n");
}

// ---- the plan file ----

const cell = (text) => String(text).replaceAll("|", "\\|").replaceAll("\n", " ");

// One row per shard, as scripts/gate/tally.mjs parses them. `results` maps a step id to
// { exit, verdict?, blockers? }; `compare` is compareBands' result or null.
export function planFileText({ wave, head, persona, base = null, results, compare, steps, today = new Date() }) {
  const day = today.toISOString().slice(0, 10);
  const rows = [];
  const byId = (id) => results[id];
  const shardRow = (step) => {
    const result = byId(step.id);
    const verdict = result?.verdict ?? `RED: exit ${result?.exit ?? "unknown"} and no verdict line`;
    const retimed = byId(`retime-${step.id}`);
    if (verdict.startsWith("INCONCLUSIVE") && retimed) {
      const receipts = `${step.id}/receipt.md, retime-${step.id}/receipt.md`;
      return retimed.exit === 0 ? `PASS after retime (${verdict}). Receipts ${receipts}` : `${retimed.verdict ?? `RED: retime exit ${retimed.exit}`}. Receipts ${receipts}`;
    }
    return `${verdict}. Receipt ${step.id}/receipt.md`;
  };
  const bandRow = (step) => {
    const band = step.id.slice(-1);
    const result = byId(step.id);
    if (!result || result.exit !== 0) return `RED: step exited ${result?.exit ?? "unknown"}. Receipt ${step.id}/`;
    if (!compare?.base) return `NO BASE: the step exited 0 and was not compared. Receipt ${step.id}/, compare.md`;
    if (compare[band].identical) return `PASS, identical to the base. Receipt ${step.id}/, compare.md`;
    return `RED: the band moved against the base (${compare[band].notes.filter((note) => !note.ok).map((note) => note.text).slice(0, 2).join(" ; ")}). Receipt ${step.id}/, compare.md`;
  };
  const weekly = steps.filter((step) => step.row === "weekly sweep");
  for (const step of steps) {
    if (step.kind === "shard" && step.row !== "weekly sweep") rows.push([step.row, shardRow(step)]);
    else if (step.kind.startsWith("bands-")) rows.push([step.row, bandRow(step)]);
    else if (step.kind === "redteam") {
      const result = byId(step.id);
      rows.push([step.row, result?.exit === 0 && result.blockers === 0 ? "CLEAR. 0 blockers. Receipt redteam/findings.md" : `RED: exit ${result?.exit ?? "unknown"}, ${result?.blockers ?? "unknown"} blocker(s). Receipt redteam/findings.md`]);
    }
  }
  if (weekly.length > 0) {
    const verdicts = weekly.map(shardRow);
    const receipts = weekly.map((step) => `${step.id}/receipt.md`).join(", ");
    rows.push(["weekly sweep", verdicts.every((verdict) => verdict.startsWith("PASS")) ? `PASS ${day}. Receipts ${receipts}` : `${verdicts.find((verdict) => !verdict.startsWith("PASS"))}. Receipts ${receipts}`]);
  }
  const node = byId("node");
  const lines = [
    `# Gate plan: wave ${wave}, head ${head.slice(0, 8)}`,
    "",
    `Written by \`scripts/gate/pc.mjs\` on ${day}. Base for the band comparison: ${base ?? "none"}. Check it with \`node scripts/gate/tally.mjs ${steps.some((step) => step.id === "scoped") ? "--wave " : ""}--plan <this file>\`.`,
    "",
    "## Gate-side",
    "",
    "| Check | Verdict |",
    "| --- | --- |",
    `| node tests | ${node ? (node.exit === 0 ? `PASS. ${cell(node.verdict ?? "")} Receipt node/summary.txt` : `RED: exit ${node.exit}. ${cell(node.verdict ?? "")} Receipt node/summary.txt`) : "RED: no result"} |`,
    "",
    "## Tally",
    "",
    "| Shard | Verdict |",
    "| --- | --- |",
    ...rows.map(([shard, verdict]) => `| ${shard} | ${cell(verdict)} |`),
    "",
  ];
  if (!persona) lines.push("## Owed", "", "The `red team <persona>` row is owed: no `--persona` was given, so the plan has no red team step.", "");
  return lines.join("\n");
}

// ---- environment, worktrees ----

// One step's environment. Every step gets its own scratch homes and slot pool, and a data home
// outside the gate root is refused, so a Godot run cannot reach the owner's real save.
export function stepEnv({ root: gateRoot, id, godot, base = process.env, platform = process.platform }) {
  const rootAbs = path.resolve(gateRoot);
  const home = path.resolve(rootAbs, "xdg", id);
  if (!id || !home.startsWith(rootAbs + path.sep) || path.relative(path.join(rootAbs, "xdg"), home).startsWith("..")) throw new Error(`step ${id}: its XDG_DATA_HOME would be outside ${rootAbs}; refusing`);
  const lockDir = path.resolve(rootAbs, "locks", id);
  if (!lockDir.startsWith(rootAbs + path.sep)) throw new Error(`step ${id}: its lock folder would be outside ${rootAbs}; refusing`);
  return {
    ...base,
    GODOT_BIN: godot,
    ...userDataEnv(path.join(home, "data"), platform),
    XDG_CONFIG_HOME: path.join(home, "config"),
    XDG_CACHE_HOME: path.join(home, "cache"),
    SCRAPKEEP_LOCK_DIR: lockDir,
    SMOKE_SLOTS: String(SLOT_POOL),
    SMOKE_FULL: "1",
  };
}

// Free detached worktrees of one head. A step gets the one it used last time when it is free
// (a challenge label resumes only in the worktree that holds it), else any free one, else a new one.
export function worktreePool({ dir, add, existing = [], owners = {}, saveOwners = () => {} }) {
  const entries = new Map(existing.map((name) => [name, false]));
  const claim = (name, stepId) => {
    entries.set(name, true);
    owners[stepId] = name;
    saveOwners(owners);
    return path.join(dir, name);
  };
  return {
    acquire(stepId) {
      const mine = owners[stepId];
      if (mine && entries.get(mine) === false) return claim(mine, stepId);
      const free = [...entries].find(([, busy]) => !busy);
      if (free) return claim(free[0], stepId);
      let n = entries.size + 1;
      while (entries.has(String(n))) n++;
      add(path.join(dir, String(n)));
      return claim(String(n), stepId);
    },
    release(worktree) {
      entries.set(path.basename(worktree), false);
    },
  };
}

// ---- the real step runner ----

const loadNow = () => Math.round(os.loadavg()[0] * 10) / 10;
const readIf = (file) => (existsSync(file) ? readFileSync(file, "utf8") : null);

function runLogged(command, args, { cwd, env, log }) {
  return new Promise((resolve) => {
    mkdirSync(path.dirname(log), { recursive: true });
    const fd = openSync(log, "a");
    const child = spawn(command, args, { cwd, env, stdio: ["ignore", fd, fd] });
    child.on("error", () => {
      closeSync(fd);
      resolve(127);
    });
    child.on("close", (code) => {
      closeSync(fd);
      resolve(code ?? 1);
    });
  });
}

export function challengeArgs({ only, seeds, bands = null, tier = null, jobs = 12, label, resume }) {
  return ["scripts/challenge/run.mjs", `--only=${only}`, `--seeds=${seeds}`, ...(bands ? [`--bands=${bands}`] : []), ...(tier ? [`--tier=${tier}`] : []), "--no-top", `--jobs=${jobs}`, `--label=${label}`, ...(resume ? ["--resume"] : [])];
}

export function nodeSummary(logText) {
  const read = (name) => Number(new RegExp(`^(?:#|ℹ) ${name} (\\d+)`, "m").exec(logText)?.[1] ?? NaN);
  return { tests: read("tests"), fail: read("fail"), pass: read("pass") };
}

async function importOnce(wt, env, log) {
  const marker = path.join(wt, "artifacts", "local", "gate-import.done");
  if (existsSync(marker) && checkImportStamp(wt, SKETCH).ok) return true;
  for (let attempt = 1; attempt <= 3; attempt++) {
    const file = `${log}.import-${attempt}`;
    const exit = await runLogged(env.GODOT_BIN, ["--headless", "--path", path.join(wt, SKETCH), "--editor", "--import"], { cwd: wt, env, log: file });
    if (attempt >= 2 && exit === 0 && !/SCRIPT ERROR/.test(readIf(file) ?? "")) {
      mkdirSync(path.dirname(marker), { recursive: true });
      writeFileSync(marker, "ok\n");
      writeImportStamp(wt, SKETCH);
      return true;
    }
  }
  return false;
}

async function runShardStep(step, ctx) {
  const args = ["scripts/gate/shard.mjs", step.kind === "retime" ? "retime" : "run", ...step.args, "--out", ctx.receipt(step)];
  return runLogged(process.execPath, args, { cwd: ctx.wt, env: ctx.env, log: path.join(ctx.receipt(step), "run.log") });
}

async function runSmokeTests(tests, ctx, dir, prefix) {
  let worst = 0;
  for (const { test, bots } of tests) {
    const base = path.join(dir, prefix + test);
    if (existsSync(base + ".exit")) {
      worst ||= Number(readFileSync(base + ".exit", "utf8"));
      continue;
    }
    const exit = await runLogged(process.execPath, ["scripts/sketch-smoke.mjs", "--sketch", "core-loop", ...(bots ? ["--bots"] : []), "--test", test], { cwd: ctx.wt, env: ctx.env, log: base + ".log" });
    writeFileSync(base + ".lines", sortedLines(readFileSync(base + ".log", "utf8")).join("\n") + "\n");
    writeFileSync(base + ".exit", `${exit}\n`);
    worst ||= exit;
  }
  return worst;
}

async function runChallenge(spec, ctx, dir, copyAs) {
  const label = `w${ctx.wave}-${ctx.head.slice(0, 8)}-${spec.suffix}`;
  const out = path.join(ctx.wt, "artifacts", "local", "challenge", label);
  let exit = 0;
  if (!existsSync(path.join(out, "table.md"))) {
    const resume = existsSync(path.join(out, "meta.json"));
    exit = await runLogged(process.execPath, challengeArgs({ ...spec, label, resume }), { cwd: ctx.wt, env: ctx.env, log: path.join(dir, `${label}.log`) });
  }
  for (const [file, name] of [["runs.ndjson", copyAs.runs], ["meta.json", copyAs.meta], ["table.md", copyAs.table]]) {
    if (existsSync(path.join(out, file))) copyFileSync(path.join(out, file), path.join(dir, name));
  }
  return existsSync(path.join(out, "table.md")) ? exit : exit || 1;
}

const kinds = {
  async shard(step, ctx) {
    return runShardStep(step, ctx);
  },
  async retime(step, ctx) {
    return runShardStep(step, ctx);
  },
  async "bands-A"(step, ctx) {
    return runSmokeTests(step.bands.A, ctx, ctx.receipt(step), "");
  },
  async "bands-B"(step, ctx) {
    if (!(await importOnce(ctx.wt, ctx.env, path.join(ctx.receipt(step), "import")))) return 3;
    const { only, seeds } = step.bands.B;
    return runChallenge({ only, seeds, suffix: only }, ctx, ctx.receipt(step), { runs: "runs.ndjson", meta: "meta.json", table: "table.md" });
  },
  async "bands-C"(step, ctx) {
    const dir = ctx.receipt(step);
    if (!(await importOnce(ctx.wt, ctx.env, path.join(dir, "import")))) return 3;
    let worst = await runSmokeTests(step.bands.C_smoke, ctx, dir, "smoke-");
    const { only, bands, tiers } = step.bands.C_rungs;
    for (const { tier, seeds } of tiers) {
      worst ||= await runChallenge({ only, seeds, bands, tier, suffix: `C-t${tier}` }, ctx, dir, { runs: `t${tier}-runs.ndjson`, meta: `t${tier}-meta.json`, table: `t${tier}-table.md` });
    }
    return worst;
  },
  async node(step, ctx) {
    const dir = ctx.receipt(step);
    const ci = await runLogged("npm", ["ci"], { cwd: ctx.wt, env: ctx.env, log: path.join(dir, "npm-ci.log") });
    if (ci !== 0) return ci;
    const exit = await runLogged("npm", ["test"], { cwd: ctx.wt, env: { ...ctx.env, SCRAPKEEP_WHOLE_TESTS: "1" }, log: path.join(dir, "npm-test.log") });
    const log = readIf(path.join(dir, "npm-test.log")) ?? "";
    const summary = nodeSummary(log);
    writeFileSync(path.join(dir, "summary.txt"), `tests ${summary.tests}\npass ${summary.pass}\nfail ${summary.fail}\nexit ${exit}\n`);
    return exit === 0 && summary.tests > 0 && summary.fail === 0 ? 0 : exit || 1;
  },
  async redteam(step, ctx) {
    const dir = ctx.receipt(step);
    const templates = path.join(os.homedir(), ".local", "share", "godot", "export_templates");
    const link = path.join(ctx.env.XDG_DATA_HOME, "godot", "export_templates");
    if (existsSync(templates) && !existsSync(link)) {
      mkdirSync(path.dirname(link), { recursive: true });
      symlinkSync(templates, link);
    }
    const exit = await runLogged(process.execPath, ["scripts/redteam/run.mjs", `--wave=${ctx.wave}`, `--persona=${step.persona}`, "--slots=8"], { cwd: ctx.wt, env: ctx.env, log: path.join(dir, "run.log") });
    const parent = path.join(ctx.wt, "artifacts", "local", "redteam");
    const found = existsSync(parent) ? readdirSync(parent).filter((name) => name.startsWith(`w${ctx.wave}-${step.persona}-`)).sort().pop() : null;
    if (found) cpSync(path.join(parent, found), dir, { recursive: true });
    return exit;
  },
};

function readStepResult(step, receipts) {
  const dir = path.join(receipts, step.id);
  const done = readIf(path.join(dir, "step.json"));
  if (!done) return null;
  const result = { ...JSON.parse(done) };
  const shard = readIf(path.join(dir, "shard.json"));
  if (shard) result.verdict = JSON.parse(shard).verdict?.line ?? null;
  const retime = readIf(path.join(dir, "receipt.md"));
  if (!shard && step.kind === "retime" && retime) result.verdict = /\*\*Verdict: (.*)\.\*\*/.exec(retime)?.[1] ?? null;
  const summary = readIf(path.join(dir, "summary.txt"));
  if (summary && step.kind === "node") result.verdict = `${/tests (\d+)/.exec(summary)?.[1]} tests, ${/fail (\d+)/.exec(summary)?.[1]} fail.`;
  const findings = readIf(path.join(dir, "findings.json"));
  if (findings) result.blockers = (JSON.parse(findings).findings ?? []).filter((finding) => finding.severity === "blocker").length;
  return result;
}

// A shard that came back INCONCLUSIVE names its suspect-load tests; a retime settles them.
function retimeFor(step, receipts) {
  const summary = readIf(path.join(receipts, step.id, "shard.json"));
  if (!summary) return [];
  const shard = JSON.parse(summary);
  if (!shard.verdict?.inconclusive) return [];
  const tests = shard.failures.filter((failure) => failure.call === "suspect-load").map((failure) => failure.test);
  if (tests.length === 0) return [];
  const bots = step.args.includes("--bots");
  return [{ id: `retime-${step.id}`, kind: "retime", weight: WEIGHTS.retime, exclusive: true, out: `retime-${step.id}`, needsBase: false, wave: step.wave, head8: step.head8, args: ["--tests", tests.join(","), ...(bots ? ["--bots"] : [])] }];
}

function parseArguments(argv) {
  const options = { command: argv[0], wave: null, head: null, root: path.join(os.homedir(), "scratch", "gate"), base: null, persona: null, budget: defaultBudget(), weekly: true, redo: [], tally: false, scoped: null };
  for (let index = 1; index < argv.length; index++) {
    const argument = argv[index];
    const value = () => {
      if (argv[index + 1] === undefined) throw new Error(`${argument} needs a value`);
      return argv[++index];
    };
    if (argument === "--wave") options.wave = Number(value());
    else if (argument === "--head") options.head = value();
    else if (argument === "--root") options.root = path.resolve(value());
    else if (argument === "--base") options.base = path.resolve(value());
    else if (argument === "--persona") options.persona = value();
    else if (argument === "--budget") options.budget = Number(value());
    else if (argument === "--no-weekly") options.weekly = false;
    else if (argument === "--redo") options.redo.push(value());
    else if (argument === "--tally") options.tally = true;
    else if (argument === "--scoped") options.scoped = [...(options.scoped ?? []), ...value().split(",")];
    else if (argument === "--scoped-from") options.scoped = [...(options.scoped ?? []), ...receiptBotShards(JSON.parse(readFileSync(value(), "utf8")))];
    else throw new Error(`unknown argument ${argument}`);
  }
  if (!["plan", "run"].includes(options.command)) throw new Error("the first argument is plan or run");
  if (!Number.isSafeInteger(options.wave) || options.wave < 1) throw new Error("--wave takes a whole number from 1");
  if (!/^[0-9a-f]{40}$/.test(options.head ?? "")) throw new Error("--head takes the full 40-character commit hash");
  if (!Number.isSafeInteger(options.budget) || options.budget < 1) throw new Error("--budget takes a whole number from 1");
  return options;
}

function git(...args) {
  const result = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  if (result.status !== 0) throw new Error(`git ${args.join(" ")} failed: ${result.stderr.trim()}`);
  return result.stdout.trim();
}

function buildPlan(options) {
  const lists = gateLists(path.join(root, SKETCH));
  const bands = options.scoped ? null : loadBands(lists);
  const weekly = options.weekly && lists.weekly.tests.length + lists.weekly.bots.length > 0 ? lists.weekly : null;
  const steps = gatePlan({ wave: options.wave, head: options.head, lists, weekly, bands, persona: options.persona, scoped: options.scoped });
  return { lists, steps };
}

async function run(options) {
  const godot = process.env.GODOT_BIN;
  if (!godot || !existsSync(godot)) throw new Error("GODOT_BIN must name the Godot 4.7.2 editor, and the file must exist");
  if (git("rev-parse", "HEAD") !== options.head) throw new Error(`this checkout is not at ${options.head.slice(0, 8)}; run pc.mjs from a checkout of the head, where the lists are counted`);
  const { lists, steps } = buildPlan(options);
  const head8 = options.head.slice(0, 8);
  const receipts = path.join(options.root, `w${options.wave}-${head8}`);
  const wtDir = path.join(receipts, "wt");
  mkdirSync(wtDir, { recursive: true });
  const ownersFile = path.join(wtDir, "owners.json");
  const owners = existsSync(ownersFile) ? JSON.parse(readFileSync(ownersFile, "utf8")) : {};
  const pool = worktreePool({
    dir: wtDir,
    existing: readdirSync(wtDir, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => entry.name),
    owners,
    saveOwners: (map) => writeFileSync(ownersFile, JSON.stringify(map, null, 2) + "\n"),
    add: (dir) => {
      const result = spawnSync("git", ["-C", root, "worktree", "add", "--detach", dir, options.head], { encoding: "utf8" });
      if (result.status !== 0) throw new Error(`git worktree add ${dir} failed: ${result.stderr.trim()}`);
    },
  });
  const baseDir = options.base;
  const stepFile = (step) => path.join(receipts, step.id, "step.json");
  const isDone = (step) => {
    if (step.barrier || options.redo.includes(step.id)) return null;
    const text = readIf(stepFile(step));
    return text ? JSON.parse(text) : null;
  };
  const planFile = path.join(options.root, `w${options.wave}-${head8}-gate-plan.md`);

  const start = async (step) => {
    if (step.kind === "compare") return runCompare(step, receipts, baseDir);
    if (step.kind === "plan-file") return writePlanFile(options, steps, receipts, planFile);
    const dir = path.join(receipts, step.id);
    mkdirSync(dir, { recursive: true });
    const env = stepEnv({ root: options.root, id: step.id, godot, base: process.env });
    for (const key of ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "SCRAPKEEP_LOCK_DIR"]) mkdirSync(env[key], { recursive: true });
    const wt = pool.acquire(step.id);
    const started = Date.now();
    const loadStart = loadNow();
    let exit = 70;
    try {
      const found = spawnSync("git", ["-C", wt, "rev-parse", "HEAD"], { encoding: "utf8" }).stdout.trim();
      if (found !== options.head) throw new Error(`${wt} is at ${found.slice(0, 8)}, not ${head8}`);
      exit = await kinds[step.kind](step, { wt, env, wave: options.wave, head: options.head, receipt: (entry) => path.join(receipts, entry.out) });
    } finally {
      pool.release(wt);
      writeFileSync(stepFile(step), JSON.stringify({ exit, seconds: Math.round((Date.now() - started) / 1000), load_start: loadStart, load_end: loadNow(), head: options.head }, null, 2) + "\n");
    }
    console.log(`${new Date().toISOString().slice(11, 19)}Z ${step.id} exit ${exit}`);
    return exit;
  };
  const exits = await runPlan(steps, { budget: options.budget, start, isDone, onExit: (step) => (step.kind === "shard" ? retimeFor(step, receipts) : []) });
  console.log(`gate plan: ${planFile}`);
  const worst = [...exits].some(([id, exit]) => exit !== 0 && !(exit === 2 && exits.get(`retime-${id}`) === 0));
  const tallyArgs = [...(options.scoped ? ["--wave"] : []), "--plan", planFile];
  console.log(`node scripts/gate/tally.mjs ${tallyArgs.join(" ")}`);
  if (options.tally) {
    const tally = spawnSync(process.execPath, ["scripts/gate/tally.mjs", ...tallyArgs], { cwd: root, stdio: "inherit" });
    return worst ? 1 : (tally.status ?? 1);
  }
  return worst ? 1 : 0;
}

function runCompare(step, receipts, baseDir) {
  const read = (side, rel) => readIf(path.join(side === "base" ? baseDir : receipts, rel));
  const compare = compareBands(read, step.bands, Boolean(baseDir));
  writeFileSync(path.join(receipts, "compare.json"), JSON.stringify(compare, null, 2) + "\n");
  writeFileSync(path.join(receipts, "compare.md"), renderCompare(compare, baseDir));
  return 0;
}

function writePlanFile(options, steps, receipts, planFile) {
  const all = [...steps];
  const results = {};
  for (const step of steps) results[step.id] = readStepResult(step, receipts);
  for (const step of steps.filter((entry) => entry.kind === "shard")) {
    const retime = { id: `retime-${step.id}`, kind: "retime" };
    results[retime.id] = readStepResult(retime, receipts);
  }
  const compare = existsSync(path.join(receipts, "compare.json")) ? JSON.parse(readFileSync(path.join(receipts, "compare.json"), "utf8")) : null;
  writeFileSync(planFile, planFileText({ wave: options.wave, head: options.head, persona: options.persona, base: options.base, results: Object.fromEntries(Object.entries(results).filter(([, value]) => value)), compare, steps: all }));
  return 0;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.command === "plan") {
    const { steps } = buildPlan(options);
    const here = git("rev-parse", "HEAD");
    if (here !== options.head) console.log(`NOTE the lists are counted in this checkout (${here.slice(0, 8)}), not at ${options.head.slice(0, 8)}`);
    console.log(formatPlan(steps, options.budget));
    return 0;
  }
  return run(options);
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error("gate pc: " + (error?.message ?? error));
    process.exitCode = 2;
  }
}
