#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  COLUMNS,
  MAX_RUN_TIER,
  fairnessByCell,
  PILOTS,
  botArgs,
  buildTable,
  cellVerdict,
  describeDoc,
  bucketInfo,
  checkMerge,
  dedupeBy,
  defaultChallengeJobs,
  estimate,
  gradeRun,
  maxJobs,
  aggregate,
  columnTarget,
  settledMark,
  jobKey,
  playerReport,
  qaRows,
  renderPlayerReport,
  hashString,
  mergeLibraryIndexes,
  planHash,
  parseNdjson,
  pickBuilds,
  planCells,
  renderTable,
  shardJobs,
  wallStats,
} from "./lib.mjs";
import { pool, runProcess, stateEnv } from "./proc.mjs";
import { GODOT_VERSION, resolveGodotBinary } from "../godot-home.mjs";
import { checkImportStamp, REIMPORT_HINT } from "../import-stamp.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const godot = resolveGodotBinary({ requireExplicit: true });
const outRoot = path.join(root, "artifacts/local/challenge");
const KIND_TIMEOUT_MS = 40 * 60_000;

const opts = {
  library: null,
  buildLibrary: false,
  libSeeds: 4,
  libPilots: PILOTS,
  cells: ["boss", "warden", "park"],
  only: null,
  seeds: null,
  libShard: null,
  libraryMerge: null,
  wardenPersona: "skipper",
  tune: "",
  resume: false,
  allowMixed: false,
  bands: ["novice", "learner1", "learner5", "expert"],
  top: true,
  persona: "brawler",
  parkPersona: "skipper",
  jobs: defaultChallengeJobs(),
  label: null,
  shard: null,
  merge: null,
  dryRun: false,
  strict: false,
  earlyStop: false,
  staleImportOk: false,
};
for (const arg of process.argv.slice(2)) {
  const [k, v] = arg.replace(/^--/, "").split("=");
  if (k === "library")
    v === undefined ? (opts.buildLibrary = true) : (opts.library = path.resolve(v));
  else if (k === "lib-seeds") opts.libSeeds = Number(v);
  else if (k === "lib-pilots") opts.libPilots = v.split(",");
  else if (k === "cells") opts.cells = v.split(",");
  else if (k === "only") opts.only = v.split(",");
  else if (k === "seeds") opts.seeds = Number(v);
  else if (k === "bands") opts.bands = v.split(",");
  else if (k === "no-top") opts.top = false;
  else if (k === "lib-shard") opts.libShard = v;
  else if (k === "library-merge") opts.libraryMerge = v.split(",");
  else if (k === "warden-persona") opts.wardenPersona = v;
  else if (k === "persona") opts.persona = v;
  else if (k === "park-persona") opts.parkPersona = v;
  else if (k === "jobs") opts.jobs = Number(v);
  else if (k === "label") opts.label = v;
  else if (k === "shard") opts.shard = v;
  else if (k === "merge") opts.merge = v.split(",");
  else if (k === "tune") opts.tune = arg.startsWith("--tune=") ? arg.slice(7) : "";
  else if (k === "tune-unruled") opts.tuneUnruled = true;
  else if (k === "tier") {
    opts.tierText = v ?? "";
    opts.tier = Number(v);
  } else if (k === "resume") opts.resume = true;
  else if (k === "allow-mixed") opts.allowMixed = true;
  else if (k === "dry-run") opts.dryRun = true;
  else if (k === "strict") opts.strict = true;
  else if (k === "stale-import-ok") opts.staleImportOk = true;
  else if (k === "early-stop") opts.earlyStop = true;
  else die("unknown option " + arg);
}

function die(message) {
  console.error("challenge: " + message);
  process.exit(1);
}

const started = Date.now();
const log = (line) => console.log(`[${((Date.now() - started) / 60000).toFixed(1)}m] ${line}`);
const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
const read = (file) => (existsSync(file) ? readFileSync(file, "utf8") : "");

const jobCap = maxJobs();
if (!(opts.jobs >= 1 && opts.jobs <= jobCap))
  die(`--jobs takes 1 to ${jobCap} on this machine (one a core and 2 GiB each, at least 6)`);
for (const b of opts.bands)
  if (!COLUMNS.some((c) => c.id === b))
    die(`--bands: ${b} is not one of ${COLUMNS.map((c) => c.id).join(", ")}`);
const columns =
  opts.top && opts.bands.includes("expert") ? [...opts.bands, "expertTop"] : opts.bands;

if (opts.merge) {
  mergeRuns();
} else if (opts.libraryMerge) {
  mergeLibraries();
} else if (opts.buildLibrary) {
  await buildLibrary();
} else {
  await runTable();
}

function runFolder(d) {
  const p = path.resolve(d);
  return existsSync(p) && statSync(p).isDirectory() ? p : path.dirname(p);
}

function mergeRuns() {
  const dirs = opts.merge.map(runFolder);
  const metas = dirs.map((d) =>
    existsSync(path.join(d, "meta.json")) ? JSON.parse(read(path.join(d, "meta.json"))) : null,
  );
  const check = checkMerge(metas, { allowMixed: opts.allowMixed });
  if (check.errors.length) die("refusing to merge:\n  " + check.errors.join("\n  "));
  const runs = dedupeBy(
    dirs.flatMap((d) => parseNdjson(read(path.join(d, "runs.ndjson")))),
    "key",
  );
  const first = metas[0] ?? {};
  finish(runs, path.join(outRoot, opts.label ?? "merged-" + stamp), {
    label: opts.label ?? "merged",
    commit: first.commit,
    plan_hash: first.plan_hash,
    library: first.library,
    buckets: first.buckets,
    tune: first.tune,
    tune_unruled: first.tune_unruled,
    run_tier: first.run_tier,
    shards: check.shards,
    warnings: check.warnings,
  });
}

function needGodot() {
  if (!godot || !existsSync(godot))
    die(`set GODOT_BIN to the Godot ${GODOT_VERSION} editor (the cloud SessionStart hook does)`);
  const stamp = checkImportStamp(root);
  if (!stamp.ok && !opts.staleImportOk)
    die(`refusing to run on a stale import: ${stamp.reason}; ${REIMPORT_HINT}`);
  if (!stamp.ok)
    console.warn(`challenge: running on a stale import (--stale-import-ok): ${stamp.reason}`);
}

async function buildLibrary() {
  const label = opts.label ?? "lib-" + stamp;
  const dir = path.join(outRoot, "library", label);
  const jobs = [];
  for (const pilot of opts.libPilots) {
    if (!PILOTS.includes(pilot)) die("--lib-pilots: unknown pilot " + pilot);
    for (const policy of ["completionist", "skipper"])
      for (let i = 0; i < opts.libSeeds; i++) jobs.push({ pilot, policy, seed: 9000 + i });
  }
  jobs.splice(0, jobs.length, ...shardJobs(jobs, opts.libShard));
  if (opts.dryRun)
    return console.log(
      `library ${label}: ${jobs.length} full park runs (to stage 6), ${opts.jobs} parallel; about ${Math.ceil((jobs.length * 600) / opts.jobs / 60)} min at 10 min a run`,
    );
  needGodot();
  mkdirSync(dir, { recursive: true });
  const index = [];
  const tasks = jobs.map((job) => async () => {
    const name = `${job.pilot}-${job.policy}-${job.seed}`;
    const out = path.join(dir, "raw", name);
    mkdirSync(out, { recursive: true });
    log("start " + name);
    const p = await runProcess(
      godot,
      root,
      [
        "--headless",
        "--fixed-fps",
        "90",
        "--path",
        "sketches/core-loop",
        "--script",
        "res://tools/band_run.gd",
        "--",
        "--out=" + out,
        "--policy=" + job.policy,
        "--seeds=" + job.seed,
        "--pilot=" + job.pilot,
        "--table=park",
        "--gate=1",
        "--keep-entrances=1",
        "--until=6",
      ],
      {
        env: stateEnv(path.join(out, "state")),
        timeout: 3600_000,
        logFile: path.join(out, "log.txt"),
      },
    );
    const row = parseNdjson(read(path.join(out, "bots.ndjson"))).at(-1);
    let stages = 0;
    for (let n = 1; n <= 6; n++) {
      const src = path.join(out, `entrance-s${n}.json`);
      if (!existsSync(src)) continue;
      mkdirSync(path.join(dir, "s" + n), { recursive: true });
      const rel = `s${n}/${name}.json`;
      copyFileSync(src, path.join(dir, rel));
      index.push(describeDoc(rel, readFileSync(src, "utf8")));
      stages++;
    }
    log(
      `done  ${name}: ${p.timedOut ? "TIMEOUT" : (row?.outcome ?? "exit " + p.exit)}, ${stages} stage entrances, ${p.wallS.toFixed(0)} s wall${row ? ", " + row.game_seconds + " s game" : ""}`,
    );
    appendFileSync(
      path.join(dir, "runs.ndjson"),
      JSON.stringify({
        name,
        ...job,
        exit: p.exit,
        timedOut: p.timedOut,
        wallS: p.wallS,
        outcome: row?.outcome ?? null,
        stage_reached: row?.stage_reached ?? null,
        game_seconds: row?.game_seconds ?? null,
      }) + "\n",
    );
  });
  await pool(tasks, opts.jobs);
  index.sort((a, b) => a.stage - b.stage || a.file.localeCompare(b.file));
  writeFileSync(path.join(dir, "index.json"), JSON.stringify(index, null, 1) + "\n");
  const per = [1, 2, 3, 4, 5, 6]
    .map((n) => `s${n}:${index.filter((d) => d.stage === n).length}`)
    .join(" ");
  console.log(`library ${dir}: ${index.length} docs (${per})`);
}

function mergeLibraries() {
  if (!opts.label) die("--library-merge needs --label=<name>");
  const dir = path.join(outRoot, "library", opts.label);
  const shards = opts.libraryMerge.map((d) => ({
    dir: path.resolve(d),
    index: JSON.parse(readFileSync(path.join(path.resolve(d), "index.json"), "utf8")),
  }));
  const merged = mergeLibraryIndexes(shards);
  for (const d of merged) {
    mkdirSync(path.join(dir, path.dirname(d.file)), { recursive: true });
    copyFileSync(path.join(d.from, d.file), path.join(dir, d.file));
  }
  writeFileSync(
    path.join(dir, "index.json"),
    JSON.stringify(
      merged.map(({ from, ...d }) => d),
      null,
      1,
    ) + "\n",
  );
  console.log(`library ${dir}: ${merged.length} docs from ${shards.length} shards`);
}

function loadLibrary(dir) {
  const indexFile = path.join(dir, "index.json");
  if (!existsSync(indexFile)) die(`no index.json in ${dir}; build one with --library`);
  const docs = JSON.parse(readFileSync(indexFile, "utf8"));
  const builds = {};
  for (let stage = 1; stage <= 6; stage++) {
    const mine = docs
      .filter((d) => d.stage === stage)
      .map((d) => ({ ...d, file: path.join(dir, d.file) }));
    if (mine.length) {
      const { ordinary, top, ranked, overlap } = pickBuilds(mine);
      builds[stage] = { ordinary, top, ranked, overlap };
    }
  }
  return builds;
}

async function runTable() {
  const builds = opts.library ? loadLibrary(opts.library) : {};
  if (
    opts.tier !== undefined &&
    !(
      opts.tierText !== "" &&
      Number.isInteger(opts.tier) &&
      opts.tier >= 0 &&
      opts.tier <= MAX_RUN_TIER
    )
  )
    die(`--tier must be a whole number 0 to ${MAX_RUN_TIER}`);
  let jobs = planCells({
    tune: opts.tune,
    tuneUnruled: opts.tuneUnruled,
    tier: opts.tier,
    builds,
    cells: opts.cells,
    only: opts.only,
    seeds: opts.seeds,
    columns,
    persona: opts.persona,
    wardenPersona: opts.wardenPersona,
    parkPersona: opts.parkPersona,
  });
  jobs = shardJobs(jobs, opts.shard);
  const missing = jobs.filter((j) => j.missing);
  if (missing.length) {
    const stages = [...new Set(missing.map((j) => j.stage))].sort();
    die(
      `${missing.length} jobs need builds for stage(s) ${stages.join(", ")}; ${opts.library ? "the library has none there" : "pass --library=<dir>"}`,
    );
  }
  const est = estimate(jobs, opts.jobs);
  const byKind = Object.fromEntries(
    ["boss", "warden", "world", "clear"].map((k) => [k, jobs.filter((j) => j.kind === k).length]),
  );
  console.log(
    `${jobs.length} jobs (${Object.entries(byKind)
      .map(([k, n]) => `${k} ${n}`)
      .join(
        ", ",
      )}); estimated ${(est.wallSeconds / 3600).toFixed(1)} h wall at ${opts.jobs} parallel`,
  );
  if (opts.dryRun) return;
  needGodot();
  const label = opts.label ?? "run-" + stamp;
  const outDir = path.join(outRoot, label);
  const runsFile = path.join(outDir, "runs.ndjson");
  const commit = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
    encoding: "utf8",
  }).stdout.trim();
  const libraryLabel = opts.library ? path.basename(opts.library) : null;
  const libraryDigest = opts.library
    ? hashString(read(path.join(opts.library, "index.json")))
    : null;
  const plan = planHash({
    libraryLabel,
    libraryDigest,
    cells: opts.cells,
    only: opts.only,
    seeds: opts.seeds,
    columns,
    persona: opts.persona,
    wardenPersona: opts.wardenPersona,
    parkPersona: opts.parkPersona,
    tune: opts.tuneUnruled ? opts.tune + " [unruled]" : opts.tune,
    tier: opts.tier,
  });
  const meta = {
    label,
    shard: opts.shard,
    plan_hash: plan,
    commit,
    library: libraryLabel,
    tune: opts.tune,
    ...(opts.tuneUnruled ? { tune_unruled: true } : {}),
    ...(opts.tier ? { run_tier: opts.tier } : {}),
    buckets: bucketInfo(builds),
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
  const done = new Set(
    parseNdjson(read(runsFile))
      .filter((r) => !["error", "killed"].includes(r.grade?.result))
      .map((r) => r.key),
  );
  const keyOf = (job) => jobKey(job, { libraryLabel, plan, commit });
  const todo = jobs.filter((j) => !done.has(keyOf(j)));
  if (todo.length < jobs.length)
    log(`resume: ${jobs.length - todo.length} jobs already done on this commit`);

  async function play(job, attempt) {
    const dir = path.join(outDir, "jobs", job.id + (attempt > 1 ? "-rerun" : ""));
    const out = path.join(dir, "out");
    mkdirSync(out, { recursive: true });
    const p = await runProcess(godot, root, botArgs(job, out), {
      env: stateEnv(path.join(dir, "state")),
      timeout: KIND_TIMEOUT_MS,
      logFile: path.join(dir, "log.txt"),
    });
    const row = parseNdjson(read(path.join(out, "bots.ndjson"))).at(-1) ?? null;
    const qaFile = path.join(out, `qa-${job.seed}.ndjson`);
    return {
      p,
      row,
      qa: existsSync(qaFile) ? qaRows(read(qaFile)) : null,
      ok: !p.timedOut && p.exit === 0 && row !== null,
    };
  }

  const record = (job, { p, row, qa }, rerun) => {
    const grade = row
      ? gradeRun(job.kind, row, job)
      : {
          result: p.timedOut ? "killed" : "error",
          why: p.timedOut ? "killed at the wall timeout" : "exit " + p.exit + ", no record",
        };
    const line = {
      ...job,
      key: keyOf(job),
      commit,
      plan_hash: plan,
      entrance:
        job.entrance && opts.library ? path.relative(opts.library, job.entrance) : job.entrance,
      row,
      grade,
      exit: p.exit,
      timedOut: p.timedOut,
      wallS: Math.round(p.wallS * 10) / 10,
      rerun,
      ...(qa ? { qa } : {}),
    };
    appendFileSync(runsFile, JSON.stringify(line) + "\n");
    addFinal(job, grade);
    log(
      `done  ${job.id}: ${grade.result}${row ? " (" + row.outcome + ", " + row.game_seconds + " s game)" : ""}, ${p.wallS.toFixed(0)} s wall`,
    );
  };

  const colKey = (job) => job.cell + "|" + job.column;
  const planned = new Map();
  for (const job of jobs) planned.set(colKey(job), (planned.get(colKey(job)) ?? 0) + 1);
  const finals = new Map();
  const addFinal = (job, grade) =>
    finals.set(colKey(job), [...(finals.get(colKey(job)) ?? []), grade]);
  for (const r of dedupeBy(parseNdjson(read(runsFile)), "id"))
    if (done.has(r.key)) addFinal(r, r.grade);
  const stopped = new Map();
  const settled = (job) => {
    if (!opts.earlyStop) return false;
    if (stopped.has(colKey(job))) return true;
    const grades = finals.get(colKey(job)) ?? [];
    const learner = job.kind === "boss" && (job.column === "learner1" || job.column === "learner5");
    const tellOpen =
      learner &&
      ["learner1", "learner5"].every(
        (c) => aggregate(finals.get(job.cell + "|" + c) ?? []).earlyDeaths === 0,
      );
    const mark = settledMark({
      grades,
      left: planned.get(colKey(job)) - grades.length,
      target: columnTarget(job.cell, job.kind, job.column),
      tellOpen,
    });
    if (mark === null) return false;
    stopped.set(colKey(job), {
      cell: job.cell,
      column: job.column,
      mark,
      planned: planned.get(colKey(job)),
    });
    log(
      `early stop ${job.cell} ${job.column}: ${grades.length} of ${planned.get(colKey(job))} seeds are in and the rest cannot change ${mark ? "✓" : "✗"}`,
    );
    return true;
  };

  const failed = [];
  await pool(
    todo.map((job) => async () => {
      if (settled(job)) return;
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
  const runs = dedupeBy(parseNdjson(read(runsFile)), "id");
  const earlyStop = [...stopped.values()].map((stop) => ({
    ...stop,
    ran: runs.filter((r) => r.cell === stop.cell && r.column === stop.column).length,
  }));
  finish(runs, outDir, {
    label,
    commit,
    plan_hash: plan,
    library: libraryLabel,
    buckets: meta.buckets,
    tune: meta.tune,
    tune_unruled: meta.tune_unruled,
    run_tier: meta.run_tier,
    shards: opts.shard ? [opts.shard] : null,
    ...(opts.earlyStop ? { early_stop: earlyStop } : {}),
  });
}

function renderEarlyStop(stops) {
  if (!stops) return "";
  if (!stops.length)
    return "\nEarly stop was on (ruling dg); no column stopped, so every planned seed ran.\n";
  const lines = stops.map(
    (s) =>
      `- ${s.cell} ${s.column}: ${s.ran} of ${s.planned} seeds ran; the seeds left could not change its ${s.mark ? "✓" : "✗"}`,
  );
  return ["", "## Stopped early (ruling dg)", "", ...lines, ""].join("\n") + "\n";
}

function finish(runs, outDir, meta) {
  const commits = [...new Set(runs.map((r) => r.commit).filter(Boolean))];
  if (commits.length > 1 && !opts.allowMixed)
    die(
      `the rows carry ${commits.length} commits (${commits.map((c) => c.slice(0, 8)).join(", ")}); rerun on one commit or pass --allow-mixed`,
    );
  mkdirSync(outDir, { recursive: true });
  const table = buildTable(runs, meta.buckets ?? {});
  const timing = wallStats(runs);
  const report = playerReport(runs);
  const fairness = fairnessByCell(runs);
  const md =
    renderTable(table, { ...meta, fairness, when: new Date().toISOString().slice(0, 16) + "Z" }) +
    renderEarlyStop(meta.early_stop) +
    "\n" +
    renderPlayerReport(report);
  writeFileSync(path.join(outDir, "table.md"), md);
  writeFileSync(
    path.join(outDir, "table.json"),
    JSON.stringify(
      { ...meta, runs: runs.length, timing, table, fairness, player_report: report },
      null,
      1,
    ) + "\n",
  );
  console.log(md);
  console.log("Wall medians per job (re-estimate SECONDS_PER_JOB in lib.mjs from these):");
  for (const [k, t] of Object.entries(timing))
    console.log(
      `  ${k}: ${t.jobs} jobs, median ${t.medianWallS?.toFixed(0)} s wall (max ${t.maxWallS.toFixed(0)}), median ${t.medianGameS?.toFixed(0)} s game`,
    );
  console.log(`table written to ${path.join(outDir, "table.md")}`);
  if (opts.strict && table.some((c) => cellVerdict(c) === "fail")) process.exit(1);
}
