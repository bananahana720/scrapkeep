import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches/core-loop");
export const DEFAULT_BUDGET = path.join(sketch, "design-v3/pacing/world1-pacing.json");
const recordedBinary = "/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64";
const RUN_TIMEOUT_MS = 1_800_000;

export class PacingError extends Error {}

export function parseArgs(argv) {
  const args = {
    budget: DEFAULT_BUDGET,
    from: [],
    run: false,
    level: "floor",
    jobs: 4,
    seeds: null,
    pilots: null,
    out: null,
  };
  for (const arg of argv) {
    const [key, value] = arg.includes("=")
      ? [arg.slice(0, arg.indexOf("=")), arg.slice(arg.indexOf("=") + 1)]
      : [arg, null];
    if (key !== "--run" && !value) throw new PacingError(`${key} needs a value: ${arg}`);
    if (key === "--run") args.run = true;
    else if (key === "--budget") args.budget = path.resolve(value);
    else if (key === "--from") args.from.push(path.resolve(value));
    else if (key === "--out") args.out = path.resolve(value);
    else if (key === "--level") {
      if (!["floor", "target"].includes(value))
        throw new PacingError(`--level is floor or target: ${arg}`);
      args.level = value;
    } else if (key === "--jobs") {
      args.jobs = Number(value);
      if (!Number.isInteger(args.jobs) || args.jobs < 1)
        throw new PacingError(`--jobs needs a whole number: ${arg}`);
    } else if (key === "--seeds") {
      args.seeds = value.split(",").map(Number);
      if (args.seeds.some((s) => !Number.isInteger(s) || s < 1))
        throw new PacingError(`--seeds needs whole numbers: ${arg}`);
    } else if (key === "--pilots") args.pilots = value.split(",").filter(Boolean);
    else throw new PacingError(`unknown argument ${arg}`);
  }
  if (!args.run && args.from.length === 0) throw new PacingError("give --run or --from=<dir>");
  return args;
}

export function loadBudget(file) {
  const budget = JSON.parse(readFileSync(file, "utf8"));
  if (budget.schema !== 1) throw new PacingError(`${file}: schema ${budget.schema}, expected 1`);
  for (const policy of budget.measure.policies) {
    if (!budget.run[policy]) throw new PacingError(`${file}: run has no ${policy} band`);
    for (const stage of budget.stages)
      if (!stage[policy]) throw new PacingError(`${file}: stage ${stage.id} has no ${policy} band`);
  }
  return budget;
}

export function median(values) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

export function readRows(dirs) {
  const rows = [];
  const seen = new Set();
  const read = (file) => {
    if (seen.has(path.resolve(file))) return;
    seen.add(path.resolve(file));
    for (const line of readFileSync(file, "utf8").split("\n"))
      if (line.trim()) rows.push(JSON.parse(line));
  };
  for (const dir of dirs) {
    if (!existsSync(dir)) throw new PacingError(`no such folder ${dir}`);
    if (existsSync(path.join(dir, "bots.ndjson"))) read(path.join(dir, "bots.ndjson"));
    for (const child of readdirSync(dir)) {
      const file = path.join(dir, child, "bots.ndjson");
      if (existsSync(file) && statSync(file).isFile()) read(file);
    }
  }
  return rows;
}

const done = (row) => row.outcome === "stages_done";
const parkNote = (row, stage) => (row.stages ?? []).find((s) => s.stage === stage);

export function stageSeconds(row, stage, parks) {
  if (stage.stage === "boss") {
    if (!done(row)) return null;
    let spent = 0;
    for (const park of parks) {
      const exit = parkNote(row, park.stage)?.exit_s;
      if (!(exit > 0)) return null;
      spent += exit;
    }
    return row.game_seconds - spent;
  }
  const exit = parkNote(row, stage.stage)?.exit_s;
  return exit > 0 ? exit : null;
}

export function fieldCount(note, field) {
  if (!note || !(field in note)) return null;
  const value = note[field];
  if (Array.isArray(value)) return value.length;
  if (typeof value === "number") return value;
  if (typeof value === "boolean") return value ? 1 : 0;
  return null;
}

function band(id, policy, value, limits, level, factor, extra = {}) {
  let status = "pass";
  if (value === null) status = "fail";
  else if (limits.floor !== undefined && value < limits.floor) status = "fail";
  else if (level === "target" && (value < limits.min || value > limits.max)) status = "fail";
  const human = value === null ? null : (value * factor) / 60;
  return { id, policy, value, ...limits, human_min: human, status, ...extra };
}

export function evaluate(budget, rows, level = "floor", expected = {}) {
  const factor = budget.human_per_bot.value;
  const parks = budget.stages.filter((s) => s.stage !== "boss");
  const checks = [];
  const content = [];
  const runs = {};
  for (const policy of budget.measure.policies) {
    const mine = rows.filter((r) => r.policy === policy);
    const finished = mine.filter(done);
    const launched = Math.max(mine.length, expected[policy] ?? 0);
    const reach = launched ? finished.length / launched : 0;
    runs[policy] = {
      runs: launched,
      rows: mine.length,
      done: finished.length,
      stalled: mine
        .filter((r) => !done(r))
        .map((r) => ({ seed: r.seed, class: r.class, outcome: r.outcome })),
    };
    checks.push({
      id: "reach",
      policy,
      value: reach,
      floor: budget.reach.floor,
      status: launched && reach >= budget.reach.floor ? "pass" : "fail",
    });
    const total = median(finished.map((r) => r.game_seconds));
    checks.push(
      band("run", policy, total, budget.run[policy], level, factor, {
        range: finished.length
          ? [
              Math.min(...finished.map((r) => r.game_seconds)),
              Math.max(...finished.map((r) => r.game_seconds)),
            ]
          : null,
      }),
    );
    for (const stage of budget.stages) {
      const values = mine.map((r) => stageSeconds(r, stage, parks)).filter((v) => v !== null);
      const extra = { n: values.length, low: values.length ? Math.min(...values) : null };
      if (stage.stage === "boss")
        extra.fight_s = median(
          finished.map((r) => r.boss?.seconds).filter((v) => typeof v === "number"),
        );
      checks.push(band(stage.id, policy, median(values), stage[policy], level, factor, extra));
    }
  }
  for (const slot of budget.content?.slots ?? []) {
    for (const parkId of slot.parks) {
      const park = parks.find((p) => p.id === parkId);
      const entry = {
        slot: slot.id,
        park: parkId,
        field: slot.field,
        planned: slot.planned?.[parkId] ?? null,
        owner: slot.owner,
      };
      for (const policy of budget.measure.policies) {
        const counts = rows
          .filter((r) => r.policy === policy)
          .map((r) => fieldCount(parkNote(r, park.stage), slot.field));
        const seen = counts.filter((c) => c !== null);
        entry[policy] = seen.length
          ? { median: median(seen), max: Math.max(...seen), n: seen.length }
          : null;
      }
      const need = slot.completionist_min?.[parkId];
      const cap = slot.skipper_max?.[parkId];
      let status = "pass";
      if (entry.completionist === null && need !== undefined) status = "pending";
      else if (need !== undefined && entry.completionist.median < need) status = "fail";
      if (cap !== undefined && entry.skipper !== null && entry.skipper.max > cap) status = "fail";
      entry.completionist_min = need ?? null;
      entry.skipper_max = cap ?? null;
      entry.status = status;
      content.push(entry);
    }
  }
  const planned = parks.map((park) => {
    let required = 0;
    let all = 0;
    for (const slot of budget.content?.slots ?? []) {
      if (!slot.parks.includes(park.id)) continue;
      required += (slot.completionist_min?.[park.id] ?? 0) * slot.bot_s;
      all += (slot.planned?.[park.id] ?? 0) * slot.bot_s;
    }
    const room =
      (park.completionist.min + park.completionist.max) / 2 -
      (park.skipper.min + park.skipper.max) / 2;
    return { park: park.id, required_s: required, everything_s: all, room_s: room };
  });
  const failing =
    checks.filter((c) => c.status === "fail").length +
    (level === "target" ? content.filter((c) => c.status !== "pass").length : 0);
  const measured = rows.length > 0;
  return {
    level,
    human_per_bot: budget.human_per_bot,
    runs,
    checks,
    content,
    planned,
    measured,
    pass: measured && failing === 0,
  };
}

const fmt = (s) => (s === null || s === undefined ? "none" : `${Math.round(s)} s`);
const mins = (m) => (m === null || m === undefined ? "" : `${m.toFixed(1)}`);

export function renderMarkdown(result, header = {}) {
  const lines = [`# World 1 pacing (${result.level})`, ""];
  for (const [key, value] of Object.entries(header)) lines.push(`- ${key}: ${value}`);
  const f = result.human_per_bot;
  lines.push(
    `- Person estimate: bot seconds x ${f.value} (${f.measured ? "measured" : `inferred ${f.low}-${f.high}, not measured`})`,
    "",
  );
  lines.push(
    `Verdict: ${result.pass ? "PASS" : result.measured ? "FAIL" : "NOTHING MEASURED"}`,
    "",
  );
  lines.push(
    "| Check | Policy | Median | Floor | Band | Person min | n | Status |",
    "| --- | --- | ---: | ---: | --- | ---: | ---: | --- |",
  );
  for (const c of result.checks) {
    if (c.id === "reach") {
      const r = result.runs[c.policy];
      lines.push(
        `| reach Brindle's rout | ${c.policy} | ${r.done}/${r.runs} | ${c.floor * 100}% | | | ${r.runs} | ${c.status} |`,
      );
      continue;
    }
    const extra = c.fight_s ? ` (fight ${fmt(c.fight_s)})` : "";
    lines.push(
      `| ${c.id} | ${c.policy} | ${fmt(c.value)}${extra} | ${fmt(c.floor)} | ${c.min}-${c.max} s | ${mins(c.human_min)} | ${c.n ?? result.runs[c.policy].done} | ${c.status} |`,
    );
  }
  lines.push(
    "",
    "## Optional content (per run, median)",
    "",
    "| Slot | Park | Field | Planned | Completionist | Needs | Skipper (max) | Cap | Status |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |",
  );
  for (const c of result.content) {
    const comp = c.completionist ? c.completionist.median : "not written";
    const skip = c.skipper ? c.skipper.max : "not written";
    lines.push(
      `| ${c.slot} | ${c.park} | ${c.field} | ${c.planned ?? ""} | ${comp} | ${c.completionist_min ?? ""} | ${skip} | ${c.skipper_max ?? ""} | ${c.status} |`,
    );
  }
  lines.push(
    "",
    "## Planned optional seconds per park",
    "",
    "| Park | Required by the budget | Everything planned | Room between the bands |",
    "| --- | ---: | ---: | ---: |",
  );
  for (const p of result.planned)
    lines.push(`| ${p.park} | ${fmt(p.required_s)} | ${fmt(p.everything_s)} | ${fmt(p.room_s)} |`);
  const stalled = Object.entries(result.runs).flatMap(([policy, r]) =>
    r.stalled.map((s) => `${policy} seed ${s.seed} (${s.class}): ${s.outcome}`),
  );
  if (stalled.length)
    lines.push(
      "",
      "## Runs that did not reach Brindle's rout",
      "",
      ...stalled.map((s) => `- ${s}`),
    );
  return `${lines.join("\n")}\n`;
}

export function buildJobs(budget, args, outDir) {
  const seeds = args.seeds ?? budget.measure.seeds;
  const pilots = args.pilots ?? budget.measure.pilots;
  const jobs = [];
  for (const policy of budget.measure.policies)
    for (const pilot of pilots)
      for (const seed of seeds) {
        const out = path.join(outDir, "bots", `${policy}-${pilot}-${seed}`);
        const botArgs = [
          `--out=${out}`,
          `--policy=${policy}`,
          `--seeds=${seed}`,
          `--table=${budget.measure.table}`,
          `--stages=${budget.measure.stages}`,
          ...budget.measure.bot_args,
          ...(budget.measure.policy_args?.[policy] ?? []),
        ];
        if (pilot !== "seed") botArgs.push(`--pilot=${pilot}`);
        jobs.push({
          policy,
          label: `${policy} ${pilot} ${seed}`,
          out,
          args: [
            "--headless",
            "--fixed-fps",
            "90",
            "--path",
            sketch,
            "--script",
            "res://tools/bot_run.gd",
            "--",
            ...botArgs,
          ],
        });
      }
  return jobs;
}

function runJob(binary, job) {
  mkdirSync(job.out, { recursive: true });
  const env = { ...process.env };
  for (const kind of ["DATA", "CONFIG", "CACHE"])
    env[`XDG_${kind}_HOME`] = path.join(job.out, "state", kind.toLowerCase());
  return new Promise((resolve) => {
    const started = Date.now();
    const child = spawn(binary, job.args, { env, stdio: ["ignore", "ignore", "pipe"] });
    let tail = "";
    child.stderr.on("data", (chunk) => {
      tail = (tail + chunk).slice(-4000);
    });
    const timer = setTimeout(() => child.kill("SIGKILL"), RUN_TIMEOUT_MS);
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        label: job.label,
        code,
        wall_s: Math.round((Date.now() - started) / 1000),
        tail: code ? tail : "",
      });
    });
  });
}

async function runPool(binary, jobs, width) {
  const results = [];
  let next = 0;
  const lane = async () => {
    while (next < jobs.length) {
      const job = jobs[next++];
      const result = await runJob(binary, job);
      console.log(`pacing: ${result.label} exit ${result.code} in ${result.wall_s} s`);
      results.push(result);
    }
  };
  await Promise.all(Array.from({ length: Math.min(width, jobs.length) }, lane));
  return results;
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    if (!(error instanceof PacingError)) throw error;
    console.error(`pacing-check: ${error.message}`);
    process.exit(2);
  }
  let budget;
  try {
    budget = loadBudget(args.budget);
  } catch (error) {
    console.error(`pacing-check: ${error.message}`);
    process.exit(2);
  }
  const expected = {};
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const outDir = args.out ?? path.join(root, "artifacts/local/pacing", stamp);
  mkdirSync(outDir, { recursive: true });
  const header = { budget: path.relative(root, args.budget) };
  let jobResults = [];
  if (args.run) {
    const binary = process.env.GODOT_BIN || recordedBinary;
    if (!existsSync(binary)) {
      console.error(`pacing-check: Godot binary not found at ${binary}; set GODOT_BIN`);
      process.exit(2);
    }
    const jobs = buildJobs(budget, args, outDir);
    for (const job of jobs) expected[job.policy] = (expected[job.policy] ?? 0) + 1;
    console.log(
      `pacing: ${jobs.length} bot runs, ${args.jobs} at a time (${os.cpus().length} CPUs)`,
    );
    jobResults = await runPool(binary, jobs, args.jobs);
    args.from.push(path.join(outDir, "bots"));
    header.runs = `${jobs.length} (${jobResults.filter((j) => j.code !== 0).length} exited non-zero)`;
  }
  header.from = args.from.map((d) => path.relative(root, d) || d).join(", ");
  const rows = readRows(args.from);
  const result = evaluate(budget, rows, args.level, expected);
  writeFileSync(
    path.join(outDir, "summary.json"),
    `${JSON.stringify({ ...result, header, jobs: jobResults }, null, 2)}\n`,
  );
  const report = renderMarkdown(result, header);
  writeFileSync(path.join(outDir, "report.md"), report);
  console.log(report);
  console.log(`pacing: wrote ${path.relative(root, outDir)}/summary.json and report.md`);
  process.exit(result.measured ? (result.pass ? 0 : 1) : 2);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  await main();
