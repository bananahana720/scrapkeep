#!/usr/bin/env node
// The alpha checkpoint in one command (design-v3/ALPHA-PLAN.md, "Admission to play").
//
//   npm run sketch:checkpoint -- --before [--quick]
//       bots and fixed checks: is the slice worth Andrew's time. One table, a pass or
//       miss per band, exit 1 on any miss.
//   npm run sketch:checkpoint -- --after <runs.ndjson>
//       reads his sitting from the game's own run log, one verdict per question.
//
// Output goes under artifacts/local/checkpoint/<timestamp>/ with a summary.json.
// --quick runs 3 seeds per policy and skips perf, for testing this script.

import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { binary as GODOT } from "./sketch-smoke.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
export const root = path.resolve(here, "..");
const sketch = path.join(root, "sketches", "core-loop");

// The thresholds, as written in ALPHA-PLAN before anything was built.
export const BANDS = {
  seeds: 16,
  quickSeeds: 3,
  explorerWinRate: 0.6,
  cpuP99Ms: 10,
  gpuP99Ms: 7,
  zoneSeconds: 60, // coordinator-owned knob: ALPHA-PLAN gives no number for "time in the zone".
  ticksPerSecond: 90,
  parallel: 6,
};

// --- Band arithmetic ---------------------------------------------------------------------

export const atMost = (measured, limit) => measured !== null && measured !== undefined && measured <= limit;
export const atLeast = (measured, limit) => measured !== null && measured !== undefined && measured >= limit;
export const greater = (measured, other) => measured !== null && other !== null && measured !== undefined && other !== undefined && measured > other;

export function median(values) {
  const sorted = values.filter((v) => typeof v === "number" && Number.isFinite(v)).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const mid = sorted.length >> 1;
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

const wins = (runs) => runs.filter((r) => r.outcome === "won");

// A bot run joined to the game's own run-log line: what the band arithmetic reads.
// heft and parts come from the last stage row that carries them. The fight is the posture
// block's fight_ticks: first posture gain to the break, not the stage clock, which also
// counts every second spent exploring before the fight.
export function summarizeRun(bot, logLine) {
  const stages = (logLine?.stages ?? []).filter((s) => s);
  const last = (key) => {
    for (let i = stages.length - 1; i >= 0; i--) if (stages[i][key] !== null && stages[i][key] !== undefined) return stages[i][key];
    return null;
  };
  const parts = last("part_ids_at_exit");
  const posture = last("posture");
  const fightTicks = typeof posture?.fight_ticks === "number" ? posture.fight_ticks : null;
  return {
    policy: bot.policy,
    seed: bot.seed,
    outcome: bot.outcome,
    heft: last("heft_at_engage"),
    parts: Array.isArray(parts) ? parts.length : null,
    fightSeconds: fightTicks === null ? null : fightTicks / BANDS.ticksPerSecond,
  };
}

const pct = (n, d) => `${n}/${d}`;
const num = (v, digits = 2) => (v === null ? "n/a" : Number(v).toFixed(digits));

// The four bot bands. `runs` is { completionist: [...], skipper: [...], camper: [...] } of summarizeRun rows.
export function evaluateBots(runs) {
  const explorer = runs.completionist ?? [];
  const skipper = runs.skipper ?? [];
  const camper = runs.camper ?? [];
  const rows = [];
  rows.push({
    band: "camper cannot win",
    measured: `${pct(wins(camper).length, camper.length)} wins`,
    threshold: "0 wins",
    pass: camper.length > 0 && wins(camper).length === 0,
  });
  rows.push({
    band: "skipper can win",
    measured: `${pct(wins(skipper).length, skipper.length)} wins`,
    threshold: "at least 1 win",
    pass: atLeast(wins(skipper).length, 1),
  });
  const skipFight = median(wins(skipper).map((r) => r.fightSeconds));
  const exploreFight = median(wins(explorer).map((r) => r.fightSeconds));
  rows.push({
    band: "skipper slower than explorer (Warden fight)",
    measured: `skipper ${num(skipFight, 1)} s, explorer ${num(exploreFight, 1)} s median`,
    threshold: "skipper > explorer",
    pass: greater(skipFight, exploreFight),
  });
  const rate = explorer.length ? wins(explorer).length / explorer.length : null;
  rows.push({
    band: "explorer win rate",
    measured: `${pct(wins(explorer).length, explorer.length)} (${rate === null ? "n/a" : Math.round(rate * 100)}%)`,
    threshold: `at least ${BANDS.explorerWinRate * 100}%`,
    pass: atLeast(rate, BANDS.explorerWinRate),
  });
  const exploreHeft = median(explorer.map((r) => r.heft));
  const skipHeft = median(skipper.map((r) => r.heft));
  rows.push({
    band: "explorer heft above skipper",
    measured: `explorer ${num(exploreHeft)}, skipper ${num(skipHeft)} median`,
    threshold: "explorer > skipper",
    pass: greater(exploreHeft, skipHeft),
  });
  const exploreParts = median(explorer.map((r) => r.parts));
  const skipParts = median(skipper.map((r) => r.parts));
  rows.push({
    band: "explorer parts above skipper",
    measured: `explorer ${num(exploreParts, 1)}, skipper ${num(skipParts, 1)} median`,
    threshold: "explorer > skipper",
    pass: greater(exploreParts, skipParts),
  });
  return rows;
}

// Perf bench JSON (tools/perf_bench.gd) on the densest scene. CPU main thread is the
// process pass (every node's _process); GPU is the viewport's measured render time.
export function evaluatePerf(bench) {
  const rows = [];
  const valid = Boolean(bench) && bench.valid === true && Array.isArray(bench.size) && bench.size[0] === 1920 && bench.size[1] === 1080;
  const cpu = bench?.stats?.process_ms?.p99 ?? null;
  const gpu = bench?.stats?.gpu_ms?.p99 ?? null;
  const where = bench ? `${bench.size?.join("x")} ${bench.display}, scene ${bench.scene}, table ${bench.table || "default"}` : "no result";
  rows.push({
    band: "perf valid (1080p, slice, native)",
    measured: where,
    threshold: "valid run at 1920x1080",
    pass: valid && bench.table === "slice" && bench.display !== "headless",
  });
  rows.push({ band: "perf CPU main thread p99", measured: cpu === null ? "n/a" : `${cpu} ms`, threshold: `at most ${BANDS.cpuP99Ms} ms`, pass: atMost(cpu, BANDS.cpuP99Ms) });
  rows.push({ band: "perf GPU p99", measured: gpu === null ? "n/a" : `${gpu} ms`, threshold: `at most ${BANDS.gpuP99Ms} ms`, pass: atMost(gpu, BANDS.gpuP99Ms) });
  return rows;
}

// The slice row's Warden numbers, read from the game's table so the sweep line is the picked cell.
export function sliceCell(defsText) {
  const plating = /"warden_plating":\s*([\d.]+)/.exec(defsText);
  const curve = /"curve":\s*([\d.]+)/.exec(defsText);
  const shatters = /"ram_shatters":\s*(true|false)/.exec(defsText);
  if (!plating || !curve || !shatters) return null;
  return { plating: Number(plating[1]), curve: Number(curve[1]), ram_shatters: shatters[1] };
}

export function evaluateSweep(tsvText, cell) {
  const lines = (tsvText || "").split("\n").filter(Boolean);
  const header = lines[0]?.split("\t") ?? [];
  const rows = lines.slice(1).map((l) => Object.fromEntries(l.split("\t").map((v, i) => [header[i], v])));
  const hit = cell && rows.find((r) => Number(r.plating) === cell.plating && Number(r.curve) === cell.curve && r.ram_shatters === cell.ram_shatters);
  if (!hit) {
    return { band: "posture sweep, picked cell", measured: "no row for the slice cell", threshold: "pass", pass: false };
  }
  return {
    band: "posture sweep, picked cell",
    measured: `${cell.plating}/${cell.curve}/${cell.ram_shatters}: grown ${hit.grown_median_s} s, mid ${hit.mid_median_s} s, small ${hit.small_median_s} s, ratio ${hit.small_to_grown}`,
    threshold: "pass column is pass",
    pass: hit.pass === "pass",
  };
}

// A gate receipt (sketch-smoke --receipt gate) for this commit that is clean and ok.
export function evaluateReceipt(receipts, head) {
  const mine = receipts.filter((r) => r.label === "gate" && r.head === head);
  if (mine.length === 0) return { band: "smoke green on this commit", measured: "no gate receipt for HEAD", threshold: "gate receipt ok", pass: false };
  mine.sort((a, b) => String(b.started_at).localeCompare(String(a.started_at)));
  const newest = mine[0];
  return {
    band: "smoke green on this commit",
    measured: `gate receipt ${newest.started_at}: ${newest.totals?.failed ?? "?"} failed of ${newest.totals?.runs ?? "?"}`,
    threshold: "gate receipt ok on a clean tree",
    pass: newest.ok === true && newest.clean === true,
  };
}

// ALPHA-PLAN lines this script does not check. They print as "by hand" and do not count
// toward the bots-and-fixed-checks verdict, so an ADMIT here never claims them.
export const BY_HAND = [
  { band: "each band fails its deliberately failing calibration case (checkpoint.test.mjs)", measured: "the test suite is the record; the rejected builds (v2 at 19fc173, drop, laps) are historical evidence only (EV-0623)", threshold: "coordinator records the suite run" },
  { band: "lair-chaser pays a measured cost", measured: "Hunt is parked (LEGIBILITY decision 4), so no lair-chaser exists on the slice", threshold: "not applicable while Hunt is parked" },
  { band: "one Fable integrated read on the checkpoint SHA", measured: "a review, not a measurement", threshold: "coordinator records it" },
  { band: "five sitting questions per arm", measured: "the slice ships one fight, no arms", threshold: "not applicable" },
].map((row) => ({ ...row, pass: null, byHand: true }));

// --- The sitting (--after) -----------------------------------------------------------------

export function readRunLog(text) {
  const byRun = new Map();
  for (const line of (text || "").split("\n")) {
    if (!line.trim()) continue;
    let record;
    try {
      record = JSON.parse(line);
    } catch {
      continue;
    }
    if (record && record.run_id !== undefined) byRun.set(record.run_id, record); // lines are cumulative: the last one wins
  }
  return [...byRun.values()].filter((r) => r.table === "slice");
}

const joinedEvents = (run) => new Set((run.stages ?? []).flatMap((s) => (Array.isArray(s.events_joined) ? s.events_joined : []))).size;
const engageTicks = (run) => {
  const values = (run.stages ?? []).map((s) => s.ticks_to_warden_engaged).filter((v) => typeof v === "number");
  return values.length ? Math.max(...values) : null;
};

// One entry per sitting question. `read` returns the per-run number (null when the run
// has no value); `reason` marks a question the log cannot answer, and `verdict` reads
// the whole log.
export const QUESTIONS = [
  {
    id: "activities",
    ask: "enters two or more activities unprompted in a run",
    fields: ["stages[].events_joined"],
    read: joinedEvents,
    verdict: (values) => values.some((v) => v >= 2),
    note: "distinct opt-in events the ball entered in the run, so a retry's re-entry counts once; prompts_shown is not tied to an event, so unprompted is read as entered",
  },
  {
    id: "smashes",
    ask: "lands harpoon smashes into packs and keeps doing it",
    fields: ["smashes", "bites"],
    read: (run) => (typeof run.smashes === "number" ? run.smashes : null),
    reason: "the log counts smashes and bites per run but not the target (a pack) or when each landed, so landing in packs and keeping on cannot be read",
  },
  {
    id: "zone",
    ask: "spends time in the zone before the Warden in at least one run",
    fields: ["stages[].ticks_to_warden_engaged"],
    read: (run) => {
      const t = engageTicks(run);
      return t === null ? null : t / BANDS.ticksPerSecond;
    },
    verdict: (values) => values.some((v) => v !== null && v >= BANDS.zoneSeconds),
    note: `seconds from stage start to the Warden's engagement on its latest attempt; a run at ${BANDS.zoneSeconds} s or more passes (a knob, ALPHA-PLAN gives no number). A run that never engages reads n/a`,
  },
  {
    id: "second_run",
    ask: "starts a second run without being asked",
    fields: ["run_id"],
    read: () => 1,
    verdict: (values) => values.length >= 2,
    note: "two distinct slice runs in the log; whether he was asked is not recorded",
  },
];

export function evaluateSitting(runs, questions = QUESTIONS) {
  return questions.map((q) => {
    const values = runs.map((r) => q.read(r));
    if (q.reason) {
      return { id: q.id, ask: q.ask, fields: q.fields, measurable: false, reason: q.reason, values, verdict: "not measurable" };
    }
    return { id: q.id, ask: q.ask, fields: q.fields, measurable: true, note: q.note, values, verdict: q.verdict(values) ? "pass" : "miss" };
  });
}

export function runRows(runs) {
  return runs.map((r) => ({
    run_id: r.run_id,
    outcome: r.outcome,
    events_joined: joinedEvents(r),
    smashes: r.smashes ?? null,
    bites: r.bites ?? null,
    engage_s: engageTicks(r) === null ? null : engageTicks(r) / BANDS.ticksPerSecond,
    attempts: (r.stages ?? []).reduce((n, s) => n + (s.attempts ?? 0), 0),
  }));
}

// --- Printing ----------------------------------------------------------------------------

export function formatTable(rows) {
  const result = (r) => (r.byHand ? "by hand" : r.pass === null ? "skipped" : r.pass ? "pass" : "MISS");
  const cells = [["band", "measured", "threshold", "result"], ...rows.map((r) => [r.band, r.measured, r.threshold, result(r)])];
  const widths = cells[0].map((_, i) => Math.max(...cells.map((row) => String(row[i]).length)));
  return cells.map((row) => row.map((c, i) => String(c).padEnd(widths[i])).join("  ").trimEnd()).join("\n");
}

export function formatSitting(runs, verdicts) {
  const out = [];
  out.push(["run_id", "outcome", "events", "smashes", "bites", "engage_s", "attempts"].join("\t"));
  for (const r of runRows(runs)) out.push([r.run_id, r.outcome, r.events_joined, r.smashes ?? "n/a", r.bites ?? "n/a", r.engage_s === null ? "n/a" : r.engage_s.toFixed(1), r.attempts].join("\t"));
  out.push("");
  for (const v of verdicts) {
    out.push(`${v.verdict === "pass" ? "pass" : v.verdict === "miss" ? "MISS" : "not measurable"}  ${v.ask}`);
    out.push(`    fields: ${v.fields.join(", ")}`);
    out.push(`    ${v.measurable ? v.note : "why: " + v.reason}`);
  }
  return out.join("\n");
}

// --- Running things ----------------------------------------------------------------------

function git(args) {
  const r = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  return r.status === 0 ? r.stdout.trim() : null;
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { ...options, stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.on("data", (d) => (output += d));
    child.stderr.on("data", (d) => (output += d));
    child.on("error", (e) => resolve({ code: -1, output: String(e) }));
    child.on("close", (code) => resolve({ code, output }));
  });
}

async function pool(jobs, width) {
  const results = new Array(jobs.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(width, jobs.length) }, async () => {
    while (next < jobs.length) {
      const i = next++;
      results[i] = await jobs[i]();
    }
  });
  await Promise.all(workers);
  return results;
}

function readNdjson(file) {
  if (!existsSync(file)) return [];
  return readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => {
    try {
      return JSON.parse(l);
    } catch {
      return null;
    }
  }).filter(Boolean);
}

async function runBots(outDir, seedCount) {
  const jobs = [];
  for (const policy of ["completionist", "skipper", "camper"]) {
    for (let seed = 1; seed <= seedCount; seed++) {
      const dir = path.join(outDir, "bots", `${policy}-${seed}`);
      mkdirSync(dir, { recursive: true });
      const env = { ...process.env };
      for (const kind of ["DATA", "CONFIG", "CACHE"]) env[`XDG_${kind}_HOME`] = path.join(dir, "state", kind.toLowerCase());
      jobs.push(async () => {
        const args = ["--headless", "--fixed-fps", "90", "--path", sketch, "--script", "res://tools/bot_run.gd", "--",
          `--out=${dir}`, `--policy=${policy}`, `--seeds=${seed}`, "--table=slice"];
        const result = await runProcess(GODOT, args, { env, cwd: root });
        writeFileSync(path.join(dir, "log.txt"), result.output);
        const bot = readNdjson(path.join(dir, "bots.ndjson"))[0];
        const lines = readNdjson(path.join(dir, "runs.ndjson"));
        if (!bot) return { policy, seed, failed: `bot_run exit ${result.code}, no bots.ndjson line` };
        const line = [...lines].reverse().find((l) => l.run_id === bot.run_id) ?? null;
        return summarizeRun(bot, line);
      });
    }
  }
  const results = await pool(jobs, BANDS.parallel);
  const grouped = { completionist: [], skipper: [], camper: [] };
  const failed = [];
  for (const r of results) {
    if (r.failed) failed.push(`${r.policy} ${r.seed}: ${r.failed}`);
    else grouped[r.policy].push(r);
  }
  return { grouped, failed };
}

function ensureImported() {
  if (existsSync(path.join(sketch, ".godot", "imported"))) return;
  spawnSync(GODOT, ["--headless", "--editor", "--import", "--quit", "--path", sketch], { encoding: "utf8", timeout: 600_000 });
}

async function runPerf(outDir) {
  const out = path.join(outDir, "perf.json");
  const args = [GODOT, "--path", sketch, "--resolution", "1920x1080", "--log-file", path.join(outDir, "perf-godot.log"),
    "--script", "res://tools/perf_bench.gd", "--", "--scene=s3", "--table=slice", `--out=${out}`];
  const load = os.loadavg();
  const result = await runProcess("claude-open", args, { env: { ...process.env, CLAUDE_OPEN_WAIT: "1" } });
  writeFileSync(path.join(outDir, "perf-claude-open.txt"), result.output);
  const bench = existsSync(out) ? JSON.parse(readFileSync(out, "utf8")) : null;
  return { bench, load };
}

function readReceipts() {
  const dir = path.join(root, "artifacts", "local", "receipts");
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((n) => n.startsWith("gate-") && n.endsWith(".json")).map((n) => {
    try {
      return JSON.parse(readFileSync(path.join(dir, n), "utf8"));
    } catch {
      return null;
    }
  }).filter(Boolean);
}

function stamp() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

function newestDirOutput() {
  const dir = path.join(root, "artifacts", "local", "checkpoint", stamp());
  mkdirSync(dir, { recursive: true });
  return dir;
}

async function before(options) {
  const outDir = newestDirOutput();
  ensureImported();
  const seedCount = options.quick ? BANDS.quickSeeds : BANDS.seeds;
  const loadAtStart = os.loadavg();
  const rows = [];
  const { grouped, failed } = await runBots(outDir, seedCount);
  rows.push(...evaluateBots(grouped));
  for (const f of failed) rows.push({ band: "bot run failed", measured: f, threshold: "every seed runs", pass: false });
  let perf = null;
  if (options.quick) {
    rows.push({ band: "perf (CPU and GPU p99, 1080p)", measured: "skipped by --quick", threshold: "-", pass: null });
  } else {
    perf = await runPerf(outDir);
    rows.push(...evaluatePerf(perf.bench));
  }
  const defs = readFileSync(path.join(sketch, "src", "core", "slice_defs.gd"), "utf8");
  const sweepFile = path.join(sketch, "tools", "posture_sweep.tsv");
  rows.push(evaluateSweep(existsSync(sweepFile) ? readFileSync(sweepFile, "utf8") : "", sliceCell(defs)));
  const head = git(["rev-parse", "HEAD"]);
  rows.push(evaluateReceipt(readReceipts(), head));
  rows.push(...BY_HAND);

  const table = formatTable(rows);
  const ok = rows.every((r) => r.pass !== false);
  writeFileSync(path.join(outDir, "summary.json"), JSON.stringify({
    mode: "before", quick: Boolean(options.quick), head, ok, load_at_start: loadAtStart, load_at_perf: perf?.load ?? null,
    seeds: seedCount, rows, bots: grouped, perf: perf?.bench ?? null,
  }, null, 2) + "\n");
  console.log(table);
  const verdict = ok ? `bots and fixed checks pass, ${BY_HAND.length} rows by hand` : "NOT ADMITTED";
  console.log(`\nload at start ${loadAtStart.map((v) => v.toFixed(2)).join(" ")}; ${verdict}; ${path.relative(root, outDir)}/summary.json`);
  return ok ? 0 : 1;
}

function after(file) {
  if (!file || !existsSync(file) || !statSync(file).isFile()) {
    console.error("checkpoint --after needs the path of a runs.ndjson");
    return 2;
  }
  const outDir = newestDirOutput();
  const runs = readRunLog(readFileSync(file, "utf8"));
  const verdicts = evaluateSitting(runs);
  console.log(`${runs.length} slice run(s) in ${file}\n`);
  console.log(formatSitting(runs, verdicts));
  writeFileSync(path.join(outDir, "summary.json"), JSON.stringify({ mode: "after", file, runs: runRows(runs), verdicts }, null, 2) + "\n");
  console.log(`\n${path.relative(root, outDir)}/summary.json`);
  return verdicts.some((v) => v.verdict === "miss") ? 1 : 0;
}

export function parseArgs(argv) {
  const options = { mode: null, quick: false, file: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--before") options.mode = "before";
    else if (argv[i] === "--after") {
      options.mode = "after";
      options.file = argv[++i] ?? null;
    } else if (argv[i] === "--quick") options.quick = true;
  }
  return options;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.mode === "before") process.exit(await before(options));
  else if (options.mode === "after") process.exit(after(options.file));
  else {
    console.error("usage: npm run sketch:checkpoint -- --before [--quick] | --after <runs.ndjson>");
    process.exit(2);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
