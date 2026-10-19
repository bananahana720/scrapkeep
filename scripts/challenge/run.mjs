#!/usr/bin/env node
// node scripts/challenge/run.mjs --library [--lib-seeds=4] [--lib-pilots=a,b] [--label=<name>]
// node scripts/challenge/run.mjs --library=<dir> [--cells=boss,warden,world] [--only=brindle,w1,world1]
//     [--seeds=16] [--bands=novice,learner1,learner5,expert] [--no-top] [--persona=brawler] [--park-persona=skipper]
//     [--jobs=4] [--label=<name>] [--shard=i/n] [--dry-run] [--strict]
// node scripts/challenge/run.mjs --merge=<dir,dir>
//
// The band table (scripts/challenge/README.md): plays each boss, Warden and park with the Novice,
// Learner and Expert bot bands from saved builds, and grades the win rates against the base-tier
// targets. Output: artifacts/local/challenge/<label>/{runs.ndjson,table.md,table.json,jobs/}.
// Exit 0 when the harness ran, whatever the table says; --strict exits 1 on any ✗.
import { spawn, spawnSync } from "node:child_process";
import { appendFileSync, copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { COLUMNS, PILOTS, botArgs, buildTable, cellVerdict, describeDoc, estimate, gradeRun, parseNdjson, pickBuilds, planCells, renderTable, shardJobs } from "./lib.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const godot = process.env.GODOT_BIN;
const outRoot = path.join(root, "artifacts/local/challenge");

const opts = {
  library: null, buildLibrary: false, libSeeds: 4, libPilots: PILOTS, cells: ["boss", "warden", "world"], only: null, seeds: 16,
  bands: ["novice", "learner1", "learner5", "expert"], top: true, persona: "brawler", parkPersona: "skipper", jobs: 4, label: null,
  shard: null, merge: null, dryRun: false, strict: false,
};
for (const arg of process.argv.slice(2)) {
  const [k, v] = arg.replace(/^--/, "").split("=");
  if (k === "library") (v === undefined ? (opts.buildLibrary = true) : (opts.library = path.resolve(v)));
  else if (k === "lib-seeds") opts.libSeeds = Number(v);
  else if (k === "lib-pilots") opts.libPilots = v.split(",");
  else if (k === "cells") opts.cells = v.split(",");
  else if (k === "only") opts.only = v.split(",");
  else if (k === "seeds") opts.seeds = Number(v);
  else if (k === "bands") opts.bands = v.split(",");
  else if (k === "no-top") opts.top = false;
  else if (k === "persona") opts.persona = v;
  else if (k === "park-persona") opts.parkPersona = v;
  else if (k === "jobs") opts.jobs = Number(v);
  else if (k === "label") opts.label = v;
  else if (k === "shard") opts.shard = v;
  else if (k === "merge") opts.merge = v.split(",");
  else if (k === "dry-run") opts.dryRun = true;
  else if (k === "strict") opts.strict = true;
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

if (opts.jobs < 1 || opts.jobs > 6) die("--jobs takes 1 to 6 (the box has 4 vCPU; band sweeps can run out of memory)");
for (const b of opts.bands) if (!COLUMNS.some((c) => c.id === b)) die(`--bands: ${b} is not one of ${COLUMNS.map((c) => c.id).join(", ")}`);
const columns = opts.top && opts.bands.includes("expert") ? [...opts.bands, "expertTop"] : opts.bands;

if (opts.merge) {
  const runs = opts.merge.flatMap((d) => parseNdjson(read(statSyncDir(d))));
  finish(dedupe(runs), path.join(outRoot, opts.label ?? "merged-" + stamp), { label: opts.label ?? "merged" });
} else if (opts.buildLibrary) {
  await buildLibrary();
} else {
  await runTable();
}

function statSyncDir(d) {
  const p = path.resolve(d);
  return existsSync(p) && statSync(p).isDirectory() ? path.join(p, "runs.ndjson") : p;
}

function dedupe(runs) {
  const byId = new Map();
  for (const r of runs) byId.set(r.id, r);
  return [...byId.values()];
}

function needGodot() {
  if (!godot || !existsSync(godot)) die("set GODOT_BIN to the Godot 4.7.2 editor (the cloud SessionStart hook does)");
}

function runProcess(args, { env, timeout, logFile }) {
  return new Promise((resolve) => {
    const t0 = Date.now();
    const child = spawn(godot, args, { cwd: root, env: { ...process.env, ...env } });
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
      resolve({ exit: code ?? (signal ? 128 : 1), signal, timedOut, text, wallS: (Date.now() - t0) / 1000 });
    });
  });
}

async function pool(tasks, slots) {
  const results = new Array(tasks.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(slots, tasks.length) }, async () => {
    while (next < tasks.length) {
      const i = next++;
      results[i] = await tasks[i]();
    }
  }));
  return results;
}

function stateEnv(dir) {
  for (const d of ["data", "config", "cache"]) mkdirSync(path.join(dir, d), { recursive: true });
  return { XDG_DATA_HOME: path.join(dir, "data"), XDG_CONFIG_HOME: path.join(dir, "config"), XDG_CACHE_HOME: path.join(dir, "cache") };
}

// --- the build library ----------------------------------------------------------------------

async function buildLibrary() {
  needGodot();
  const label = opts.label ?? "lib-" + stamp;
  const dir = path.join(outRoot, "library", label);
  const jobs = [];
  for (const pilot of opts.libPilots) {
    if (!PILOTS.includes(pilot)) die("--lib-pilots: unknown pilot " + pilot);
    for (const policy of ["completionist", "skipper"]) for (let i = 0; i < opts.libSeeds; i++) jobs.push({ pilot, policy, seed: 9000 + i });
  }
  if (opts.dryRun) return console.log(`library ${label}: ${jobs.length} full park runs (to stage 6), 4 parallel; about ${Math.ceil((jobs.length * 600) / opts.jobs / 60)} min at 10 min a run`);
  mkdirSync(dir, { recursive: true });
  const index = [];
  const tasks = jobs.map((job) => async () => {
    const name = `${job.pilot}-${job.policy}-${job.seed}`;
    const out = path.join(dir, "raw", name);
    mkdirSync(out, { recursive: true });
    log("start " + name);
    const p = await runProcess([
      "--headless", "--fixed-fps", "90", "--path", "sketches/core-loop", "--script", "res://tools/band_run.gd", "--",
      "--out=" + out, "--policy=" + job.policy, "--seeds=" + job.seed, "--pilot=" + job.pilot, "--table=park", "--gate=1", "--keep-entrances=1", "--until=6",
    ], { env: stateEnv(path.join(out, "state")), timeout: 3600_000, logFile: path.join(out, "log.txt") });
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
    log(`done  ${name}: ${p.timedOut ? "TIMEOUT" : row?.outcome ?? "exit " + p.exit}, ${stages} stage entrances, ${p.wallS.toFixed(0)} s wall${row ? ", " + row.game_seconds + " s game" : ""}`);
    appendFileSync(path.join(dir, "runs.ndjson"), JSON.stringify({ name, ...job, exit: p.exit, timedOut: p.timedOut, wallS: p.wallS, outcome: row?.outcome ?? null, stage_reached: row?.stage_reached ?? null, game_seconds: row?.game_seconds ?? null }) + "\n");
  });
  await pool(tasks, opts.jobs);
  index.sort((a, b) => a.stage - b.stage || a.file.localeCompare(b.file));
  writeFileSync(path.join(dir, "index.json"), JSON.stringify(index, null, 1) + "\n");
  const per = [1, 2, 3, 4, 5, 6].map((n) => `s${n}:${index.filter((d) => d.stage === n).length}`).join(" ");
  console.log(`library ${dir}: ${index.length} docs (${per})`);
}

function loadLibrary(dir) {
  const indexFile = path.join(dir, "index.json");
  if (!existsSync(indexFile)) die(`no index.json in ${dir}; build one with --library`);
  const docs = JSON.parse(readFileSync(indexFile, "utf8"));
  const builds = {};
  for (let stage = 1; stage <= 6; stage++) {
    const mine = docs.filter((d) => d.stage === stage).map((d) => ({ ...d, file: path.join(dir, d.file) }));
    if (mine.length) {
      const { ordinary, top } = pickBuilds(mine);
      builds[stage] = { ordinary, top };
    }
  }
  return builds;
}

// --- the table ------------------------------------------------------------------------------

const KIND_TIMEOUT_MS = 40 * 60_000;

async function runTable() {
  const builds = opts.library ? loadLibrary(opts.library) : {};
  let jobs = planCells({ builds, cells: opts.cells, only: opts.only, seeds: opts.seeds, columns, persona: opts.persona, parkPersona: opts.parkPersona });
  jobs = shardJobs(jobs, opts.shard);
  const missing = jobs.filter((j) => j.missing);
  if (missing.length) {
    const stages = [...new Set(missing.map((j) => j.stage))].sort();
    die(`${missing.length} jobs need builds for stage(s) ${stages.join(", ")}; ${opts.library ? "the library has none there" : "pass --library=<dir>"}`);
  }
  const est = estimate(jobs, opts.jobs);
  const byKind = Object.fromEntries(["boss", "warden", "world"].map((k) => [k, jobs.filter((j) => j.kind === k).length]));
  console.log(`${jobs.length} jobs (${Object.entries(byKind).map(([k, n]) => `${k} ${n}`).join(", ")}); estimated ${(est.wallSeconds / 3600).toFixed(1)} h wall at ${opts.jobs} parallel`);
  if (opts.dryRun) return;
  needGodot();
  const label = opts.label ?? "run-" + stamp;
  const outDir = path.join(outRoot, label);
  mkdirSync(path.join(outDir, "jobs"), { recursive: true });
  const runsFile = path.join(outDir, "runs.ndjson");
  const commit = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" }).stdout.trim();

  async function play(job, attempt) {
    const dir = path.join(outDir, "jobs", job.id + (attempt > 1 ? "-rerun" : ""));
    const out = path.join(dir, "out");
    mkdirSync(out, { recursive: true });
    const p = await runProcess(botArgs(job, out), { env: stateEnv(path.join(dir, "state")), timeout: KIND_TIMEOUT_MS, logFile: path.join(dir, "log.txt") });
    const row = parseNdjson(read(path.join(out, "bots.ndjson"))).at(-1) ?? null;
    return { p, row, ok: !p.timedOut && p.exit === 0 && row !== null };
  }

  const record = (job, { p, row }, rerun) => {
    const grade = row ? gradeRun(job.kind, row, job) : { result: p.timedOut ? "timeout" : "error", why: p.timedOut ? "killed at the wall timeout" : "exit " + p.exit + ", no record" };
    const line = { ...job, row, grade, exit: p.exit, timedOut: p.timedOut, wallS: Math.round(p.wallS * 10) / 10, rerun };
    appendFileSync(runsFile, JSON.stringify(line) + "\n");
    log(`done  ${job.id}: ${grade.result}${row ? " (" + row.outcome + ", " + row.game_seconds + " s game)" : ""}, ${p.wallS.toFixed(0)} s wall`);
  };

  const failed = [];
  await pool(jobs.map((job) => async () => {
    log("start " + job.id);
    const r = await play(job, 1);
    if (r.ok) record(job, r, false);
    else failed.push({ job, first: r });
  }), opts.jobs);
  // A killed or timed-out job is rerun once alone (band sweeps can run out of memory) before it counts.
  for (const { job, first } of failed) {
    log(`rerun ${job.id} alone (first try: ${first.p.timedOut ? "timeout" : "exit " + first.p.exit})`);
    record(job, await play(job, 2), true);
  }
  finish(parseNdjson(read(runsFile)), outDir, { label, commit });
}

function finish(runs, outDir, meta) {
  mkdirSync(outDir, { recursive: true });
  const table = buildTable(runs);
  const md = renderTable(table, { ...meta, when: new Date().toISOString().slice(0, 16) + "Z" });
  writeFileSync(path.join(outDir, "table.md"), md);
  writeFileSync(path.join(outDir, "table.json"), JSON.stringify({ ...meta, runs: runs.length, table }, null, 1) + "\n");
  console.log(md);
  console.log(`table written to ${path.join(outDir, "table.md")}`);
  if (opts.strict && table.some((c) => cellVerdict(c) === "fail")) process.exit(1);
}
