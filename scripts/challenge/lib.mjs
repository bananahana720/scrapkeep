// The challenge lane's pure half: the band targets, which runs a table needs, how one run is
// graded, and how the grades become a table. scripts/challenge/run.mjs does the running; nothing
// here starts Godot. The skill bands themselves (Novice, Learner, Expert) live in
// sketches/core-loop/tools/skill_band.gd.

export const PILOTS = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"];

// Coordinator ruling, DECISIONS.md section 5, 19 Oct 01:58 (verbatim):
// "Base-tier targets with an ordinary build: bosses and Wardens beat Novice in at least 85% of
// attempts; Learner wins 15-35% on a first attempt and 60% or more by the fifth; Expert wins 85%
// or more; a top-decile (cracked) build with an Expert wins 97% or more and keeps the existing
// growth ratios. Every lethal attack has a readable tell of at least 0.6 s, and no boss kills a
// Learner in its first 45 s. Parks: Novice reaches the world's Warden in at most half its runs,
// Learner in 80% or more."
// "Beat Novice in 85%" is a Novice win rate of at most 15%. Rates are win fractions.
export const TARGETS = {
  fight: {
    novice: { max: 0.15 },
    learner1: { min: 0.15, max: 0.35 },
    learner5: { min: 0.6 },
    expert: { min: 0.85 },
    expertTop: { min: 0.97 },
  },
  world: {
    novice: { max: 0.5 },
    learner1: { min: 0.8 },
  },
  earliestLearnerBossDeathS: 45,
  tellS: 0.6, // not measured here: the bot cannot tell what a player reads
};

export const COLUMNS = [
  { id: "novice", label: "Novice", band: "novice", attempt: 1, build: "ordinary" },
  { id: "learner1", label: "Learner a1", band: "learner", attempt: 1, build: "ordinary" },
  { id: "learner5", label: "Learner a5", band: "learner", attempt: 5, build: "ordinary" },
  { id: "expert", label: "Expert ordinary", band: "expert", attempt: 1, build: "ordinary" },
  { id: "expertTop", label: "Expert top", band: "expert", attempt: 1, build: "top" },
];
// The worlds' park question is only reach: Novice and Learner on a first attempt.
export const WORLD_COLUMNS = ["novice", "learner1"];

// stage = the stage the fight happens on; the boss waits after a world's last stage.
export const BOSSES = [
  { id: "brindle", name: "Admiral Brindle", world: 1, stage: 2 },
  { id: "waking", name: "the Waking", world: 2, stage: 4 },
  { id: "mind", name: "the Mind", world: 3, stage: 6 },
];
export const WARDENS = [1, 2, 3, 4, 5, 6].map((n) => ({ id: "w" + n, stage: n, world: Math.ceil(n / 2) }));
export const WORLDS = [1, 2, 3].map((w) => ({ id: "world" + w, world: w, first: 2 * w - 1, last: 2 * w }));

// A Warden run: the fight may last 240 s from engagement (over 3x the 45-85 s stagger bands); the stage cap is lifted
// to 600 s so it cannot cut an engaged fight first, and the tick guard sits past it.
export const WARDEN_FIGHT_LIMIT_S = 240;
export const WARDEN_STAGE_LIMIT_S = 600;
export const WARDEN_TICKS = (WARDEN_STAGE_LIMIT_S + 100) * 90;
export const DEFAULT_SEEDS = { fight: 24, world: 16 };
export const BOSS_TICKS = 480 * 90; // the driver's own boss limit is 420 s
export const WORLD_TICKS = 700 * 90;
export const LIBRARY_STAGES = 6;
export const MIN_BUCKET = 3;

// --- build library --------------------------------------------------------------------------

// Rank a stage's docs by mass, then parts count. ordinary = rank percentile 40 to 60, top = 90 and up;
// each bucket widens (ordinary both ways, top downward) until it holds MIN_BUCKET docs or every doc.
export function pickBuilds(docs) {
  const ranked = [...docs].sort((a, b) => a.mass - b.mass || a.parts - b.parts || String(a.file).localeCompare(String(b.file)));
  const n = ranked.length;
  if (n === 0) return { ordinary: [], top: [], ranked };
  const pct = (i) => (n === 1 ? 0.5 : i / (n - 1));
  let lo = ranked.findIndex((_, i) => pct(i) >= 0.4 - 1e-9);
  let hi = ranked.length - 1 - [...ranked].reverse().findIndex((_, i) => pct(n - 1 - i) <= 0.6 + 1e-9);
  if (lo < 0 || hi < lo) {
    lo = Math.floor((n - 1) / 2);
    hi = lo;
  }
  while (hi - lo + 1 < Math.min(MIN_BUCKET, n)) {
    if (lo > 0) lo--;
    if (hi - lo + 1 < Math.min(MIN_BUCKET, n) && hi < n - 1) hi++;
  }
  let start = ranked.findIndex((_, i) => pct(i) >= 0.9 - 1e-9);
  if (start < 0) start = n - 1;
  while (n - start < Math.min(MIN_BUCKET, n)) start--;
  return { ordinary: ranked.slice(lo, hi + 1), top: ranked.slice(start), ranked };
}

// An entrance file is the RunStore's envelope: { generation, schema, run: { stage, mass, parts, ... } }.
export function describeDoc(file, text) {
  const doc = JSON.parse(text);
  const run = doc.run ?? doc;
  return {
    file, stage: run.stage, pilot: run.class_id, mass: run.mass ?? 0, heft_class: run.heft_class ?? 0,
    parts: (run.parts ?? []).length, hp: run.hp, max_hp: run.max_hp,
  };
}

// --- planning the table ---------------------------------------------------------------------

// columns: ids from COLUMNS (run.mjs adds expertTop beside expert unless --no-top).
// builds: { [stage]: { ordinary: [doc], top: [doc] } } (pickBuilds per stage); doc.file is the path to hand to --entrance.
// A cell is a fight or a park; a column is a band (and a build bucket); a job is one seed of one column of one cell.
export function planCells(opts) {
  const {
    builds = {}, cells = ["boss", "warden", "world"], only = null, seeds = null, columns = COLUMNS.map((c) => c.id), persona = "brawler", wardenPersona = "skipper", parkPersona = "skipper",
  } = opts;
  const jobs = [];
  const want = (id) => !only || only.includes(id);
  const defs = [];
  for (const b of BOSSES) if (cells.includes("boss") && want(b.id)) defs.push({ kind: "boss", ...b });
  for (const w of WARDENS) if (cells.includes("warden") && want(w.id)) defs.push({ kind: "warden", ...w });
  for (const w of WORLDS) if (cells.includes("world") && want(w.id)) defs.push({ kind: "world", ...w, stage: w.first });
  for (const def of defs) {
    const cols = COLUMNS.filter((c) => columns.includes(c.id) && (def.kind !== "world" || WORLD_COLUMNS.includes(c.id)));
    for (const col of cols) {
      const stage = def.kind === "world" ? def.first : def.stage;
      // Stage 1 is the start of a run: no build to carry, so it plays fresh (the seed picks the pilot).
      const docs = stage === 1 ? [null] : (builds[stage]?.[col.build] ?? []);
      const count = seeds ?? (def.kind === "world" ? DEFAULT_SEEDS.world : DEFAULT_SEEDS.fight);
      for (let i = 0; i < count; i++) {
        const doc = docs.length ? docs[i % docs.length] : undefined;
        if (doc === undefined) {
          jobs.push({ ...base(def, col, i, persona, wardenPersona, parkPersona), missing: true });
          continue;
        }
        jobs.push(base(def, col, i, persona, wardenPersona, parkPersona, doc));
      }
    }
  }
  return jobs;
}

// Seeds depend on the cell and the index only, so columns of a cell face the same seeds.
function cellSeed(def, i) {
  const slot = def.kind === "boss" ? def.world - 1 : def.kind === "warden" ? 3 + def.stage - 1 : 9 + def.world - 1;
  return 40000 + slot * 100 + i;
}

function base(def, col, i, persona, wardenPersona, parkPersona, doc = null) {
  const seed = cellSeed(def, i);
  const policy = def.kind === "world" ? parkPersona : def.kind === "warden" ? wardenPersona : persona;
  const from = def.kind === "world" ? def.first : def.stage;
  const args = ["--band=" + col.band, "--attempt=" + col.attempt, "--cell=" + def.id];
  if (doc) args.push("--entrance=" + doc.file, "--from-stage=" + from);
  else if (from !== 1) args.push("--from-stage=" + from);
  if (def.kind === "boss") args.push("--to-boss=1", "--until=" + def.stage, "--ticks=" + BOSS_TICKS);
  else if (def.kind === "warden") args.push("--until=" + def.stage, "--fight-limit=" + WARDEN_FIGHT_LIMIT_S, "--stage-limit=" + WARDEN_STAGE_LIMIT_S, "--ticks=" + WARDEN_TICKS);
  else args.push("--stop-at=engaged:" + def.last, "--ticks=" + WORLD_TICKS);
  return {
    id: `${def.id}-${col.id}-${seed}`, kind: def.kind, cell: def.id, stage: def.stage, column: col.id, band: col.band, attempt: col.attempt,
    build: def.kind === "world" ? "ordinary" : col.build, policy, seed, entrance: doc ? doc.file : null, pilot: doc?.pilot ?? null, args,
  };
}

// Job i of n goes to shard (i mod n) + 1: an even, deterministic split with each column spread across shards.
export function shardJobs(jobs, spec) {
  if (!spec) return jobs;
  const m = /^(\d+)\/(\d+)$/.exec(spec);
  if (!m || Number(m[1]) < 1 || Number(m[1]) > Number(m[2])) throw new Error("--shard must be i/n with 1 <= i <= n");
  return jobs.filter((_, k) => k % Number(m[2]) === Number(m[1]) - 1);
}

export function botArgs(job, out) {
  return [
    "--headless", "--fixed-fps", "90", "--path", "sketches/core-loop", "--script", "res://tools/band_run.gd", "--",
    "--out=" + out, "--policy=" + job.policy, "--seeds=" + job.seed, "--table=park", "--gate=1", ...job.args,
  ];
}

// --- grading --------------------------------------------------------------------------------

// win / loss / timeout / error. A timeout (a stall, a fight cap, a tick guard) is not a win; an error
// (no row, or no fight reached) is not either, and the table counts both apart from losses.
export function gradeRun(kind, row, job = {}) {
  if (!row) return { result: "error", why: "no record" };
  const stages = row.stages ?? [];
  if (kind === "boss") {
    const boss = row.boss;
    if (boss?.defeated_s != null) return { result: "win", fightS: boss.defeated_s, hpLost: boss.hp_lost ?? null };
    if (row.outcome === "died") return { result: "loss", fightS: boss?.seconds ?? null, hpLost: boss?.hp_lost ?? null, diedS: boss?.died_s ?? boss?.seconds ?? null };
    if (row.outcome === "boss_stalled" || boss) return { result: "timeout", reason: row.outcome, fightS: boss?.seconds ?? null, hpLost: boss?.hp_lost ?? null };
    return { result: "error", why: "the boss was never entered (" + row.outcome + ")" };
  }
  if (kind === "warden") {
    const note = stages.find((s) => s.stage === (job.stage ?? row.stage_reached));
    if (note?.warden_broken_s != null) {
      const fightS = note.warden_engaged_s != null ? round2(note.warden_broken_s - note.warden_engaged_s) : null;
      return { result: "win", fightS, hpLost: note.hp_lost ?? null };
    }
    if (row.outcome === "died") return { result: "loss", fightS: null, hpLost: note?.hp_lost ?? null };
    return { result: "timeout", reason: row.outcome, fightS: null, hpLost: note?.hp_lost ?? null };
  }
  if (kind === "world") {
    if (row.outcome === "reached") return { result: "win", fightS: row.game_seconds ?? null, hpLost: null };
    if (row.outcome === "died") return { result: "loss", fightS: row.game_seconds ?? null, hpLost: null };
    return { result: "timeout", reason: row.outcome, fightS: row.game_seconds ?? null, hpLost: null };
  }
  throw new Error("unknown kind " + kind);
}

const round2 = (x) => Math.round(x * 100) / 100;

export function wilson(wins, n, z = 1.96) {
  if (!n) return { lo: 0, hi: 1 };
  const p = wins / n;
  const d = 1 + (z * z) / n;
  const centre = (p + (z * z) / (2 * n)) / d;
  const half = (z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n))) / d;
  return { lo: Math.max(0, centre - half), hi: Math.min(1, centre + half) };
}

export function median(xs) {
  const v = xs.filter((x) => x != null && Number.isFinite(x)).sort((a, b) => a - b);
  if (!v.length) return null;
  const m = v.length >> 1;
  return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
}

// One column of one cell: grades is the list of gradeRun results.
export function aggregate(grades) {
  const count = (r) => grades.filter((g) => g.result === r).length;
  const n = grades.length;
  const wins = count("win");
  const { lo, hi } = wilson(wins, n);
  const deaths = grades.filter((g) => g.result === "loss" && g.diedS != null).map((g) => g.diedS);
  return {
    n, wins, losses: count("loss"), timeouts: count("timeout"),
    capped: grades.filter((g) => g.result === "timeout" && ["fight_capped", "boss_stalled", "ticks_done"].includes(g.reason)).length,
    stalled: grades.filter((g) => g.result === "timeout" && !["fight_capped", "boss_stalled", "ticks_done"].includes(g.reason)).length, errors: count("error"), rate: n ? wins / n : null, lo, hi,
    medianFightS: median(grades.filter((g) => g.result === "win").map((g) => g.fightS)),
    medianHpLost: median(grades.map((g) => g.hpLost)),
    earliestDeathS: deaths.length ? Math.min(...deaths) : null,
    earlyDeaths: deaths.filter((s) => s < TARGETS.earliestLearnerBossDeathS).length,
  };
}

// ok = the point estimate meets the target; null = no target or no runs.
export function meets(target, rate) {
  if (!target || rate == null) return null;
  if (target.min != null && rate < target.min - 1e-9) return false;
  if (target.max != null && rate > target.max + 1e-9) return false;
  return true;
}

export function targetFor(kind, column) {
  return (kind === "world" ? TARGETS.world : TARGETS.fight)[column] ?? null;
}

export function describeTarget(t) {
  if (!t) return "";
  if (t.min != null && t.max != null) return `${pct(t.min)}-${pct(t.max)}`;
  return t.min != null ? `>= ${pct(t.min)}` : `<= ${pct(t.max)}`;
}

const pct = (x) => Math.round(x * 100) + "%";

// --- the table ------------------------------------------------------------------------------

// runs: rows as written to runs.ndjson: { job fields..., row }. Returns one entry per cell.
export function buildTable(runs) {
  const cells = new Map();
  for (const r of runs) {
    const key = r.cell;
    if (!cells.has(key)) cells.set(key, { cell: key, kind: r.kind, stage: r.stage, grades: {} });
    const c = cells.get(key);
    (c.grades[r.column] ??= []).push(r.grade ?? gradeRun(r.kind, r.row, r));
  }
  const order = [...BOSSES, ...WARDENS, ...WORLDS].map((d) => d.id);
  return [...cells.values()].sort((a, b) => order.indexOf(a.cell) - order.indexOf(b.cell)).map((c) => {
    const columns = {};
    for (const col of COLUMNS) {
      if (!c.grades[col.id]) continue;
      const a = aggregate(c.grades[col.id]);
      const target = targetFor(c.kind, col.id);
      columns[col.id] = { ...a, target, ok: meets(target, a.rate) };
    }
    const ord = columns.expert?.medianFightS;
    const top = columns.expertTop?.medianFightS;
    const l1 = columns.learner1;
    return {
      cell: c.cell, kind: c.kind, stage: c.stage, columns,
      growthRatio: ord && top ? round2(top / ord) : null,
      tell: c.kind === "boss" && l1 ? { earlyDeaths: l1.earlyDeaths, earliestDeathS: l1.earliestDeathS, ok: l1.earlyDeaths === 0 } : null,
    };
  });
}

export function cellVerdict(cell) {
  const marks = Object.values(cell.columns).map((c) => c.ok);
  const bad = marks.includes(false) || cell.tell?.ok === false;
  return bad ? "fail" : marks.includes(true) ? "pass" : "none";
}

function cellText(c) {
  if (!c) return "-";
  const mark = c.ok === null ? "" : c.ok ? " ✓" : " ✗";
  // A stall or a fight cap is the fight beating the player, not a win: shown beside the deaths.
  const extra = [c.losses ? `${c.losses} died` : "", c.capped ? `${c.capped} capped` : "", c.stalled ? `${c.stalled} stalled` : "", c.errors ? `${c.errors} error` : ""].filter(Boolean).join(", ");
  return `${pct(c.rate)} (${c.n}) [${pct(c.lo)}-${pct(c.hi)}]${mark} vs ${describeTarget(c.target)}${extra ? " (" + extra + ")" : ""}`;
}

const fmt = (x, d = 1) => (x == null ? "-" : Number(x).toFixed(d));

export function renderTable(table, meta = {}) {
  const lines = ["# Challenge band table", ""];
  if (meta.label) lines.push(`Label ${meta.label}${meta.commit ? ", commit " + meta.commit.slice(0, 8) : ""}${meta.when ? ", " + meta.when : ""}.`, "");
  lines.push("Win rate (runs) [Wilson 95%] ✓/✗ against the target; ✓/✗ judges the point estimate. Brackets after a cell count deaths, fight caps (fight_capped, boss_stalled) and stalls; none is a win. Fight s and HP lost are medians over the cell's runs; top/ord is the Expert top fight time over the Expert ordinary fight time.", "");
  const fights = table.filter((c) => c.kind !== "world");
  if (fights.length) {
    lines.push("## Bosses and Wardens", "");
    lines.push("| Cell | Novice | Learner a1 | Learner a5 | Expert ordinary | Expert top | Learner a1 deaths < 45 s | Fight s (ord / top) | HP lost (ord) | top/ord |");
    lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |");
    for (const c of fights) {
      const t = c.tell;
      const tell = t ? (t.ok ? "0 ✓" : `${t.earlyDeaths} ✗ (earliest ${fmt(t.earliestDeathS)} s)`) : "-";
      lines.push(`| ${c.cell} | ${["novice", "learner1", "learner5", "expert", "expertTop"].map((id) => cellText(c.columns[id])).join(" | ")} | ${tell} | ${fmt(c.columns.expert?.medianFightS)} / ${fmt(c.columns.expertTop?.medianFightS)} | ${fmt(c.columns.expert?.medianHpLost)} | ${c.growthRatio ?? "-"} |`);
    }
    lines.push("");
  }
  const worlds = table.filter((c) => c.kind === "world");
  if (worlds.length) {
    lines.push("## Parks (reach the world's Warden)", "");
    lines.push("| World | Novice | Learner a1 | Game s to reach (Learner) |", "| --- | --- | --- | --- |");
    for (const c of worlds) lines.push(`| ${c.cell} | ${cellText(c.columns.novice)} | ${cellText(c.columns.learner1)} | ${fmt(c.columns.learner1?.medianFightS)} |`);
    lines.push("");
  }
  const failing = table.filter((c) => cellVerdict(c) === "fail").map((c) => c.cell);
  lines.push(failing.length ? `Cells with a ✗: ${failing.join(", ")}.` : "No cell has a ✗.", "");
  return lines.join("\n");
}

export function parseNdjson(text) {
  const rows = [];
  for (const line of (text ?? "").split("\n")) {
    if (!line.trim()) continue;
    try {
      rows.push(JSON.parse(line));
    } catch {
      // A line cut short by a kill is itself a missing run.
    }
  }
  return rows;
}

// Estimated wall seconds per job by kind (measured on the 4-vCPU box; see README), for --dry-run.
export const SECONDS_PER_JOB = { boss: 335, warden: 330, world: 330 }; // wall s per job at 4 parallel on the 4-vCPU box, smoke medians; world is a guess (no sample before 19 Oct)

export function estimate(jobs, parallel = 4, perKind = SECONDS_PER_JOB) {
  const total = jobs.reduce((s, j) => s + (perKind[j.kind] ?? 120), 0);
  return { jobs: jobs.length, cpuSeconds: total, wallSeconds: Math.ceil(total / Math.max(1, parallel)) };
}

// Library sharding: shards are separate folders with their own index.json (file paths relative to the folder).
// Returns the joined entries, each with `from` (its shard folder); a file name seen twice keeps the first.
export function mergeLibraryIndexes(shards) {
  const seen = new Set();
  const out = [];
  for (const { dir, index } of shards) {
    for (const d of index) {
      if (seen.has(d.file)) continue;
      seen.add(d.file);
      out.push({ ...d, from: dir });
    }
  }
  return out.sort((a, b) => a.stage - b.stage || a.file.localeCompare(b.file));
}

// Wall and game seconds per job by kind, for re-estimating --dry-run.
export function wallStats(runs) {
  const out = {};
  for (const kind of ["boss", "warden", "world"]) {
    const r = runs.filter((x) => x.kind === kind);
    if (!r.length) continue;
    out[kind] = { jobs: r.length, medianWallS: median(r.map((x) => x.wallS)), maxWallS: Math.max(...r.map((x) => x.wallS ?? 0)), medianGameS: median(r.map((x) => x.row?.game_seconds)) };
  }
  return out;
}
