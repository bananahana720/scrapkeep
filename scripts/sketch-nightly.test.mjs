import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { acquireSlot } from "./lib/machine-lock.mjs";
import {
  acquireNightlySlot,
  artifacts,
  BOT_SEEDS,
  buildPlan,
  buildReceipt,
  commandFor,
  DEFAULT_RUNS,
  EXPORT_TIMEOUT_MS,
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
const scripts = ["res://tests/deterministic_test.gd", "res://tests/presentation_audio_test.gd"];
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
    step.kind === "test" ? "[rule] checked -> PASS\nfixture_test: PASS\n" : "tool completed\n",
});

test("nightly launches bot-tier tests with their smoke marker caps", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "nightly-marker-test-"));
  const sources = {
    "ordinary.gd": "extends SceneTree\n",
    "solo.gd": "# smoke: solo timeout=300s\n",
    "bots.gd": "# smoke: bots timeout=900s\n",
    "bots_max.gd": "# smoke: bots timeout=2400s\n",
    "bots_default.gd": "# smoke: bots\n",
  };
  try {
    mkdirSync(path.join(directory, "tests"));
    for (const [name, source] of Object.entries(sources))
      writeFileSync(path.join(directory, "tests", name), source);
    const options = parseArgs(["--runs", "1"]);
    const plan = buildPlan(options, {
      directory,
      scripts: Object.keys(sources).map((name) => `res://tests/${name}`),
      baseline: {},
      outDir: directory,
      imported: true,
    }).filter((step) => step.kind === "test");
    assert.equal(plan.find((step) => step.script === "res://tests/bots.gd").timeout_ms, 900_000);
    const launches = {};
    await runNightly(options, {
      plan,
      git,
      startedAt,
      outDir: directory,
      runner: async (step, timeoutMs) => {
        assert.equal(step.solo, step.script !== "res://tests/ordinary.gd");
        launches[path.basename(step.script)] = timeoutMs;
        return passingRunner(step);
      },
      readArtifacts: () => ({}),
      log: () => {},
    });
    assert.deepEqual(launches, {
      "ordinary.gd": 180_000,
      "solo.gd": 300_000,
      "bots.gd": 900_000,
      "bots_max.gd": 1_800_000,
      "bots_default.gd": 1_200_000,
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

async function fixture(fn) {
  const outDir = mkdtempSync(path.join(os.tmpdir(), "sketch-nightly-test-"));
  try {
    mkdirSync(path.join(outDir, "tests"));
    for (const script of scripts)
      writeFileSync(path.join(outDir, script.replace(/^res:\/\//, "")), "extends SceneTree\n");
    const plan = buildPlan(options, {
      directory: outDir,
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

test("argument parsing defaults and validation", () => {
  assert.deepEqual(parseArgs([]), {
    dryRun: false,
    runs: DEFAULT_RUNS,
    export: false,
  });
  assert.deepEqual(parseArgs(["--dry-run", "--runs", "4"]), {
    dryRun: true,
    runs: 4,
    export: false,
  });
  assert.equal(parseArgs(["--export"]).export, true);
  for (const value of [undefined, "0", "-1", "1.1", "NaN", "Infinity", "1e3", "9007199254740992"]) {
    assert.throws(
      () => parseArgs(value === undefined ? ["--runs"] : ["--runs", value]),
      /positive integer/,
    );
  }
  assert.throws(() => parseArgs(["--quick"]), /unknown argument/);
});

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
    assert.equal(plan.find((s) => s.kind === "fuzz").args.includes("--seeds=1-200"), true);
    assert.equal(plan.filter((s) => s.kind === "perf").length, 3);
    assert.equal(plan.filter((s) => s.kind === "test").length, scripts.length * DEFAULT_RUNS);
    for (const step of plan.filter((s) => s.command)) assert.ok(step.args.includes("--headless"));
    assert.match(plan.find((s) => s.kind === "skip").reason, /headless-only/);
    assert.deepEqual(
      plan.filter((s) => s.kind === "test").map((s) => s.solo),
      [false, true, false, true, false, true],
    );
    assert.equal(
      buildPlan(options, { directory: outDir, scripts, baseline, outDir, imported: false })[0].kind,
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

test("GPU lock is conditional on rendering", () => {
  const step = { command: "godot", args: ["--headless"] };
  assert.deepEqual(commandFor(step), step);
  assert.deepEqual(commandFor({ ...step, render: true }), {
    command: "flock",
    args: ["/tmp/scrapkeep-gpu.lock", "godot", "--headless"],
  });
});

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
        .every((r) => r.exit === 0 && r.ms >= 0 && r.command && Array.isArray(r.args)),
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

test("red failing fake runner counts failures over runs", async () =>
  fixture(async ({ plan, outDir }) => {
    let calls = 0;
    const runner = async (step) => {
      calls++;
      return step.kind === "test" && step.script === scripts[0] && step.run === 2
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
  assert.doesNotMatch(result.stdout, /^export win proof/m);
  const exported = spawnSync(
    process.execPath,
    ["scripts/sketch-nightly.mjs", "--dry-run", "--runs", "1", "--export"],
    {
      encoding: "utf8",
      env: { ...process.env, GODOT_BIN: "/does/not/exist/nightly-godot" },
    },
  );
  assert.equal(exported.status, 0, exported.stderr);
  assert.match(exported.stdout, /export win proof: .*sketch-export\.mjs" "--win-proof"/);
  assert.doesNotMatch(
    exported.stdout,
    /does\/not\/exist\/nightly-godot" "--headless" "--path" "[^"]*" "--rendering/,
  );
});

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
      artifacts({ kind: "bot", policy: "skipper", seed: 1, out: botDir }).bot.fightSeconds,
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
    assert.throws(() => artifacts({ kind: "fuzz", out: outDir }), /hard invariant miss/);
    rows[0].anomalies = [{ kind: "frame_time" }];
    fuzz();
    assert.equal(artifacts({ kind: "fuzz", out: outDir }).fuzz.soft_anomalies, 1);
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
    const missing = await runProcess({ ...step, command: "/does/not/exist/nightly-runner" }, 5000);
    assert.equal(missing.code, -1);
    assert.match(missing.output, /ENOENT/);
    const timeout = await runProcess({ ...step, args: ["-e", "setInterval(() => {}, 1000)"] }, 50);
    assert.equal(timeout.timed_out, true);
    assert.equal(timeout.code, null);
  }));

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

test("export step is opt-in, first after import, alone and unrendered", async () =>
  fixture(({ outDir }) => {
    const build = (opts, imported) =>
      buildPlan(opts, { directory: outDir, scripts, baseline, outDir, imported });
    const exportOptions = { ...options, export: true };
    assert.equal(build(options, true).filter((s) => s.kind === "export").length, 0);
    const plan = build(exportOptions, true);
    assert.equal(plan.filter((s) => s.kind === "export").length, 1);
    assert.equal(plan[0].kind, "export");
    assert.equal(plan[0].command, process.execPath);
    assert.deepEqual(plan[0].args, [path.resolve("scripts/sketch-export.mjs"), "--win-proof"]);
    assert.equal(plan[0].render, false);
    assert.equal(plan[0].timeout_ms, EXPORT_TIMEOUT_MS);
    const withImport = build(exportOptions, false);
    assert.equal(withImport[0].kind, "import");
    assert.equal(withImport[1].kind, "export");
    assert.equal(plan.filter((s) => s.kind === "bot").length, 3 * BOT_SEEDS);
  }));

test("export artifacts require a won win proof", () => {
  const out = [
    "win proof: won at stage 6, 900 ticks, 90 s wall, policy skipper seed 1, pack /x/p.pck",
    "package: /x/p.tar.gz",
    "version: v1",
    "executable: /x/game",
  ].join("\n");
  assert.deepEqual(artifacts({ kind: "export" }, out), {
    export: {
      version: "v1",
      package: "/x/p.tar.gz",
      executable: "/x/game",
      win_proof: "won at stage 6, 900 ticks, 90 s wall, policy skipper seed 1, pack /x/p.pck",
    },
  });
  assert.throws(
    () => artifacts({ kind: "export" }, "win proof: died at stage 2\n"),
    /won win proof/,
  );
  assert.throws(() => artifacts({ kind: "export" }, ""), /won win proof/);
});

test("fake export run reports in the receipt and a failing export is red", async () =>
  fixture(async ({ outDir }) => {
    const exportOptions = { ...options, export: true };
    const plan = buildPlan(exportOptions, {
      directory: outDir,
      scripts,
      baseline,
      outDir,
      imported: true,
    });
    const run = (runner, opts = exportOptions, p = plan) =>
      runNightly(opts, {
        plan: p,
        git,
        startedAt,
        outDir,
        runner,
        readArtifacts: (step) =>
          step.kind === "export" ? { export: { win_proof: "won at stage 6" } } : data(step),
        log: () => {},
      });
    const green = await run(passingRunner);
    assert.equal(green.exit, 0);
    assert.equal(green.receipt.export.win_proof, "won at stage 6");
    const red = await run(async (step) =>
      step.kind === "export"
        ? { code: 1, output: "sketch:export FAIL: export failed\n" }
        : passingRunner(step),
    );
    assert.equal(red.exit, 1);
    assert.equal(red.receipt.results.find((r) => r.kind === "export").ok, false);
    const plain = buildPlan(options, {
      directory: outDir,
      scripts,
      baseline,
      outDir,
      imported: true,
    });
    const off = await run(passingRunner, options, plain);
    assert.equal(off.receipt.export, null);
  }));

test("export step links real templates into the isolated data home", async () =>
  fixture(async ({ outDir }) => {
    const realData = mkdtempSync(path.join(os.tmpdir(), "sketch-nightly-data-"));
    const saved = process.env.XDG_DATA_HOME;
    try {
      mkdirSync(path.join(realData, "godot/export_templates/4.7.2.stable"), {
        recursive: true,
      });
      process.env.XDG_DATA_HOME = realData;
      const step = {
        kind: "export",
        command: process.execPath,
        args: [
          "-e",
          "const fs=require('fs');console.log(process.env.XDG_DATA_HOME);console.log(fs.existsSync(process.env.XDG_DATA_HOME+'/godot/export_templates/4.7.2.stable'))",
        ],
        state_dir: outDir,
      };
      const linked = await runProcess(step, 5000);
      assert.ok(linked.output.includes(path.join(outDir, "state/data")));
      assert.match(linked.output, /true/);
      const plain = await runProcess(
        { ...step, kind: "tool", state_dir: path.join(outDir, "other") },
        5000,
      );
      assert.match(plain.output, /false/);
    } finally {
      if (saved === undefined) delete process.env.XDG_DATA_HOME;
      else process.env.XDG_DATA_HOME = saved;
      rmSync(realData, { recursive: true, force: true });
    }
  }));

test("the nightly waits on the smoke runs' machine slot and gives up at its wall budget", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "nightly-slot-"));
  try {
    const options = { directory: dir, slots: 1, quietDirectory: dir, pollMs: 10, log: () => {} };
    const smoke = await acquireSlot(options);
    await assert.rejects(
      acquireNightlySlot(Date.now() + 60, options),
      /nightly wall budget exhausted waiting for the smoke machine lock/,
    );
    smoke.release();
    const release = await acquireNightlySlot(Date.now() + 5_000, options);
    await assert.rejects(
      acquireSlot({ ...options, sleep: () => Promise.reject(new Error("slot held")) }),
      /slot held/,
    );
    release();
    (await acquireSlot(options)).release();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
