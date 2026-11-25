#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, appendFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { dedupeBy, parseNdjson, shardJobs } from "./lib.mjs";
import { gateBotArgs, planGateJobs, summarizeRun } from "./gates-lib.mjs";
import { pool, runProcess, stateEnv } from "./proc.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outRoot = path.join(root, "artifacts/local/pack-pressure");
const TIMEOUT_MS = 45 * 60_000;

const opts = {
  variants: ["base"],
  seeds: [1, 2, 3, 4, 5],
  botSeeds: [1, 2, 3, 4],
  exploreBy: 900,
  jobs: 4,
  label: null,
  shard: null,
  resume: false,
  dryRun: false,
  report: null,
  out: null,
};
for (const arg of process.argv.slice(2)) {
  const [k, ...rest] = arg.replace(/^--/, "").split("=");
  const v = rest.join("=");
  if (k === "variants") opts.variants = v.split(",");
  else if (k === "seeds") opts.seeds = v.split(",").map(Number);
  else if (k === "bot-seeds") opts.botSeeds = v.split(",").map(Number);
  else if (k === "jobs") opts.jobs = Number(v);
  else if (k === "explore-by") opts.exploreBy = Number(v);
  else if (k === "label") opts.label = v;
  else if (k === "shard") opts.shard = v;
  else if (k === "report") opts.report = v.split(",");
  else if (k === "out") opts.out = v;
  else if (k === "resume") opts.resume = true;
  else if (k === "dry-run") opts.dryRun = true;
  else {
    console.error("pack-pressure: unknown option " + arg);
    process.exit(1);
  }
}

const read = (f) => (existsSync(f) ? readFileSync(f, "utf8") : "");
const median = (xs) => {
  const s = xs.filter((x) => x != null && Number.isFinite(x)).sort((a, b) => a - b);
  if (!s.length) return null;
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const flag = (variant) =>
  variant === "base"
    ? []
    : variant.includes("=")
      ? ["--tune=" + variant]
      : ["--pack-pressure=" + variant];
const slug = (variant) => variant.replace(/[^A-Za-z0-9-]+/g, "_");

export function planJobs(variants, seeds, botSeeds) {
  const jobs = [];
  for (const variant of variants) {
    for (const g of planGateJobs({ arms: ["orbit"], stages: [1, 2], seeds, runs: 1 })) {
      jobs.push({
        id: `${slug(variant)}-${g.id}`,
        variant,
        kind: "orbit",
        stage: g.stage,
        seed: g.seed,
        gate: g,
      });
    }
    for (const policy of ["skipper", "completionist"]) {
      for (const seed of botSeeds) {
        jobs.push({ id: `${slug(variant)}-${policy}-seed${seed}`, variant, kind: policy, seed });
      }
    }
  }
  return jobs;
}

function argsFor(job, out) {
  if (job.kind === "orbit") return [...gateBotArgs(job.gate, out), ...flag(job.variant)];
  const extra = job.kind === "completionist" ? ["--explore-by=" + opts.exploreBy] : [];
  return [
    "--headless",
    "--fixed-fps",
    "90",
    "--path",
    "sketches/core-loop",
    "--script",
    "res://tools/bot_run.gd",
    "--",
    "--out=" + out,
    "--policy=" + job.kind,
    "--seeds=" + job.seed,
    "--table=park",
    "--stages=2",
    "--gate=1",
    "--panel-log=1",
    ...extra,
    ...flag(job.variant),
  ];
}

const main = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (main && opts.report) report(opts.report);
else if (main) await run();

async function run() {
  const jobs = shardJobs(planJobs(opts.variants, opts.seeds, opts.botSeeds), opts.shard);
  console.log(`${jobs.length} jobs over ${opts.variants.join(", ")}, ${opts.jobs} parallel`);
  if (opts.dryRun) return;
  const godot = process.env.GODOT_BIN;
  if (!godot || !existsSync(godot)) throw new Error("set GODOT_BIN to the Godot 4.7.2 editor");
  const label =
    opts.label ?? "pp-" + new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const dir = path.join(outRoot, label);
  const runsFile = path.join(dir, "runs.ndjson");
  if (existsSync(runsFile) && !opts.resume)
    throw new Error(`${label} has results; pass --resume or a new --label`);
  mkdirSync(path.join(dir, "jobs"), { recursive: true });
  writeFileSync(
    path.join(dir, "meta.json"),
    JSON.stringify(
      {
        label,
        shard: opts.shard,
        variants: opts.variants,
        seeds: opts.seeds,
        botSeeds: opts.botSeeds,
      },
      null,
      1,
    ) + "\n",
  );
  const done = new Set(
    parseNdjson(read(runsFile))
      .filter((r) => r.row)
      .map((r) => r.id),
  );
  const t0 = Date.now();
  await pool(
    jobs
      .filter((j) => !done.has(j.id))
      .map((job) => async () => {
        const jd = path.join(dir, "jobs", job.id);
        const out = path.join(jd, "out");
        mkdirSync(out, { recursive: true });
        const args = argsFor(job, out);
        writeFileSync(path.join(jd, "cmd.txt"), `${godot} ${args.join(" ")}\n`);
        const p = await runProcess(godot, root, args, {
          env: stateEnv(path.join(jd, "state")),
          timeout: TIMEOUT_MS,
          logFile: path.join(jd, "log.txt"),
        });
        const row = parseNdjson(read(path.join(out, "bots.ndjson"))).at(-1) ?? null;
        const { gate, ...rest } = job;
        appendFileSync(
          runsFile,
          JSON.stringify({
            ...rest,
            row,
            exit: p.exit,
            timedOut: p.timedOut,
            wallS: Math.round(p.wallS),
          }) + "\n",
        );
        console.log(
          `[${((Date.now() - t0) / 60000).toFixed(1)}m] ${job.id}: ${row ? row.outcome + ", " + row.game_seconds + " s" : "no record"}`,
        );
      }),
    opts.jobs,
  );
}

export function summarize(rows) {
  const orbit = rows
    .filter((r) => r.kind === "orbit")
    .map((r) => ({
      ...summarizeRun(r.row, { ...r, arm: "orbit" }),
      pressure: r.row?.pressure ?? null,
    }));
  const byStage = {};
  for (const stage of [1, 2]) {
    const runs = orbit.filter((s) => s.stage === stage);
    const valid = runs.filter((s) => !s.void);
    byStage[stage] = {
      runs: runs.length,
      valid: valid.length,
      died: valid.filter((s) => s.died).length,
      medianDeathAfterHitS: median(valid.map((s) => s.death_after_hit_s)),
      hull120: median(runs.map((s) => s.hull_lost_120s)),
      hullPerMin: median(runs.map((s) => s.hull_per_min)),
      zeroLoss: runs.filter((s) => s.hull_lost_120s === 0).length,
      circleShare: median(runs.map((s) => s.circle_share)),
    };
  }
  const bots = {};
  for (const policy of ["skipper", "completionist"]) {
    const rs = rows.filter((r) => r.kind === policy && r.row);
    const stageNote = (r, n) => (r.row.stages ?? []).find((s) => s.stage === n) ?? {};
    bots[policy] = {
      runs: rs.length,
      minutes: median(rs.map((r) => r.row.game_seconds / 60)),
      deaths: rs.filter((r) => ["died", "lost"].includes(r.row.outcome)).length,
      outcomes: rs.map((r) => r.row.outcome),
      hull: median(
        rs.map((r) => (stageNote(r, 1).hull_lost ?? 0) + (stageNote(r, 2).hull_lost ?? 0)),
      ),
      kills: [1, 2].map((n) =>
        median(
          rs.map(
            (r) =>
              (r.row.panel_kills ?? []).filter((k) => k[0] === n && k[1] !== "yard_clear").length,
          ),
        ),
      ),
      reached2: rs.filter((r) => (r.row.stage_reached ?? 0) >= 2).length,
    };
  }
  const pressure = orbit.map((s) => s.pressure).filter(Boolean);
  return {
    orbit: byStage,
    bots,
    boilHitsMedian: median(pressure.map((p) => p.boil_hits)),
    churnDragMedian: median(pressure.map((p) => p.churn_drag_s)),
  };
}

function report(dirs) {
  const rows = dedupeBy(
    dirs.flatMap((d) => parseNdjson(read(path.join(path.resolve(d), "runs.ndjson")))),
    "id",
  );
  const variants = [...new Set(rows.map((r) => r.variant))];
  const f = (x, d = 1) => (x == null ? "-" : x.toFixed(d));
  const L = [
    "| Variant | Orbit deaths s1 / s2 | Death after first hit (s) | Hull lost in the 120 s window, median s1 / s2 | Windows with no loss | Skipper min | Skipper deaths | Skipper hull lost | Skipper kills s1 / s2 | Completionist min | Completionist deaths | Completionist hull lost |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
  ];
  const all = {};
  for (const v of variants) {
    const s = summarize(rows.filter((r) => r.variant === v));
    all[v] = s;
    const o = s.orbit;
    L.push(
      `| ${v} | ${o[1].died}/${o[1].valid} · ${o[2].died}/${o[2].valid} | ${f(o[1].medianDeathAfterHitS, 0)} · ${f(o[2].medianDeathAfterHitS, 0)} | ${f(o[1].hull120, 0)} · ${f(o[2].hull120, 0)} | ${o[1].zeroLoss + o[2].zeroLoss}/${o[1].runs + o[2].runs} | ${f(s.bots.skipper.minutes, 2)} | ${s.bots.skipper.deaths}/${s.bots.skipper.runs} | ${f(s.bots.skipper.hull, 0)} | ${f(s.bots.skipper.kills[0], 0)} · ${f(s.bots.skipper.kills[1], 0)} | ${f(s.bots.completionist.minutes, 2)} | ${s.bots.completionist.deaths}/${s.bots.completionist.runs} | ${f(s.bots.completionist.hull, 0)} |`,
    );
  }
  const md = L.join("\n") + "\n";
  console.log(md);
  if (opts.out) {
    writeFileSync(opts.out, md);
    writeFileSync(opts.out.replace(/\.md$/, ".json"), JSON.stringify(all, null, 1) + "\n");
  }
}
