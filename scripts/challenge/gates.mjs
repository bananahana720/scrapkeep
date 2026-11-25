#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { dedupeBy, hashString, maxJobs, parseNdjson, shardJobs } from "./lib.mjs";
import {
  ARMS,
  GATE_ARMS,
  RUNS_PER_SEED,
  SEEDS,
  STAGES,
  STAGE_LIMIT_S,
  driverAudioReads,
  evaluateGates,
  gateBotArgs,
  groupByArm,
  planGateJobs,
  renderGates,
  summarizeRun,
} from "./gates-lib.mjs";
import { pool, runProcess, stateEnv } from "./proc.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const godot = process.env.GODOT_BIN;
const outRoot = path.join(root, "artifacts/local/challenge");
const KIND_TIMEOUT_MS = 40 * 60_000;
const DRIVER = path.join(root, "sketches/core-loop/tools/bot_driver.gd");

const opts = {
  gates: ["1", "2", "4"],
  only: null,
  stages: STAGES,
  seeds: SEEDS,
  runs: RUNS_PER_SEED,
  jobs: 4,
  label: null,
  shard: null,
  merge: null,
  resume: false,
  dryRun: false,
  strict: false,
  tune: "",
  stageLimit: STAGE_LIMIT_S,
};
for (const arg of process.argv.slice(2)) {
  const [k, v] = arg.replace(/^--/, "").split("=");
  if (k === "gates") opts.gates = v.split(",");
  else if (k === "only") opts.only = v.split(",");
  else if (k === "stages") opts.stages = v.split(",").map(Number);
  else if (k === "seeds") opts.seeds = v.split(",").map(Number);
  else if (k === "runs") opts.runs = Number(v);
  else if (k === "jobs") opts.jobs = Number(v);
  else if (k === "label") opts.label = v;
  else if (k === "shard") opts.shard = v;
  else if (k === "merge") opts.merge = v.split(",");
  else if (k === "tune") opts.tune = arg.slice(7);
  else if (k === "stage-limit") opts.stageLimit = Number(v);
  else if (k === "resume") opts.resume = true;
  else if (k === "dry-run") opts.dryRun = true;
  else if (k === "strict") opts.strict = true;
  else die("unknown option " + arg);
}

function die(message) {
  console.error("gates: " + message);
  process.exit(1);
}

const started = Date.now();
const log = (line) => console.log(`[${((Date.now() - started) / 60000).toFixed(1)}m] ${line}`);
const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
const read = (file) => (existsSync(file) ? readFileSync(file, "utf8") : "");

const jobCap = maxJobs();
if (!(opts.jobs >= 1 && opts.jobs <= jobCap)) die(`--jobs takes 1 to ${jobCap} on this machine`);
if (!(opts.stageLimit >= 150))
  die("--stage-limit takes 150 s or more (contact plus the 120 s window)");
for (const g of opts.gates)
  if (!["1", "2", "4"].includes(g)) die(`--gates: ${g} is not 1, 2 or 4 (gate 3 is card G-B)`);

function armsFor() {
  if (opts.only) {
    for (const a of opts.only)
      if (!ARMS[a]) die(`--only: ${a} is not one of ${Object.keys(ARMS).join(", ")}`);
    return opts.only;
  }
  return Object.keys(ARMS).filter((a) =>
    ARMS[a].gates.some((g) => opts.gates.includes(g.slice(1))),
  );
}

if (opts.merge) {
  const dirs = opts.merge.map((d) => path.resolve(d));
  const runs = dedupeBy(
    dirs.flatMap((d) => parseNdjson(read(path.join(d, "runs.ndjson")))),
    "id",
  );
  const metas = dirs.map((d) =>
    existsSync(path.join(d, "meta.json")) ? JSON.parse(read(path.join(d, "meta.json"))) : {},
  );
  const plans = new Set(metas.map((m) => m.plan_hash));
  if (plans.size > 1) die("refusing to merge folders of different plans");
  finish(runs, path.join(outRoot, opts.label ?? "gates-merged-" + stamp), {
    ...metas[0],
    label: opts.label ?? "merged",
  });
} else {
  await runGates();
}

async function runGates() {
  const arms = armsFor();
  let jobs = planGateJobs({
    arms,
    stages: opts.stages,
    seeds: opts.seeds,
    runs: opts.runs,
    tune: opts.tune,
    stageLimit: opts.stageLimit,
  });
  jobs = shardJobs(jobs, opts.shard);
  console.log(
    `${jobs.length} jobs (${arms.map((a) => `${a} ${jobs.filter((j) => j.arm === a).length}`).join(", ")}) at --fixed-fps 90, ${opts.jobs} parallel`,
  );
  if (opts.dryRun) return;
  if (!godot || !existsSync(godot)) die("set GODOT_BIN to the Godot 4.7.2 editor");
  if (!existsSync(path.join(root, "sketches/core-loop/.godot/global_script_class_cache.cfg")))
    die(
      "this worktree was never imported; run $GODOT_BIN --headless --path sketches/core-loop --import first",
    );
  const label = opts.label ?? "gates-" + stamp;
  const outDir = path.join(outRoot, label);
  const runsFile = path.join(outDir, "runs.ndjson");
  const commit = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
    encoding: "utf8",
  }).stdout.trim();
  const plan = hashString(
    JSON.stringify([arms, opts.stages, opts.seeds, opts.runs, opts.tune, opts.stageLimit]),
  );
  const meta = {
    label,
    shard: opts.shard,
    plan_hash: plan,
    commit,
    arms,
    stages: opts.stages,
    seeds: opts.seeds,
    runs: opts.runs,
    tune: opts.tune,
    stage_limit: opts.stageLimit,
    jobs: jobs.length,
  };
  if (existsSync(runsFile) || existsSync(path.join(outDir, "meta.json"))) {
    if (!opts.resume)
      die(
        `label ${label} already has results; pick a new --label or pass --resume to continue the same plan`,
      );
    const old = existsSync(path.join(outDir, "meta.json"))
      ? JSON.parse(read(path.join(outDir, "meta.json")))
      : null;
    if (!old || old.plan_hash !== plan || old.shard !== opts.shard)
      die(`--resume: ${label} was a different plan or shard`);
  } else if (opts.resume) die(`--resume: ${label} has nothing to resume`);
  mkdirSync(path.join(outDir, "jobs"), { recursive: true });
  writeFileSync(path.join(outDir, "meta.json"), JSON.stringify(meta, null, 1) + "\n");

  const keyOf = (job) => `${plan}:${commit.slice(0, 8)}:${job.id}`;
  const done = new Set(
    parseNdjson(read(runsFile))
      .filter((r) => r.row && !r.timedOut)
      .map((r) => r.key),
  );
  const todo = jobs.filter((j) => !done.has(keyOf(j)));
  if (todo.length < jobs.length)
    log(`resume: ${jobs.length - todo.length} jobs already done on this commit`);

  async function play(job, attempt) {
    const dir = path.join(outDir, "jobs", job.id + (attempt > 1 ? "-rerun" : ""));
    const out = path.join(dir, "out");
    mkdirSync(out, { recursive: true });
    const args = gateBotArgs(job, out);
    writeFileSync(
      path.join(dir, "cmd.txt"),
      `GODOT_BIN=${godot}\ncd ${root}\n${godot} ${args.join(" ")}\n`,
    );
    const p = await runProcess(godot, root, args, {
      env: stateEnv(path.join(dir, "state")),
      timeout: KIND_TIMEOUT_MS,
      logFile: path.join(dir, "log.txt"),
    });
    const row = parseNdjson(read(path.join(out, "bots.ndjson"))).at(-1) ?? null;
    return { p, row, ok: !p.timedOut && p.exit === 0 && row !== null };
  }
  const record = (job, { p, row }, rerun) => {
    const line = {
      ...job,
      key: keyOf(job),
      commit,
      plan_hash: plan,
      row,
      exit: p.exit,
      timedOut: p.timedOut,
      wallS: Math.round(p.wallS * 10) / 10,
      rerun,
    };
    appendFileSync(runsFile, JSON.stringify(line) + "\n");
    log(
      `done  ${job.id}: ${row ? `${row.outcome}, ${row.game_seconds} s game` : "no record (exit " + p.exit + ")"}, ${p.wallS.toFixed(0)} s wall`,
    );
  };
  const failed = [];
  await pool(
    todo.map((job) => async () => {
      log("start " + job.id);
      const r = await play(job, 1);
      if (r.ok) record(job, r, false);
      else failed.push({ job, first: r });
    }),
    opts.jobs,
  );
  for (const { job, first } of failed) {
    log(
      `rerun ${job.id} alone (first try: ${first.p.timedOut ? "timeout" : "exit " + first.p.exit})`,
    );
    record(job, await play(job, 2), true);
  }
  finish(dedupeBy(parseNdjson(read(runsFile)), "id"), outDir, meta);
}

function finish(runs, outDir, meta) {
  mkdirSync(outDir, { recursive: true });
  const jobById = (r) => ({ id: r.id, arm: r.arm, stage: r.stage, seed: r.seed, rep: r.rep });
  const summaries = runs.map((r) => summarizeRun(r.row, jobById(r)));
  const byArm = groupByArm(summaries);
  const audio = driverAudioReads(readFileSync(DRIVER, "utf8"));
  const ev = evaluateGates(byArm, {
    auditFree: audio.length === 0,
    stages: meta.stages ?? STAGES,
    seeds: meta.seeds ?? SEEDS,
    runs: meta.runs ?? RUNS_PER_SEED,
  });
  const voidByArm = Object.fromEntries(
    Object.entries(byArm).map(([a, s]) => [
      a,
      s.filter((x) => x.void).map((x) => ({ id: x.id, why: x.void })),
    ]),
  );
  const md =
    renderGates(ev, {
      when: new Date().toISOString().slice(0, 16) + "Z",
      commit: meta.commit,
      voidByArm,
    }) +
    (audio.length
      ? "\nAudio reads found in the driver:\n" +
        audio.map((h) => `- line ${h.line}: ${h.text}`).join("\n") +
        "\n"
      : "");
  writeFileSync(path.join(outDir, "gates.md"), md);
  writeFileSync(
    path.join(outDir, "gates.json"),
    JSON.stringify({ ...meta, runs: runs.length, evaluation: ev, summaries }, null, 1) + "\n",
  );
  console.log(md);
  console.log(`gates written to ${path.join(outDir, "gates.md")}`);
  const bad = opts.gates
    .map((g) => ev["gate" + g])
    .filter((g) => !g.parked)
    .some((g) => g.broken || g.real.verdict !== "PASS");
  if (opts.strict && bad) process.exit(1);
}
