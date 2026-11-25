#!/usr/bin/env node
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  HITCH_MS,
  PILOTS,
  botArgs,
  carryList,
  grade,
  hitches,
  parseNdjson,
  planWave,
  readBotJob,
  renderMarkdown,
  sharedHitches,
  sweepSeed,
  waveSeed,
} from "./lib.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const sketch = path.join(root, "sketches/core-loop");
const godot = process.env.GODOT_BIN;

const opts = {
  wave: null,
  quick: false,
  slots: 4,
  carry: null,
  export: true,
  count: null,
  sweep: false,
  block: 0,
  persona: null,
};
for (const arg of process.argv.slice(2)) {
  const [k, v] = arg.replace(/^--/, "").split("=");
  if (k === "wave") opts.wave = Number(v);
  else if (k === "quick") opts.quick = true;
  else if (k === "slots") opts.slots = Math.max(1, Number(v));
  else if (k === "runs") opts.count = Number(v);
  else if (k === "carry") opts.carry = v;
  else if (k === "no-export") opts.export = false;
  else if (k === "sweep") opts.sweep = true;
  else if (k === "block") opts.block = Number(v);
  else if (k === "persona") opts.persona = v;
  else die("unknown option " + arg);
}
if (!godot || !existsSync(godot))
  die("set GODOT_BIN to the Godot 4.7.2 editor (the cloud SessionStart hook does)");
if (opts.wave === null || Number.isNaN(opts.wave))
  die("--wave=<n> is required; it picks the seeds and the persona x pilot cells");

function die(message) {
  console.error("redteam: " + message);
  process.exit(1);
}

if (
  !Number.isInteger(opts.block) ||
  opts.block < 0 ||
  opts.block > 4 ||
  (opts.block && !opts.sweep)
)
  die("--block takes 0 to 4 and needs --sweep");
const seedOf = opts.sweep ? (w, i) => sweepSeed(w, i + 100 * opts.block) : waveSeed;
const fuzzAt = opts.sweep ? 500 + 50 * opts.block - 100 * opts.block : 50;
const count = opts.count ?? (opts.quick ? 5 : opts.sweep ? 60 : 10);
const carry = opts.carry ? (JSON.parse(readFileSync(opts.carry, "utf8")).carry ?? []) : [];
if (opts.persona && opts.sweep) die("--persona is a head pass and cannot be a sweep");
const jobs = planWave({
  wave: opts.wave,
  count,
  quick: opts.quick,
  carry,
  seed: seedOf,
  persona: opts.persona,
});
const started = new Date();
const stamp = started.toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
const outDir = path.join(
  root,
  "artifacts/local/redteam",
  `w${opts.wave}${opts.sweep ? "-sweep" + opts.block : ""}${opts.persona ? "-" + opts.persona : ""}-${stamp}`,
);
const jobsDir = path.join(outDir, "jobs");
mkdirSync(jobsDir, { recursive: true });
const commit = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
  encoding: "utf8",
}).stdout.trim();
const JOB_TIMEOUT = (opts.quick ? 10 : 40) * 60_000;
const log = (line) => console.log(`[${((Date.now() - started) / 60000).toFixed(1)}m] ${line}`);

function runProcess(args, { cwd = root, env = {}, timeout = JOB_TIMEOUT, logFile }) {
  return new Promise((resolve) => {
    const child = spawn(godot, args, { cwd, env: { ...process.env, ...env } });
    let text = "";
    let timedOut = false;
    child.stdout.on("data", (d) => (text += d));
    child.stderr.on("data", (d) => (text += d));
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeout);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      if (logFile) writeFileSync(logFile, text);
      resolve({ exit: code ?? (signal ? 128 : 1), signal, timedOut, text });
    });
  });
}

async function pool(tasks, slots) {
  const results = new Array(tasks.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(slots, tasks.length) }, async () => {
      while (next < tasks.length) {
        const i = next++;
        results[i] = await tasks[i]();
      }
    }),
  );
  return results;
}

const read = (file) => (existsSync(file) ? readFileSync(file, "utf8") : "");
const readJson = (file) => {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return null;
  }
};

function botTask(job) {
  return async () => {
    const dir = path.join(jobsDir, job.id);
    const out = path.join(dir, "out");
    const state = path.join(dir, "state");
    for (const d of ["data", "config", "cache"])
      mkdirSync(path.join(state, d), { recursive: true });
    log(`start ${job.id}${job.stages ? " (stages " + job.stages + ")" : ""}`);
    const p = await runProcess(botArgs(job, out), {
      env: {
        XDG_DATA_HOME: path.join(state, "data"),
        XDG_CONFIG_HOME: path.join(state, "config"),
        XDG_CACHE_HOME: path.join(state, "cache"),
      },
      logFile: path.join(dir, "log.txt"),
    });
    const result = readBotJob(job, {
      exit: p.exit,
      timedOut: p.timedOut,
      log: p.text,
      bots: read(path.join(out, "bots.ndjson")),
      runs: read(path.join(out, "runs.ndjson")),
      events: read(path.join(out, `events-${job.seed}.ndjson`)),
      profile: readJson(path.join(out, `profile-${job.seed}.json`)),
    });
    log(
      `done  ${job.id}: ${p.timedOut ? "TIMEOUT" : (result.row?.outcome ?? "exit " + p.exit)} at stage ${result.row?.stage_reached ?? "-"}`,
    );
    return result;
  };
}

const extras = { fuzzSeconds: opts.quick ? 30 : 60 };

function fuzzTask() {
  return async () => {
    const first = seedOf(opts.wave, fuzzAt);
    const n = opts.quick || opts.persona ? 6 : opts.sweep ? 40 : 20;
    const seeds = `${first}-${first + n - 1}`;
    const dir = path.join(jobsDir, "item-fuzz");
    mkdirSync(dir, { recursive: true });
    log("start item fuzz " + seeds);
    const p = await runProcess(
      [
        "--headless",
        "--fixed-fps",
        "90",
        "--path",
        "sketches/core-loop",
        "--script",
        "res://tools/item_fuzz.gd",
        "--",
        "--seeds=" + seeds,
        "--seconds=" + extras.fuzzSeconds,
        "--out=" + dir,
      ],
      {
        logFile: path.join(dir, "log.txt"),
        timeout: Math.max(JOB_TIMEOUT, n * extras.fuzzSeconds * 2500),
      },
    );
    extras.fuzz = [
      ...read(path.join(dir, "anomalies.md")).matchAll(
        /^- seed (\d+), (\w+), tick \d+: (\w+), (.*?) \(cap (.*?)\)\. .*?Build: (.*?)\. KEEP/gm,
      ),
    ].map((m) => ({
      seed: Number(m[1]),
      class: m[2],
      kind: m[3],
      reading: m[4],
      cap: m[5],
      build: m[6],
    }));
    extras.fuzzSummary = (
      p.text.match(/^item_fuzz: \d+ seeds, .*$/m) ?? [
        `exit ${p.exit}${p.timedOut ? " (timeout)" : ""}`,
      ]
    )[0];
    if (p.timedOut)
      extras.fuzzSummary = `timed out after ${extras.fuzz.length} anomalies (harness budget, not a game finding)`;
    else if (p.exit !== 0)
      extras.fuzz.push({ seed: first, kind: "crash_in_fuzz", reading: `exit ${p.exit}` });
    log("done  item fuzz: " + extras.fuzzSummary);
  };
}

function sweepTask() {
  return async () => {
    const dir = path.join(jobsDir, "build-sweep");
    mkdirSync(dir, { recursive: true });
    extras.sweep = [];
    for (const arm of ["stack", "compose"]) {
      const p = await runProcess(
        [
          "--headless",
          "--path",
          "sketches/core-loop",
          "--script",
          "res://tools/build_sweep.gd",
          "--",
          "--arm=" + arm,
          ...(arm === "compose"
            ? ["--seed=" + seedOf(opts.wave, 0), "--builds=" + (opts.quick ? 1000 : 10000)]
            : []),
        ],
        { logFile: path.join(dir, arm + ".txt") },
      );
      const problems = [...p.text.matchAll(/^build_sweep problem: (.*)$/gm)].map(
        (m) => `${arm}: ${m[1]}`,
      );
      extras.sweep.push(...problems);
      if (p.exit !== 0 && problems.length === 0)
        extras.sweep.push(`${arm} arm failed (exit ${p.exit}); see jobs/build-sweep/${arm}.txt`);
    }
    log(`done  build sweep: ${extras.sweep.length} problem(s)`);
  };
}

async function perfBench() {
  const dir = path.join(jobsDir, "perf-bench");
  mkdirSync(dir, { recursive: true });
  const out = path.join(dir, "s3.json");
  log("start perf bench s3 (alone, so contention does not count)");
  const p = await runProcess(
    [
      "--headless",
      "--path",
      "sketches/core-loop",
      "--script",
      "res://tools/perf_bench.gd",
      "--",
      "--scene=s3",
      "--out=" + out,
    ],
    { logFile: path.join(dir, "log.txt"), timeout: 15 * 60_000 },
  );
  const info = readJson(out);
  const frame = info?.stats?.frame_ms ?? info?.frame_ms;
  extras.perfBench =
    p.exit !== 0 || !frame
      ? { error: `exit ${p.exit}` }
      : { p99: frame.p99, max: frame.max ?? null, p50: frame.p50 };
  log("done  perf bench: " + JSON.stringify(extras.perfBench));
}

function placeholders() {
  const p = spawnSync(
    "node",
    [path.join(root, "scripts/placeholder-gate.mjs"), "--json", "--limit", "1000"],
    { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  let rows = [];
  try {
    rows = JSON.parse(p.stdout);
  } catch {
    rows = [];
  }
  const byKind = {};
  for (const r of rows) byKind[r.kind] = (byKind[r.kind] ?? 0) + (r.count ?? 1);
  extras.placeholders = { total: Object.values(byKind).reduce((a, b) => a + b, 0), byKind };
  log(`placeholders: ${extras.placeholders.total}`);
}

async function hitchTriage(results) {
  const { shared } = sharedHitches(results);
  const [r, list] = [...shared].sort((a, b) => b[1].length - a[1].length)[0] ?? [];
  if (!r) return;
  const ticks = Math.min(Math.max(...list.map((s) => s.tick)) + 90, 9000);
  const tally = {};
  for (const [name, extra] of [
    ["alone", []],
    ["noMix", ["--bot-no-mix=1"]],
  ]) {
    const dir = path.join(jobsDir, "hitch-" + name);
    const job = {
      ...r.job,
      args: [...r.job.args.filter((a) => !a.startsWith("--ticks=")), "--ticks=" + ticks, ...extra],
    };
    const state = path.join(dir, "state");
    for (const d of ["data", "config", "cache"])
      mkdirSync(path.join(state, d), { recursive: true });
    log(`hitch triage ${name}: ${r.job.id} to tick ${ticks}`);
    await runProcess(botArgs(job, path.join(dir, "out")), {
      env: {
        XDG_DATA_HOME: path.join(state, "data"),
        XDG_CONFIG_HOME: path.join(state, "config"),
        XDG_CACHE_HOME: path.join(state, "cache"),
      },
      logFile: path.join(dir, "log.txt"),
      timeout: 15 * 60_000,
    });
    const out = path.join(dir, "out");
    const h = hitches(
      readJson(path.join(out, `profile-${r.job.seed}.json`)),
      parseNdjson(read(path.join(out, `events-${r.job.seed}.ndjson`))),
    );
    tally[name] = list.filter((s) => h.spikes.some((x) => Math.abs(x.tick - s.tick) <= 2)).length;
  }
  extras.hitchTriage = {
    run: r.job.id,
    tested: list.length,
    alone: tally.alone,
    noMix: tally.noMix,
  };
  log(`hitch triage: ${JSON.stringify(extras.hitchTriage)} (over ${HITCH_MS} ms)`);
}

log(
  `red team wave ${opts.wave} on ${commit.slice(0, 10)}: ${jobs.length} bot runs, ${opts.slots} slots, out ${path.relative(root, outDir)}`,
);
const imp = await runProcess(
  ["--headless", "--path", "sketches/core-loop", "--editor", "--import"],
  { logFile: path.join(outDir, "import.txt"), timeout: 15 * 60_000 },
);
if (imp.exit !== 0) die("editor import failed; see " + path.join(outDir, "import.txt"));
if (opts.export) {
  log("start cloud export (export, headless boots)");
  const ex = spawnSync("node", [path.join(root, "scripts/cloud/export-headless.mjs")], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    timeout: 30 * 60_000,
  });
  writeFileSync(path.join(outDir, "export.txt"), (ex.stdout ?? "") + (ex.stderr ?? ""));
  if (ex.status !== 0)
    extras.exportFailure = (
      (ex.stderr ?? "").split("\n").find((l) => l.startsWith("cloud export:")) ??
      `exit ${ex.status}`
    ).slice(0, 200);
  log("done  cloud export: " + (extras.exportFailure ?? "PASS"));
}
placeholders();

const botTasks = jobs.map(botTask);
const results = [];
const tasks = [
  fuzzTask(),
  sweepTask(),
  ...botTasks.map((t) => async () => results.push(await t())),
];
await pool(tasks, opts.slots);
results.sort((a, b) => jobs.indexOf(a.job) - jobs.indexOf(b.job));
await hitchTriage(results);
if (!opts.quick) await perfBench();

const findings = grade(results, extras);
const minutes = Math.round((Date.now() - started) / 60000);
const page = renderMarkdown({
  wave: opts.sweep ? `${opts.wave} (sweep)` : opts.wave,
  commit,
  started: started.toISOString().slice(0, 16) + "Z",
  minutes,
  results,
  findings,
  extras,
});
writeFileSync(path.join(outDir, "findings.md"), page);
writeFileSync(
  path.join(outDir, "findings.json"),
  JSON.stringify(
    {
      wave: opts.wave,
      commit,
      started: started.toISOString(),
      minutes,
      quick: opts.quick,
      pilots: PILOTS,
      runs: results.map((r) => ({
        ...r.job,
        outcome: r.timedOut ? "timeout" : (r.row?.outcome ?? "crash"),
        stage: r.row?.stage_reached ?? null,
        game_seconds: r.row?.game_seconds ?? null,
        hits: (r.row?.stages ?? []).reduce((n, s) => n + (s.hits ?? 0), 0),
        exit: r.exit,
        piles: r.piles,
        hitches: r.perf,
      })),
      extras: { ...extras, fuzz: undefined, fuzzCount: extras.fuzz?.length ?? 0 },
      findings,
      carry: carryList(findings),
    },
    null,
    2,
  ),
);
log(`findings: ${path.relative(root, path.join(outDir, "findings.md"))}`);
console.log(page.split("\n").slice(0, 6).join("\n"));
