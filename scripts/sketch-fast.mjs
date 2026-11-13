import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  countChecks,
  acquireMachine,
  binary,
  IMPORT_TRIES,
  importWithRetry,
  scriptErrorCount,
  isBot,
  isSolo,
  judge,
  expiredLine,
  expiredQuarantine,
  quarantineNote,
  quarantineRecord,
  readQuarantineEntries,
  testTimeoutMs,
} from "./sketch-smoke.mjs";
import { readLedger } from "./known-failing.mjs";

// npm run sketch:fast: the fast PR lane of the tiered gate (ORCHESTRATOR, "Tiered gate").
// It judges one PR head in about 15 minutes, cheapest and most-often-failing checks first, and
// stops at the first failure that is the PR's own: red twice on the head and green on the base.
//   1. static: sketch-lint, placeholder count no higher than the base, check:docs, the node
//      tests that touch the changed scripts
//   2. Godot: import (up to three tries), boot, then the tests the diff reaches, cheapest first
// The full gate runs once per staging head and the red team plays each staging head; the fast
// lane never replaces them. Bot-tier tests the diff reaches are listed for the bot shards.
// Every test run that ends red keeps its log beside the receipt (failedRunLog), also when a rerun
// then passes, so a flaky crash can still be read afterwards.
// Run: node scripts/sketch-fast.mjs [--base origin/main] [--budget 900] [--width <lanes>] [--dry-run] [--receipt <label>]

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const RECEIPT_SCHEMA = "scrapkeep-fast-receipt/1";
// A test with no timings row is priced at 180 s. At 30 s the wave 18 lane ran 2289 s on a 600 s
// budget: 14 of 86 picked tests had no row, and five of them were bot runs.
export const DEFAULT_ESTIMATE_MS = 180_000;
// A test with no row that is named like a bot run or a sweep is listed for the bot shards.
export const UNKNOWN_BOT_NAME = /^(bot_.*|.*_sweep_.*)\.gd$/;
// A file more tests than this reach directly is a hub (game.gd, tests/support/t.gd): its own
// direct tests still run, but nothing is selected through it at the second step.
export const HUB_TESTS = 25;
export const CANARY_COUNT = 4;
// Content pins (music rows, attack rows, world digest, scatter rows) live in unit_suite, which no
// res:// path reaches from most diffs, so it always runs (cloud gate, 18 Oct). new_world_cost
// scans every src/ script for a world, map or boss named outright, so no single path reaches it
// either; it takes about a second (BACKLOG.md SG-01, 12 Nov).
export const ALWAYS = ["tests/unit_suite_test.gd", "tests/new_world_cost_test.gd"];
// Some couplings have no res:// path: one park's recipe change moves other parks' bake hashes.
export const PATH_RULES = [
  {
    name: "park data",
    match: /(^|\/)parks?\/|(^|\/)park_[^/]*$/,
    tests: ["tests/park_park_*", "tests/park_bake_fresh_test.gd", "tests/park_graph_test.gd", "tests/park_dressing_pin_test.gd", "tests/park_props_test.gd"],
  },
  {
    // The map standard (ruling ct): a park change faces the checks that read the baked map.
    name: "map standard",
    match: /(^|\/)parks?\/|(^|\/)park_[^/]*$/,
    tests: ["tests/park_landmark_sight_test.gd", "tests/site_markers_test.gd", "tests/park_fight_bowl_test.gd", "tests/park_feature_census_test.gd", "tests/park_breath_test.gd", "tests/park_rhythm_test.gd", "tests/handover_rows_test.gd", "tests/park_scrap_lines_test.gd", "tests/park_scrap_trail_test.gd"],
  },
];
// Long whole-run proofs a change class must face; they go to the bot shards even past the budget.
export const SHARD_RULES = [
  {
    name: "movement, boss, posture or damage",
    match: /^src\/(movement|boss)\/|posture|damage/,
    tests: ["tests/posture_bands_reactor_test.gd", "tests/alpha_posture_bands_*"],
  },
];
const TEXT_EXTENSIONS = new Set([".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".gdshader"]);

export function parseArgs(argv) {
  const options = { base: "origin/main", budgetS: 900, dryRun: false, receipt: "fast", width: null, baseCheck: true, batch: true, pre: [] };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--base" && argv[i + 1]) options.base = argv[++i];
    else if (arg === "--budget" && argv[i + 1]) options.budgetS = Number(argv[++i]);
    else if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--receipt" && argv[i + 1]) options.receipt = argv[++i];
    else if (arg === "--width" && argv[i + 1]) options.width = Number(argv[++i]);
    else if (arg === "--no-base-check") options.baseCheck = false;
    else if (arg === "--no-batch") options.batch = false;
    else if (arg === "--pre" && argv[i + 1]) options.pre.push(argv[++i].replace(/^#/, ""));
  }
  if (!Number.isFinite(options.budgetS) || options.budgetS <= 0) throw new Error("--budget needs seconds above zero");
  if (options.pre.some((pr) => !/^\d+$/.test(pr))) throw new Error("--pre takes PR numbers");
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

function expand(index, globs) {
  return index.tests.filter((test) =>
    globs.some((glob) => new RegExp("^" + glob.split("*").map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*") + "$").test(test)),
  );
}

// tier 0: a changed test or an ALWAYS test; 1: a test that names the changed file, or is named after it;
// 2: a test that names a non-hub file which names the changed file.
export function selectTests(index, changed, { hub = HUB_TESTS } = {}) {
  const picked = new Map();
  const hubs = [];
  const unmapped = [];
  const shards = new Map();
  const add = (test, tier, why) => {
    const prior = picked.get(test);
    if (!prior || prior.tier > tier) picked.set(test, { tier, why });
  };
  if (changed.length > 0) for (const test of expand(index, ALWAYS)) add(test, 0, "always (content pins)");
  for (const rel of changed) {
    for (const rule of PATH_RULES) if (rule.match.test(rel)) for (const test of expand(index, rule.tests)) add(test, 1, `${rule.name}: ${rel}`);
    for (const rule of SHARD_RULES) if (rule.match.test(rel)) for (const test of expand(index, rule.tests)) if (!shards.has(test)) shards.set(test, `${rule.name}: ${rel}`);
    if (isTopLevelTest(rel)) {
      if (index.files.has(rel)) add(rel, 0, "changed");
      // A test that extends a changed test runs its parent's checks: kest_set_piece_test
      // went red on main in wave 31 because only its parent, kest_kit_test, was picked.
      // The walk follows the whole chain, as scripts/gate/carry.mjs does: dress_wog_fallback_test
      // extends dress_wog_test, which extends dress_material_test.
      const reached = new Set([rel]);
      const queue = [rel];
      while (queue.length > 0) {
        for (const test of referrers(index, queue.shift()).filter(isTopLevelTest)) {
          if (reached.has(test)) continue;
          reached.add(test);
          queue.push(test);
          add(test, 1, `reaches the changed test ${rel}`);
        }
      }
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
    if (reached === 0 && stemTests(index, rel).length === 0 && !PATH_RULES.some((rule) => rule.match.test(rel))) unmapped.push(rel);
  }
  for (const test of shards.keys()) picked.delete(test);
  return { picked, hubs, unmapped, shards };
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
export function plan({ picked, timings, budgetMs, width, solo = () => false, bots: knownBots = () => false }) {
  const bots = (test) => knownBots(test) || (timings[test] === undefined && UNKNOWN_BOT_NAME.test(path.posix.basename(test)));
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
// A test red on both sides is base-red only when the head fails no check the base passes:
// #104 took unit_suite from 6 to 11 failing checks with the same test red on the base.
// A cached base red is weaker evidence than a fresh one, so a head red that shows no checks
// (a crash) is never base-red on a cached verdict; it takes a fresh base run to say so.
export function classifyFailure({ rerunOk, baseOk, headChecks = [], baseChecks = [], baseCached = false }) {
  if (rerunOk) return { kind: "flaky", newChecks: [] };
  if (baseOk === false) {
    if (baseCached && headChecks.length === 0) return { kind: "pr-red", newChecks: [] };
    const base = new Set(baseChecks);
    const newChecks = headChecks.filter((check) => !base.has(check));
    return newChecks.length > 0 ? { kind: "pr-red", newChecks } : { kind: "base-red", newChecks: [] };
  }
  return { kind: "pr-red", newChecks: [] };
}

// A test the known-failing ledger lists as a flake can fail twice in a row with the base green
// (audio_bake_cancel_test fails between 1 run in 5 and 1 in 3), and that pair alone would read as the PR's
// red. So before such a test is the PR's red it gets up to LEDGER_FLAKE_RUNS more head runs:
// one green makes it flaky, and red on every run makes it the PR's red after all. The row
// buys more evidence; it never excuses a test the PR really broke.
export const LEDGER_FLAKE_RUNS = 3;

export function ledgerFlakes(rows) {
  return new Set(rows.filter((row) => row.kind === "flake").map((row) => row.test));
}

// `verdict` is classifyFailure's "pr-red"; `runs` are the extra head runs, in order.
export function settleLedgerFlake(verdict, runs) {
  if (runs.some((run) => run.killed)) return { kind: "stopped", newChecks: [] };
  if (runs.some((run) => run.ok)) return { kind: "flaky", newChecks: [], ledger: true };
  return { ...verdict, ledgerRuns: runs.length };
}

// A check's name is its bracketed label ("[Spillway skipper breaks it in 50 to 90 s] median ..."),
// so measured values that change run to run do not make a check look new.
export function failingChecks(output) {
  return [...new Set(output.replace(/\r/g, "").split("\n").filter((line) => line.includes("-> FAIL")).map((line) => {
    const label = /^\s*\[([^\]]+)\]/.exec(line);
    return label ? label[1] : line.replace(/->\s*FAIL.*$/, "").trim();
  }))].sort();
}

// Added files must not be symlinks, root files or new top-level folders (#104 committed a
// node_modules symlink, which broke every merge into a tree that has node_modules).
// .mcp.json is the one root file a tool requires there: Claude Code reads project MCP servers
// only from the repo root (the Godot MCP, Andrew 12 Nov 2026).
export const ROOT_FILES_ALLOWED = new Set([".mcp.json"]);
export function hygieneFindings(rawLines, baseTopLevel) {
  const findings = [];
  for (const line of rawLines) {
    const match = /^:(\d+) (\d+) \S+ \S+ A\t(.+)$/.exec(line);
    if (!match) continue;
    const [, , mode, file] = match;
    if (mode === "120000") findings.push(`symlink added: ${file}`);
    else if (ROOT_FILES_ALLOWED.has(file)) continue;
    else if (!file.includes("/")) findings.push(`root file added: ${file}`);
    else if (!baseTopLevel.has(file.split("/")[0])) findings.push(`new top-level folder: ${file}`);
  }
  return findings;
}

// The Godot MCP adds an McpBridge autoload to project.godot while the game runs and removes it
// on stop; a commit made mid-session, or after a killed session, would ship it.
export function bridgeFindings(projectGodot) {
  return /McpBridge/.test(projectGodot) ? ["project.godot carries the Godot MCP's McpBridge autoload: call stop_project, then commit"] : [];
}

// Merge commits on the PR's first-parent path each carry another branch. A carried PR that has
// moved on since is stale (#101 and #102 carried #79 without 1f69c639 and failed on old bakes).
export function mergedBranch(subject) {
  return /\bfrom [\w.-]+\/([\w./-]+)$/.exec(subject)?.[1] ?? /(?:remote-tracking branch '|branch ')(?:origin\/)?([\w./-]+)'/.exec(subject)?.[1] ?? null;
}

export function carriedPrs(merges, { prHeads = new Map(), branchHeads = new Map() }, isAncestor) {
  const prsAt = (sha) => [...prHeads].filter(([, head]) => head === sha).map(([pr]) => pr);
  return merges.map(({ merge, carried, subject }) => {
    const exact = prsAt(carried);
    if (exact.length > 0) return { merge, carried, prs: exact, stale: false };
    const named = /#(\d+)/.exec(subject)?.[1];
    const branch = mergedBranch(subject);
    const head = named && prHeads.has(named) ? prHeads.get(named) : branch && branchHeads.has(branch) ? branchHeads.get(branch) : null;
    if (!head) return { merge, carried, prs: [], branch, stale: false, subject };
    const prs = named && prHeads.has(named) ? [named] : prsAt(head);
    return { merge, carried, prs, branch, stale: head !== carried && !isAncestor(head), head };
  });
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

// Fold passing tests' wall times into the timings file the lane orders by. Three row shapes:
// a smoke receipt's label ("... res://tests/a_test.gd", ms), a fast-lane row's test
// ("tests/a_test.gd", ms) and a gate shard's test ("a_test", seconds; scripts/gate/shard.mjs).
export function timingsFromReceipt(receipt) {
  const tests = {};
  for (const row of receipt.results ?? []) {
    if (!row.ok) continue;
    const text = String(row.test ?? row.label ?? "");
    const match = /(?:^|res:\/\/)(tests\/[^ ]+\.gd)$/.exec(text);
    const name = match ? match[1] : /^[a-z0-9_]+$/.test(text) ? `tests/${text}.gd` : null;
    const ms = Number.isFinite(row.ms) ? row.ms : Number.isFinite(row.seconds) ? row.seconds * 1000 : 0;
    if (name && ms > 0) tests[name] = Math.round(ms);
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

// What a red run printed is kept whole up to this many lines. A longer log keeps its first
// LOG_HEAD_LINES (the engine's start-up) and its last LOG_TAIL_LINES (the failure), with the cut named.
export const LOG_HEAD_LINES = 200;
export const LOG_TAIL_LINES = 2000;

export function cappedLog(output, head = LOG_HEAD_LINES, tail = LOG_TAIL_LINES) {
  const lines = String(output ?? "").split("\n");
  if (lines.at(-1) === "") lines.pop();
  if (lines.length <= head + tail) return lines.join("\n");
  return [...lines.slice(0, head), `[sketch:fast cut ${lines.length - head - tail} lines here; ${lines.length} lines printed]`, ...lines.slice(lines.length - tail)].join("\n");
}

// The log of one red run: what ran, how it ended, then stdout and stderr as they arrived.
export function failedRunLog({ test, where, attempt, head, exit, signal, timedOut, ms, reason, output }) {
  const facts = [
    `test: ${test}`,
    `ran on: ${where === "base" ? "the merge base" : "the head"} (${head}), run ${attempt} there`,
    `exit: ${exit ?? "none"}${signal ? `, signal ${signal}` : ""}${timedOut ? ", stopped at its time limit" : ""}`,
    `seconds: ${(ms / 1000).toFixed(1)}`,
    `reason: ${reason}`,
  ];
  return `${facts.join("\n")}\n--- stdout and stderr ---\n${cappedLog(output)}\n`;
}

// tests/a/b_test.gd, second red run on the head -> a__b_test.head-2.log
export function failedRunLogName(test, where, attempt) {
  return `${test.replace(/^tests\//, "").replace(/\.gd$/, "").replaceAll("/", "__")}.${where}-${attempt}.log`;
}

export function receiptBaseName(label, head, startedAt) {
  return `${label}-${head.slice(0, 12)}-${startedAt.replace(/[:.]/g, "-")}`;
}

// A run that ended on a signal the lane did not send. SIGKILL is usually the container's memory
// limit (dmesg "Memory cgroup out of memory"), not the test; any other signal is a crash.
export function signalReason(signal) {
  if (!signal || signal === "SIGKILL") return "killed by a signal before its time limit (often the container's memory limit; see dmesg)";
  return `ended on ${signal} before its time limit (a crash in the engine or the test; the kept log has the backtrace)`;
}

const running = new Set();

function runGodot(sketchDir, test, timeoutMs, onChild = () => {}) {
  return new Promise((resolve) => {
    const started = Date.now();
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-fast-"));
    const child = spawn(binary, ["--headless", "--path", sketchDir, "--script", "res://" + test], { env: { ...process.env, XDG_DATA_HOME: dataHome } });
    running.add(child);
    onChild(child);
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      running.delete(child);
      rmSync(dataHome, { recursive: true, force: true });
      const verdict = judge({ test: "res://" + test, status: code, output });
      const reason = code === null && !timedOut && child.killedByLane !== true ? signalReason(signal) : verdict.reason;
      resolve({ test, ok: verdict.ok, exit: code, signal: signal ?? null, ms: Date.now() - started, reason, checks: failingChecks(output), passes: countChecks(output).passes, tail: output.split("\n").slice(-30).join("\n"), killed: child.killedByLane === true, timedOut, output });
    });
  });
}

function runBatch(sketchDir, tests, timeoutMs, onChild = () => {}) {
  return new Promise((resolve) => {
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-fast-"));
    const child = spawn(binary, ["--headless", "--path", sketchDir, "--script", "res://tools/test_batch.gd"], { env: { ...process.env, XDG_DATA_HOME: dataHome, SCRAPKEEP_TEST_BATCH: tests.join(",") } });
    running.add(child);
    onChild(child);
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.on("close", () => {
      clearTimeout(timer);
      running.delete(child);
      rmSync(dataHome, { recursive: true, force: true });
      const { done, cut, rest } = splitBatch(output, tests);
      const runs = done.map((row) => {
        const verdict = judge({ test: "res://" + row.test, status: row.exit, output: row.output });
        return { test: row.test, ok: verdict.ok, exit: row.exit, signal: null, ms: row.ms, reason: verdict.reason, checks: failingChecks(row.output), passes: countChecks(row.output).passes, tail: row.output.split("\n").slice(-30).join("\n"), killed: false, timedOut: false, output: row.output, batched: true };
      });
      resolve({ runs, unfinished: cut ? [cut, ...rest] : rest, killed: child.killedByLane === true });
    });
  });
}

function stopChild(child) {
  child.killedByLane = true;
  child.kill("SIGKILL");
}

function stopRunning() {
  for (const child of running) stopChild(child);
}

// A headless Godot test uses about one core (1.06 measured on a world 1 bot run, 11 Nov), so the
// lane takes one lane per idle core, at least 2 and at most 8. Width 2 left half of a 4 vCPU
// cloud box idle; on a loaded PC the idle count keeps it at 2. --width overrides it.
export function defaultWidth(cpus = os.cpus().length, load = os.loadavg()[0]) {
  return Math.min(8, Math.max(2, Math.round(cpus - load)));
}

// Every Godot process the lane starts holds one of `width` lanes, so a confirm's head rerun and
// base run never push one machine slot past its width (GRAPH caps a 4 vCPU box at 6 lanes).
// A task holds one lane at a time and never waits for a second, so lanes cannot deadlock.
// A warm batch runs several game tests one after another in one Godot (tools/test_batch.gd), so
// the game's scripts compile once per batch instead of once per test (about 7 s each). A test
// joins a batch only when it is a plain SceneTree script that no marker sends to its own process:
// it times itself, warms or measures a first load, starts processes or sets the environment.
const BATCH_SOLO = /get_ticks_|OS\.set_environment|ProjectSettings\.set|OS\.(execute|create_process|kill)|\b(warm|hitch|cold)\b|change_scene/;
// Only short tests batch: compiling is about 7 s of a test, so a test past BATCH_TEST_MAX_MS gains
// little, and a long batch holds its lane while the others sit idle at the end (a first try that
// batched long tests took 222 and 231 s against 174 s one Godot each). The game also counts
// frames for the whole process, so a long test that times cards by frame can read differently
// after others; alone, it reads as it always has.
export const BATCH_MAX_TESTS = 8;
export const BATCH_MAX_MS = 60_000;
export const BATCH_TEST_MAX_MS = 15_000;

export function batchable(source) {
  return /^extends SceneTree\r?$/m.test(source.split("\n", 1)[0]) && !isSolo(source) && !BATCH_SOLO.test(source);
}

// Takes the batch for one lane from the front of the queue: consecutive batchable rows, at most
// BATCH_MAX_TESTS and about BATCH_MAX_MS of measured time. A row that cannot batch goes alone.
export function takeBatch(queue, canBatch, maxTests = BATCH_MAX_TESTS, maxMs = BATCH_MAX_MS) {
  const batch = [];
  let ms = 0;
  while (queue.length > 0 && batch.length < maxTests && canBatch(queue[0]) && (batch.length === 0 || ms + queue[0].ms <= maxMs)) {
    ms += queue[0].ms;
    batch.push(queue.shift());
  }
  return batch;
}

// Splits a batch's output into each test's own output by its BATCH START and BATCH END lines.
// A test that started and never ended was cut off (a crash or the time limit); the tests after
// it never started.
export function splitBatch(output, tests) {
  const done = [];
  let open = null;
  let lines = [];
  for (const line of output.split("\n")) {
    const start = /^BATCH START (\S+)/.exec(line);
    const end = /^BATCH END (\S+) exit=(-?\d+) ms=(\d+)/.exec(line);
    if (start) {
      open = start[1];
      lines = [];
    } else if (end && open === end[1]) {
      done.push({ test: open, exit: Number(end[2]), ms: Number(end[3]), output: lines.join("\n") });
      open = null;
    } else if (open) lines.push(line);
  }
  const ended = new Set(done.map((row) => row.test));
  return { done, cut: open, rest: tests.filter((test) => !ended.has(test) && test !== open) };
}

export function lanePool(width) {
  let free = width;
  const waiters = [];
  return async (task) => {
    if (free > 0) free--;
    else await new Promise((resolve) => waiters.push(resolve));
    try {
      return await task();
    } finally {
      const next = waiters.shift();
      if (next) next();
      else free++;
    }
  };
}

// Only a clean base verdict is cached. A timeout or a kill can come from machine load, and a
// cached one would read every later real red on that test as base-red.
export function cacheableBaseRun(run) {
  return run.exit !== null && !run.killed && !run.timedOut;
}

// A base red is trusted from the cache only once two base runs agreed on the same failing
// checks (a flaky base red then lasts for the run that saw it). A fresh pass replaces the entry.
export function settleBaseEntry(prior, run) {
  if (run.ok) return { ok: true, checks: [] };
  const same = prior && prior.ok === false && prior.checks.length > 0
    && prior.checks.length === run.checks.length && prior.checks.every((check, i) => check === run.checks[i]);
  return { ok: false, checks: run.checks, confirmed: Boolean(same) };
}

export function trustedBaseEntry(entry) {
  return Boolean(entry) && (entry.ok === true || entry.confirmed === true);
}

// The base run that may judge this run's verdict. A lane stop says nothing; a base timeout or
// outside kill (exit null, say the OOM killer) says "red on the base too" only when the head rerun
// timed out as well, else a crash on the head would hide behind a load failure on the base.
// One exception: a base that died by a signal keeps its verdict when the head rerun died by the
// same signal and both fail the same checks (an abort at exit on both sides).
// SIGKILL is the OOM killer or the lane's own timeout kill, so it never counts.
export function usableBaseRun(rerun, baseRun) {
  if (!baseRun || baseRun.killed) return null;
  if ((baseRun.timedOut || baseRun.exit === null) && !rerun.timedOut) {
    const signal = baseRun.signal;
    const sameSignal = Boolean(signal) && signal !== "SIGKILL" && rerun.signal === signal && !baseRun.timedOut && !rerun.killed;
    const head = [...(rerun.checks ?? [])].sort();
    const base = [...(baseRun.checks ?? [])].sort();
    const sameChecks = head.length === base.length && head.every((check, i) => check === base[i]);
    // An earlier abort on the head shows as fewer passing checks, so the counts must match too.
    const samePasses = rerun.passes === baseRun.passes;
    return sameSignal && sameChecks && samePasses ? baseRun : null;
  }
  return baseRun;
}

function importAsync(args) {
  return new Promise((resolve) => {
    const child = spawn(binary, [...args, "--import"], { stdio: "ignore" });
    const timer = setTimeout(() => child.kill("SIGKILL"), 180_000);
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve(code);
    });
  });
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
  // --pre PRs must already be merged into the head; the base gains them too, so their changes
  // neither count as the PR's diff nor as the PR's reds (#100 needs #91, #78 needs #67).
  for (const pr of options.pre) {
    git(["fetch", "-q", "origin", `+refs/pull/${pr}/head:refs/remotes/pr/${pr}`]);
    if (spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", `refs/remotes/pr/${pr}`, "HEAD"]).status !== 0) {
      console.error(`--pre ${pr}: the head does not contain PR #${pr} at its current head. Merge it first: git merge --no-edit refs/remotes/pr/${pr}`);
      process.exit(2);
    }
  }
  const receipt = {
    schema: RECEIPT_SCHEMA,
    label: options.receipt,
    head: git(["rev-parse", "HEAD"]),
    base: options.base,
    merge_base: mergeBase,
    started_at: startedAt,
    stages: [],
    ok: true,
  };
  const receiptDirectory = path.join(root, "artifacts", "local", "receipts");
  const receiptName = receiptBaseName(options.receipt, receipt.head, startedAt);
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
    for (const pr of options.pre) git(["-c", "user.name=sketch-fast", "-c", "user.email=sketch-fast@localhost", "merge", "-q", "--no-edit", `refs/remotes/pr/${pr}`], baseTree);
    return baseTree;
  };
  const diffBase = options.pre.length > 0 ? git(["rev-parse", "HEAD"], baseDir()) : mergeBase;
  const changedPaths = git(["diff", "--name-only", diffBase, "HEAD"]).split("\n").filter(Boolean);
  const changed = classify(changedPaths);
  receipt.diff_base = diffBase;
  receipt.pre = options.pre;
  receipt.changed = changedPaths.length;
  const finish = (code) => {
    receipt.wall_ms = Date.now() - started;
    if (baseTree) spawnSync("git", ["-C", root, "worktree", "remove", "--force", baseTree]);
    mkdirSync(receiptDirectory, { recursive: true });
    const file = path.join(receiptDirectory, `${receiptName}.json`);
    writeFileSync(file, JSON.stringify(receipt, null, 2) + "\n");
    log(`receipt ${file}`);
    log(`sketch:fast ${receipt.ok ? "pass" : "fail"} in ${Math.round(receipt.wall_ms / 1000)}s on ${receipt.head.slice(0, 8)} (merge base ${mergeBase.slice(0, 8)}). Fast lane only: the staging full gate and red team still judge the wave.`);
    process.exit(code ?? (receipt.ok ? 0 : 1));
  };

  log(`sketch:fast: ${changedPaths.length} changed paths (${changed.godot.length} sketch, ${changed.node.length} node, ${changed.docs.length} docs) since ${diffBase.slice(0, 8)}${options.pre.length ? ` (merge base plus ${options.pre.map((pr) => "#" + pr).join(", ")})` : ""}`);

  // Stage 0: what the head is made of. Hygiene, then any stale branch it carries.
  const baseTop = new Set(git(["ls-tree", "--name-only", diffBase]).split("\n").filter(Boolean));
  const hygiene = [
    ...hygieneFindings(git(["diff", "--raw", "--no-abbrev", "--diff-filter=A", diffBase, "HEAD"]).split("\n"), baseTop),
    ...bridgeFindings(spawnSync("git", ["-C", root, "show", "HEAD:sketches/core-loop/project.godot"], { encoding: "utf8" }).stdout ?? ""),
  ];
  if (!stage("tree hygiene", hygiene.length === 0, { note: hygiene.length ? hygiene.slice(0, 5).join("; ") : "no symlink, root file or new top-level folder", findings: hygiene }) && !options.dryRun) finish();
  const merges = git(["rev-list", "--first-parent", "--merges", "--parents", `${mergeBase}..HEAD`]).split("\n").filter(Boolean)
    .map((line) => line.split(" "))
    .filter(([, , second]) => second && spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", second, mergeBase]).status !== 0)
    .map(([merge, , carried]) => ({ merge, carried, subject: git(["log", "-1", "--format=%s", merge]) }));
  if (merges.length > 0) {
    const heads = { prHeads: new Map(), branchHeads: new Map() };
    const remote = spawnSync("git", ["-C", root, "ls-remote", "origin", "refs/pull/*/head", "refs/heads/*"], { encoding: "utf8", timeout: 60_000 });
    for (const line of (remote.stdout || "").split("\n")) {
      const pull = /^([0-9a-f]{40})\trefs\/pull\/(\d+)\/head$/.exec(line);
      if (pull) heads.prHeads.set(pull[2], pull[1]);
      const branch = /^([0-9a-f]{40})\trefs\/heads\/(.+)$/.exec(line);
      if (branch) heads.branchHeads.set(branch[2], branch[1]);
    }
    const isAncestor = (sha) => {
      spawnSync("git", ["-C", root, "fetch", "-q", "origin", sha]);
      return spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", sha, "HEAD"]).status === 0;
    };
    const carried = carriedPrs(merges, heads, isAncestor);
    receipt.carried = carried;
    const label = (row) => row.prs.length ? row.prs.map((pr) => "#" + pr).join(", ") : row.branch ?? "an unnamed branch";
    for (const row of carried) log(`  carries ${label(row)} at ${row.carried.slice(0, 8)}${row.stale ? ` (stale: its head is now ${row.head.slice(0, 8)})` : ""}${row.subject && !row.branch ? ` (${row.subject})` : ""}`);
    const stale = carried.filter((row) => row.stale);
    if (!stage("carried branches current", stale.length === 0, { note: stale.length ? stale.map((row) => `${label(row)} carried at ${row.carried.slice(0, 8)}, now ${row.head.slice(0, 8)}`).join("; ") : `${carried.length} merges, none stale` }) && !options.dryRun) {
      log("  merge each stale branch's current head into the PR (or drop the carry), then rerun");
      finish();
    }
  }


  // Godot selection first: the dry run and the receipt both need it.
  const index = buildIndex(sketchDir);
  const timings = readTimings();
  const selection = selectTests(index, changed.godot);
  if (changed.godot.length > 0) for (const test of canaries(index, timings)) if (!selection.picked.has(test)) selection.picked.set(test, { tier: 3, why: "canary" });
  const width = options.width ?? defaultWidth();
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
    bot_shards: [...new Set([...lanePlan.bots, ...selection.shards.keys()])].sort(),
    shard_reasons: Object.fromEntries(selection.shards),
    estimate_ms: lanePlan.estimateMs,
  };
  log(`selected ${lanePlan.parallel.length + lanePlan.solo.length} tests (${lanePlan.solo.length} solo), about ${Math.round(lanePlan.estimateMs / 1000)}s at width ${width}; ${lanePlan.deferred.length} past the budget go to the staging full gate; ${receipt.selection.bot_shards.length} for the bot shards`);
  if (selection.hubs.length > 0) log(`hub files changed (each named by more than ${HUB_TESTS} tests): ${selection.hubs.join(", ")}`);
  if (selection.unmapped.length > 0) log(`no test names: ${selection.unmapped.slice(0, 8).join(", ")}${selection.unmapped.length > 8 ? ", ..." : ""}`);
  if (options.dryRun) {
    for (const row of [...lanePlan.parallel, ...lanePlan.solo]) log(`  ${(row.ms / 1000).toFixed(1)}s t${row.tier} ${row.test} (${row.why})`);
    for (const row of lanePlan.deferred) log(`  deferred t${row.tier} ${row.test}`);
    for (const test of receipt.selection.bot_shards) log(`  bot shard ${test}${selection.shards.has(test) ? ` (${selection.shards.get(test)})` : ""}`);
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

  // Stage 2: Godot. Import in up to three tries, boot, then the selected tests.
  const quarantineEntries = readQuarantineEntries(sketchDir);
  const quarantine = new Set(quarantineEntries.map((entry) => entry.test));
  const expired = expiredQuarantine(quarantineEntries);
  for (const entry of expired) log(expiredLine(entry));
  if (!stage("quarantine", expired.length === 0, { note: expired.length ? `${expired.length} expired: ${expired.map((entry) => entry.test).join(", ")}` : `${quarantineEntries.length} rows, none expired` })) finish();
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
    stage("godot", false, { note: "no Godot binary, so no test ran" });
    finish(2);
  }
  await acquireMachine();
  const base = ["--headless", "--path", sketchDir];
  const imported = importWithRetry(SKETCH, base, (job) => {
    const t = Date.now();
    const result = spawnSync(binary, job.args, { encoding: "utf8", timeout: 180_000 });
    return { label: job.label, exit: result.status, signal: result.signal ?? null, scriptErrors: scriptErrorCount((result.stdout || "") + (result.stderr || "")), ok: result.status === 0, ms: Date.now() - t };
  }, log);
  if (!stage("import", imported.ok, { note: imported.tries.map((row) => `${row.outcome} exit=${row.exit ?? row.signal}`).join(", ") })) finish();
  const boot = spawnSync(binary, [...base, "--quit-after", "300"], { encoding: "utf8", timeout: 180_000, env: { ...process.env, XDG_DATA_HOME: mkdtempSync(path.join(os.tmpdir(), "sketch-fast-")) } });
  const bootVerdict = judge({ status: boot.status, output: (boot.stdout || "") + (boot.stderr || "") });
  if (!stage("boot", bootVerdict.ok, { note: bootVerdict.reason ?? "300 frames" })) finish();

  const results = [];
  const flaky = [];
  const ledgerFlaky = [];
  const flakeRows = ledgerFlakes((await readLedger(root))?.rows ?? []);
  const baseRed = [];
  let prRed = null;
  const inLane = lanePool(width);
  const stopped = (test) => ({ test, ok: false, exit: null, ms: 0, reason: "lane stopped", checks: [], tail: "", killed: true, timedOut: false });
  // Every run that ends red keeps its log in a folder named after the receipt, and the receipt
  // lists it. A run the lane stopped is no verdict and keeps nothing.
  receipt.failed_runs = [];
  const redRuns = new Map();
  const keepRed = (where) => ({ output, ...run }) => {
    if (run.ok || run.killed) return run;
    const key = `${run.test} ${where}`;
    const attempt = (redRuns.get(key) ?? 0) + 1;
    redRuns.set(key, attempt);
    const file = path.join(receiptDirectory, `${receiptName}-logs`, failedRunLogName(run.test, where, attempt));
    const kept = { test: run.test, where, attempt, exit: run.exit, signal: run.signal, timed_out: run.timedOut, ms: run.ms, reason: run.reason, log: null };
    try {
      mkdirSync(path.dirname(file), { recursive: true });
      writeFileSync(file, failedRunLog({ ...run, where, attempt, head: where === "base" ? diffBase : receipt.head, output }));
      kept.log = path.relative(root, file);
      log(`  log of this red run of ${run.test}: ${kept.log}`);
    } catch (error) {
      log(`  log of this red run of ${run.test} not written (${error.message}); the verdict still stands`);
    }
    receipt.failed_runs.push(kept);
    return run;
  };
  const godot = (dir, test, timeoutMs, onChild, skip = () => false) => inLane(() => (prRed || skip() ? stopped(test) : runGodot(dir, test, timeoutMs, onChild).then(keepRed(dir === sketchDir ? "head" : "base"))));

  // A failure is rerun on the head and on the merge base side by side before it is the PR's
  // (a solo test reruns alone first). Base verdicts are cached per base tree and Godot binary in
  // the shared git directory, so every worktree reuses them and --pre merges hit the cache too.
  const baseTreeId = git(["rev-parse", `${diffBase}^{tree}`]);
  const baseCacheFile = path.join(path.resolve(root, git(["rev-parse", "--git-common-dir"])), "sketch-fast", `base-runs-${baseTreeId.slice(0, 12)}.json`);
  const binaryStat = existsSync(binary) ? statSync(binary) : null;
  const binaryId = `${binary} ${binaryStat?.size ?? 0} ${binaryStat?.mtimeMs ?? 0}`;
  const readBaseCache = () => {
    try {
      const stored = JSON.parse(readFileSync(baseCacheFile, "utf8"));
      return stored.binary === binaryId ? stored.tests ?? {} : {};
    } catch {
      return {};
    }
  };
  const baseCache = readBaseCache();
  let baseImport = null;
  async function onBase(test, timeoutMs, cancel = { cancelled: false }) {
    if (!options.baseCheck) return null;
    if (trustedBaseEntry(baseCache[test])) {
      log(`  ${test} on the merge base: cached (${baseCache[test].ok ? "green" : "red"})`);
      return { ...baseCache[test], cached: true };
    }
    const baseSketch = path.join(baseDir(), SKETCH);
    if (!existsSync(path.join(baseSketch, test))) return null;
    if (cancel.cancelled || prRed) return null;
    baseImport ??= inLane(async () => {
      if (prRed) return false;
      const args = ["--headless", "--path", baseSketch];
      // The base tree is a fresh checkout, where the engine's first import can crash (IMPORT_TRIES).
      for (let attempt = 1; attempt <= IMPORT_TRIES; attempt++) {
        if (prRed) return false;
        if ((await importAsync(args)) === 0) return true;
        if (attempt < IMPORT_TRIES) log(`${SKETCH} (base) import try ${attempt} of ${IMPORT_TRIES} failed; trying again`);
      }
      return false;
    });
    if (!(await baseImport)) {
      log(`  ${test} on the merge base: no verdict (the base import failed ${IMPORT_TRIES} times)`);
      return null;
    }
    if (cancel.cancelled) return null;
    log(`  running ${test} on the merge base`);
    const run = await godot(
      baseSketch,
      test,
      timeoutMs,
      (child) => {
        cancel.child = child;
        if (cancel.cancelled) stopChild(child);
      },
      () => cancel.cancelled,
    );
    if (cacheableBaseRun(run)) {
      // Another lane on this base tree may have written since; keep its entries, replace atomically.
      const disk = readBaseCache();
      baseCache[test] = settleBaseEntry(disk[test] ?? baseCache[test], run);
      const merged = { ...disk, ...baseCache };
      try {
        mkdirSync(path.dirname(baseCacheFile), { recursive: true });
        const temp = `${baseCacheFile}.${process.pid}.tmp`;
        writeFileSync(temp, JSON.stringify({ binary: binaryId, tree: baseTreeId, tests: merged }, null, 2) + "\n");
        renameSync(temp, baseCacheFile);
      } catch (error) {
        log(`  base verdict cache not written (${error.message}); the verdict still stands`);
      }
    }
    return run;
  }

  async function confirm(first) {
    const source = sourceOf(sketchDir, first.test);
    const timeoutMs = testTimeoutMs(source);
    let rerun;
    let baseRun = null;
    if (isSolo(source)) {
      log(`  rerunning ${first.test} alone (${first.reason})`);
      rerun = await godot(sketchDir, first.test, timeoutMs);
      if (!rerun.ok) baseRun = await onBase(first.test, timeoutMs);
    } else {
      log(`  rerunning ${first.test} on the head and the merge base (${first.reason})`);
      const cancel = { cancelled: false, child: null };
      const pending = godot(sketchDir, first.test, timeoutMs);
      const basePending = onBase(first.test, timeoutMs, cancel);
      rerun = await pending;
      // A green rerun makes the base verdict moot: stop the base run and cache nothing from it.
      if (rerun.ok) {
        cancel.cancelled = true;
        if (cancel.child) stopChild(cancel.child);
      }
      baseRun = await basePending;
    }
    // A run the lane stopped is not a verdict; the PR's red already decides the lane.
    if (rerun.killed) return { kind: "stopped", newChecks: [], rerun };
    baseRun = usableBaseRun(rerun, baseRun);
    const baseOk = rerun.ok || !baseRun ? null : baseRun.ok;
    const baseChecks = rerun.ok || !baseRun ? [] : baseRun.checks;
    const verdict = classifyFailure({ rerunOk: rerun.ok, baseOk, headChecks: rerun.checks, baseChecks, baseCached: Boolean(baseRun?.cached) });
    if (verdict.kind !== "pr-red" || !flakeRows.has(path.posix.basename(first.test, ".gd"))) return { ...verdict, rerun };
    const more = [];
    while (more.length < LEDGER_FLAKE_RUNS && !more.some((run) => run.ok || run.killed)) {
      log(`  ${first.test} has a flake row in the known-failing ledger: head run ${more.length + 1} of up to ${LEDGER_FLAKE_RUNS} more`);
      more.push(await godot(sketchDir, first.test, timeoutMs));
    }
    return { ...settleLedgerFlake(verdict, more), rerun };
  }

  async function handle(result) {
    const quarantined = quarantine.has(path.posix.basename(result.test, ".gd"));
    results.push({ test: result.test, ok: result.ok, exit: result.exit, signal: result.signal ?? null, failing: (result.checks ?? []).length, ms: result.ms, reason: result.reason, quarantined });
    log(`${result.ok ? "PASS" : "FAIL"} ${result.test} exit=${result.exit} ${(result.ms / 1000).toFixed(1)}s${quarantined ? " (quarantined)" : ""}`);
    if (!result.ok && quarantined) {
      const entry = quarantineEntries.find((row) => row.test === path.posix.basename(result.test, ".gd"));
      log(`  ${quarantineNote(entry)}`);
    }
    if (result.ok || quarantined || result.killed) return;
    const { kind, newChecks, ledger, ledgerRuns } = await confirm(result);
    log(`  ${result.test}: ${kind}${ledger ? " (a known-failing ledger flake: green on a later head run)" : ""}${newChecks.length ? ` (new failing checks: ${newChecks.join("; ")})` : ""}`);
    if (kind === "stopped") return;
    if (kind === "flaky") {
      flaky.push(result.test);
      if (ledger) ledgerFlaky.push(result.test);
    } else if (kind === "base-red") baseRed.push(result.test);
    else if (!prRed) {
      const reason = newChecks.length ? `fails checks the base passes: ${newChecks.join("; ")}` : result.reason;
      prRed = { test: result.test, reason: ledgerRuns ? `${reason}; listed as a flake in the known-failing ledger, but red on all ${ledgerRuns + 2} head runs` : reason, tail: result.tail };
      stopRunning();
    }
  }

  const queue = [...lanePlan.parallel];
  // A red in a warm batch is rerun alone before anything else sees it, and the alone run is the
  // verdict: a batch can save time but never adds a red of its own. Each such rerun is listed.
  receipt.batch = { on: options.batch, batches: 0, tests: 0, reruns: [] };
  const canBatch = (row) => options.batch && !row.alone && row.ms <= BATCH_TEST_MAX_MS && batchable(sourceOf(sketchDir, row.test));
  async function runBatched(rows) {
    const tests = rows.map((row) => row.test);
    const timeoutMs = rows.reduce((sum, row) => sum + testTimeoutMs(sourceOf(sketchDir, row.test)), 0);
    const batch = await inLane(() => (prRed ? { runs: [], unfinished: [], killed: true } : runBatch(sketchDir, tests, timeoutMs)));
    receipt.batch.batches++;
    receipt.batch.tests += batch.runs.length;
    for (const run of batch.runs) {
      if (prRed) return;
      if (run.ok) {
        await handle(run);
        continue;
      }
      keepRed("batch")(run);
      log(`  ${run.test} red in a warm batch (${run.reason}); rerunning it alone`);
      const alone = await godot(sketchDir, run.test, testTimeoutMs(sourceOf(sketchDir, run.test)));
      receipt.batch.reruns.push({ test: run.test, batch_reason: run.reason, alone_ok: alone.ok });
      await handle(alone);
    }
    if (!batch.killed) for (const test of batch.unfinished.reverse()) queue.unshift({ ...rows.find((row) => row.test === test), alone: true });
  }
  async function worker() {
    while (queue.length > 0 && !prRed) {
      const rows = takeBatch(queue, canBatch);
      if (rows.length > 1) {
        await runBatched(rows);
        continue;
      }
      const row = rows[0] ?? queue.shift();
      const result = await godot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test)));
      await handle(result);
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, queue.length) }, worker));
  for (const row of lanePlan.solo) {
    if (prRed) break;
    await handle(await runGodot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test))).then(keepRed("head")));
  }
  receipt.results = results;
  receipt.quarantined = results.filter((row) => row.quarantined).map((row) => quarantineRecord(quarantineEntries.find((entry) => entry.test === path.posix.basename(row.test, ".gd")), { ok: row.ok, exit: row.exit, signal: row.signal, failing: row.failing }));
  receipt.flaky = flaky;
  receipt.ledger_flaky = ledgerFlaky;
  receipt.base_red = baseRed;
  if (prRed) {
    log(prRed.tail);
    stage("tests", false, { note: `${prRed.test} is the PR's red: ${prRed.reason}`, pr_red: prRed.test });
  } else {
    stage("tests", true, { note: `${results.length} run, ${flaky.length} flaky, ${baseRed.length} base-red` });
  }
  if (flaky.length) log(`flaky (red then green on rerun; make deterministic, never skip): ${flaky.join(", ")}`);
  if (baseRed.length) log(`base-red (red on the merge base too; not this PR): ${baseRed.join(", ")}`);
  if (receipt.selection.bot_shards.length) log(`bot shards to run: ${receipt.selection.bot_shards.map((test) => path.posix.basename(test, ".gd")).join(" ")}`);
  if (lanePlan.deferred.length) log(`past the budget, for the staging full gate: ${lanePlan.deferred.length} tests`);
  finish();
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (process.argv[2] === "--fold-timings") {
    const files = process.argv.slice(3);
    if (files.length === 0) throw new Error("--fold-timings takes one or more receipt files (smoke, fast lane or gate shard.json)");
    const receipts = files.map((file) => JSON.parse(readFileSync(file, "utf8")));
    const tests = Object.assign({}, readTimings(), ...receipts.map(timingsFromReceipt));
    const source = receipts.length === 1 ? `${receipts[0].label ?? receipts[0].title ?? files[0]} ${receipts[0].head ?? ""}`.trim() : `${receipts.length} receipts on ${[...new Set(receipts.map((receipt) => String(receipt.head ?? "").slice(0, 8)))].join(", ")} (passing tests only; older rows kept)`;
    writeFileSync(TIMINGS_FILE, JSON.stringify({ source, tests: Object.fromEntries(Object.entries(tests).sort()) }, null, 2) + "\n");
    console.log(`sketch:fast timings: ${Object.keys(tests).length} tests after ${files.length} receipt${files.length === 1 ? "" : "s"}`);
  } else main();
}
