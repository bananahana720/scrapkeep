import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  acquireMachine,
  binary,
  importWithRetry,
  isBot,
  isSolo,
  judge,
  readQuarantine,
  testTimeoutMs,
} from "./sketch-smoke.mjs";

// npm run sketch:fast: the fast PR lane of the tiered gate (ORCHESTRATOR, "Tiered gate").
// It judges one PR head in about 15 minutes, cheapest and most-often-failing checks first, and
// stops at the first failure that is the PR's own: red twice on the head and green on the base.
//   1. static: sketch-lint, placeholder count no higher than the base, check:docs, the node
//      tests that touch the changed scripts
//   2. Godot: import (retried once), boot, then the tests the diff reaches, cheapest first
// The full gate runs once per staging head and the red team plays each staging head; the fast
// lane never replaces them. Bot-tier tests the diff reaches are listed for the bot shards.
// Run: node scripts/sketch-fast.mjs [--base origin/main] [--budget 900] [--dry-run] [--receipt <label>]

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const RECEIPT_SCHEMA = "scrapkeep-fast-receipt/1";
const DEFAULT_ESTIMATE_MS = 30_000;
// A file more tests than this reach directly is a hub (game.gd, tests/support/t.gd): its own
// direct tests still run, but nothing is selected through it at the second step.
export const HUB_TESTS = 25;
export const CANARY_COUNT = 4;
const TEXT_EXTENSIONS = new Set([".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".gdshader"]);

export function parseArgs(argv) {
  const options = { base: "origin/main", budgetS: 900, dryRun: false, receipt: "fast", width: null, baseCheck: true };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--base" && argv[i + 1]) options.base = argv[++i];
    else if (arg === "--budget" && argv[i + 1]) options.budgetS = Number(argv[++i]);
    else if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--receipt" && argv[i + 1]) options.receipt = argv[++i];
    else if (arg === "--width" && argv[i + 1]) options.width = Number(argv[++i]);
    else if (arg === "--no-base-check") options.baseCheck = false;
  }
  if (!Number.isFinite(options.budgetS) || options.budgetS <= 0) throw new Error("--budget needs seconds above zero");
  return options;
}

// Split repo paths into what each stage needs. Godot paths are relative to the sketch.
export function classify(paths) {
  const out = { godot: [], node: [], docs: [], other: [] };
  const prefix = SKETCH + "/";
  for (const file of paths) {
    if (file.startsWith(prefix)) out.godot.push(file.slice(prefix.length).replace(/\.uid$/, ""));
    else if (/\.(mjs|js)$/.test(file) && /^(scripts|tests|tools|server)\//.test(file)) out.node.push(file);
    else if (file.endsWith(".md")) out.docs.push(file);
    else out.other.push(file);
  }
  out.godot = [...new Set(out.godot)];
  return out;
}

export function isTopLevelTest(rel) {
  return /^tests\/[^/]+\.gd$/.test(rel);
}

function walk(directory, base, out) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(full, base, out);
    else if (TEXT_EXTENSIONS.has(path.extname(entry.name))) out.push(path.relative(base, full).split(path.sep).join("/"));
  }
  return out;
}

// The index maps each sketch file to its text, so referrers can be found by res:// path.
export function buildIndex(sketchDir) {
  const files = new Map();
  for (const rel of walk(sketchDir, sketchDir, [])) files.set(rel, readFileSync(path.join(sketchDir, rel), "utf8"));
  return indexFromFiles(files);
}

export function indexFromFiles(files) {
  const tests = [...files.keys()].filter(isTopLevelTest).sort();
  return { files, tests, cache: new Map() };
}

export function referrers(index, rel) {
  if (index.cache.has(rel)) return index.cache.get(rel);
  const needle = "res://" + rel;
  const found = [];
  for (const [file, text] of index.files) {
    if (file === rel) continue;
    const at = text.indexOf(needle);
    // "res://src/a.gd" must not match "res://src/a.gd.bak" or "res://src/a.gdshader".
    if (at >= 0 && !/[\w.]/.test(text[at + needle.length] ?? "")) found.push(file);
  }
  index.cache.set(rel, found);
  return found;
}

function stemTests(index, rel) {
  const stem = path.posix.basename(rel).replace(/\.[^.]+$/, "");
  if (stem.length < 4) return [];
  return index.tests.filter((test) => path.posix.basename(test).startsWith(stem + "_"));
}

// tier 0: a changed test; 1: a test that names the changed file, or is named after it;
// 2: a test that names a non-hub file which names the changed file.
export function selectTests(index, changed, { hub = HUB_TESTS } = {}) {
  const picked = new Map();
  const hubs = [];
  const unmapped = [];
  const add = (test, tier, why) => {
    const prior = picked.get(test);
    if (!prior || prior.tier > tier) picked.set(test, { tier, why });
  };
  for (const rel of changed) {
    if (isTopLevelTest(rel)) {
      if (index.files.has(rel)) add(rel, 0, "changed");
      continue;
    }
    const first = referrers(index, rel);
    const direct = first.filter(isTopLevelTest);
    for (const test of direct) add(test, 1, `names ${rel}`);
    for (const test of stemTests(index, rel)) add(test, 1, `named after ${rel}`);
    if (direct.length > hub) hubs.push(rel);
    let reached = direct.length;
    for (const middle of first) {
      if (isTopLevelTest(middle)) continue;
      const second = referrers(index, middle).filter(isTopLevelTest);
      if (second.length > hub) continue;
      for (const test of second) add(test, 2, `names ${middle}, which names ${rel}`);
      reached += second.length;
    }
    if (reached === 0 && stemTests(index, rel).length === 0) unmapped.push(rel);
  }
  return { picked, hubs, unmapped };
}

// Canaries: the cheapest tests that load the whole game, so a broad break shows in seconds
// even when the diff maps to nothing.
export function canaries(index, timings, count = CANARY_COUNT) {
  const whole = new Set(referrers(index, "src/game.gd").filter(isTopLevelTest));
  return Object.entries(timings)
    .filter(([test]) => whole.has(test))
    .sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))
    .slice(0, count)
    .map(([test]) => test);
}

export function estimate(timings, test) {
  return timings[test] ?? DEFAULT_ESTIMATE_MS;
}

// Keep the highest tiers within the budget (changed tests always), then run cheapest first so
// a failure shows as early as it can. Whatever the budget leaves out is named, never dropped
// silently; the staging full gate runs it.
export function plan({ picked, timings, budgetMs, width, solo = () => false, bots = () => false }) {
  const rows = [...picked].map(([test, row]) => ({ test, ...row, ms: estimate(timings, test) }));
  const botRows = rows.filter((row) => bots(row.test));
  const runnable = rows.filter((row) => !bots(row.test)).sort((a, b) => a.tier - b.tier || a.ms - b.ms || a.test.localeCompare(b.test));
  const kept = [];
  const deferred = [];
  let spent = 0;
  for (const row of runnable) {
    const cost = solo(row.test) ? row.ms : row.ms / width;
    if (row.tier === 0 || spent + cost <= budgetMs) {
      kept.push(row);
      spent += cost;
    } else deferred.push(row);
  }
  const order = (a, b) => a.tier === 0 && b.tier !== 0 ? -1 : b.tier === 0 && a.tier !== 0 ? 1 : a.ms - b.ms || a.test.localeCompare(b.test);
  return {
    parallel: kept.filter((row) => !solo(row.test)).sort(order),
    solo: kept.filter((row) => solo(row.test)).sort(order),
    deferred,
    bots: botRows.map((row) => row.test).sort(),
    estimateMs: Math.round(spent),
  };
}

// Verdict for one test after its retries. A head failure that passes on rerun is flaky (listed,
// not blamed); one that also fails on the base is base-red (listed, not blamed).
export function classifyFailure({ rerunOk, baseOk }) {
  if (rerunOk) return "flaky";
  if (baseOk === false) return "base-red";
  return "pr-red";
}

export function nodeTestsFor(changedNode, allNodeTests, readText) {
  const picked = new Set();
  for (const file of changedNode) if (/\.test\.(mjs|js)$/.test(file)) picked.add(file);
  const modules = changedNode.filter((file) => !/\.test\.(mjs|js)$/.test(file)).map((file) => path.posix.basename(file));
  if (modules.length === 0) return [...picked].sort();
  for (const test of allNodeTests) {
    const text = readText(test);
    if (modules.some((name) => text.includes("/" + name + '"') || text.includes("/" + name + "'"))) picked.add(test);
  }
  return [...picked].sort();
}

// Placeholder rows grouped by kind and where; an increase in any group fails the lane.
export function placeholderIncrease(baseRows, headRows) {
  const key = (row) => `${row.kind} ${row.where}`;
  const total = (rows) => {
    const map = new Map();
    for (const row of rows) map.set(key(row), (map.get(key(row)) ?? 0) + (row.count ?? 1));
    return map;
  };
  const base = total(baseRows);
  const grew = [];
  for (const [group, count] of total(headRows)) if (count > (base.get(group) ?? 0)) grew.push(`${group}: ${base.get(group) ?? 0} -> ${count}`);
  return grew;
}

function git(args, cwd = root) {
  const result = spawnSync("git", ["-C", cwd, ...args], { encoding: "utf8" });
  if (result.status !== 0 || result.error) throw new Error(`git ${args.join(" ")}: ${(result.stderr || "").trim()}`);
  return result.stdout.trim();
}

function readTimings() {
  try {
    return JSON.parse(readFileSync(TIMINGS_FILE, "utf8")).tests ?? {};
  } catch {
    return {};
  }
}

// Fold a smoke receipt's per-test wall times into the timings file the lane orders by.
export function timingsFromReceipt(receipt) {
  const tests = {};
  for (const row of receipt.results ?? []) {
    const match = /res:\/\/(tests\/[^ ]+\.gd)$/.exec(row.label);
    if (match && row.ok) tests[match[1]] = Math.round(row.ms);
  }
  return tests;
}

function placeholderRows(sketchDir) {
  const result = spawnSync(process.execPath, [path.join(root, "scripts", "placeholder-gate.mjs"), "--project", sketchDir, "--json"], { encoding: "utf8", maxBuffer: 64 << 20 });
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(`placeholder-gate gave no JSON for ${sketchDir}: ${(result.stderr || "").slice(0, 400)}`);
  }
}

const running = new Set();

function runGodot(sketchDir, test, timeoutMs) {
  return new Promise((resolve) => {
    const started = Date.now();
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-fast-"));
    const child = spawn(binary, ["--headless", "--path", sketchDir, "--script", "res://" + test], { env: { ...process.env, XDG_DATA_HOME: dataHome } });
    running.add(child);
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.on("close", (code) => {
      clearTimeout(timer);
      running.delete(child);
      rmSync(dataHome, { recursive: true, force: true });
      const verdict = judge({ test: "res://" + test, status: code, output });
      resolve({ test, ok: verdict.ok, exit: code, ms: Date.now() - started, reason: verdict.reason, tail: output.split("\n").slice(-30).join("\n"), killed: child.killedByLane === true });
    });
  });
}

function stopRunning() {
  for (const child of running) {
    child.killedByLane = true;
    child.kill("SIGKILL");
  }
}

function sourceOf(sketchDir, test) {
  return readFileSync(path.join(sketchDir, test), "utf8");
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const startedAt = new Date().toISOString();
  const started = Date.now();
  const sketchDir = path.join(root, SKETCH);
  const mergeBase = git(["merge-base", options.base, "HEAD"]);
  const changedPaths = git(["diff", "--name-only", mergeBase, "HEAD"]).split("\n").filter(Boolean);
  const changed = classify(changedPaths);
  const receipt = {
    schema: RECEIPT_SCHEMA,
    label: options.receipt,
    head: git(["rev-parse", "HEAD"]),
    base: options.base,
    merge_base: mergeBase,
    started_at: startedAt,
    changed: changedPaths.length,
    stages: [],
    ok: true,
  };
  const log = (line) => console.log(line);
  const stage = (name, ok, detail = {}) => {
    receipt.stages.push({ name, ok, ms: Date.now() - started, ...detail });
    log(`${ok ? "PASS" : "FAIL"} ${name}${detail.note ? ` (${detail.note})` : ""}`);
    if (!ok) receipt.ok = false;
    return ok;
  };
  let baseTree = null;
  const baseDir = () => {
    if (baseTree) return baseTree;
    baseTree = mkdtempSync(path.join(os.tmpdir(), "sketch-fast-base-"));
    rmSync(baseTree, { recursive: true, force: true });
    git(["worktree", "add", "--detach", baseTree, mergeBase]);
    return baseTree;
  };
  const finish = (code) => {
    receipt.wall_ms = Date.now() - started;
    if (baseTree) spawnSync("git", ["-C", root, "worktree", "remove", "--force", baseTree]);
    const directory = path.join(root, "artifacts", "local", "receipts");
    mkdirSync(directory, { recursive: true });
    const file = path.join(directory, `${options.receipt}-${receipt.head.slice(0, 12)}-${startedAt.replace(/[:.]/g, "-")}.json`);
    writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
    log(`receipt ${file}`);
    log(`sketch:fast ${receipt.ok ? "pass" : "fail"} in ${Math.round(receipt.wall_ms / 1000)}s on ${receipt.head.slice(0, 8)} (merge base ${mergeBase.slice(0, 8)}). Fast lane only: the staging full gate and red team still judge the wave.`);
    process.exit(code ?? (receipt.ok ? 0 : 1));
  };

  log(`sketch:fast: ${changedPaths.length} changed paths (${changed.godot.length} sketch, ${changed.node.length} node, ${changed.docs.length} docs) since ${mergeBase.slice(0, 8)}`);

  // Godot selection first: the dry run and the receipt both need it.
  const index = buildIndex(sketchDir);
  const timings = readTimings();
  const selection = selectTests(index, changed.godot);
  if (changed.godot.length > 0) for (const test of canaries(index, timings)) if (!selection.picked.has(test)) selection.picked.set(test, { tier: 3, why: "canary" });
  const width = options.width ?? 2;
  const lanePlan = plan({
    picked: selection.picked,
    timings,
    budgetMs: options.budgetS * 1000,
    width,
    solo: (test) => isSolo(sourceOf(sketchDir, test)),
    bots: (test) => isBot(sourceOf(sketchDir, test)),
  });
  receipt.selection = {
    hubs: selection.hubs,
    unmapped: selection.unmapped,
    tests: Object.fromEntries([...selection.picked].map(([test, row]) => [test, row])),
    deferred_to_full_gate: lanePlan.deferred.map((row) => row.test),
    bot_shards: lanePlan.bots,
    estimate_ms: lanePlan.estimateMs,
  };
  log(`selected ${lanePlan.parallel.length + lanePlan.solo.length} tests (${lanePlan.solo.length} solo), about ${Math.round(lanePlan.estimateMs / 1000)}s at width ${width}; ${lanePlan.deferred.length} past the budget go to the staging full gate; ${lanePlan.bots.length} bot-tier for the shards`);
  if (selection.hubs.length > 0) log(`hub files changed (each named by more than ${HUB_TESTS} tests): ${selection.hubs.join(", ")}`);
  if (selection.unmapped.length > 0) log(`no test names: ${selection.unmapped.slice(0, 8).join(", ")}${selection.unmapped.length > 8 ? ", ..." : ""}`);
  if (options.dryRun) {
    for (const row of [...lanePlan.parallel, ...lanePlan.solo]) log(`  ${(row.ms / 1000).toFixed(1)}s t${row.tier} ${row.test} (${row.why})`);
    for (const row of lanePlan.deferred) log(`  deferred t${row.tier} ${row.test}`);
    for (const test of lanePlan.bots) log(`  bot shard ${test}`);
    process.exit(0);
  }

  // Stage 1: static checks, sub-second to a minute, the commonest PR reds.
  const lint = spawnSync(process.execPath, [path.join(root, "scripts", "sketch-lint.mjs"), "--sketch", "core-loop"], { encoding: "utf8" });
  if (!stage("sketch-lint", lint.status === 0, { note: (lint.stdout || "").trim().split("\n").pop() })) {
    log(lint.stdout + lint.stderr);
    finish();
  }
  if (changed.godot.length > 0) {
    const grew = placeholderIncrease(placeholderRows(path.join(baseDir(), SKETCH)), placeholderRows(sketchDir));
    if (!stage("placeholders no higher than base", grew.length === 0, { note: grew.length ? grew.slice(0, 5).join("; ") : "no group grew", grew })) finish();
  }
  if (changed.docs.length > 0) {
    const docs = spawnSync(process.execPath, [path.join(root, "scripts", "check-docs.mjs")], { encoding: "utf8" });
    if (!stage("check:docs", docs.status === 0, { note: (docs.stdout || "").trim().split("\n")[0] })) {
      log(docs.stdout + docs.stderr);
      finish();
    }
  }
  if (changed.node.length > 0) {
    const all = git(["ls-files", "*.test.mjs", "*.test.js"]).split("\n").filter((file) => file && !file.startsWith(SKETCH) && !file.includes("node_modules"));
    const nodeTests = nodeTestsFor(changed.node, all, (file) => readFileSync(path.join(root, file), "utf8"));
    if (nodeTests.length > 0) {
      const node = spawnSync(process.execPath, ["--test", ...nodeTests], { cwd: root, encoding: "utf8", maxBuffer: 64 << 20 });
      if (!stage("node tests", node.status === 0, { note: nodeTests.join(" "), tests: nodeTests })) {
        log((node.stdout || "").split("\n").filter((line) => /^not ok|error:|location:/.test(line.trim())).slice(0, 40).join("\n"));
        finish();
      }
    }
  }
  if (lanePlan.parallel.length + lanePlan.solo.length === 0 && changed.godot.length === 0) {
    stage("godot", true, { note: "no sketch change" });
    finish();
  }

  // Stage 2: Godot. Import with one retry, boot, then the selected tests.
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
    finish(2);
  }
  await acquireMachine();
  const base = ["--headless", "--path", sketchDir];
  const imported = importWithRetry(SKETCH, base, (job) => {
    const t = Date.now();
    const result = spawnSync(binary, job.args, { encoding: "utf8", timeout: 180_000 });
    return { label: job.label, exit: result.status, ok: result.status === 0, ms: Date.now() - t };
  });
  if (!stage("import", imported.ok, { note: imported.results.map((row) => `exit=${row.exit}`).join(", ") })) finish();
  const boot = spawnSync(binary, [...base, "--quit-after", "300"], { encoding: "utf8", timeout: 180_000, env: { ...process.env, XDG_DATA_HOME: mkdtempSync(path.join(os.tmpdir(), "sketch-fast-")) } });
  const bootVerdict = judge({ status: boot.status, output: (boot.stdout || "") + (boot.stderr || "") });
  if (!stage("boot", bootVerdict.ok, { note: bootVerdict.reason ?? "300 frames" })) finish();

  const quarantine = readQuarantine(sketchDir);
  const results = [];
  const flaky = [];
  const baseRed = [];
  let baseImported = false;
  let prRed = null;

  // A failure is rerun alone on the head, then on the merge base, before it is the PR's.
  async function confirm(first) {
    const timeoutMs = testTimeoutMs(sourceOf(sketchDir, first.test));
    log(`  rerunning ${first.test} alone (${first.reason})`);
    const rerun = await runGodot(sketchDir, first.test, timeoutMs);
    let baseOk = null;
    if (!rerun.ok && options.baseCheck) {
      const baseSketch = path.join(baseDir(), SKETCH);
      if (existsSync(path.join(baseSketch, first.test))) {
        if (!baseImported) {
          importWithRetry(`${SKETCH} (base)`, ["--headless", "--path", baseSketch], (job) => {
            const result = spawnSync(binary, job.args, { encoding: "utf8", timeout: 180_000 });
            return { label: job.label, exit: result.status, ok: result.status === 0 };
          });
          baseImported = true;
        }
        log(`  running ${first.test} on the merge base`);
        baseOk = (await runGodot(baseSketch, first.test, timeoutMs)).ok;
      }
    }
    return { kind: classifyFailure({ rerunOk: rerun.ok, baseOk }), rerun };
  }

  async function handle(result) {
    const quarantined = quarantine.has(path.posix.basename(result.test, ".gd"));
    results.push({ test: result.test, ok: result.ok, exit: result.exit, ms: result.ms, reason: result.reason, quarantined });
    log(`${result.ok ? "PASS" : "FAIL"} ${result.test} exit=${result.exit} ${(result.ms / 1000).toFixed(1)}s${quarantined ? " (quarantined)" : ""}`);
    if (result.ok || quarantined || result.killed) return;
    const { kind } = await confirm(result);
    log(`  ${result.test}: ${kind}`);
    if (kind === "flaky") flaky.push(result.test);
    else if (kind === "base-red") baseRed.push(result.test);
    else if (!prRed) {
      prRed = { test: result.test, reason: result.reason, tail: result.tail };
      stopRunning();
    }
  }

  const queue = [...lanePlan.parallel];
  async function worker() {
    while (queue.length > 0 && !prRed) {
      const row = queue.shift();
      const result = await runGodot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test)));
      await handle(result);
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, queue.length) }, worker));
  for (const row of lanePlan.solo) {
    if (prRed) break;
    await handle(await runGodot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test))));
  }
  receipt.results = results;
  receipt.flaky = flaky;
  receipt.base_red = baseRed;
  if (prRed) {
    log(prRed.tail);
    stage("tests", false, { note: `${prRed.test} is red on the head twice and green on the base: ${prRed.reason}`, pr_red: prRed.test });
  } else {
    stage("tests", true, { note: `${results.length} run, ${flaky.length} flaky, ${baseRed.length} base-red` });
  }
  if (flaky.length) log(`flaky (red then green on rerun; make deterministic, never skip): ${flaky.join(", ")}`);
  if (baseRed.length) log(`base-red (red on the merge base too; not this PR): ${baseRed.join(", ")}`);
  if (lanePlan.bots.length) log(`bot shards to run: ${lanePlan.bots.map((test) => path.posix.basename(test, ".gd")).join(" ")}`);
  if (lanePlan.deferred.length) log(`past the budget, for the staging full gate: ${lanePlan.deferred.length} tests`);
  finish();
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (process.argv[2] === "--fold-timings") {
    const receipt = JSON.parse(readFileSync(process.argv[3], "utf8"));
    const prior = readTimings();
    const tests = { ...prior, ...timingsFromReceipt(receipt) };
    writeFileSync(TIMINGS_FILE, JSON.stringify({ source: `${receipt.label} ${receipt.head ?? ""}`.trim(), tests: Object.fromEntries(Object.entries(tests).sort()) }, null, 2) + "\n");
    console.log(`sketch:fast timings: ${Object.keys(tests).length} tests from ${process.argv[3]}`);
  } else main();
}
