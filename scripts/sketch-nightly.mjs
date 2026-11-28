#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { resolveGodotBinary, scratchGodotEnv } from "./godot-home.mjs";
import * as testRunner from "./lib/godot-test-runner.mjs";
import { acquireSlot } from "./lib/machine-lock.mjs";
import { pool, runProcess as runChild } from "./lib/proc.mjs";
import { runnerReceiptPath, writeJsonReceipt } from "./lib/receipt.mjs";
import {
  BANDS,
  TABLE,
  checkpointPassed,
  evaluateBots,
  median,
  summarizeRun,
} from "./checkpoint.mjs";
import { gitOptional } from "./lib/git.mjs";
import { isMain } from "./lib/cli.mjs";

export const MAX_WALL_MS = 60 * 60_000;
export const MAX_FLAKE_RATE = 0.01;
export const BOT_SEEDS = BANDS.seeds;
export const DEFAULT_RUNS = 3;
export const PERF_RUNS = 3;
export const FUZZ_SEEDS = 200;
export const FUZZ_SECONDS = 90;
const TOOL_TIMEOUT_MS = 15 * 60_000;
export const EXPORT_TIMEOUT_MS = 20 * 60_000;
const FINISH_RESERVE_MS = 45_000;
const WIDTH = BANDS.parallel;
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches", "core-loop");
const GPU_LOCK = "/tmp/scrapkeep-gpu.lock";
export const EXPORT_SCRIPT = path.join(root, "scripts", "sketch-export.mjs");

export function parseArgs(argv) {
  const options = { dryRun: false, runs: DEFAULT_RUNS, export: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--dry-run") options.dryRun = true;
    else if (argv[i] === "--export") options.export = true;
    else if (argv[i] === "--runs") {
      const value = argv[++i];
      if (!/^\d+$/.test(value ?? "") || !Number.isSafeInteger(Number(value)) || Number(value) < 1) {
        throw new Error("--runs needs a positive integer");
      }
      options.runs = Number(value);
    } else throw new Error(`unknown argument ${argv[i]}`);
  }
  return options;
}

export function flakeRate(failures, runs) {
  return runs === 0 ? null : failures / runs;
}

export function flakePasses(failures, runs) {
  const rate = flakeRate(failures, runs);
  return rate !== null && rate <= MAX_FLAKE_RATE;
}

export function testEntry(script) {
  return script;
}

export function soloScripts(scripts, baseline, directory = sketch) {
  const prefix = "sketches/core-loop/";
  const allowed = new Set((baseline.L1 ?? []).map((file) => `res://${file.replace(prefix, "")}`));
  if (allowed.has("res://tests/trees/child_runs.gd")) {
    allowed.add("res://tests/tree_bot_test.gd");
    allowed.add("res://tests/tree_play_test.gd");
  }
  return new Set(
    scripts.filter((script) => allowed.has(script) || testRunner.isSoloScript(directory, script)),
  );
}

export function buildPlan(
  options,
  {
    directory = sketch,
    scripts = testRunner.testScripts(directory),
    baseline = JSON.parse(
      readFileSync(path.join(root, "scripts/sketch-lint.baseline.json"), "utf8"),
    ),
    outDir,
    imported = existsSync(path.join(directory, ".godot/imported")),
  } = {},
) {
  const solo = soloScripts(scripts, baseline, directory);
  const command = resolveGodotBinary() ?? "godot";
  const plan = [];
  const add = (id, kind, args, extra = {}) => {
    plan.push({
      id,
      kind,
      command,
      args,
      render: false,
      timeout_ms: TOOL_TIMEOUT_MS,
      ...extra,
    });
  };
  const base = ["--headless", "--path", directory];
  if (!imported) add("import", "import", [...base, "--import"], { timeout_ms: 600_000 });
  if (options.export)
    add("export win proof", "export", [EXPORT_SCRIPT, "--win-proof"], {
      command: process.execPath,
      timeout_ms: EXPORT_TIMEOUT_MS,
    });
  for (const policy of ["completionist", "skipper", "camper"]) {
    for (let seed = 1; seed <= BOT_SEEDS; seed++) {
      const dir = path.join(outDir, "bots", `${policy}-${seed}`);
      add(
        `bot ${policy} ${seed}`,
        "bot",
        [
          "--headless",
          "--fixed-fps",
          "90",
          "--path",
          sketch,
          "--script",
          "res://tools/bot_run.gd",
          "--",
          `--out=${dir}`,
          `--policy=${policy}`,
          `--seeds=${seed}`,
          `--table=${TABLE}`,
        ],
        { policy, seed, out: dir },
      );
    }
  }
  const fuzz = path.join(outDir, "fuzz");
  add(
    "item fuzz",
    "fuzz",
    [
      "--headless",
      "--fixed-fps",
      "90",
      "--path",
      sketch,
      "--script",
      "res://tools/item_fuzz.gd",
      "--",
      `--seeds=1-${FUZZ_SEEDS}`,
      `--seconds=${FUZZ_SECONDS}`,
      `--out=${fuzz}`,
    ],
    { out: fuzz },
  );
  for (let run = 1; run <= PERF_RUNS; run++) {
    const out = path.join(outDir, `perf-${run}.json`);
    add(
      `perf ${run}`,
      "perf",
      [
        ...base,
        "--script",
        "res://tools/perf_bench.gd",
        "--",
        "--scene=s3",
        `--table=${TABLE}`,
        `--out=${out}`,
      ],
      { out, timeout_ms: 310_000 },
    );
  }
  plan.push({
    id: "GPU perf",
    kind: "skip",
    command: null,
    args: [],
    render: false,
    reason:
      "headless-only: perf_bench GPU/render timings require a native renderer; no GPU baseline exists",
  });
  for (let run = 1; run <= options.runs; run++) {
    for (const script of [
      ...scripts.filter((s) => !solo.has(s)),
      ...scripts.filter((s) => solo.has(s)),
    ]) {
      add(`${script} run ${run}`, "test", [...base, "--script", testEntry(script)], {
        script,
        run,
        solo: solo.has(script),
        timeout_ms: testRunner.testTimeoutMs(
          readFileSync(path.join(directory, script.replace(/^res:\/\//, "")), "utf8"),
        ),
      });
    }
  }
  return plan;
}

export function commandFor(step) {
  return step.render
    ? { command: "flock", args: [GPU_LOCK, step.command, ...step.args] }
    : { command: step.command, args: step.args };
}

function ndjson(file) {
  return readFileSync(file, "utf8")
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line));
}

export function artifacts(step, output = "") {
  if (step.kind === "export") {
    const field = (name) => output.match(new RegExp(`^${name}: (.+)$`, "m"))?.[1] ?? null;
    const winProof = field("win proof");
    if (!winProof?.startsWith("won ")) throw new Error("export ran without a won win proof line");
    return {
      export: {
        version: field("version"),
        package: field("package"),
        executable: field("executable"),
        win_proof: winProof,
      },
    };
  }
  if (step.kind === "bot") {
    const bots = ndjson(path.join(step.out, "bots.ndjson"));
    const bot = bots[0];
    if (bots.length !== 1 || bot.policy !== step.policy || bot.seed !== step.seed)
      throw new Error("missing or mismatched bot record");
    const line = ndjson(path.join(step.out, "runs.ndjson"))
      .reverse()
      .find((r) => r.run_id === bot.run_id);
    if (!line || line.table !== TABLE) throw new Error(`missing ${TABLE} run-log record`);
    return { bot: summarizeRun(bot, line) };
  }
  if (step.kind === "fuzz") {
    const runs = ndjson(path.join(step.out, "fuzz.ndjson"));
    const seeds = new Set(runs.map((r) => r.seed));
    const hard = new Set(["non_finite_ball", "non_finite_enemy", "bolts", "guard", "reduction"]);
    const anomalies = runs.flatMap((r) => r.anomalies);
    const hardCount = anomalies.filter(
      (a) => hard.has(a.kind) || a.kind.startsWith("charges_") || a.kind.startsWith("floor_"),
    ).length;
    const covered = new Set(runs.flatMap((r) => [...r.natural, ...r.injected]));
    const complete =
      runs.length === FUZZ_SEEDS &&
      seeds.size === FUZZ_SEEDS &&
      [...seeds].every((s) => Number.isInteger(s) && s >= 1 && s <= FUZZ_SEEDS) &&
      runs.every((r) => r.ticks >= FUZZ_SECONDS * 90 || Boolean(r.ended));
    if (!complete || covered.size !== 12 || hardCount > 0)
      throw new Error(
        `fuzz incomplete or hard invariant miss: ${runs.length} seeds, ${covered.size} triggers, ${hardCount} hard anomalies`,
      );
    return {
      fuzz: {
        seeds: runs.length,
        hard_anomalies: hardCount,
        soft_anomalies: anomalies.length - hardCount,
        anomalies_file: path.join(step.out, "anomalies.md"),
      },
    };
  }
  if (step.kind === "perf") {
    const bench = JSON.parse(readFileSync(step.out, "utf8"));
    if (
      bench.valid !== true ||
      bench.display !== "headless" ||
      bench.table !== TABLE ||
      bench.scene !== "s3" ||
      !Number.isFinite(bench.stats?.process_ms?.p50)
    )
      throw new Error("invalid headless perf artifact");
    return { perf: bench };
  }
  return {};
}

export async function runProcess(step, timeoutMs) {
  const launch = commandFor(step);
  const state = path.join(step.state_dir, "state");
  if (step.kind === "export") {
    const realData = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share");
    const godotData = path.join(state, "data", "godot");
    mkdirSync(godotData, { recursive: true });
    const templates = path.join(godotData, "export_templates");
    if (!existsSync(templates))
      symlinkSync(path.join(realData, "godot/export_templates"), templates);
  }
  const env = scratchGodotEnv(state, { baseEnv: process.env });
  const res = await runChild(launch.command, launch.args, { cwd: root, env, timeoutMs });
  if (res.error) {
    return {
      code: -1,
      output: `${res.output}\n${res.error.message}`,
      timed_out: false,
    };
  }
  return { code: res.exit, output: res.output, timed_out: res.timedOut };
}

export function buildReceipt({ options, plan, results, git, startedAt, wallMs, lockWaitMs = 0 }) {
  const scripts = [...new Set(plan.filter((s) => s.kind === "test").map((s) => s.script))];
  const flakes = scripts.map((script) => {
    const runs = results.filter((r) => r.script === script && r.exit !== undefined);
    const failures = runs.filter((r) => !r.ok).length;
    return {
      script,
      runs: runs.length,
      planned_runs: options.runs,
      failures,
      rate: flakeRate(failures, runs.length),
      ok: runs.length === options.runs && flakePasses(failures, runs.length),
    };
  });
  const grouped = { completionist: [], skipper: [], camper: [] };
  for (const row of results) if (row.bot && row.ok) grouped[row.bot.policy].push(row.bot);
  const bands = evaluateBots(grouped).map((row) =>
    row.band === "skipper smash damage per fight"
      ? {
          ...row,
          threshold: "not gated: no pre-chain baseline in nightly",
          pass: true,
          gated: false,
        }
      : row,
  );
  const fullMatrix = Object.values(grouped).every((runs) => runs.length === BOT_SEEDS);
  const perf = results.filter((r) => r.ok && r.perf).map((r) => r.perf);
  const perfMedians = Object.fromEntries(
    ["process_ms", "frame_ms", "physics_ms", "gpu_ms"].map((key) => [
      key,
      median(perf.map((b) => b.stats?.[key]?.p50)),
    ]),
  );
  const failed = results.filter((r) => r.kind !== "test" && r.kind !== "skip" && !r.ok);
  const counts = results.reduce(
    (sum, r) => ({
      passes: sum.passes + (r.passes ?? 0),
      fails: sum.fails + (r.fails ?? 0),
    }),
    { passes: 0, fails: 0 },
  );
  const ok =
    git.clean === true &&
    Boolean(git.tree) &&
    fullMatrix &&
    checkpointPassed(bands) &&
    scripts.length > 0 &&
    flakes.every((r) => r.ok) &&
    failed.length === 0 &&
    wallMs < MAX_WALL_MS;
  return {
    schema: "scrapkeep-nightly-receipt/1",
    label: "nightly",
    root,
    head: git.head,
    tree: git.tree,
    clean: git.clean,
    dirty_paths: git.dirty_paths,
    started_at: startedAt,
    wall_ms: wallMs,
    lock_wait_ms: lockWaitMs,
    thresholds: {
      flake_rate: MAX_FLAKE_RATE,
      max_wall_ms: MAX_WALL_MS,
      bot_bands: BANDS,
      perf_gated: false,
    },
    options,
    plan,
    results,
    bot_bands: bands,
    full_bot_matrix: fullMatrix,
    flakes,
    export: results.find((r) => r.kind === "export")?.export ?? null,
    perf: {
      runs: perf.length,
      medians_p50_ms: perfMedians,
      gated: false,
      reason: "no baseline; headless CPU only, GPU unavailable",
    },
    totals: {
      runs: results.filter((r) => r.exit !== undefined).length,
      passed: results.filter((r) => r.ok === true).length,
      failed: results.filter((r) => r.ok === false).length,
      skipped: results.filter((r) => r.kind === "skip").length,
      ...counts,
    },
    ok,
  };
}

export async function runNightly(
  options,
  {
    plan,
    git,
    startedAt,
    outDir,
    runner = runProcess,
    readArtifacts = artifacts,
    log = console.log,
    now = Date.now,
    started = now(),
    lockWaitMs = 0,
  },
) {
  if (options.dryRun) {
    for (const step of plan) {
      const launch = commandFor(step);
      log(
        step.kind === "skip"
          ? `SKIP ${step.id}: ${step.reason}`
          : `${step.id}${step.solo ? " [solo]" : ""}: ${[launch.command, ...launch.args].map((s) => JSON.stringify(s)).join(" ")}`,
      );
    }
    return { exit: 0, receipt: null };
  }
  const results = new Array(plan.length);
  async function run(index) {
    const step = plan[index];
    const row = { ...step, ...commandFor(step) };
    if (step.kind === "skip") {
      results[index] = { ...row, ok: null, ms: 0 };
      return;
    }
    const remaining = MAX_WALL_MS - FINISH_RESERVE_MS - (now() - started);
    if (remaining <= 0) {
      results[index] = {
        ...row,
        ok: false,
        ms: 0,
        reason: "nightly wall budget exhausted; not launched",
      };
      return;
    }
    const before = now();
    const dir = path.join(outDir, "steps", String(index));
    mkdirSync(dir, { recursive: true });
    let result;
    let data = {};
    try {
      result = await runner({ ...step, state_dir: dir }, Math.min(step.timeout_ms, remaining));
      const verdict = testRunner.judge({
        test: step.kind === "test",
        status: result.code,
        output: result.output,
      });
      data = {
        ok: verdict.ok && !result.timed_out,
        reason: result.timed_out ? "process time limit exceeded" : verdict.reason,
        skips: verdict.skips,
      };
      if (data.ok) Object.assign(data, readArtifacts(step, result.output ?? ""));
    } catch (error) {
      data = { ok: false, reason: error.message };
      result ??= { code: -1, output: error.message };
    }
    const output = result.output ?? "";
    const checks = testRunner.countChecks(output);
    const verdictLine =
      output
        .split(/\r?\n/)
        .filter((line) => /^[\w.-]+: (PASS|FAIL)\b/.test(line))
        .at(-1) ?? null;
    const logFile = path.join(dir, "log.txt");
    writeFileSync(logFile, output);
    results[index] = {
      ...row,
      ...data,
      exit: result.code,
      ms: now() - before,
      ...checks,
      verdict_line: verdictLine,
      timed_out: Boolean(result.timed_out),
      log: logFile,
    };
    log(
      `${data.ok ? "PASS" : "FAIL"} ${step.id} exit=${result.code} ${(results[index].ms / 1000).toFixed(1)}s${data.reason ? `: ${data.reason}` : ""}`,
    );
  }
  for (let first = 0; first < plan.length;) {
    const step = plan[first];
    let end = first + 1;
    if (step.kind === "bot" || (step.kind === "test" && !step.solo)) {
      while (
        end < plan.length &&
        plan[end].kind === step.kind &&
        !plan[end].solo &&
        plan[end].run === step.run
      )
        end++;
    }
    const indices = Array.from({ length: end - first }, (_, i) => first + i);
    await pool(
      indices.map((idx) => () => run(idx)),
      WIDTH,
    );
    first = end;
  }
  const receipt = buildReceipt({
    options,
    plan,
    results,
    git,
    startedAt,
    wallMs: now() - started,
    lockWaitMs,
  });
  return { exit: receipt.ok ? 0 : 1, receipt };
}

function gitState() {
  const git = (args) => gitOptional(args, { cwd: root, timeout: 10_000 });
  const status = git(["status", "--porcelain"]);
  return {
    head: git(["rev-parse", "HEAD"]),
    tree: git(["rev-parse", "HEAD^{tree}"]),
    clean: status === null ? null : status === "",
    dirty_paths: status === null ? null : status.split("\n").filter(Boolean),
  };
}

export async function acquireNightlySlot(deadline, options = {}) {
  const lease = await acquireSlot({
    ...options,
    sleep: (ms) => {
      if (Date.now() >= deadline)
        throw new Error("nightly wall budget exhausted waiting for the smoke machine lock");
      return new Promise((resolve) => setTimeout(resolve, Math.min(ms, deadline - Date.now())));
    },
  });
  return lease.release;
}

export function writeReceipt(receipt) {
  return writeJsonReceipt(
    runnerReceiptPath(root, "nightly", receipt.tree, receipt.started_at),
    receipt,
  );
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const startedAt = new Date().toISOString();
  const started = Date.now();
  const outDir = path.join(root, "artifacts/local/nightly", startedAt.replace(/[:.]/g, "-"));
  const plan = buildPlan(options, { outDir });
  if (options.dryRun) {
    await runNightly(options, { plan });
    return;
  }
  const git = gitState();
  let release;
  let outcome;
  try {
    release = await acquireNightlySlot(started + MAX_WALL_MS - FINISH_RESERVE_MS);
    process.once("exit", release);
    outcome = await runNightly(options, {
      plan,
      git,
      startedAt,
      started,
      outDir,
      lockWaitMs: Date.now() - started,
    });
  } catch (error) {
    console.error(error.message);
    outcome = {
      exit: 1,
      receipt: buildReceipt({
        options,
        plan,
        results: [],
        git,
        startedAt,
        wallMs: Date.now() - started,
      }),
    };
    outcome.receipt.error = error.message;
  } finally {
    if (release) {
      process.removeListener("exit", release);
      release();
    }
  }
  const after = gitState();
  outcome.receipt.git_at_end = after;
  outcome.receipt.wall_ms = Date.now() - started;
  if (
    after.clean !== true ||
    after.tree !== git.tree ||
    after.head !== git.head ||
    outcome.receipt.wall_ms >= MAX_WALL_MS
  ) {
    outcome.receipt.ok = false;
    outcome.exit = 1;
  }
  console.log(`receipt ${writeReceipt(outcome.receipt)}`);
  process.exitCode = outcome.exit;
}

if (isMain(import.meta.url))
  main().catch((error) => {
    console.error(`sketch:nightly: ${error.message}`);
    process.exitCode = 2;
  });
