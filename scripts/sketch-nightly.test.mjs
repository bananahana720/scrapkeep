// Rules: ALPHA-PLAN Testing and T8's runner, receipt, threshold and dry-run contract.
import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  artifacts,
  BOT_SEEDS,
  buildPlan,
  buildReceipt,
  commandFor,
  DEFAULT_RUNS,
  flakePasses,
  flakeRate,
  MAX_FLAKE_RATE,
  MAX_WALL_MS,
  parseArgs,
  runNightly,
  runProcess,
  soloScripts,
} from "./sketch-nightly.mjs";

const git = {
  head: "a".repeat(40),
  tree: "b".repeat(40),
  clean: true,
  dirty_paths: [],
};
const startedAt = "2026-10-03T12:00:00.000Z";
const scripts = [
  "res://tests/deterministic_test.gd",
  "res://tests/presentation_audio_test.gd",
];
const baseline = {
  L1: ["sketches/core-loop/tests/presentation_audio_test.gd"],
};
const options = parseArgs([]);
const botData = (step) => ({
  policy: step.policy,
  seed: step.seed,
  outcome: step.policy === "camper" ? "died" : "won",
  heft: step.policy === "completionist" ? 2 : 1,
  parts: step.policy === "completionist" ? 8 : 2,
  bestCombo: 2,
  fightSeconds: step.policy === "completionist" ? 20 : 90,
});
const data = (step) => {
  if (step.kind === "bot") return { bot: botData(step) };
  if (step.kind === "perf")
    return {
      perf: {
        stats: {
          process_ms: { p50: 100 },
          frame_ms: { p50: 200 },
          physics_ms: { p50: 80 },
        },
      },
    };
  return {};
};
const passingRunner = async (step) => ({
  code: 0,
  output:
    step.kind === "test"
      ? "[rule] checked -> PASS\nfixture_test: PASS\n"
      : "tool completed\n",
});

async function fixture(fn) {
  const outDir = mkdtempSync(path.join(os.tmpdir(), "sketch-nightly-test-"));
  try {
    const plan = buildPlan(options, {
      scripts,
      baseline,
      outDir,
      imported: true,
    });
    return await fn({ plan, outDir });
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
}

// Rule: parse explicit flags, require positive integral repetition counts, reject typos.
test("argument parsing defaults and validation", () => {
  assert.deepEqual(parseArgs([]), { dryRun: false, runs: DEFAULT_RUNS });
  assert.deepEqual(parseArgs(["--dry-run", "--runs", "4"]), {
    dryRun: true,
    runs: 4,
  });
  for (const value of [
    undefined,
    "0",
    "-1",
    "1.1",
    "NaN",
    "Infinity",
    "1e3",
    "9007199254740992",
  ]) {
    assert.throws(
      () => parseArgs(value === undefined ? ["--runs"] : ["--runs", value]),
      /positive integer/,
    );
  }
  assert.throws(() => parseArgs(["--quick"]), /unknown argument/);
});

// Rule: >1% flakes is red, exactly 1% is green, no runs is unknown and red.
test("flake arithmetic and inclusive threshold, including zero runs", () => {
  assert.equal(MAX_FLAKE_RATE, 0.01);
  assert.equal(flakeRate(0, 0), null);
  assert.equal(flakePasses(0, 0), false);
  assert.equal(flakeRate(1, 100), 0.01);
  assert.equal(flakePasses(1, 100), true);
  assert.equal(flakePasses(2, 100), false);
  assert.equal(flakePasses(0, 3), true);
  assert.equal(flakeRate(1, 3), 1 / 3);
});

// Rule: the full checkpoint bot matrix precedes fuzz, perf and repeated full tests.
test("plan matches checkpoint commands, optional import and serial wall-clock tests", async () =>
  fixture(({ plan, outDir }) => {
    assert.equal(plan.filter((s) => s.kind === "bot").length, 3 * BOT_SEEDS);
    assert.deepEqual(plan[0].args, [
      "--headless",
      "--fixed-fps",
      "90",
      "--path",
      path.resolve("sketches/core-loop"),
      "--script",
      "res://tools/bot_run.gd",
      "--",
      `--out=${outDir}/bots/completionist-1`,
      "--policy=completionist",
      "--seeds=1",
      "--table=default",
    ]);
    assert.equal(
      plan.find((s) => s.kind === "fuzz").args.includes("--seeds=1-200"),
      true,
    );
    assert.equal(plan.filter((s) => s.kind === "perf").length, 3);
    assert.equal(
      plan.filter((s) => s.kind === "test").length,
      scripts.length * DEFAULT_RUNS,
    );
    for (const step of plan.filter((s) => s.command))
      assert.ok(step.args.includes("--headless"));
    assert.match(plan.find((s) => s.kind === "skip").reason, /headless-only/);
    assert.deepEqual(
      plan.filter((s) => s.kind === "test").map((s) => s.solo),
      [false, true, false, true, false, true],
    );
    assert.equal(
      buildPlan(options, { scripts, baseline, outDir, imported: false })[0]
        .kind,
      "import",
    );
    const helperBaseline = {
      L1: ["sketches/core-loop/tests/trees/child_runs.gd"],
    };
    assert.deepEqual(
      [
        ...soloScripts(
          ["res://tests/tree_bot_test.gd", "res://tests/tree_play_test.gd"],
          helperBaseline,
        ),
      ],
      ["res://tests/tree_bot_test.gd", "res://tests/tree_play_test.gd"],
    );
  }));

// Rule: GPU flock surrounds rendered steps only; headless commands take no GPU lock.
test("GPU lock is conditional on rendering", () => {
  const step = { command: "godot", args: ["--headless"] };
  assert.deepEqual(commandFor(step), step);
  assert.deepEqual(commandFor({ ...step, render: true }), {
    command: "flock",
    args: ["/tmp/scrapkeep-gpu.lock", "godot", "--headless"],
  });
});

// Rule: passing fake processes yield green, even with expensive ungated perf numbers.
test("green passing fake runner and receipt shape", async () =>
  fixture(async ({ plan, outDir }) => {
    const { exit, receipt } = await runNightly(options, {
      plan,
      git,
      startedAt,
      outDir,
      runner: passingRunner,
      readArtifacts: data,
      log: () => {},
    });
    assert.equal(exit, 0);
    assert.equal(receipt.ok, true);
    assert.equal(receipt.schema, "scrapkeep-nightly-receipt/1");
    assert.deepEqual(
      [receipt.tree, receipt.head, receipt.clean, receipt.dirty_paths],
      [git.tree, git.head, true, []],
    );
    assert.equal(receipt.started_at, startedAt);
    assert.equal(receipt.plan.length, receipt.results.length);
    assert.equal(receipt.totals.runs, plan.length - 1);
    assert.equal(receipt.totals.failed, 0);
    assert.equal(receipt.totals.skipped, 1);
    assert.equal(receipt.totals.passes, scripts.length * DEFAULT_RUNS);
    assert.equal(receipt.totals.fails, 0);
    assert.ok(receipt.wall_ms >= 0);
    assert.ok(
      receipt.results
        .filter((r) => r.kind !== "skip")
        .every(
          (r) =>
            r.exit === 0 && r.ms >= 0 && r.command && Array.isArray(r.args),
        ),
    );
    assert.equal(receipt.full_bot_matrix, true);
    assert.ok(receipt.bot_bands.every((r) => r.pass));
    assert.deepEqual(
      receipt.flakes.map((r) => [r.runs, r.failures, r.rate, r.ok]),
      [
        [3, 0, 0, true],
        [3, 0, 0, true],
      ],
    );
    assert.equal(receipt.perf.gated, false);
    assert.equal(receipt.perf.medians_p50_ms.process_ms, 100);
    assert.equal(receipt.perf.medians_p50_ms.gpu_ms, null);
    assert.equal(receipt.thresholds.max_wall_ms, 60 * 60_000);
  }));

// Rule: failing exits or printed FAIL verdicts count as failures, with no retries.
test("red failing fake runner counts failures over runs", async () =>
  fixture(async ({ plan, outDir }) => {
    let calls = 0;
    const runner = async (step) => {
      calls++;
      return step.kind === "test" &&
        step.script === scripts[0] &&
        step.run === 2
        ? { code: 1, output: "[rule] wrong -> FAIL\nfixture_test: FAIL (1)\n" }
        : passingRunner(step);
    };
    const { exit, receipt } = await runNightly(options, {
      plan,
      git,
      startedAt,
      outDir,
      runner,
      readArtifacts: data,
      log: () => {},
    });
    assert.equal(exit, 1);
    assert.equal(calls, plan.filter((s) => s.command).length);
    assert.deepEqual(receipt.flakes[0], {
      script: scripts[0],
      runs: 3,
      planned_runs: 3,
      failures: 1,
      rate: 1 / 3,
      ok: false,
    });
    assert.equal(receipt.totals.fails, 1);
    const bad = await runNightly(options, {
      plan,
      git,
      startedAt,
      outDir,
      runner: async (step) =>
        step.kind === "test"
          ? { code: 0, output: "fixture_test: FAIL (1)\n" }
          : passingRunner(step),
      readArtifacts: data,
      log: () => {},
    });
    assert.equal(bad.exit, 1);
  }));

// Rule: bot band misses, process exceptions, missing artifacts and dirty trees are red.
test("bot band miss and infrastructure failure cannot pass", async () =>
  fixture(async ({ plan, outDir }) => {
    const run = (extra) =>
      runNightly(options, {
        plan,
        git,
        startedAt,
        outDir,
        runner: passingRunner,
        readArtifacts: data,
        log: () => {},
        ...extra,
      });
    const camperWins = await run({
      readArtifacts: (step) =>
        step.kind === "bot" && step.policy === "camper"
          ? { bot: { ...botData(step), outcome: "won" } }
          : data(step),
    });
    assert.equal(camperWins.exit, 1);
    assert.equal(camperWins.receipt.bot_bands[0].pass, false);
    assert.equal(
      (
        await run({
          runner: async () => {
            throw new Error("fake spawn error");
          },
        })
      ).exit,
      1,
    );
    assert.equal(
      (
        await run({
          readArtifacts: () => {
            throw new Error("missing artifact");
          },
        })
      ).exit,
      1,
    );
    assert.equal((await run({ git: { ...git, clean: false } })).exit, 1);
  }));

// Rule: budget exhaustion prevents spawning and leaves incomplete tests red.
test("wall budget bounds launch and reports zero completed runs", async () =>
  fixture(async ({ plan, outDir }) => {
    let spawns = 0;
    const { receipt, exit } = await runNightly(options, {
      plan,
      git,
      startedAt,
      outDir,
      started: 0,
      now: () => MAX_WALL_MS,
      runner: async () => {
        spawns++;
      },
      log: () => {},
    });
    assert.equal(spawns, 0);
    assert.equal(exit, 1);
    assert.equal(receipt.flakes[0].rate, null);
    assert.equal(receipt.flakes[0].runs, 0);
    assert.ok(
      receipt.results
        .filter((r) => r.kind !== "skip")
        .every((r) => /budget exhausted/.test(r.reason)),
    );
  }));

// Rule: wall-clock tests run alone after all concurrent tests in each repeat.
test("solo scheduling has no overlapping fake processes", async () =>
  fixture(async ({ plan, outDir }) => {
    let active = 0;
    let peak = 0;
    const runner = async (step) => {
      if (step.solo) assert.equal(active, 0);
      active++;
      peak = Math.max(peak, active);
      await new Promise((resolve) => setImmediate(resolve));
      if (step.solo) assert.equal(active, 1);
      active--;
      return passingRunner(step);
    };
    assert.equal(
      (
        await runNightly(options, {
          plan,
          git,
          startedAt,
          outDir,
          runner,
          readArtifacts: data,
          log: () => {},
        })
      ).exit,
      0,
    );
    assert.ok(peak > 1 && peak <= 6);
  }));

// Rule: dry-run prints every planned command without spawning or writing evidence.
test("dry-run produces ordered plan without invoking runner", async () =>
  fixture(async ({ plan }) => {
    const lines = [];
    const result = await runNightly(
      { ...options, dryRun: true },
      {
        plan,
        runner: () => {
          assert.fail("dry-run spawned");
        },
        log: (line) => lines.push(line),
      },
    );
    assert.deepEqual(result, { exit: 0, receipt: null });
    assert.equal(lines.length, plan.length);
    assert.match(lines[0], /bot completionist 1/);
    assert.match(lines.at(-1), /run 3 \[solo\]/);
    assert.equal(lines.filter((line) => line.startsWith("SKIP")).length, 1);
  }));

// Rule: the real CLI dry-run must also succeed with an unusable Godot path.
test("CLI dry-run never launches Godot", () => {
  const result = spawnSync(
    process.execPath,
    ["scripts/sketch-nightly.mjs", "--dry-run", "--runs", "1"],
    {
      encoding: "utf8",
      env: { ...process.env, GODOT_BIN: "/does/not/exist/nightly-godot" },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /does\/not\/exist\/nightly-godot/);
  assert.match(result.stdout, /item fuzz/);
  assert.match(result.stdout, /GPU perf/);
});

// Rule: artifacts must describe the exact bot seed and complete fuzz workload.
test("artifact validation rejects missing seeds and hard fuzz violations", async () =>
  fixture(({ outDir }) => {
    const botDir = path.join(outDir, "bot");
    mkdirSync(botDir);
    const bot = { policy: "skipper", seed: 1, outcome: "won", run_id: "run" };
    writeFileSync(path.join(botDir, "bots.ndjson"), JSON.stringify(bot) + "\n");
    writeFileSync(
      path.join(botDir, "runs.ndjson"),
      JSON.stringify({
        run_id: "run",
        table: "default",
        stages: [
          {
            heft_at_engage: 1,
            part_ids_at_exit: ["a"],
            posture: { fight_ticks: 900 },
          },
        ],
      }) + "\n",
    );
    assert.equal(
      artifacts({ kind: "bot", policy: "skipper", seed: 1, out: botDir }).bot
        .fightSeconds,
      10,
    );
    assert.throws(
      () => artifacts({ kind: "bot", policy: "skipper", seed: 2, out: botDir }),
      /mismatched/,
    );
    const rows = Array.from({ length: 200 }, (_, i) => ({
      seed: i + 1,
      ticks: 8100,
      natural: Array.from({ length: 12 }, (_, k) => `trigger${k}`),
      injected: [],
      anomalies: [],
    }));
    const fuzz = () =>
      writeFileSync(
        path.join(outDir, "fuzz.ndjson"),
        rows.map((r) => JSON.stringify(r)).join("\n"),
      );
    fuzz();
    assert.equal(artifacts({ kind: "fuzz", out: outDir }).fuzz.seeds, 200);
    rows[0].anomalies.push({ kind: "bolts" });
    fuzz();
    assert.throws(
      () => artifacts({ kind: "fuzz", out: outDir }),
      /hard invariant miss/,
    );
    rows[0].anomalies = [{ kind: "frame_time" }];
    fuzz();
    assert.equal(
      artifacts({ kind: "fuzz", out: outDir }).fuzz.soft_anomalies,
      1,
    );
    rows[0].seed = 2;
    fuzz();
    assert.throws(() => artifacts({ kind: "fuzz", out: outDir }), /incomplete/);
  }));

test("artifact validation rejects retired slice run-log records", async () =>
  fixture(({ outDir }) => {
    writeFileSync(
      path.join(outDir, "bots.ndjson"),
      JSON.stringify({ policy: "skipper", seed: 1, run_id: "run" }) + "\n",
    );
    writeFileSync(
      path.join(outDir, "runs.ndjson"),
      JSON.stringify({ run_id: "run", table: "slice", stages: [] }) + "\n",
    );
    assert.throws(
      () => artifacts({ kind: "bot", policy: "skipper", seed: 1, out: outDir }),
      /missing default run-log record/,
    );
  }));

// Rule: process execution captures exits and output, isolates saves and enforces timeouts.
test("process runner handles exits, spawn errors and time limits", async () =>
  fixture(async ({ outDir }) => {
    const step = {
      command: process.execPath,
      args: [
        "-e",
        "console.log(process.env.XDG_DATA_HOME); console.error('stderr'); process.exit(7)",
      ],
      state_dir: outDir,
    };
    const failed = await runProcess(step, 5000);
    assert.equal(failed.code, 7);
    assert.match(failed.output, /stderr/);
    assert.ok(failed.output.includes(path.join(outDir, "state/data")));
    assert.equal(failed.timed_out, false);
    const missing = await runProcess(
      { ...step, command: "/does/not/exist/nightly-runner" },
      5000,
    );
    assert.equal(missing.code, -1);
    assert.match(missing.output, /ENOENT/);
    const timeout = await runProcess(
      { ...step, args: ["-e", "setInterval(() => {}, 1000)"] },
      50,
    );
    assert.equal(timeout.timed_out, true);
    assert.equal(timeout.code, null);
  }));

// Rule: incomplete matrix or empty test list is never green.
test("empty receipt is red and contains no fabricated flake rate", () => {
  const receipt = buildReceipt({
    options,
    plan: [],
    results: [],
    git,
    startedAt,
    wallMs: 0,
  });
  assert.equal(receipt.ok, false);
  assert.equal(receipt.full_bot_matrix, false);
  assert.deepEqual(receipt.flakes, []);
  assert.deepEqual(receipt.totals, {
    runs: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    passes: 0,
    fails: 0,
  });
});
