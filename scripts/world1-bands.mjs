#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { median } from "./checkpoint.mjs";
import { cellVerdict, meets, targetFor } from "./challenge/lib.mjs";
import { LEDGER_FILE, parseLedger, pastReview } from "./known-failing.mjs";
import { scan } from "./placeholder-gate.mjs";
import { FINDINGS_FILE, parseFindings } from "./redteam/lib.mjs";
import { readRuns } from "./run-summary.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const ROWS_FILE = path.join(root, "scripts", "world1-bands.rows.json");
export const WORLD1_MAPS = ["park_dam", "park_flume"];

const read = (file) => readFileSync(path.isAbsolute(file) ? file : path.join(root, file), "utf8");
const has = (file) => existsSync(path.isAbsolute(file) ? file : path.join(root, file));
const isNum = (v) => typeof v === "number" && Number.isFinite(v);

export function joinRuns(botsText, runsText) {
  const logs = new Map(readRuns(runsText).map((r) => [r.run_id, r]));
  return readRuns(botsText).map((bot) => ({ bot, log: logs.get(bot.run_id) ?? null }));
}

export function readBotDir(dir) {
  const bots = path.join(dir, "bots.ndjson");
  const runs = path.join(dir, "runs.ndjson");
  if (!existsSync(bots)) throw new Error(`no bots.ndjson in ${dir}`);
  return joinRuns(readFileSync(bots, "utf8"), existsSync(runs) ? readFileSync(runs, "utf8") : "");
}

export function phaseCount(text) {
  const found = /PHASE_NAMES\s*:?=\s*\[([^\]]*)\]/.exec(text ?? "");
  return found ? (found[1].match(/"[^"]*"/g) ?? []).length : null;
}

export function constBand(text, name) {
  const found = new RegExp(
    `const\\s+${name}\\s*(?::\\s*[\\w\\[\\]]+\\s*)?:?=\\s*\\[\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*\\]`,
  ).exec(text ?? "");
  return found ? { min: Number(found[1]), max: Number(found[2]) } : null;
}

const routed = ({ bot }) => {
  const boss = bot.boss;
  return isNum(boss?.defeated_s) && bot.outcome === "stages_done";
};

export function stageCount(bot, key) {
  const parks = (bot.stages ?? []).filter((s) => s && key in s);
  if (!parks.length) return null;
  return parks.reduce(
    (n, s) =>
      n +
      (Array.isArray(s[key]) ? s[key].length : isNum(s[key]) ? s[key] : s[key] === true ? 1 : 0),
    0,
  );
}

export const MEASURES = {
  routed: (run) => (typeof run.bot.outcome !== "string" ? null : routed(run) ? 1 : 0),
  rout_s: (run) =>
    routed(run) && isNum(run.bot.boss.entered_run_s)
      ? run.bot.boss.entered_run_s + run.bot.boss.defeated_s
      : null,
  brindle_phase: ({ log }) =>
    isNum(log?.brindle_phase_reached) ? log.brindle_phase_reached : null,
  brindle_final_phase: (run, ctx) => {
    if (!isNum(ctx.phases)) return null;
    if (!routed(run)) return 0;
    const reached = run.log?.brindle_phase_reached;
    return isNum(reached) ? (reached >= ctx.phases ? 1 : 0) : null;
  },
  kills: ({ log }) => (isNum(log?.tallies?.kills) ? log.tallies.kills : null),
  parts: ({ log }) => {
    const stages = (log?.stages ?? []).filter((s) => Array.isArray(s?.part_ids_at_exit));
    return stages.length ? stages[stages.length - 1].part_ids_at_exit.length : null;
  },
  panels: ({ bot }) => (Array.isArray(bot.panels) ? bot.panels.length : null),
  rogues_beaten: ({ bot }) => stageCount(bot, "rogues_beaten"),
  secrets_found: ({ bot }) => stageCount(bot, "secrets_found"),
};

const within = (v, row) =>
  v !== null &&
  (row.min === undefined || v >= row.min - 1e-9) &&
  (row.max === undefined || v <= row.max + 1e-9);

export function describeBand(row, unit = row.unit ?? "") {
  if (String(row.stat ?? "").startsWith("share")) {
    const pc = (x) => `${Math.round(x * 100)}%`;
    if (row.min !== undefined && row.max !== undefined) return `${pc(row.min)}-${pc(row.max)}`;
    if (row.min !== undefined) return `>= ${pc(row.min)}`;
    if (row.max !== undefined) return `<= ${pc(row.max)}`;
  }
  const u = unit ? ` ${unit}` : "";
  if (row.min !== undefined && row.max !== undefined) return `${row.min}-${row.max}${u}`;
  if (row.min !== undefined) return `>= ${row.min}${u}`;
  if (row.max !== undefined) return `<= ${row.max}${u}`;
  return "-";
}

const fmt = (v) => (v === null ? "n/a" : Number.isInteger(v) ? String(v) : v.toFixed(2));

function botRow(row, runs, ctx) {
  const byPolicy = (policy) => runs.filter((r) => r.bot.policy === policy);
  if (row.stat === "each_policy") {
    const counts = ctx.policies.map((p) => {
      const got = new Set(byPolicy(p).map((r) => r.bot.seed));
      let n = 0;
      while (got.has(n + 1)) n++;
      return [p, n];
    });
    return {
      measured: counts.map(([p, n]) => `${p} seeds 1-${n}`).join(", "),
      pass: counts.every(([, n]) => within(n, row)),
    };
  }
  const measure = MEASURES[row.metric];
  if (!measure) return { measured: `unknown metric ${row.metric}`, pass: false };
  const values = (list) => list.map((r) => measure(r, ctx));
  const lacking = (list, all) => {
    const gaps = all.filter((v) => !isNum(v)).length;
    if (!list.length) return `no ${row.policy ?? ""} runs`.replace("  ", " ");
    return gaps ? `no data: ${gaps} of ${list.length} runs lack the field` : null;
  };
  if (row.stat === "median_gap") {
    const sides = ["completionist", "skipper"].map((p) => {
      const list = byPolicy(p);
      const all = values(list);
      return { p, why: lacking(list, all), m: median(all) };
    });
    const bad = sides.find((x) => x.why);
    if (bad) return { measured: `${bad.p}: ${bad.why}`, pass: false, noData: true };
    const [a, b] = sides.map((x) => x.m);
    const gap = a - b;
    return {
      measured: `completionist ${fmt(a)}, skipper ${fmt(b)} (gap ${fmt(gap)})`,
      pass: within(gap, row),
    };
  }
  const list = row.policy ? byPolicy(row.policy) : runs;
  const all = values(list);
  const vs = all.filter(isNum);
  const why = lacking(list, all);
  if (why) return { measured: why, pass: false, noData: true };
  let v = null;
  if (row.stat === "median") v = median(vs);
  else if (row.stat === "min") v = Math.min(...vs);
  else if (row.stat === "max") v = Math.max(...vs);
  else if (row.stat === "share") v = vs.reduce((s, x) => s + x, 0) / all.length;
  else if (row.stat === "share_positive") v = vs.filter((x) => x > 0).length / all.length;
  else return { measured: `unknown stat ${row.stat}`, pass: false };
  const tail = "";
  const shown = row.stat.startsWith("share")
    ? `${Math.round(v * 100)}% of ${all.length}`
    : `${fmt(v)}${row.unit ? " " + row.unit : ""} over ${vs.length}`;
  return { measured: shown + tail, pass: within(v, row) };
}

const allMedian = (vs) => (vs.length && vs.every(isNum) ? median(vs) : null);

export function stageSeconds(run, stage) {
  const parks = (run.bot.stages ?? []).filter((s) => s?.stage === 1 || s?.stage === 2);
  if (stage === "boss") {
    if (
      !routed(run) ||
      !isNum(run.bot.game_seconds) ||
      parks.length !== 2 ||
      !parks.every((s) => isNum(s.exit_s))
    )
      return null;
    return run.bot.game_seconds - parks[0].exit_s - parks[1].exit_s;
  }
  const row = parks.find((s) => s.stage === stage);
  return isNum(row?.exit_s) && row.exit_s > 0 ? row.exit_s : null;
}

const runSeconds = (run) =>
  routed(run) && isNum(run.bot.game_seconds) ? run.bot.game_seconds : null;

export function pacingChecks(name, pacing, runs) {
  const pol = (p) => runs.filter((r) => r.bot.policy === p);
  const stage = (policy, filter) =>
    (pacing.stages ?? []).filter(filter).map((st) => ({
      what: st.id,
      band: pacingBand(st[policy]),
      value: allMedian(pol(policy).map((r) => stageSeconds(r, st.stage))),
    }));
  if (name === "skipper_total" || name === "completionist_total") {
    const policy = name.split("_")[0];
    return [
      {
        what: "run",
        band: pacingBand(pacing.run?.[policy]),
        value: allMedian(pol(policy).map(runSeconds)),
      },
    ];
  }
  if (name === "skipper_stage") return stage("skipper", (st) => st.stage !== "boss");
  if (name === "brindle_fight") return stage("skipper", (st) => st.stage === "boss");
  return [];
}

export function pacingBand(spec) {
  const ok = (x) => x === undefined || isNum(x);
  if (!spec || !ok(spec.min) || !ok(spec.max) || (spec.min === undefined && spec.max === undefined))
    return null;
  return { min: spec.min, max: spec.max };
}

function pacingRow(row, runs, pacing) {
  if (!pacing) return { measured: "pacing file not on this base", pass: false, noData: true };
  if (pacing.schema !== 1)
    return {
      measured: `pacing file schema ${pacing.schema}, checker reads 1`,
      pass: false,
      noData: true,
    };
  const checks = pacingChecks(row.band, pacing, runs);
  if (!checks.length || checks.some((c) => !c.band))
    return {
      measured: `no numeric min/max for ${row.band} in the pacing file`,
      pass: false,
      noData: true,
    };
  const threshold = checks.map((c) => `${c.what} ${describeBand(c.band, "s")}`).join("; ");
  const missing = checks.filter((c) => c.value === null);
  if (missing.length)
    return {
      measured: `no data: ${missing.map((c) => c.what).join(", ")} not on every run`,
      threshold,
      pass: false,
      noData: true,
    };
  return {
    measured: checks
      .map((c) => `${c.what} median ${fmt(c.value)} s (${(c.value / 60).toFixed(1)} bot-min)`)
      .join("; "),
    threshold,
    pass: checks.every((c) => within(c.value, c.band)),
  };
}

function beatRow(row, runs, ctx) {
  const entries = runs.flatMap((r) =>
    Array.isArray(r.log?.flourishes) ? r.log.flourishes.map((f) => ({ ...f, run: r })) : [],
  );
  if (row.check === "present") {
    if (ctx.beatRowsText === null)
      return { measured: "beat rows file not on this base", pass: false, noData: true };
    const missingRows = ctx.beats.filter((id) => !new RegExp(`"${id}"`).test(ctx.beatRowsText));
    const seen = new Set(entries.filter((e) => e.full !== false).map((e) => e.id));
    const unseen = ctx.beats.filter((id) => !seen.has(id));
    const parts = [];
    if (missingRows.length) parts.push(`no row: ${missingRows.join(", ")}`);
    if (unseen.length) parts.push(`never played on a fresh profile: ${unseen.join(", ")}`);
    return {
      measured: parts.length
        ? parts.join("; ")
        : `${ctx.beats.length} of ${ctx.beats.length} rows, all played`,
      pass: parts.length === 0,
      noData: !entries.length,
    };
  }
  if (!entries.length)
    return { measured: "no flourishes in the run log", pass: false, noData: true };
  if (row.check === "each_max") {
    const full = entries.filter((e) => e.full !== false && isNum(e.s));
    const worst = full.sort((a, b) => b.s - a.s)[0];
    if (!worst) return { measured: "no full-length beat with a length", pass: false, noData: true };
    return { measured: `longest ${worst.id} ${fmt(worst.s)} s`, pass: within(worst.s, row) };
  }
  if (row.check === "repeat_total") {
    const repeats = runs.filter(
      (r) =>
        Array.isArray(r.log?.flourishes) &&
        r.log.flourishes.length &&
        r.log.flourishes.every((f) => f.full === false),
    );
    if (!repeats.length)
      return { measured: "no repeat-profile run in the inputs", pass: false, noData: true };
    if (repeats.some((r) => r.log.flourishes.some((f) => !isNum(f.s))))
      return { measured: "a repeat run's beat has no length", pass: false, noData: true };
    const totals = repeats.map((r) => r.log.flourishes.reduce((s, f) => s + f.s, 0));
    const worst = Math.max(...totals);
    return {
      measured: `worst repeat run ${fmt(worst)} s over ${repeats.length}`,
      pass: within(worst, row),
    };
  }
  return { measured: `unknown check ${row.check}`, pass: false };
}

export function world1Placeholders(findings) {
  return findings.filter((f) => f.kind !== "park" || WORLD1_MAPS.includes(f.where));
}

function placeholderRow(row, findings) {
  const mine = world1Placeholders(findings);
  const total = mine.reduce((s, f) => s + (f.count ?? 1), 0);
  const sample = mine
    .slice(0, 3)
    .map((f) => `${f.where}: ${f.what}`)
    .join("; ");
  return { measured: `${total}${sample ? " (" + sample + ")" : ""}`, pass: within(total, row) };
}

function frameRow(row, frames, scenes) {
  const missing = scenes.filter((s) => !frames[s]);
  if (missing.length === scenes.length)
    return { measured: "no frame summaries given", pass: false, noData: true };
  const parts = scenes.map((s) =>
    frames[s]
      ? `${s} p99 ${frames[s].p99_ms} ms, ${frames[s].over_hitch} over ${frames[s].budget?.hitch_ms ?? "?"} ms${frames[s].pass ? "" : " MISS"}`
      : `${s} missing`,
  );
  return {
    measured: parts.join("; "),
    pass: missing.length === 0 && scenes.every((s) => frames[s].pass === true),
  };
}

function regrade(cell, overrides = {}) {
  if (!cell.columns) return cell;
  const columns = {};
  for (const [id, col] of Object.entries(cell.columns)) {
    if (typeof col?.rate !== "number") {
      columns[id] = col;
      continue;
    }
    const target = overrides[id] ?? targetFor(cell.kind, id);
    columns[id] = { ...col, target, ok: col.incomplete ? null : meets(target, col.rate) };
  }
  return { ...cell, columns };
}

function challengeRow(row, table, cells) {
  if (!table) return { measured: "no challenge table given", pass: false, noData: true };
  const byCell = new Map(
    (table.table ?? []).map((c) => [c.cell, regrade(c, row.targets?.[c.cell])]),
  );
  const unmeasured = (id) =>
    Object.keys(row.targets?.[id] ?? {}).filter((col) => {
      const c = byCell.get(id).columns[col];
      return typeof c?.rate !== "number" || c.incomplete;
    });
  const verdictOf = (id) => {
    if (!byCell.has(id)) return "missing";
    if (!byCell.get(id).columns) return "no columns";
    const gap = unmeasured(id);
    return gap.length ? `not measured (${gap.join(", ")})` : cellVerdict(byCell.get(id));
  };
  const verdicts = cells.map((id) => [id, verdictOf(id)]);
  const ungraded = verdicts.some(
    ([, v]) => v === "missing" || v === "no columns" || v.startsWith("not measured"),
  );
  return {
    measured:
      verdicts.map(([id, v]) => `${id} ${v}`).join(", ") +
      (table.commit ? ` (table at ${String(table.commit).slice(0, 8)})` : ""),
    pass: verdicts.every(([, v]) => v === "pass"),
    ...(ungraded ? { noData: true } : {}),
    threshold: recordedBands(row.targets),
  };
}

function recordedBands(targets) {
  const bands = Object.entries(targets ?? {}).flatMap(([cell, cols]) =>
    Object.entries(cols).map(
      ([col, t]) =>
        `${cell} ${col} ${[t.min != null ? `>= ${Math.round(t.min * 100)}%` : "", t.max != null ? `<= ${Math.round(t.max * 100)}%` : ""].filter(Boolean).join(" ")}`,
    ),
  );
  return bands.length ? `harness targets; recorded: ${bands.join(", ")}` : "harness targets";
}

export const otherWorld = (finding) => /^World [23]\b/.test(finding.meets ?? "");

function findingsRow(row, findings) {
  if (!findings)
    return { measured: "play findings file not on this base", pass: false, noData: true };
  if (findings.problems.length)
    return {
      measured: `the findings file does not parse (${findings.problems.length} problem(s))`,
      pass: false,
      noData: true,
    };
  const mine = findings.rows.filter((f) => row.grades.includes(f.grade) && !otherWorld(f));
  return {
    measured: `${mine.length}${mine.length ? " (" + mine.map((f) => f.id).join(", ") + ")" : ""}`,
    pass: within(mine.length, row),
  };
}

function ledgerRow(row, ledger, today) {
  if (!ledger)
    return { measured: "known-failing ledger not on this base", pass: false, noData: true };
  if (ledger.problems.length)
    return {
      measured: `the ledger does not parse (${ledger.problems.length} problem(s))`,
      pass: false,
      noData: true,
    };
  const late = pastReview(ledger.rows, today);
  return {
    measured: `${late.length} of ${ledger.rows.length} past review on ${today}${
      late.length
        ? " (" +
          late
            .slice(0, 4)
            .map((r) => r.test)
            .join(", ") +
          (late.length > 4 ? ", ..." : "") +
          ")"
        : ""
    }`,
    pass: within(late.length, row),
  };
}

export const COMMIT = /^[0-9a-f]{7,40}$/;
export function receiptRow(row, receipt, head) {
  if (!receipt)
    return {
      measured: `no receipt (${row.producer ?? "no producer yet"})`,
      pass: false,
      noData: true,
    };
  if (typeof head !== "string" || !COMMIT.test(head))
    return {
      measured: "no head to judge the receipt against (--head <commit>)",
      pass: false,
      noData: true,
    };
  if (typeof receipt.head !== "string" || !COMMIT.test(receipt.head))
    return { measured: "the receipt names no head", pass: false, noData: true };
  if (!(head.startsWith(receipt.head) || receipt.head.startsWith(head)))
    return {
      measured: `stale receipt: written at ${receipt.head.slice(0, 9)}, judging ${head.slice(0, 9)}`,
      pass: false,
      noData: true,
    };
  const said =
    typeof receipt.measured === "string" && receipt.measured
      ? receipt.measured
      : receipt.pass === true
        ? "pass"
        : "fail";
  if (row.plant && receipt.plant_caught !== true)
    return { measured: `void, the planted fault was not shown caught: ${said}`, pass: false };
  return { measured: said, pass: receipt.pass === true };
}

export function evaluate(spec, inputs) {
  const ctx = {
    policies: spec.bots?.policies ?? ["skipper", "completionist"],
    beats: spec.beats ?? [],
    beatRowsText: inputs.beatRowsText ?? null,
    phases: inputs.phases ?? null,
  };
  const runs = inputs.runs ?? [];
  return spec.rows.map((specRow) => {
    let row = specRow;
    if (row.max_from_pacing) {
      const max = inputs.pacing?.[row.max_from_pacing];
      if (!isNum(max))
        return {
          id: row.id,
          area: row.area,
          label: row.label,
          status: row.status,
          enforced_from: row.enforced_from ?? null,
          measured: `no ${row.max_from_pacing} in the pacing file`,
          threshold: "-",
          verdict: row.status === "info" ? "info" : "no data",
          blocks: row.status === "gate",
        };
      row = { ...row, max };
    }
    let result;
    if (row.status === "sitting")
      return {
        id: row.id,
        area: row.area,
        label: row.label,
        status: row.status,
        enforced_from: null,
        measured: "-",
        threshold: "-",
        verdict: "his call",
        blocks: false,
      };
    if (row.cadence === "sitting" && !inputs.sitting)
      result = { measured: "not run (sitting cadence; pass --sitting)", pass: null, skipped: true };
    else if (row.source === "bots")
      result = runs.length
        ? botRow(row, runs, ctx)
        : { measured: "no bot runs given", pass: false, noData: true };
    else if (row.source === "pacing") result = pacingRow(row, runs, inputs.pacing);
    else if (row.source === "beats") result = beatRow(row, runs, ctx);
    else if (row.source === "placeholders") result = placeholderRow(row, inputs.findings ?? []);
    else if (row.source === "frames")
      result = frameRow(row, inputs.frames ?? {}, spec.frame_scenes ?? []);
    else if (row.source === "challenge")
      result = challengeRow(row, inputs.challenge, spec.challenge_cells ?? []);
    else if (row.source === "findings") result = findingsRow(row, inputs.playFindings ?? null);
    else if (row.source === "ledger") result = ledgerRow(row, inputs.ledger ?? null, inputs.today);
    else if (row.source === "receipt")
      result = receiptRow(row, inputs.receipts?.[row.id] ?? null, inputs.head ?? null);
    else result = { measured: `unknown source ${row.source}`, pass: false };
    if (row.band_from) {
      const band = constBand(inputs.bandTexts?.[row.band_from.file] ?? null, row.band_from.const);
      if (band && row.source === "bots") {
        const again = botRow({ ...row, ...band }, runs, ctx);
        result = {
          ...again,
          threshold: `${describeBand(band)} (${path.basename(row.band_from.file)} ${row.band_from.const})`,
        };
      } else if (!band) {
        const where = inputs.bandTexts?.[row.band_from.file]
          ? `${row.band_from.const} not found in`
          : "band file not on this base:";
        result = {
          measured: result.measured,
          threshold: `${where} ${path.basename(row.band_from.file)}`,
          pass: false,
          noData: true,
        };
      }
    }
    const threshold = result.threshold ?? (row.status === "info" ? "-" : describeBand(row));
    const verdict = result.skipped
      ? "not run"
      : row.status === "info"
        ? "info"
        : result.pass
          ? "pass"
          : result.noData
            ? "no data"
            : "miss";
    const blocks = row.status === "gate" && !result.skipped && result.pass !== true;
    return {
      id: row.id,
      area: row.area,
      label: row.label,
      status: row.status,
      enforced_from: row.enforced_from ?? null,
      measured: result.measured,
      threshold,
      verdict,
      blocks,
    };
  });
}

export const passed = (rows) => rows.every((r) => !r.blocks);

export function renderTable(rows, meta = {}) {
  const lines = [
    `# World 1 bands${meta.commit ? " at " + meta.commit : ""}`,
    "",
    "| Row | Area | Measured | Band | Verdict | Status |",
    "| --- | --- | --- | --- | --- | --- |",
  ];
  for (const r of rows.filter((x) => x.status !== "sitting")) {
    const status =
      r.status === "report" && r.enforced_from
        ? `report until ${r.enforced_from.join(", ")}`
        : r.status;
    lines.push(
      `| ${r.label} | ${r.area} | ${r.measured.replace(/\|/g, "/")} | ${r.threshold} | ${r.verdict}${r.blocks ? " (blocks)" : ""} | ${status} |`,
    );
  }
  const blocking = rows.filter((r) => r.blocks);
  lines.push(
    "",
    blocking.length
      ? `world 1 bands: NOT READY (${blocking.length} gate row(s): ${blocking.map((r) => r.id).join(", ")})`
      : "world 1 bands: READY (every gate row passes)",
  );
  const his = rows.filter((r) => r.status === "sitting");
  if (his.length)
    lines.push(
      "",
      "Only Andrew decides these, at his sitting (listed, never graded):",
      ...his.map((r) => `- ${r.area}: ${r.label}`),
    );
  return lines.join("\n");
}

export function parseArgs(argv) {
  const args = {
    bots: [],
    challenge: null,
    frames: {},
    sitting: false,
    json: false,
    out: null,
    receipts: {},
    receiptDirs: [],
    head: null,
    today: new Date().toISOString().slice(0, 10),
    rows: ROWS_FILE,
    project: path.join(root, "sketches/core-loop"),
  };
  const value = (i, name) => {
    const v = argv[i + 1];
    if (v === undefined || v === "" || v.startsWith("--")) throw new Error(`${name} needs a value`);
    return v;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--bots") args.bots.push(value(i++, a));
    else if (a === "--challenge") args.challenge = value(i++, a);
    else if (a === "--frames") {
      const v = value(i++, a);
      const eq = v.indexOf("=");
      if (eq < 1 || eq === v.length - 1)
        throw new Error(`--frames takes <scene>=<summary.json>: ${v}`);
      args.frames[v.slice(0, eq)] = v.slice(eq + 1);
    } else if (a === "--receipt") {
      const v = value(i++, a);
      const eq = v.indexOf("=");
      if (eq < 1 || eq === v.length - 1)
        throw new Error(`--receipt takes <row id>=<receipt.json>: ${v}`);
      args.receipts[v.slice(0, eq)] = v.slice(eq + 1);
    } else if (a === "--receipts") args.receiptDirs.push(value(i++, a));
    else if (a === "--head") {
      args.head = value(i++, a);
      if (!COMMIT.test(args.head))
        throw new Error(`--head takes 7 to 40 hex characters of a commit: ${args.head}`);
    } else if (a === "--today") {
      args.today = value(i++, a);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(args.today) || Number.isNaN(Date.parse(args.today)))
        throw new Error(`--today takes YYYY-MM-DD: ${args.today}`);
    } else if (a === "--sitting") args.sitting = true;
    else if (a === "--json") args.json = true;
    else if (a === "--out") args.out = value(i++, a);
    else if (a === "--rows") args.rows = path.resolve(value(i++, a));
    else if (a === "--project") args.project = path.resolve(value(i++, a));
    else throw new Error(`unknown argument: ${a}`);
  }
  return args;
}

function checkoutHead() {
  try {
    return execFileSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const head = args.head ?? checkoutHead();
  const spec = JSON.parse(read(args.rows));
  const runs = args.bots.flatMap((d) => readBotDir(path.resolve(d)));
  const frames = Object.fromEntries(
    Object.entries(args.frames).map(([k, f]) => [k, JSON.parse(readFileSync(f, "utf8"))]),
  );
  const receiptFiles = {};
  for (const dir of args.receiptDirs)
    for (const row of spec.rows.filter((r) => r.source === "receipt"))
      if (existsSync(path.join(dir, `${row.id}.json`)))
        receiptFiles[row.id] = path.join(dir, `${row.id}.json`);
  Object.assign(receiptFiles, args.receipts);
  const receipts = Object.fromEntries(
    Object.entries(receiptFiles).map(([k, f]) => [k, JSON.parse(readFileSync(f, "utf8"))]),
  );
  const bandFiles = spec.rows.filter((r) => r.band_from).map((r) => r.band_from.file);
  const inputs = {
    runs,
    sitting: args.sitting,
    pacing: has(spec.pacing_file) ? JSON.parse(read(spec.pacing_file)) : null,
    challenge: args.challenge ? JSON.parse(readFileSync(args.challenge, "utf8")) : null,
    frames,
    findings: scan(args.project),
    playFindings: has(FINDINGS_FILE) ? parseFindings(read(FINDINGS_FILE)) : null,
    ledger: has(LEDGER_FILE) ? parseLedger(read(LEDGER_FILE)) : null,
    receipts,
    head,
    today: args.today,
    beatRowsText: has(spec.beat_rows_file) ? read(spec.beat_rows_file) : null,
    phases: has(spec.brindle_phase_names_file)
      ? phaseCount(read(spec.brindle_phase_names_file))
      : null,
    bandTexts: Object.fromEntries(bandFiles.filter(has).map((f) => [f, read(f)])),
  };
  const rows = evaluate(spec, inputs);
  const out = args.json
    ? JSON.stringify({ ready: passed(rows), rows }, null, 2)
    : renderTable(rows);
  console.log(out);
  if (!args.json)
    console.log(
      `Read ${args.sitting ? "with" : "without"} --sitting, judging ${head ? head.slice(0, 12) : "no head"}.`,
    );
  if (args.out) {
    mkdirSync(args.out, { recursive: true });
    writeFileSync(
      path.join(args.out, "world1-bands.json"),
      JSON.stringify(
        { ready: passed(rows), sitting: args.sitting, head, bots: args.bots, rows },
        null,
        2,
      ) + "\n",
    );
    writeFileSync(path.join(args.out, "world1-bands.md"), renderTable(rows) + "\n");
  }
  process.exitCode = passed(rows) ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
