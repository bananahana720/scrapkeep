import { spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  expiredLine,
  expiredQuarantine,
  quarantineNote,
  quarantineRecord,
  readQuarantineEntries,
  spawnCollect,
} from "./sketch-smoke.mjs";
import {
  ROOT_FILES_ALLOWED,
  SKILL_LINK,
  bridgeFindings,
  carriedPrs,
  checkLabels,
  checksRemoved,
  hygieneFindings,
  mergedBranch,
  placeholderIncrease,
  removedChecks,
} from "./lib/fast-diff-checks.mjs";
import {
  BATCH_MAX_MS,
  BATCH_MAX_TESTS,
  BATCH_TEST_MAX_MS,
  IMPORT_TRIES,
  batchable,
  countChecks,
  evaluateBatchOutput,
  globToRegExp,
  importWithRetry,
  isBot,
  isSolo,
  judge,
  matchesGlob,
  runGodotBatch,
  scriptErrorCount,
  splitBatch,
  takeBatch,
  takeBatchPacked,
  testFixedFps,
  testTimeoutMs,
} from "./lib/godot-test-runner.mjs";
import { acquireMachine } from "./lib/machine-lock.mjs";
import { killGroup, runProcess } from "./lib/proc.mjs";
import { runnerReceiptBaseName, runnerReceiptPath, writeJsonReceipt } from "./lib/receipt.mjs";
import { readLedger } from "./known-failing.mjs";
import { checkImportStamp, godotIdentity, writeImportStamp } from "./import-stamp.mjs";
import { resolveGodotBinary, withScratchGodotEnv } from "./godot-home.mjs";
import { discoverTestFiles, shuffleFiles } from "./ci/node-tests.mjs";
import { packDurationShards } from "./ci/shard-plan.mjs";

const binary = resolveGodotBinary();

export {
  BATCH_MAX_MS,
  BATCH_MAX_TESTS,
  BATCH_TEST_MAX_MS,
  ROOT_FILES_ALLOWED,
  SKILL_LINK,
  batchable,
  bridgeFindings,
  carriedPrs,
  checkLabels,
  checksRemoved,
  hygieneFindings,
  mergedBranch,
  placeholderIncrease,
  removedChecks,
  splitBatch,
  takeBatch,
  takeBatchPacked,
};

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH = "sketches/core-loop";
const TIMINGS_FILE = path.join(root, "scripts", "sketch-fast.timings.json");
const RECEIPT_SCHEMA = "scrapkeep-fast-receipt/1";
export const DEFAULT_ESTIMATE_MS = 180_000;
export const UNKNOWN_BOT_NAME = /^(bot_.*|.*_sweep_.*)\.gd$/;
export const HUB_TESTS = 25;
export const CANARY_COUNT = 4;
export const ALWAYS = [
  "tests/unit_suite_test.gd",
  "tests/new_world_cost_test.gd",
  "tests/colour_meanings_test.gd",
  "tests/app_shell_test.gd",
  "tests/identity_value_lint_test.gd",
  "tests/asset_registry_test.gd",
  "tests/test_tool_owners_test.gd",
];
export const PATH_RULES = [
  {
    name: "park data",
    match: /(^|\/)parks?\/|(^|\/)park_[^/]*$/,
    tests: [
      "tests/park_park_*",
      "tests/park_bake_fresh_test.gd",
      "tests/park_bake_spike_test.gd",
      "tests/park_graph_test.gd",
      "tests/park_regions_test.gd",
      "tests/park_anchor_span_test.gd",
      "tests/park_field_posts_test.gd",
      "tests/park_dressing_pin_test.gd",
      "tests/park_props_test.gd",
      "tests/spillway_finds_test.gd",
    ],
  },
  {
    name: "asset registry and model kits",
    match: /^assets\/.*\.(?:glb|png|jpg|jpeg|webp|hdr|json)$|^assets\/registry\.d\//,
    tests: [
      "tests/asset_registry_test.gd",
      "tests/dress_mds_assets_test.gd",
      "tests/dress_mdm_assets_test.gd",
    ],
  },
  {
    name: "map standard",
    match: /(^|\/)parks?\/|(^|\/)park_[^/]*$/,
    tests: [
      "tests/park_landmark_sight_test.gd",
      "tests/site_markers_test.gd",
      "tests/park_fight_bowl_test.gd",
      "tests/park_feature_census_test.gd",
      "tests/park_breath_test.gd",
      "tests/park_rhythm_test.gd",
      "tests/handover_rows_test.gd",
      "tests/park_scrap_lines_test.gd",
      "tests/park_scrap_trail_test.gd",
      "tests/dam_incline_yard_test.gd",
    ],
  },
];
export const NODE_PATH_RULES = [
  {
    name: "park prop far meshes",
    match: /(^|\/)park\/props\/|^tools\/model_audit\.py$/,
    tests: ["scripts/far-faults.test.mjs"],
  },
  {
    name: "asset budget audit",
    match:
      /^(tools\/budget_audit\.mjs|assets\/asset_budgets\.json|assets\/registry\.json)$|^assets\/models\//,
    tests: ["scripts/budget-audit.test.mjs"],
  },
  {
    name: "palette",
    match:
      /^(src\/core\/palette\.gd|tools\/blender\/common\.py|tools\/blender\/park\/props\/kit\.py|tools\/palette_gd\.py|tools\/icons\/)/,
    tests: ["scripts/palette-gd.test.mjs", "tests/palette-kit.test.js"],
  },
];

export function nodeTestsForPaths(paths, rules = NODE_PATH_RULES) {
  return [
    ...new Set(
      rules
        .filter((rule) => paths.some((file) => rule.match.test(file)))
        .flatMap((rule) => rule.tests),
    ),
  ].sort();
}

export const SHARD_RULES = [
  {
    name: "movement, boss, posture or damage",
    match: /^src\/(movement|boss)\/|posture|damage/,
    tests: ["tests/posture_bands_reactor_test.gd", "tests/alpha_posture_bands_*"],
  },
];
const TEXT_EXTENSIONS = new Set([".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".gdshader"]);

export function normalizeTestPattern(pattern) {
  return String(pattern)
    .replace(/^res:\/\//, "")
    .replace(/^sketches\/core-loop\//, "")
    .replace(/^tests\//, "")
    .replace(/\.gd$/, "");
}

export function resolveNamedTests(allTests, patterns) {
  const normalized = patterns.map(normalizeTestPattern);
  return allTests
    .filter((rel) => {
      const name = path.posix.basename(rel, ".gd");
      return normalized.some((glob) => matchesGlob(glob, name));
    })
    .sort();
}

export function unmatchedTestPatterns(allTests, patterns) {
  return patterns.filter((pattern) => resolveNamedTests(allTests, [pattern]).length === 0);
}

const VALUE_FLAGS = new Set(["--base", "--budget", "--receipt", "--width", "--pre"]);

export function parseArgs(argv) {
  const options = {
    base: "origin/main",
    budgetS: 900,
    dryRun: false,
    receipt: "fast",
    width: null,
    baseCheck: true,
    batch: true,
    shuffle: false,
    seed: null,
    ciGodotOnly: false,
    shard: null,
    pre: [],
    tests: [],
  };
  let explicitBaseCheck = null;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--base" && argv[i + 1] && !argv[i + 1].startsWith("-")) options.base = argv[++i];
    else if (arg === "--budget" && argv[i + 1]) options.budgetS = Number(argv[++i]);
    else if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--receipt" && argv[i + 1] && !argv[i + 1].startsWith("-"))
      options.receipt = argv[++i];
    else if (arg === "--width" && argv[i + 1]) options.width = Number(argv[++i]);
    else if (arg === "--base-check") explicitBaseCheck = true;
    else if (arg === "--no-base-check") explicitBaseCheck = false;
    else if (arg === "--no-batch") options.batch = false;
    else if (arg === "--shuffle") options.shuffle = true;
    else if (arg === "--ci-godot-only") options.ciGodotOnly = true;
    else if (arg === "--shard") {
      if (i + 1 >= argv.length) throw new Error("--shard requires INDEX/TOTAL");
      const raw = argv[++i];
      if (!/^\d+\/\d+$/.test(raw)) {
        throw new Error(`--shard must be INDEX/TOTAL (for example 1/2); got "${raw}"`);
      }
      const [index, total] = raw.split("/").map(Number);
      if (
        !Number.isSafeInteger(index) ||
        !Number.isSafeInteger(total) ||
        index < 1 ||
        total < 1 ||
        index > total
      ) {
        throw new Error(`--shard ${raw} out of range`);
      }
      options.shard = { index, total };
    } else if (arg === "--test") {
      if (i + 1 >= argv.length || !argv[i + 1] || argv[i + 1].startsWith("-")) {
        throw new Error("--test requires a test name or glob");
      }
      options.tests.push(argv[++i]);
    } else if (arg === "--seed") {
      if (i + 1 >= argv.length) throw new Error("--seed requires a value");
      const raw = argv[++i];
      if (raw.trim() === "" || !Number.isFinite(Number(raw))) {
        throw new Error(`--seed must be a finite number; got "${raw}"`);
      }
      options.seed = Math.trunc(Number(raw)) >>> 0;
    } else if (arg === "--pre" && argv[i + 1]) options.pre.push(argv[++i].replace(/^#/, ""));
    else if (VALUE_FLAGS.has(arg)) throw new Error(`${arg} requires a value`);
    else {
      throw new Error(
        `unknown argument "${arg}"; pass each flag and each value as its own argument, ` +
          "one --test <name> per test",
      );
    }
  }
  options.baseCheck = explicitBaseCheck ?? options.tests.length === 0;
  if (!Number.isFinite(options.budgetS) || options.budgetS <= 0)
    throw new Error("--budget needs seconds above zero");
  if (options.width !== null && (!Number.isSafeInteger(options.width) || options.width < 1))
    throw new Error("--width must be a positive integer");
  if (options.pre.some((pr) => !/^\d+$/.test(pr))) throw new Error("--pre takes PR numbers");
  return options;
}

export function classify(paths) {
  const out = { godot: [], node: [], docs: [], other: [] };
  const prefix = SKETCH + "/";
  for (const file of paths) {
    if (file.startsWith(prefix)) out.godot.push(file.slice(prefix.length).replace(/\.uid$/, ""));
    else if (/\.(mjs|js)$/.test(file) && /^(scripts|tests|tools|server)\//.test(file))
      out.node.push(file);
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
    else if (TEXT_EXTENSIONS.has(path.extname(entry.name)))
      out.push(path.relative(base, full).split(path.sep).join("/"));
  }
  return out;
}

export function buildIndex(sketchDir) {
  const files = new Map();
  for (const rel of walk(sketchDir, sketchDir, []))
    files.set(rel, readFileSync(path.join(sketchDir, rel), "utf8"));
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
  const patterns = globs.map(globToRegExp);
  return index.tests.filter((test) => patterns.some((pattern) => pattern.test(test)));
}

export function selectTests(index, changed, { hub = HUB_TESTS } = {}) {
  const picked = new Map();
  const hubs = [];
  const unmapped = [];
  const shards = new Map();
  const add = (test, tier, why) => {
    const prior = picked.get(test);
    if (!prior || prior.tier > tier) picked.set(test, { tier, why });
  };
  if (changed.length > 0)
    for (const test of expand(index, ALWAYS)) add(test, 0, "always (content pins)");
  for (const rel of changed) {
    for (const rule of PATH_RULES)
      if (rule.match.test(rel))
        for (const test of expand(index, rule.tests)) add(test, 0, `${rule.name}: ${rel}`);
    for (const rule of SHARD_RULES)
      if (rule.match.test(rel))
        for (const test of expand(index, rule.tests))
          if (!shards.has(test)) shards.set(test, `${rule.name}: ${rel}`);
    if (isTopLevelTest(rel)) {
      if (index.files.has(rel)) add(rel, 0, "changed");
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
    if (
      reached === 0 &&
      stemTests(index, rel).length === 0 &&
      !PATH_RULES.some((rule) => rule.match.test(rel))
    )
      unmapped.push(rel);
  }
  for (const test of shards.keys()) picked.delete(test);
  return { picked, hubs, unmapped, shards };
}

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

export function plan({
  picked,
  timings,
  budgetMs,
  width,
  solo = () => false,
  bots: knownBots = () => false,
  allowBots = false,
}) {
  const bots = (test) =>
    !allowBots &&
    (knownBots(test) ||
      (timings[test] === undefined && UNKNOWN_BOT_NAME.test(path.posix.basename(test))));
  const rows = [...picked].map(([test, row]) => ({ test, ...row, ms: estimate(timings, test) }));
  const botRows = rows.filter((row) => bots(row.test));
  const runnable = rows
    .filter((row) => !bots(row.test))
    .sort((a, b) => a.tier - b.tier || a.ms - b.ms || a.test.localeCompare(b.test));
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
  const parallelOrder = (a, b) =>
    a.tier === 0 && b.tier !== 0
      ? -1
      : b.tier === 0 && a.tier !== 0
        ? 1
        : b.ms - a.ms || a.test.localeCompare(b.test);
  const soloOrder = (a, b) =>
    a.tier === 0 && b.tier !== 0
      ? -1
      : b.tier === 0 && a.tier !== 0
        ? 1
        : a.ms - b.ms || a.test.localeCompare(b.test);
  return {
    parallel: kept.filter((row) => !solo(row.test)).sort(parallelOrder),
    solo: kept.filter((row) => solo(row.test)).sort(soloOrder),
    deferred,
    bots: botRows.map((row) => row.test).sort(),
    estimateMs: Math.round(spent),
  };
}

function sliceShardRows(rows, index, total) {
  if (total === 1) return [...rows];
  const packed = packDurationShards(
    rows.map((row) => ({ name: row.test, ms: row.ms })),
    total,
  );
  const keep = new Set(packed[index - 1].tests);
  return rows.filter((row) => keep.has(row.test));
}

export function shardLanePlan(lanePlan, shard, width = 1) {
  if (!shard) return lanePlan;
  const { index, total } = shard;
  if (
    !Number.isInteger(total) ||
    total < 1 ||
    !Number.isInteger(index) ||
    index < 1 ||
    index > total
  ) {
    throw new Error(`--shard ${index}/${total} out of range`);
  }
  const parallel = sliceShardRows(lanePlan.parallel, index, total);
  const solo = sliceShardRows(lanePlan.solo, index, total);
  const parallelMs = parallel.reduce((sum, row) => sum + row.ms, 0);
  const soloMs = solo.reduce((sum, row) => sum + row.ms, 0);
  return {
    ...lanePlan,
    parallel,
    solo,
    estimateMs: Math.round(parallelMs / Math.max(1, width) + soloMs),
  };
}

export function shouldRunBoot(options) {
  if (options.tests.length > 0) return false;
  if (options.shard && options.shard.index !== 1) return false;
  return true;
}

export function classifyFailure({
  rerunOk,
  baseOk,
  headChecks = [],
  baseChecks = [],
  baseCached = false,
}) {
  if (rerunOk) return { kind: "flaky", newChecks: [] };
  if (baseOk === false) {
    if (baseCached && headChecks.length === 0) return { kind: "pr-red", newChecks: [] };
    const base = new Set(baseChecks);
    const newChecks = headChecks.filter((check) => !base.has(check));
    return newChecks.length > 0
      ? { kind: "pr-red", newChecks }
      : { kind: "base-red", newChecks: [] };
  }
  return { kind: "pr-red", newChecks: [] };
}

export const LEDGER_FLAKE_RUNS = 3;

export function ledgerFlakes(rows) {
  return new Set(rows.filter((row) => row.kind === "flake").map((row) => row.test));
}

export function settleLedgerFlake(verdict, runs) {
  if (runs.some((run) => run.killed)) return { kind: "stopped", newChecks: [] };
  if (runs.some((run) => run.ok)) return { kind: "flaky", newChecks: [], ledger: true };
  return { ...verdict, ledgerRuns: runs.length };
}

export function failingChecks(output) {
  return [
    ...new Set(
      output
        .replace(/\r/g, "")
        .split("\n")
        .filter((line) => line.includes("-> FAIL"))
        .map((line) => {
          const label = /^\s*\[([^\]]+)\]/.exec(line);
          return label ? label[1] : line.replace(/->\s*FAIL.*$/, "").trim();
        }),
    ),
  ].sort();
}

export function nodeTestsFor(changedNode, allNodeTests, readText) {
  const picked = new Set();
  for (const file of changedNode) if (/\.test\.(mjs|js)$/.test(file)) picked.add(file);
  const modules = changedNode
    .filter((file) => !/\.test\.(mjs|js)$/.test(file))
    .map((file) => path.posix.basename(file));
  if (modules.length === 0) return [...picked].sort();
  for (const test of allNodeTests) {
    const text = readText(test);
    if (modules.some((name) => text.includes("/" + name + '"') || text.includes("/" + name + "'")))
      picked.add(test);
  }
  return [...picked].sort();
}

export function selectStage1NodeTests({
  changedNode,
  changedGodot,
  allNodeTests,
  readText,
  ciGodotOnly = false,
  coveredByCi = [],
  isPrimaryShard = true,
}) {
  if (ciGodotOnly && !isPrimaryShard) return [];
  const pathNodeTests = nodeTestsForPaths(changedGodot);
  if (changedNode.length === 0 && pathNodeTests.length === 0) return [];
  const combined = [
    ...new Set([...nodeTestsFor(changedNode, allNodeTests, readText), ...pathNodeTests]),
  ].sort();
  if (!ciGodotOnly) return combined;
  const covered = new Set(coveredByCi);
  return combined.filter((file) => !covered.has(file));
}

function git(args, cwd = root) {
  const result = spawnSync("git", ["-C", cwd, ...args], { encoding: "utf8" });
  if (result.status !== 0 || result.error)
    throw new Error(`git ${args.join(" ")}: ${(result.stderr || "").trim()}`);
  return result.stdout.trim();
}

function readTimings() {
  try {
    return JSON.parse(readFileSync(TIMINGS_FILE, "utf8")).tests ?? {};
  } catch {
    return {};
  }
}

export function timingsFromReceipt(receipt) {
  const tests = {};
  for (const row of receipt.results ?? []) {
    if (!row.ok) continue;
    const text = String(row.test ?? row.label ?? "");
    const match = /(?:^|res:\/\/)(tests\/[^ ]+\.gd)$/.exec(text);
    const name = match ? match[1] : /^[a-z0-9_]+$/.test(text) ? `tests/${text}.gd` : null;
    const ms = Number.isFinite(row.ms)
      ? row.ms
      : Number.isFinite(row.seconds)
        ? row.seconds * 1000
        : 0;
    if (name && ms > 0) tests[name] = Math.round(ms);
  }
  return tests;
}

async function spawnText(command, args, { cwd = root, timeoutMs = 120_000 } = {}) {
  const res = await runProcess(command, args, { cwd, timeoutMs, killGraceMs: 5_000 });
  return {
    status: res.exit,
    stdout: res.stdout,
    stderr: res.error ? res.stderr + String(res.error.message ?? res.error) : res.stderr,
  };
}

async function placeholderRowsAsync(sketchDir) {
  const result = await spawnText(
    process.execPath,
    [path.join(root, "scripts", "placeholder-gate.mjs"), "--project", sketchDir, "--json"],
    { timeoutMs: 120_000 },
  );
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(
      `placeholder-gate gave no JSON for ${sketchDir}: ${(result.stderr || "").slice(0, 400)}`,
    );
  }
}

export function seedBaseGodot(headSketchDir, baseSketchDir, platform = process.platform) {
  const src = path.join(headSketchDir, ".godot");
  const dst = path.join(baseSketchDir, ".godot");
  if (!existsSync(src) || existsSync(dst)) return false;
  try {
    let copied = false;
    if (platform === "linux") {
      copied =
        spawnSync("cp", ["-a", "--reflink=auto", src, dst], { stdio: "ignore" }).status === 0;
    } else if (platform === "darwin") {
      copied = spawnSync("cp", ["-Rc", src, dst], { stdio: "ignore" }).status === 0;
    }
    if (!copied) cpSync(src, dst, { recursive: true });
    rmSync(path.join(dst, "scrapkeep-import.json"), { force: true });
    return true;
  } catch {
    rmSync(dst, { recursive: true, force: true });
    return false;
  }
}

export const LOG_HEAD_LINES = 200;
export const LOG_TAIL_LINES = 2000;

export function cappedLog(output, head = LOG_HEAD_LINES, tail = LOG_TAIL_LINES) {
  const lines = String(output ?? "").split("\n");
  if (lines.at(-1) === "") lines.pop();
  if (lines.length <= head + tail) return lines.join("\n");
  return [
    ...lines.slice(0, head),
    `[sketch:fast cut ${lines.length - head - tail} lines here; ${lines.length} lines printed]`,
    ...lines.slice(lines.length - tail),
  ].join("\n");
}

export function failedRunLog({
  test,
  where,
  attempt,
  head,
  exit,
  signal,
  timedOut,
  ms,
  reason,
  output,
}) {
  const facts = [
    `test: ${test}`,
    `ran on: ${where === "base" ? "the merge base" : "the head"} (${head}), run ${attempt} there`,
    `exit: ${exit ?? "none"}${signal ? `, signal ${signal}` : ""}${timedOut ? ", stopped at its time limit" : ""}`,
    `seconds: ${(ms / 1000).toFixed(1)}`,
    `reason: ${reason}`,
  ];
  return `${facts.join("\n")}\n--- stdout and stderr ---\n${cappedLog(output)}\n`;
}

export function failedRunLogName(test, where, attempt) {
  return `${test
    .replace(/^tests\//, "")
    .replace(/\.gd$/, "")
    .replaceAll("/", "__")}.${where}-${attempt}.log`;
}

export function receiptBaseName(label, head, startedAt) {
  return runnerReceiptBaseName(label, head, startedAt);
}

export function signalReason(signal) {
  if (!signal || signal === "SIGKILL")
    return "killed by a signal before its time limit (often the container's memory limit; see dmesg)";
  return `ended on ${signal} before its time limit (a crash in the engine or the test; the kept log has the backtrace)`;
}

const running = new Set();

function fixedFpsFor(sketchDir, test) {
  try {
    return testFixedFps(sourceOf(sketchDir, test));
  } catch {
    return null;
  }
}

async function runGodot(sketchDir, test, timeoutMs, onChild = () => {}, fixedFps = null) {
  const started = Date.now();
  const fps = fixedFps ?? fixedFpsFor(sketchDir, test);
  const fpsArgs = fps ? ["--fixed-fps", String(fps)] : [];
  let spawned = null;
  let res;
  try {
    res = await withScratchGodotEnv(
      (env) =>
        runProcess(
          binary,
          ["--headless", ...fpsArgs, "--path", sketchDir, "--script", "res://" + test],
          {
            env,
            timeoutMs,
            onChild: (child) => {
              spawned = child;
              running.add(child);
              onChild(child);
            },
          },
        ),
      { prefix: "sketch-fast-", dirs: null },
    );
  } finally {
    if (spawned) running.delete(spawned);
  }
  const killed = spawned?.killedByLane === true;
  const verdict = judge({ test: "res://" + test, status: res.exit, output: res.output });
  const reason =
    res.exit === null && !res.timedOut && !killed ? signalReason(res.signal) : verdict.reason;
  return {
    test,
    ok: verdict.ok,
    exit: res.exit,
    signal: res.signal ?? null,
    ms: Date.now() - started,
    reason,
    checks: failingChecks(res.output),
    passes: countChecks(res.output).passes,
    tail: res.output.split("\n").slice(-30).join("\n"),
    killed,
    timedOut: res.timedOut,
    output: res.output,
  };
}

export function interpretBatchOutput(
  output,
  tests,
  { code = 0, signal = null, killed = false, platform = process.platform } = {},
) {
  const parsed = evaluateBatchOutput(output, tests, { code, signal, platform });
  if (parsed.tainted) {
    return {
      runs: [],
      unfinished: [...tests],
      killed,
      outsideError: parsed.outsideError,
      unexpectedExit: parsed.unexpectedExit,
    };
  }
  const runs = parsed.done.map((row) => {
    const verdict = judge({
      test: "res://" + row.test,
      status: row.exit,
      output: row.output,
      platform,
    });
    return {
      test: row.test,
      ok: verdict.ok,
      exit: row.exit,
      signal: null,
      ms: row.ms,
      reason: verdict.reason,
      checks: failingChecks(row.output),
      passes: countChecks(row.output).passes,
      tail: row.output.split("\n").slice(-30).join("\n"),
      killed: false,
      timedOut: false,
      output: row.output,
      batched: true,
    };
  });
  return {
    runs,
    unfinished: parsed.cut ? [parsed.cut, ...parsed.rest] : parsed.rest,
    killed,
    outsideError: false,
    unexpectedExit: false,
  };
}

async function runBatch(sketchDir, tests, timeoutMs, onChild = () => {}, fixedFps = null) {
  let spawned = null;
  let batch;
  try {
    batch = await runGodotBatch({
      binary,
      sketchDir,
      tests,
      timeoutMs,
      fixedFps,
      prefix: "sketch-fast-",
      onChild: (child) => {
        spawned = child;
        running.add(child);
        onChild(child);
      },
    });
  } finally {
    if (spawned) running.delete(spawned);
  }
  return interpretBatchOutput(batch.output, tests, {
    code: batch.code,
    signal: batch.signal,
    killed: spawned?.killedByLane === true,
  });
}

async function runBoot(sketchDir, timeoutMs = 180_000) {
  const started = Date.now();
  let spawned = null;
  let res;
  try {
    res = await withScratchGodotEnv(
      (env) =>
        runProcess(binary, ["--headless", "--path", sketchDir, "--quit-after", "300"], {
          env,
          timeoutMs,
          onChild: (child) => {
            spawned = child;
            running.add(child);
          },
        }),
      { prefix: "sketch-fast-", dirs: null },
    );
  } finally {
    if (spawned) running.delete(spawned);
  }
  const verdict = judge({ status: res.exit, output: res.output });
  return {
    ok: verdict.ok,
    status: res.exit,
    signal: res.signal ?? null,
    ms: Date.now() - started,
    reason: verdict.reason,
    output: res.output,
    killed: spawned?.killedByLane === true,
    timedOut: res.timedOut,
  };
}

export async function runBootTask({ inLane, shouldStop, run, onStop, stage }) {
  return inLane(async () => {
    if (shouldStop()) return { ok: true, killed: true };
    const boot = await run();
    if (boot.killed) return { ok: true, killed: true };
    const ok = stage("boot", boot.ok, { note: boot.reason ?? "300 frames" });
    if (!ok) onStop();
    return { ok, killed: false };
  });
}

function stopChild(child) {
  child.killedByLane = true;
  killGroup(child, "SIGKILL");
}

function stopRunning() {
  for (const child of running) stopChild(child);
}

export function defaultWidth(cpus = os.cpus().length, load = os.loadavg()[0], env = process.env) {
  if (env?.CI === "true" || env?.GITHUB_ACTIONS === "true") {
    return Math.min(16, Math.max(2, cpus));
  }
  return Math.min(16, Math.max(2, Math.round(cpus - load)));
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

export function cacheableBaseRun(run) {
  return run.exit !== null && !run.killed && !run.timedOut;
}

export function settleBaseEntry(prior, run) {
  if (run.ok) return { ok: true, checks: [] };
  const same =
    prior &&
    prior.ok === false &&
    prior.checks.length > 0 &&
    prior.checks.length === run.checks.length &&
    prior.checks.every((check, i) => check === run.checks[i]);
  return { ok: false, checks: run.checks, confirmed: Boolean(same) };
}

export function trustedBaseEntry(entry) {
  return Boolean(entry) && (entry.ok === true || entry.confirmed === true);
}

export function usableBaseRun(rerun, baseRun) {
  if (!baseRun || baseRun.killed) return null;
  if ((baseRun.timedOut || baseRun.exit === null) && !rerun.timedOut) {
    const signal = baseRun.signal;
    const sameSignal =
      Boolean(signal) &&
      signal !== "SIGKILL" &&
      rerun.signal === signal &&
      !baseRun.timedOut &&
      !rerun.killed;
    const head = [...(rerun.checks ?? [])].sort();
    const base = [...(baseRun.checks ?? [])].sort();
    const sameChecks = head.length === base.length && head.every((check, i) => check === base[i]);
    const samePasses = rerun.passes === baseRun.passes;
    return sameSignal && sameChecks && samePasses ? baseRun : null;
  }
  return baseRun;
}

async function importAsync(args) {
  const res = await withScratchGodotEnv(
    (env) =>
      runProcess(binary, [...args, "--import"], { env, stdio: "ignore", timeoutMs: 180_000 }),
    { prefix: "sketch-fast-", homeOnly: true },
  );
  return res.exit;
}

function sourceOf(sketchDir, test) {
  return readFileSync(path.join(sketchDir, test), "utf8");
}

async function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(`sketch:fast: ${error.message}`);
    process.exit(2);
  }
  const startedAt = new Date().toISOString();
  const started = Date.now();
  const sketchDir = path.join(root, SKETCH);
  const namedMode = options.tests.length > 0;
  const headSha = git(["rev-parse", "HEAD"]);
  const mergeBase =
    namedMode && !options.baseCheck ? headSha : git(["merge-base", options.base, "HEAD"]);
  for (const pr of options.pre) {
    git(["fetch", "-q", "origin", `+refs/pull/${pr}/head:refs/remotes/pr/${pr}`]);
    if (
      spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", `refs/remotes/pr/${pr}`, "HEAD"])
        .status !== 0
    ) {
      console.error(
        `--pre ${pr}: the head does not contain PR #${pr} at its current head. Merge it first: git merge --no-edit refs/remotes/pr/${pr}`,
      );
      process.exit(2);
    }
  }
  const receipt = {
    schema: RECEIPT_SCHEMA,
    label: options.receipt,
    head: headSha,
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
    for (const pr of options.pre)
      git(
        [
          "-c",
          "user.name=sketch-fast",
          "-c",
          "user.email=sketch-fast@localhost",
          "merge",
          "-q",
          "--no-edit",
          `refs/remotes/pr/${pr}`,
        ],
        baseTree,
      );
    return baseTree;
  };
  const diffBase = options.pre.length > 0 ? git(["rev-parse", "HEAD"], baseDir()) : mergeBase;
  const changedPaths = namedMode
    ? []
    : git(["diff", "--name-only", diffBase, "HEAD"]).split("\n").filter(Boolean);
  const changed = classify(changedPaths);
  receipt.diff_base = diffBase;
  receipt.pre = options.pre;
  receipt.changed = changedPaths.length;
  if (options.ciGodotOnly) receipt.ci_godot_only = true;
  if (options.shard) receipt.shard = options.shard;
  if (namedMode) receipt.named_tests = options.tests;
  const finish = (code) => {
    receipt.wall_ms = Date.now() - started;
    if (baseTree) spawnSync("git", ["-C", root, "worktree", "remove", "--force", baseTree]);
    const file = writeJsonReceipt(
      runnerReceiptPath(root, options.receipt, receipt.head, startedAt),
      receipt,
    );
    log(`receipt ${file}`);
    log(
      `sketch:fast ${receipt.ok ? "pass" : "fail"} in ${Math.round(receipt.wall_ms / 1000)}s on ${receipt.head.slice(0, 8)} (merge base ${mergeBase.slice(0, 8)}). Fast lane only: the staging full gate and red team still judge the wave.`,
    );
    process.exit(code ?? (receipt.ok ? 0 : 1));
  };

  if (namedMode) {
    log(`sketch:fast: --test filter (${options.tests.join(", ")})`);
  } else {
    log(
      `sketch:fast: ${changedPaths.length} changed paths (${changed.godot.length} sketch, ${changed.node.length} node, ${changed.docs.length} docs) since ${diffBase.slice(0, 8)}${options.pre.length ? ` (merge base plus ${options.pre.map((pr) => "#" + pr).join(", ")})` : ""}`,
    );

    const baseTop = new Set(git(["ls-tree", "--name-only", diffBase]).split("\n").filter(Boolean));
    const hygiene = [
      ...hygieneFindings(
        git(["diff", "--raw", "--no-abbrev", "--diff-filter=A", diffBase, "HEAD"]).split("\n"),
        baseTop,
      ),
      ...bridgeFindings(
        spawnSync("git", ["-C", root, "show", "HEAD:sketches/core-loop/project.godot"], {
          encoding: "utf8",
        }).stdout ?? "",
      ),
    ];
    if (
      !stage("tree hygiene", hygiene.length === 0, {
        note: hygiene.length
          ? hygiene.slice(0, 5).join("; ")
          : "no symlink, root file or new top-level folder",
        findings: hygiene,
      }) &&
      !options.dryRun
    )
      finish();
    const show = (ref, file) => {
      const r = spawnSync("git", ["-C", root, "show", `${ref}:${file}`], {
        encoding: "utf8",
        maxBuffer: 64 * 1024 * 1024,
      });
      return r.status === 0 ? r.stdout : null;
    };
    receipt.checks_removed = checksRemoved(
      git(["diff", "--name-status", "-M", diffBase, "HEAD"]).split("\n"),
      show,
      diffBase,
      "HEAD",
    );
    for (const row of receipt.checks_removed)
      log(
        `  checks removed from ${row.test}: ${row.labels.map((label) => `"${label}"`).join(", ")}`,
      );
    if (receipt.checks_removed.length > 0)
      log("  name each removed check in the pull request and say what now covers it");
    const deepSweepPromise = options.ciGodotOnly
      ? null
      : spawnText(
          process.execPath,
          [path.join(root, "scripts", "deep-sweep.mjs"), "--base", mergeBase, "--head", "HEAD"],
          { timeoutMs: 60_000 },
        );
    const merges = git([
      "rev-list",
      "--first-parent",
      "--merges",
      "--parents",
      `${mergeBase}..HEAD`,
    ])
      .split("\n")
      .filter(Boolean)
      .map((line) => line.split(" "))
      .filter(
        ([, , second]) =>
          second &&
          spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", second, mergeBase])
            .status !== 0,
      )
      .map(([merge, , carried]) => ({
        merge,
        carried,
        subject: git(["log", "-1", "--format=%s", merge]),
      }));
    const recordDeepSweep = async () => {
      if (!deepSweepPromise) return;
      const swept = await deepSweepPromise;
      receipt.deep_sweep =
        swept.status === 0
          ? Object.fromEntries(
              [...swept.stdout.matchAll(/^## (D\d) .*\((\d+)\)$/gm)].map((m) => [
                m[1],
                Number(m[2]),
              ]),
            )
          : null;
      if (receipt.deep_sweep === null) log("  deep sweep did not run");
      else if (Object.values(receipt.deep_sweep).some((n) => n > 0))
        log(
          `  deep sweep leads on this branch: ${Object.entries(receipt.deep_sweep)
            .filter(([, n]) => n > 0)
            .map(([rule, n]) => `${rule} ${n}`)
            .join(", ")} (node scripts/deep-sweep.mjs --base ${mergeBase.slice(0, 10)} lists them)`,
        );
    };
    if (merges.length > 0) {
      const heads = { prHeads: new Map(), branchHeads: new Map() };
      const remote = spawnSync(
        "git",
        ["-C", root, "ls-remote", "origin", "refs/pull/*/head", "refs/heads/*"],
        { encoding: "utf8", timeout: 60_000 },
      );
      for (const line of (remote.stdout || "").split("\n")) {
        const pull = /^([0-9a-f]{40})\trefs\/pull\/(\d+)\/head$/.exec(line);
        if (pull) heads.prHeads.set(pull[2], pull[1]);
        const branch = /^([0-9a-f]{40})\trefs\/heads\/(.+)$/.exec(line);
        if (branch) heads.branchHeads.set(branch[2], branch[1]);
      }
      const isAncestor = (sha) => {
        spawnSync("git", ["-C", root, "fetch", "-q", "origin", sha]);
        return (
          spawnSync("git", ["-C", root, "merge-base", "--is-ancestor", sha, "HEAD"]).status === 0
        );
      };
      const carried = carriedPrs(merges, heads, isAncestor);
      receipt.carried = carried;
      const label = (row) =>
        row.prs.length
          ? row.prs.map((pr) => "#" + pr).join(", ")
          : (row.branch ?? "an unnamed branch");
      for (const row of carried)
        log(
          `  carries ${label(row)} at ${row.carried.slice(0, 8)}${row.stale ? ` (stale: its head is now ${row.head.slice(0, 8)})` : ""}${row.subject && !row.branch ? ` (${row.subject})` : ""}`,
        );
      const stale = carried.filter((row) => row.stale);
      if (
        !stage("carried branches current", stale.length === 0, {
          note: stale.length
            ? stale
                .map(
                  (row) =>
                    `${label(row)} carried at ${row.carried.slice(0, 8)}, now ${row.head.slice(0, 8)}`,
                )
                .join("; ")
            : `${carried.length} merges, none stale`,
        }) &&
        !options.dryRun
      ) {
        await recordDeepSweep();
        log("  merge each stale branch's current head into the PR (or drop the carry), then rerun");
        finish();
      }
    }
    await recordDeepSweep();
  }

  const index = buildIndex(sketchDir);
  const timings = readTimings();
  const width = options.width ?? defaultWidth();
  let selection;
  let lanePlan;
  if (namedMode) {
    const unmatched = unmatchedTestPatterns(index.tests, options.tests);
    if (unmatched.length > 0) {
      console.error(`sketch:fast: no tests/*.gd matched ${unmatched.join(", ")}`);
      process.exit(2);
    }
    const matched = resolveNamedTests(index.tests, options.tests);
    const picked = new Map(matched.map((test) => [test, { tier: 0, why: "named (--test)" }]));
    selection = { picked, hubs: [], unmapped: [], shards: new Map() };
    lanePlan = plan({
      picked: selection.picked,
      timings,
      budgetMs: Infinity,
      width,
      solo: (test) => isSolo(sourceOf(sketchDir, test)),
      bots: () => false,
      allowBots: true,
    });
  } else {
    selection = selectTests(index, changed.godot);
    if (changed.godot.length > 0)
      for (const test of canaries(index, timings))
        if (!selection.picked.has(test)) selection.picked.set(test, { tier: 3, why: "canary" });
    lanePlan = plan({
      picked: selection.picked,
      timings,
      budgetMs: options.budgetS * 1000,
      width,
      solo: (test) => isSolo(sourceOf(sketchDir, test)),
      bots: (test) => isBot(sourceOf(sketchDir, test)),
    });
  }
  if (options.shard) {
    lanePlan = shardLanePlan(lanePlan, options.shard, width);
    receipt.shard = {
      ...options.shard,
      parallel: lanePlan.parallel.length,
      solo: lanePlan.solo.length,
    };
  }
  receipt.selection = {
    hubs: selection.hubs,
    unmapped: selection.unmapped,
    tests: Object.fromEntries([...selection.picked].map(([test, row]) => [test, row])),
    deferred_to_full_gate: lanePlan.deferred.map((row) => row.test),
    bot_shards: [...new Set([...lanePlan.bots, ...selection.shards.keys()])].sort(),
    shard_reasons: Object.fromEntries(selection.shards),
    estimate_ms: lanePlan.estimateMs,
  };
  log(
    `selected ${lanePlan.parallel.length + lanePlan.solo.length} tests (${lanePlan.solo.length} solo)${options.shard ? ` [shard ${options.shard.index}/${options.shard.total}]` : ""}, about ${Math.round(lanePlan.estimateMs / 1000)}s at width ${width}; ${lanePlan.deferred.length} past the budget go to the staging full gate; ${receipt.selection.bot_shards.length} for the bot shards`,
  );
  if (selection.hubs.length > 0)
    log(
      `hub files changed (each named by more than ${HUB_TESTS} tests): ${selection.hubs.join(", ")}`,
    );
  if (selection.unmapped.length > 0)
    log(
      `no test names: ${selection.unmapped.slice(0, 8).join(", ")}${selection.unmapped.length > 8 ? ", ..." : ""}`,
    );
  if (options.dryRun) {
    for (const row of [...lanePlan.parallel, ...lanePlan.solo])
      log(`  ${(row.ms / 1000).toFixed(1)}s t${row.tier} ${row.test} (${row.why})`);
    for (const row of lanePlan.deferred) log(`  deferred t${row.tier} ${row.test}`);
    for (const test of receipt.selection.bot_shards)
      log(
        `  bot shard ${test}${selection.shards.has(test) ? ` (${selection.shards.get(test)})` : ""}`,
      );
    process.exit(0);
  }

  let lint = null;
  let placeholderPair = null;
  let docs = null;
  let node = null;
  let nodeTests = [];
  if (!namedMode) {
    const isPrimaryShard = !options.shard || options.shard.index === 1;
    const pathNodeTests = nodeTestsForPaths(changed.godot);
    if (changed.node.length > 0 || pathNodeTests.length > 0) {
      const all = git(["ls-files", "*.test.mjs", "*.test.js"])
        .split("\n")
        .filter((file) => file && !file.startsWith(SKETCH) && !file.includes("node_modules"));
      let coveredByCi = [];
      if (options.ciGodotOnly) {
        try {
          coveredByCi = discoverTestFiles(root);
        } catch {
          coveredByCi = [];
        }
      }
      nodeTests = selectStage1NodeTests({
        changedNode: changed.node,
        changedGodot: changed.godot,
        allNodeTests: all,
        readText: (file) => readFileSync(path.join(root, file), "utf8"),
        ciGodotOnly: options.ciGodotOnly,
        coveredByCi,
        isPrimaryShard,
      });
    }
    const baseSketchForPlaceholders =
      changed.godot.length > 0 && (!options.ciGodotOnly || isPrimaryShard)
        ? path.join(baseDir(), SKETCH)
        : null;
    [lint, placeholderPair, docs, node] = await Promise.all([
      options.ciGodotOnly
        ? Promise.resolve(null)
        : spawnText(process.execPath, [
            path.join(root, "scripts", "sketch-lint.mjs"),
            "--sketch",
            "core-loop",
            "--base",
            mergeBase,
          ]),
      baseSketchForPlaceholders
        ? Promise.all([
            placeholderRowsAsync(baseSketchForPlaceholders),
            placeholderRowsAsync(sketchDir),
          ])
        : Promise.resolve(null),
      !options.ciGodotOnly && changed.docs.length > 0
        ? spawnText(process.execPath, [path.join(root, "scripts", "check-docs.mjs")])
        : Promise.resolve(null),
      nodeTests.length > 0
        ? spawnText(process.execPath, ["--test", ...nodeTests], { cwd: root, timeoutMs: 300_000 })
        : Promise.resolve(null),
    ]);
  }
  if (
    lint &&
    !stage("sketch-lint", lint.status === 0, { note: (lint.stdout || "").trim().split("\n").pop() })
  ) {
    log(lint.stdout + lint.stderr);
    finish();
  }
  if (placeholderPair) {
    const grew = placeholderIncrease(placeholderPair[0], placeholderPair[1]);
    if (
      !stage("placeholders no higher than base", grew.length === 0, {
        note: grew.length ? grew.slice(0, 5).join("; ") : "no group grew",
        grew,
      })
    )
      finish();
  }
  if (docs) {
    if (
      !stage("check:docs", docs.status === 0, { note: (docs.stdout || "").trim().split("\n")[0] })
    ) {
      log(docs.stdout + docs.stderr);
      finish();
    }
  }
  if (node) {
    if (!stage("node tests", node.status === 0, { note: nodeTests.join(" "), tests: nodeTests })) {
      log(
        (node.stdout || "")
          .split("\n")
          .filter((line) => /^not ok|error:|location:/.test(line.trim()))
          .slice(0, 40)
          .join("\n"),
      );
      finish();
    }
  }
  if (
    !namedMode &&
    lanePlan.parallel.length + lanePlan.solo.length === 0 &&
    changed.godot.length === 0
  ) {
    stage("godot", true, { note: "no sketch change" });
    finish();
  }

  const quarantineEntries = readQuarantineEntries(sketchDir);
  const quarantine = new Set(quarantineEntries.map((entry) => entry.test));
  const expired = expiredQuarantine(quarantineEntries);
  for (const entry of expired) log(expiredLine(entry));
  if (
    !stage("quarantine", expired.length === 0, {
      note: expired.length
        ? `${expired.length} expired: ${expired.map((entry) => entry.test).join(", ")}`
        : `${quarantineEntries.length} rows, none expired`,
    })
  )
    finish();
  const runBootHere = shouldRunBoot(options);
  if (!runBootHere && lanePlan.parallel.length + lanePlan.solo.length === 0) {
    stage("tests", true, {
      note: options.shard
        ? `0 run (shard ${options.shard.index}/${options.shard.total} empty)`
        : "0 run",
    });
    finish();
  }
  if (!binary || !existsSync(binary)) {
    console.error(`Godot binary not found${binary ? ` at ${binary}` : ""}; set GODOT_BIN`);
    stage("godot", false, { note: "no Godot binary, so no test ran" });
    finish(2);
  }
  await acquireMachine();
  const base = ["--headless", "--path", sketchDir];
  const stampOk =
    process.env.SMOKE_FORCE_IMPORT !== "1" &&
    checkImportStamp(root, SKETCH, { godot: godotIdentity(binary) }).ok;
  if (stampOk) {
    stage("import", true, { note: "cached (stamp matches HEAD)" });
  } else {
    const imported = await importWithRetry(
      SKETCH,
      base,
      async (job) => {
        const t = Date.now();
        const result = await withScratchGodotEnv(
          (env) => spawnCollect(binary, job.args, { timeoutMs: 180_000, env }),
          { prefix: "sketch-fast-", homeOnly: true },
        );
        return {
          label: job.label,
          exit: result.status,
          signal: result.signal ?? null,
          scriptErrors: scriptErrorCount(result.output),
          ok: result.status === 0,
          ms: Date.now() - t,
        };
      },
      log,
    );
    if (
      !stage("import", imported.ok, {
        note: imported.tries
          .map((row) => `${row.outcome} exit=${row.exit ?? row.signal}`)
          .join(", "),
      })
    )
      finish();
    writeImportStamp(root, SKETCH, { godot: godotIdentity(binary) });
  }
  const results = [];
  const flaky = [];
  const ledgerFlaky = [];
  const flakeRows = ledgerFlakes((await readLedger(root))?.rows ?? []);
  const baseRed = [];
  let prRed = null;
  let bootFailed = false;
  const shouldStop = () => Boolean(prRed || bootFailed);
  const inLane = lanePool(width);
  const stopped = (test) => ({
    test,
    ok: false,
    exit: null,
    ms: 0,
    reason: "lane stopped",
    checks: [],
    tail: "",
    killed: true,
    timedOut: false,
  });
  receipt.failed_runs = [];
  const redRuns = new Map();
  const keepRed =
    (where) =>
    ({ output, ...run }) => {
      if (run.ok || run.killed) return run;
      const key = `${run.test} ${where}`;
      const attempt = (redRuns.get(key) ?? 0) + 1;
      redRuns.set(key, attempt);
      const file = path.join(
        receiptDirectory,
        `${receiptName}-logs`,
        failedRunLogName(run.test, where, attempt),
      );
      const kept = {
        test: run.test,
        where,
        attempt,
        exit: run.exit,
        signal: run.signal,
        timed_out: run.timedOut,
        ms: run.ms,
        reason: run.reason,
        log: null,
      };
      try {
        mkdirSync(path.dirname(file), { recursive: true });
        writeFileSync(
          file,
          failedRunLog({
            ...run,
            where,
            attempt,
            head: where === "base" ? diffBase : receipt.head,
            output,
          }),
        );
        kept.log = path.relative(root, file);
        log(`  log of this red run of ${run.test}: ${kept.log}`);
      } catch (error) {
        log(
          `  log of this red run of ${run.test} not written (${error.message}); the verdict still stands`,
        );
      }
      receipt.failed_runs.push(kept);
      return run;
    };
  const godot = (dir, test, timeoutMs, onChild, skip = () => false) =>
    inLane(() =>
      shouldStop() || skip()
        ? stopped(test)
        : runGodot(dir, test, timeoutMs, onChild).then(
            keepRed(dir === sketchDir ? "head" : "base"),
          ),
    );

  const baseTreeId = git(["rev-parse", `${diffBase}^{tree}`]);
  const baseCacheFile = path.join(
    path.resolve(root, git(["rev-parse", "--git-common-dir"])),
    "sketch-fast",
    `base-runs-${baseTreeId.slice(0, 12)}.json`,
  );
  const binaryId = godotIdentity(binary) ?? "";
  const readBaseCache = () => {
    try {
      const stored = JSON.parse(readFileSync(baseCacheFile, "utf8"));
      return stored.binary === binaryId ? (stored.tests ?? {}) : {};
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
    if (cancel.cancelled || shouldStop()) return null;
    baseImport ??= inLane(async () => {
      if (shouldStop()) return false;
      seedBaseGodot(sketchDir, baseSketch);
      const args = ["--headless", "--path", baseSketch];
      for (let attempt = 1; attempt <= IMPORT_TRIES; attempt++) {
        if (shouldStop()) return false;
        if ((await importAsync(args)) === 0) return true;
        if (attempt < IMPORT_TRIES)
          log(`${SKETCH} (base) import try ${attempt} of ${IMPORT_TRIES} failed; trying again`);
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
      const disk = readBaseCache();
      baseCache[test] = settleBaseEntry(disk[test] ?? baseCache[test], run);
      const merged = { ...disk, ...baseCache };
      try {
        mkdirSync(path.dirname(baseCacheFile), { recursive: true });
        const temp = `${baseCacheFile}.${process.pid}.tmp`;
        writeFileSync(
          temp,
          JSON.stringify({ binary: binaryId, tree: baseTreeId, tests: merged }, null, 2) + "\n",
        );
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
      if (rerun.ok) {
        cancel.cancelled = true;
        if (cancel.child) stopChild(cancel.child);
      }
      baseRun = await basePending;
    }
    if (rerun.killed) return { kind: "stopped", newChecks: [], rerun };
    baseRun = usableBaseRun(rerun, baseRun);
    const baseOk = rerun.ok || !baseRun ? null : baseRun.ok;
    const baseChecks = rerun.ok || !baseRun ? [] : baseRun.checks;
    const verdict = classifyFailure({
      rerunOk: rerun.ok,
      baseOk,
      headChecks: rerun.checks,
      baseChecks,
      baseCached: Boolean(baseRun?.cached),
    });
    if (verdict.kind !== "pr-red" || !flakeRows.has(path.posix.basename(first.test, ".gd")))
      return { ...verdict, rerun };
    const more = [];
    while (more.length < LEDGER_FLAKE_RUNS && !more.some((run) => run.ok || run.killed)) {
      log(
        `  ${first.test} has a flake row in the known-failing ledger: head run ${more.length + 1} of up to ${LEDGER_FLAKE_RUNS} more`,
      );
      more.push(await godot(sketchDir, first.test, timeoutMs));
    }
    return { ...settleLedgerFlake(verdict, more), rerun };
  }

  async function handle(result) {
    const quarantined = quarantine.has(path.posix.basename(result.test, ".gd"));
    results.push({
      test: result.test,
      ok: result.ok,
      exit: result.exit,
      signal: result.signal ?? null,
      failing: (result.checks ?? []).length,
      ms: result.ms,
      reason: result.reason,
      quarantined,
    });
    log(
      `${result.ok ? "PASS" : "FAIL"} ${result.test} exit=${result.exit} ${(result.ms / 1000).toFixed(1)}s${quarantined ? " (quarantined)" : ""}`,
    );
    if (!result.ok && quarantined) {
      const entry = quarantineEntries.find(
        (row) => row.test === path.posix.basename(result.test, ".gd"),
      );
      log(`  ${quarantineNote(entry)}`);
    }
    if (result.ok || quarantined || result.killed) return;
    const { kind, newChecks, ledger, ledgerRuns } = await confirm(result);
    log(
      `  ${result.test}: ${kind}${ledger ? " (a known-failing ledger flake: green on a later head run)" : ""}${newChecks.length ? ` (new failing checks: ${newChecks.join("; ")})` : ""}`,
    );
    if (kind === "stopped") return;
    if (kind === "flaky") {
      flaky.push(result.test);
      if (ledger) ledgerFlaky.push(result.test);
    } else if (kind === "base-red") baseRed.push(result.test);
    else if (!prRed) {
      const reason = newChecks.length
        ? `fails checks the base passes: ${newChecks.join("; ")}`
        : result.reason;
      prRed = {
        test: result.test,
        reason: ledgerRuns
          ? `${reason}; listed as a flake in the known-failing ledger, but red on all ${ledgerRuns + 2} head runs`
          : reason,
        tail: result.tail,
      };
      stopRunning();
    }
  }

  const shuffleSeed = options.shuffle ? (options.seed ?? (Date.now() & 0xffffffff) >>> 0) : null;
  if (options.shuffle) {
    log(
      `sketch:fast shuffling ${lanePlan.parallel.length} parallel tests with seed=${shuffleSeed}`,
    );
  }
  const queue = options.shuffle
    ? shuffleFiles(lanePlan.parallel, shuffleSeed)
    : [...lanePlan.parallel];
  receipt.batch = { on: options.batch, batches: 0, tests: 0, reruns: [] };
  const canBatch = (row) =>
    options.batch &&
    !row.alone &&
    row.ms <= BATCH_TEST_MAX_MS &&
    batchable(sourceOf(sketchDir, row.test));
  async function runBatched(rows, fixedFps = null) {
    const tests = rows.map((row) => row.test);
    const timeoutMs = rows.reduce(
      (sum, row) => sum + testTimeoutMs(sourceOf(sketchDir, row.test)),
      0,
    );
    const batch = await inLane(() =>
      shouldStop()
        ? { runs: [], unfinished: [], killed: true }
        : runBatch(sketchDir, tests, timeoutMs, () => {}, fixedFps),
    );
    receipt.batch.batches++;
    receipt.batch.tests += batch.runs.length;
    if (!batch.killed && (batch.outsideError || batch.unexpectedExit)) {
      log(
        `  warm batch hit ${batch.outsideError ? "an outside-batch error" : "an unexpected exit"}; rerunning ${batch.unfinished.length} test(s) alone`,
      );
    }
    for (const run of batch.runs) {
      if (shouldStop()) return;
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
    if (!batch.killed && !shouldStop())
      for (const test of batch.unfinished.reverse())
        queue.unshift({ ...rows.find((row) => row.test === test), alone: true });
  }
  async function worker() {
    while (queue.length > 0 && !shouldStop()) {
      const firstFps = fixedFpsFor(sketchDir, queue[0].test);
      const rows = takeBatchPacked(
        queue,
        (row) => canBatch(row) && fixedFpsFor(sketchDir, row.test) === firstFps,
      );
      if (rows.length > 1) {
        await runBatched(rows, firstFps);
        continue;
      }
      const row = rows[0] ?? queue.shift();
      const result = await godot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test)));
      await handle(result);
    }
  }
  const bootPromise = runBootHere
    ? runBootTask({
        inLane,
        shouldStop,
        run: () => runBoot(sketchDir),
        onStop: () => {
          bootFailed = true;
          stopRunning();
        },
        stage,
      })
    : Promise.resolve({ ok: true, killed: false });
  await Promise.all([
    bootPromise,
    ...Array.from({ length: Math.min(width, queue.length) }, worker),
  ]);
  if (bootFailed) finish();
  for (const row of lanePlan.solo) {
    if (shouldStop()) break;
    await handle(
      await runGodot(sketchDir, row.test, testTimeoutMs(sourceOf(sketchDir, row.test))).then(
        keepRed("head"),
      ),
    );
  }
  receipt.results = results;
  receipt.quarantined = results
    .filter((row) => row.quarantined)
    .map((row) =>
      quarantineRecord(
        quarantineEntries.find((entry) => entry.test === path.posix.basename(row.test, ".gd")),
        { ok: row.ok, exit: row.exit, signal: row.signal, failing: row.failing },
      ),
    );
  receipt.flaky = flaky;
  receipt.ledger_flaky = ledgerFlaky;
  receipt.base_red = baseRed;
  if (prRed) {
    log(prRed.tail);
    stage("tests", false, {
      note: `${prRed.test} is the PR's red: ${prRed.reason}`,
      pr_red: prRed.test,
    });
  } else {
    stage("tests", true, {
      note: `${results.length} run, ${flaky.length} flaky, ${baseRed.length} base-red`,
    });
  }
  if (flaky.length)
    log(`flaky (red then green on rerun; make deterministic, never skip): ${flaky.join(", ")}`);
  if (baseRed.length)
    log(`base-red (red on the merge base too; not this PR): ${baseRed.join(", ")}`);
  if (receipt.selection.bot_shards.length)
    log(
      `bot shards to run: ${receipt.selection.bot_shards.map((test) => path.posix.basename(test, ".gd")).join(" ")}`,
    );
  if (lanePlan.deferred.length)
    log(`past the budget, for the staging full gate: ${lanePlan.deferred.length} tests`);
  finish();
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv[2] === "--fold-timings") {
    const files = process.argv.slice(3);
    if (files.length === 0)
      throw new Error(
        "--fold-timings takes one or more receipt files (smoke, fast lane or gate shard.json)",
      );
    const receipts = files.map((file) => JSON.parse(readFileSync(file, "utf8")));
    const tests = Object.assign({}, readTimings(), ...receipts.map(timingsFromReceipt));
    const source =
      receipts.length === 1
        ? `${receipts[0].label ?? receipts[0].title ?? files[0]} ${receipts[0].head ?? ""}`.trim()
        : `${receipts.length} receipts on ${[...new Set(receipts.map((receipt) => String(receipt.head ?? "").slice(0, 8)))].join(", ")} (passing tests only; older rows kept)`;
    writeFileSync(
      TIMINGS_FILE,
      JSON.stringify({ source, tests: Object.fromEntries(Object.entries(tests).sort()) }, null, 2) +
        "\n",
    );
    console.log(
      `sketch:fast timings: ${Object.keys(tests).length} tests after ${files.length} receipt${files.length === 1 ? "" : "s"}`,
    );
  } else main();
}
