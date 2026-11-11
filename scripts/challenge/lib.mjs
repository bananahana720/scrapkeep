// The challenge lane's pure half: the band targets, which runs a table needs, how one run is
// graded, and how the grades become a table. scripts/challenge/run.mjs does the running; nothing
// here starts Godot. The skill bands themselves (Novice, Learner, Expert) live in
// sketches/core-loop/tools/skill_band.gd.

import fairnessLines from "./fairness.json" with { type: "json" };

export const PILOTS = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"];

// Coordinator ruling, DECISIONS.md section 5, 19 Oct 01:58 (verbatim):
// "Base-tier targets with an ordinary build: bosses and Wardens beat Novice in at least 85% of
// attempts; Learner wins 15-35% on a first attempt and 60% or more by the fifth; Expert wins 85%
// or more; a top-decile (cracked) build with an Expert wins 97% or more and keeps the existing
// growth ratios. Every lethal attack has a readable tell of at least 0.6 s, and no boss kills a
// Learner in its first 45 s. Parks: Novice reaches the world's Warden in at most half its runs,
// Learner in 80% or more."
// "Beat Novice in 85%" is a Novice win rate of at most 15%. Rates are win fractions.
// Learner attempt 1 is information only at bosses and Wardens (DECISIONS section 5, 19 Oct 19:00,
// which replaced it as a graded band), so a fight cell has no learner1 target and no ✓/✗ there;
// LEARNER1_FIGHT_REFERENCE is the old 15-35% range, printed beside the table for reading only.
export const LEARNER1_FIGHT_REFERENCE = { min: 0.15, max: 0.35 };
export const TARGETS = {
  fight: {
    novice: { max: 0.15 },
    learner5: { min: 0.6 },
    expert: { min: 0.85 },
    expertTop: { min: 0.97 },
  },
  world: {
    novice: { max: 0.5 },
    learner1: { min: 0.8 },
  },
  earliestLearnerBossDeathS: 45,
  tellS: fairnessLines.tellS, // the one tell time (fairness.json); the readable-tell check itself is the attack sheet's, not this table's
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
// World chains are a comparison column only (coordinator ruling, 19 Oct 04:32Z: "chain, information only"):
// no target, no ✓/✗, never in the fail or incomplete lists.
const CHAIN_IDS = new Set(WORLDS.map((w) => w.id));
export const isChain = (cell) => CHAIN_IDS.has(cell);
// A park cell: resume park N and stop the tick its own Warden is engaged. This is the default park measure: the
// world chain above has to break the first park's Warden on the way, so it mixes the park target with the Warden one
// (a Learner who wins that Warden 15-35% of the time cannot reach the second park's Warden 80% of the time).
export const PARKS = [1, 2, 3, 4, 5, 6].map((n) => ({ id: "park" + n, park: n, world: Math.ceil(n / 2), first: n, last: n }));

// The whole-World-1 clear (wave 36, difficulty-plan.md row D8): one bot run of the dam, the flume and Admiral Brindle in one
// attempt. It is its own cell, never part of `--only=w1` (that id is the stage 1 Warden) and never in the default cells, so
// today's band runs stay as they are; ask for it with `--only=w1clear` (`--cells=clear` alone selects nothing). Information only,
// no target. One run has one persona, so the whole clear plays the Warden persona (skipper, the one `w1` uses and the seeds are
// shared with, 40300 up) through Brindle too; the `brindle` cell plays the brawler, so its Brindle leg is not comparable.
// No `--to-boss`: that flag (band_run.gd) calls enter_boss on the first in-stage tick, so a run from stage 1 would fight Brindle
// at once on an unbuilt ball (seen on 40300 in the first clear receipts, boss entered at 0.01 s). The world's own flow reaches
// Brindle after the flume's Warden, and `--until=2` ends the run when stage 3 opens, which is after Brindle falls.
export const W1CLEAR = { id: "w1clear", world: 1, first: 1, last: 2 };
export const W1CLEAR_COLUMNS = ["novice", "learner1", "learner5", "expert"];
export const W1CLEAR_TICKS = (2 * 600 + 420 + 120) * 90; // two stages at the 600 s cap, the boss's 420 s limit, a margin

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

// Rank a stage's docs by mass, then parts count. ordinary = rank percentile 40 to 60, top = 90 and up.
// A bucket short of MIN_BUCKET docs widens (ordinary one rank each way, top downward) until it has them or
// every doc is in. A small library therefore makes the buckets overlap (a doc in both); `overlap` counts those,
// and the table marks the Expert-top column "(overlaps ordinary)" when it is not zero.
export function pickBuilds(docs) {
  const ranked = [...docs].sort((a, b) => a.mass - b.mass || a.parts - b.parts || String(a.file).localeCompare(String(b.file)));
  const n = ranked.length;
  if (n === 0) return { ordinary: [], top: [], ranked, overlap: 0 };
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
  const ordinary = ranked.slice(lo, hi + 1);
  const top = ranked.slice(start);
  const overlap = ordinary.filter((d) => top.includes(d)).length;
  return { ordinary, top, ranked, overlap };
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
    builds = {}, cells = ["boss", "warden", "park"], only = null, seeds = null, columns = COLUMNS.map((c) => c.id), persona = "brawler", wardenPersona = "skipper", parkPersona = "skipper",
  } = opts;
  const jobs = [];
  const tuneArgs = [...(opts.tune ? ["--tune=" + opts.tune] : []), ...(opts.tuneUnruled ? ["--tune-unruled"] : []), ...(opts.tier ? ["--run-tier=" + opts.tier] : [])];
  const want = (id) => !only || only.includes(id);
  const defs = [];
  for (const b of BOSSES) if (cells.includes("boss") && want(b.id)) defs.push({ kind: "boss", ...b });
  for (const w of WARDENS) if (cells.includes("warden") && want(w.id)) defs.push({ kind: "warden", ...w });
  for (const w of WORLDS) if (cells.includes("world") && want(w.id)) defs.push({ kind: "world", ...w, stage: w.first });
  for (const p of PARKS) if (cells.includes("park") && want(p.id)) defs.push({ kind: "world", ...p, stage: p.first });
  if (only?.includes(W1CLEAR.id)) defs.push({ kind: "clear", ...W1CLEAR, stage: W1CLEAR.first });
  for (const def of defs) {
    const cols = COLUMNS.filter((c) => columns.includes(c.id) && (def.kind !== "world" || WORLD_COLUMNS.includes(c.id)) && (def.kind !== "clear" || W1CLEAR_COLUMNS.includes(c.id)));
    for (const col of cols) {
      const stage = def.kind === "world" ? def.first : def.stage;
      // Stage 1 is the start of a run: no build to carry, so it plays fresh (the seed picks the pilot).
      const docs = stage === 1 ? [null] : (builds[stage]?.[col.build] ?? []);
      const count = seeds ?? (def.kind === "world" || def.kind === "clear" ? DEFAULT_SEEDS.world : DEFAULT_SEEDS.fight);
      for (let i = 0; i < count; i++) {
        const doc = docs.length ? docs[i % docs.length] : undefined;
        if (doc === undefined) {
          jobs.push({ ...base(def, col, i, persona, wardenPersona, parkPersona, null, tuneArgs), missing: true });
          continue;
        }
        jobs.push(base(def, col, i, persona, wardenPersona, parkPersona, doc, tuneArgs));
      }
    }
  }
  return jobs;
}

// Seeds depend on the cell and the index only, so columns of a cell face the same seeds.
function cellSeed(def, i) {
  // The same seeds as `w1` (the stage 1 Warden), so the two cells pair seed for seed on stage 1.
  if (def.kind === "clear") return 40000 + (3 + W1CLEAR.first - 1) * 100 + i;
  const slot = def.kind === "boss" ? def.world - 1 : def.kind === "warden" ? 3 + def.stage - 1 : def.park ? 12 + def.park - 1 : 9 + def.world - 1;
  return 40000 + slot * 100 + i;
}

function base(def, col, i, persona, wardenPersona, parkPersona, doc = null, tuneArgs = []) {
  const seed = cellSeed(def, i);
  const policy = def.kind === "clear" ? wardenPersona : def.kind === "world" ? parkPersona : def.kind === "warden" ? wardenPersona : persona;
  const from = def.kind === "world" || def.kind === "clear" ? def.first : def.stage;
  const args = [...tuneArgs, "--band=" + col.band, "--attempt=" + col.attempt, "--cell=" + def.id];
  if (doc) args.push("--entrance=" + doc.file, "--from-stage=" + from);
  else if (from !== 1) args.push("--from-stage=" + from);
  if (def.kind === "clear") args.push("--until=" + def.last, "--fight-limit=" + WARDEN_FIGHT_LIMIT_S, "--stage-limit=" + WARDEN_STAGE_LIMIT_S, "--ticks=" + W1CLEAR_TICKS);
  else if (def.kind === "boss") args.push("--to-boss=1", "--until=" + def.stage, "--ticks=" + BOSS_TICKS);
  else if (def.kind === "warden") args.push("--until=" + def.stage, "--fight-limit=" + WARDEN_FIGHT_LIMIT_S, "--stage-limit=" + WARDEN_STAGE_LIMIT_S, "--ticks=" + WARDEN_TICKS);
  else args.push("--stop-at=engaged:" + def.last, "--ticks=" + WORLD_TICKS);
  return {
    id: `${def.id}-${col.id}-${seed}`, kind: def.kind, cell: def.id, stage: def.stage, column: col.id, band: col.band, attempt: col.attempt,
    build: def.kind === "world" || def.kind === "clear" ? "ordinary" : col.build, policy, seed, entrance: doc ? doc.file : null, pilot: doc?.pilot ?? null, args,
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
    "--out=" + out, "--policy=" + job.policy, "--seeds=" + job.seed, "--table=park", "--gate=1", "--qa-log=1", ...job.args,
  ];
}

// --- what a player would report -----------------------------------------------------------------

// Every band run plays the park table with the play watch on (bot_run --qa-log=1, src/core/play_watch.gd,
// which only reads the game): a run judged on its win or loss is also read for what a player would
// report. Worst first: a wedge against a wall, a fall through the floor, an empty objective plate and
// a hull bar off the hull are bugs wherever they happen; stuck and hung are read with the bot's goal (a camper waits by design).
export const QA_KINDS = ["wedged", "fell", "blank", "bar", "stuck", "hung"];
const QA_PLACE_M = 10;

// The watch's rows from one run's qa-<seed>.ndjson, without the objective rows (every plate change).
export function qaRows(text) {
  return parseNdjson(text)
    .filter((row) => QA_KINDS.includes(row.kind))
    .map(({ kind, stage, s, at, flow, goal }) => ({ kind, stage, s, at, flow, goal }));
}

// runs: the runs.ndjson lines; a line carries `qa` (qaRows of its run) when the watch's file was read.
// Rows are gathered by kind, stage and place (a QA_PLACE_M square), so one bad spot met by ten runs is one line.
export function playerReport(runs) {
  const watched = runs.filter((run) => Array.isArray(run.qa));
  const kinds = Object.fromEntries(QA_KINDS.map((kind) => [kind, { rows: 0, runs: 0 }]));
  const places = new Map();
  for (const run of watched) {
    for (const kind of new Set(run.qa.map((row) => row.kind))) kinds[kind].runs += 1;
    for (const row of run.qa) {
      kinds[row.kind].rows += 1;
      const near = (row.at ?? []).map((x) => Math.round(x / QA_PLACE_M) * QA_PLACE_M);
      const key = [row.kind, row.stage, ...near].join(" ");
      const place = places.get(key) ?? { kind: row.kind, stage: row.stage, near, rows: 0, runs: new Set(), cells: new Set(), goals: new Set() };
      place.rows += 1;
      place.runs.add(run.id);
      place.cells.add(run.cell);
      if (row.goal) place.goals.add(row.goal);
      places.set(key, place);
    }
  }
  const list = [...places.values()]
    .map((place) => ({ ...place, runs: place.runs.size, cells: [...place.cells].sort(), goals: [...place.goals].sort() }))
    .sort((a, b) => QA_KINDS.indexOf(a.kind) - QA_KINDS.indexOf(b.kind) || b.runs - a.runs || a.stage - b.stage || String(a.near).localeCompare(String(b.near)));
  return { runs: runs.length, watched: watched.length, kinds, places: list };
}

export function renderPlayerReport(report, limit = 25) {
  const lines = ["## What a player would report", ""];
  if (report.watched === 0) return [...lines, "No run carried the play watch's rows (runs recorded before it was switched on).", ""].join("\n");
  lines.push(`The play watch (src/core/play_watch.gd) read ${report.watched} of ${report.runs} runs. It only reads the game, so the win rates above are what they would be without it. Information, not graded: a wedge, a fall, an empty objective plate or a hull bar off the hull is a bug to chase wherever it shows; a stuck or hung row is read with the bot's goal, since a camper waits by design.`, "");
  lines.push("| Kind | Rows | Runs with one |", "| --- | --- | --- |");
  for (const kind of QA_KINDS) lines.push(`| ${kind} | ${report.kinds[kind].rows} | ${report.kinds[kind].runs} |`);
  lines.push("");
  if (report.places.length === 0) return [...lines, "No place was reported.", ""].join("\n");
  lines.push("| Kind | Stage | Near (x, y, z) | Runs | Rows | Cells | Bot's goal |", "| --- | --- | --- | --- | --- | --- | --- |");
  for (const place of report.places.slice(0, limit)) lines.push(`| ${place.kind} | ${place.stage} | ${place.near.join(", ")} | ${place.runs} | ${place.rows} | ${place.cells.join(", ")} | ${place.goals.slice(0, 3).join("; ")} |`);
  if (report.places.length > limit) lines.push("", `${report.places.length - limit} more places are in table.json.`);
  lines.push("");
  return lines.join("\n");
}

// --- grading --------------------------------------------------------------------------------

// win / loss / timeout / error. A timeout (a stall, a fight cap, a tick guard) is not a win; an error
// (no row, or no fight reached) is not either, and the table counts both apart from losses.
// The comps study's per-fight report (research/comps/difficulty/SUMMARY.md, Lab measure), from one fight record:
// the largest single hit as a share of pilot health and the share of health lost in the fight's first 45 s.
// A Warden never engaged has no fight to report, so its shares are null, not zero. The study file arrives with #167.
export function fightReport(note, maxHp, engaged = true) {
  if (!note || !engaged) return { largestShare: null, largestSource: null, hp45Share: null, largestHullShare: null, hull45Share: null };
  // hp_lost* and largest_hit are the whole hit before scrap armour; hull_* is what reached the hull. Rows
  // recorded before the driver kept hull keys read null for the hull, not zero.
  const hullKnown = note.hull_lost_45s != null || note.largest_hull_hit != null || note.hull_lost != null;
  return {
    largestShare: note.largest_hit_share ?? (note.largest_hit != null && maxHp ? note.largest_hit / maxHp : null),
    largestSource: note.largest_hit_source ?? null,
    hp45Share: maxHp ? Math.round(((note.hp_lost_45s ?? 0) / maxHp) * 1000) / 1000 : null,
    largestHullShare: hullKnown ? note.largest_hull_hit_share ?? 0 : null,
    hull45Share: hullKnown && maxHp ? Math.round(((note.hull_lost_45s ?? 0) / maxHp) * 1000) / 1000 : null,
  };
}

export function gradeRun(kind, row, job = {}) {
  if (!row) return { result: "error", why: "no record" };
  if (row.resumed === false) return { result: "error", why: "the run did not resume its entrance doc" };
  const stages = row.stages ?? [];
  if (kind === "boss") {
    const boss = row.boss;
    const rep = fightReport(boss, row.max_hp);
    if (boss?.defeated_s != null) return { result: "win", fightS: boss.defeated_s, hpLost: boss.hp_lost ?? null, ...rep };
    if (row.outcome === "died" || row.outcome === "lost") return { result: "loss", fightS: boss?.seconds ?? null, hpLost: boss?.hp_lost ?? null, diedS: boss?.died_s ?? boss?.seconds ?? null, ...rep };
    // "boss" is the driver finding no boss module in the boss state: the harness's fault, not a fight.
    if (row.outcome === "boss") return { result: "error", why: "no boss module in the boss state" };
    if (row.outcome === "boss_stalled" || boss) return { result: "timeout", reason: row.outcome, fightS: boss?.seconds ?? null, hpLost: boss?.hp_lost ?? null, ...rep };
    return { result: "error", why: "the boss was never entered (" + row.outcome + ")" };
  }
  if (kind === "warden") {
    const note = stages.find((s) => s.stage === (job.stage ?? row.stage_reached));
    const rep = fightReport(note, note?.max_hp ?? row.max_hp, note != null && fightStart(note) != null);
    if (note?.warden_broken_s != null) {
      const start = fightStart(note);
      const fightS = start != null ? round2(note.warden_broken_s - start) : null;
      return { result: "win", fightS, hpLost: note.hp_lost ?? null, ...rep };
    }
    if (row.outcome === "died" || row.outcome === "lost") return { result: "loss", fightS: null, hpLost: note?.hp_lost ?? null, ...rep };
    return { result: "timeout", reason: row.outcome, fightS: null, hpLost: note?.hp_lost ?? null, ...rep };
  }
  if (kind === "world") {
    if (row.outcome === "reached") return { result: "win", fightS: row.game_seconds ?? null, hpLost: null };
    if (row.outcome === "died" || row.outcome === "lost") return { result: "loss", fightS: row.game_seconds ?? null, hpLost: null };
    return { result: "timeout", reason: row.outcome, fightS: row.game_seconds ?? null, hpLost: null };
  }
  if (kind === "clear") {
    // Won = Admiral Brindle defeated in the same attempt. Where it ended: the stage reached, and how (death, a cap, or the clear).
    const boss = row.boss;
    // where: the stage the run was in, or the boss fight when a boss note exists, so a stage 2 death reads apart from a boss death.
    const at = { stage: row.stage_reached ?? null, gameS: row.game_seconds ?? null, where: row.boss ? "boss" : "s" + (row.stage_reached ?? "?") };
    if (boss?.defeated_s != null) return { result: "win", fightS: row.game_seconds ?? null, hpLost: null, end: "clear", ...at };
    if (row.outcome === "died" || row.outcome === "lost") return { result: "loss", fightS: row.game_seconds ?? null, hpLost: null, diedS: row.game_seconds ?? null, end: "death", ...at };
    if (row.outcome === "stalled" || row.outcome === "fight_capped" || row.outcome === "boss_stalled" || row.outcome === "ticks_done") return { result: "timeout", reason: row.outcome, fightS: row.game_seconds ?? null, hpLost: null, end: "cap", ...at };
    return { result: "error", why: "the clear ended as " + row.outcome };
  }
  throw new Error("unknown kind " + kind);
}

// bot_driver.gd fight_start_of: the fight clock starts at the later of the bot's turn to the Warden and its engagement.
export function fightStart(note) {
  const turned = note.warden_fight_s;
  const engaged = note.warden_engaged_s;
  if (turned == null) return engaged ?? null;
  if (engaged == null) return turned;
  return Math.max(turned, engaged);
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

export const EXCLUDED = ["error", "killed"];
export const INCOMPLETE_SHARE = 0.1;
const CAPPED = ["fight_capped", "boss_stalled", "ticks_done"];

// One column of one cell: grades is the list of gradeRun results. Errors (no record, boss never entered, doc not
// resumed) and harness kills are excluded: they are not in n or the rate. Over 10% excluded makes the column incomplete.
export function aggregate(grades) {
  const total = grades.length;
  const error = grades.filter((g) => g.result === "error").length;
  const killed = grades.filter((g) => g.result === "killed").length;
  const used = grades.filter((g) => !EXCLUDED.includes(g.result));
  const count = (r) => used.filter((g) => g.result === r).length;
  const n = used.length;
  const wins = count("win");
  const { lo, hi } = wilson(wins, n);
  const deaths = used.filter((g) => g.result === "loss" && g.diedS != null).map((g) => g.diedS);
  const hit = used.filter((g) => g.largestShare != null).sort((a, b) => b.largestShare - a.largestShare)[0] ?? null;
  const hp45 = used.map((g) => g.hp45Share).filter((x) => x != null);
  return {
    n, total, wins, losses: count("loss"), timeouts: count("timeout"),
    capped: used.filter((g) => g.result === "timeout" && CAPPED.includes(g.reason)).length,
    stalled: used.filter((g) => g.result === "timeout" && !CAPPED.includes(g.reason)).length,
    excluded: { error, killed }, incomplete: total > 0 && (error + killed) / total > INCOMPLETE_SHARE,
    rate: n ? wins / n : null, lo, hi,
    medianFightS: median(used.filter((g) => g.result === "win").map((g) => g.fightS)),
    medianHpLost: median(used.map((g) => g.hpLost)),
    largestHullShare: used.some((g) => g.largestHullShare != null) ? Math.max(...used.map((g) => g.largestHullShare ?? 0)) : null,
    medianHull45Share: median(used.map((g) => g.hull45Share).filter((x) => x != null)),
    maxHull45Share: used.some((g) => g.hull45Share != null) ? Math.max(...used.map((g) => g.hull45Share ?? 0)) : null,
    earliestDeathS: deaths.length ? Math.min(...deaths) : null,
    deathsS: deaths,
    earlyDeaths: deaths.filter((s) => s < TARGETS.earliestLearnerBossDeathS).length,
    largestShare: hit?.largestShare ?? null, largestSource: hit?.largestSource ?? null,
    medianHp45Share: median(hp45), maxHp45Share: hp45.length ? Math.max(...hp45) : null,
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
export function buildTable(runs, buckets = {}) {
  const cells = new Map();
  for (const r of runs) {
    const key = r.cell;
    if (!cells.has(key)) cells.set(key, { cell: key, kind: r.kind, stage: r.stage, grades: {} });
    const c = cells.get(key);
    (c.grades[r.column] ??= []).push(r.grade ?? gradeRun(r.kind, r.row, r));
  }
  const order = [...BOSSES, ...WARDENS, ...PARKS, ...WORLDS, W1CLEAR].map((d) => d.id);
  return [...cells.values()].sort((a, b) => order.indexOf(a.cell) - order.indexOf(b.cell)).map((c) => {
    const columns = {};
    for (const col of COLUMNS) {
      if (!c.grades[col.id]) continue;
      const a = aggregate(c.grades[col.id]);
      const target = isChain(c.cell) || c.kind === "clear" ? null : targetFor(c.kind, col.id);
      columns[col.id] = { ...a, target, ok: a.incomplete ? null : meets(target, a.rate) };
    }
    const ord = columns.expert?.medianFightS;
    const top = columns.expertTop?.medianFightS;
    // The 45 s check covers every Learner column that ran (attempt 1 and attempt 5).
    const learners = [columns.learner1, columns.learner5].filter(Boolean);
    const deaths = learners.flatMap((l) => l.deathsS);
    const early = deaths.filter((d) => d < TARGETS.earliestLearnerBossDeathS).length;
    const overlap = buckets[c.stage]?.overlap ?? 0;
    return {
      cell: c.cell, kind: c.kind, stage: c.stage, columns, overlap, info: isChain(c.cell) || c.kind === "clear",
      ...(c.kind === "clear" ? { ends: endsByColumn(c.grades) } : {}),
      growthRatio: ord && top ? round2(top / ord) : null, // reported, not graded
      tell: c.kind === "boss" && learners.length ? {
        earlyDeaths: early, earliestDeathS: deaths.length ? Math.min(...deaths) : null,
        ok: learners.some((l) => l.incomplete) ? null : early === 0,
      } : null,
    };
  });
}

export function cellVerdict(cell) {
  if (cell.info) return "info";
  const marks = Object.values(cell.columns).map((c) => c.ok);
  const bad = marks.includes(false) || cell.tell?.ok === false;
  if (bad) return "fail";
  if (Object.values(cell.columns).some((c) => c.incomplete)) return "incomplete";
  return marks.includes(true) ? "pass" : "none";
}

function cellText(c, note = "") {
  if (!c) return "-";
  const out = [c.excluded.error ? `${c.excluded.error} error` : "", c.excluded.killed ? `${c.excluded.killed} killed` : ""].filter(Boolean).join(", ");
  if (c.incomplete) return `incomplete: ${c.n} of ${c.total} counted (excluded: ${out})${note}`;
  const mark = c.ok === null ? "" : c.ok ? " ✓" : " ✗";
  // A stall or a fight cap is the fight beating the player, not a win: shown beside the deaths.
  const extra = [c.losses ? `${c.losses} died` : "", c.capped ? `${c.capped} capped` : "", c.stalled ? `${c.stalled} stalled` : "", ""].filter(Boolean).join(", ");
  return `${pct(c.rate)} (${c.n}) [${pct(c.lo)}-${pct(c.hi)}]${mark}${c.target ? " vs " + describeTarget(c.target) : ""}${extra ? " (" + extra + ")" : ""}${out ? " (excluded: " + out + ")" : ""}${note}`;
}

const fmt = (x, d = 1) => (x == null ? "-" : Number(x).toFixed(d));

export function renderTable(table, meta = {}) {
  const lines = ["# Challenge band table", ""];
  if (meta.tune_unruled) lines.push("Unruled: --tune-unruled was set, so pilot.* dials applied. No ruling allows them; this table is information only.", "");
  if (meta.run_tier) lines.push(`Run tier ${meta.run_tier} (HARD ladder rung ${meta.run_tier}, bot_run --run-tier): every run picks it on the start card, or takes it as a resumed stage opens. The ✓/✗ marks still judge the base-tier targets.`, "");
  if (meta.tune) lines.push(`Tuned: --tune=${meta.tune} requested (difficulty dials, src/core/challenge_dials.gd). The applied dials are on each run row as "dials", from describe(); a rejected entry is not applied.`, "");
  if (meta.label) lines.push(`Label ${meta.label}${meta.commit ? ", commit " + meta.commit.slice(0, 8) : ""}${meta.when ? ", " + meta.when : ""}.`, "");
  if (table.some((c) => c.kind !== "world")) lines.push(`Learner a1 at bosses and Wardens is information only (DECISIONS section 5, 19 Oct 19:00): no ✓/✗; the old reference range was ${pct(LEARNER1_FIGHT_REFERENCE.min)}-${pct(LEARNER1_FIGHT_REFERENCE.max)}. Parks still grade Learner a1 reach.`, "");
  lines.push("Win rate (runs) [Wilson 95%] ✓/✗ against the target; ✓/✗ judges the point estimate. Brackets after a cell count deaths, fight caps (fight_capped, boss_stalled) and stalls; none is a win. Runs with no record, an unresumed doc or a harness kill are excluded from n and the rate and noted as `excluded`; over 10% excluded makes the column incomplete. Fight s and HP lost are medians over the cell's runs; top/ord is the Expert top fight time over the Expert ordinary fight time.", "");
  const fights = table.filter((c) => c.kind !== "world" && c.kind !== "clear");
  if (fights.length) {
    lines.push("## Bosses and Wardens", "");
    lines.push("| Cell | Novice | Learner a1 | Learner a5 | Expert ordinary | Expert top | Learner deaths < 45 s | Fight s (ord / top) | HP lost (ord) | top/ord (reported, not graded) |");
    lines.push("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |");
    for (const c of fights) {
      const t = c.tell;
      const tell = t ? (t.ok === null ? "incomplete" : t.ok ? "0 ✓" : `${t.earlyDeaths} ✗ (earliest ${fmt(t.earliestDeathS)} s)`) : "-";
      lines.push(`| ${c.cell} | ${["novice", "learner1", "learner5", "expert", "expertTop"].map((id) => cellText(c.columns[id], id === "expertTop" && c.overlap ? " (overlaps ordinary)" : "")).join(" | ")} | ${tell} | ${fmt(c.columns.expert?.medianFightS)} / ${fmt(c.columns.expertTop?.medianFightS)} | ${fmt(c.columns.expert?.medianHpLost)} | ${c.growthRatio ?? "-"}${c.growthRatio != null && c.overlap ? " (overlaps ordinary)" : ""} |`);
    }
    lines.push("");
  }
  if (fights.length) {
    lines.push("## Fight report (comps study format)", "", "From research/comps/difficulty/SUMMARY.md, Lab measure. Reference rows, which are tuning ranges, not rulings: boss TTK 50-90 s and Warden 90-150 s at an ordinary build (rows 1, 2); an ordinary hit 15-25% of pilot health, a heavy one 30-50%, and no single hit kills from full (rows 9, 10); a Learner loses well under full health in the first 45 s (row 11). Largest hit is the biggest single hit in any band's run, with its source id. Hit and HP-lost shares are the whole hit before scrap armour; the hull columns are what reached the hull after armour (blank for rows recorded before the driver kept them). Tells and recovery come from the attack sheet (`tools/attack_sheet.gd`), not from these runs. Warden rows count from the Warden fight's start.", "");
    lines.push("| Cell | Expert ordinary TTK s | Largest hit, share of HP (source) | Learner a1 HP lost in first 45 s, share (median / max) | Largest hull hit | Learner a1 hull lost in first 45 s (median / max) |", "| --- | --- | --- | --- | --- | --- |");
    for (const c of fights) {
      const all = Object.values(c.columns).filter((x) => x.largestShare != null).sort((a, b) => b.largestShare - a.largestShare)[0];
      const l1 = c.columns.learner1;
      const hullMax = Math.max(-1, ...Object.values(c.columns).map((x) => x.largestHullShare ?? -1));
      lines.push(`| ${c.cell} | ${fmt(c.columns.expert?.medianFightS)} | ${all ? `${pct(all.largestShare)} (${all.largestSource ?? "?"})` : "-"} | ${l1?.medianHp45Share != null ? `${pct(l1.medianHp45Share)} / ${pct(l1.maxHp45Share)}` : "-"} | ${hullMax >= 0 ? pct(hullMax) : "-"} | ${l1?.medianHull45Share != null ? `${pct(l1.medianHull45Share)} / ${pct(l1.maxHull45Share)}` : "-"} |`);
    }
    lines.push("");
  }
  const parkRow = (c) => `| ${c.cell} | ${cellText(c.columns.novice)} | ${cellText(c.columns.learner1)} | ${fmt(c.columns.learner1?.medianFightS)} |`;
  const parks = table.filter((c) => c.kind === "world" && !c.info);
  if (parks.length) {
    lines.push("## Parks (reach the Warden)", "", "`parkN` resumes park N and stops when that park's Warden is engaged; reaching it is the win.", "");
    lines.push("| Cell | Novice | Learner a1 | Game s to reach (Learner) |", "| --- | --- | --- | --- |");
    for (const c of parks) lines.push(parkRow(c));
    lines.push("");
  }
  const chains = table.filter((c) => c.info && c.kind === "world");
  if (chains.length) {
    lines.push("## World chains (information only, not graded)", "", "`worldN` (only with `--cells=world`) starts at the world's first park and stops at its second park's Warden, so it must break the first Warden on the way. Coordinator ruling 19 Oct 04:32Z: the park target is read per park; the chain is a comparison column with no target.", "");
    lines.push("| Cell | Novice | Learner a1 | Game s to reach (Learner) |", "| --- | --- | --- | --- |");
    for (const c of chains) lines.push(parkRow(c));
    lines.push("");
  }
  const clears = table.filter((c) => c.kind === "clear");
  if (clears.length) {
    lines.push("## Whole World 1 clear (information only, not graded)", "", "`w1clear` plays the dam, the flume and Admiral Brindle in one attempt from a fresh run; a win is Brindle defeated. Where each run ended: the stage it reached, or the boss fight, and whether it died, hit a time cap (a stall or a fight cap) or cleared.", "");
    lines.push("| Band | Clears (runs) [Wilson 95%] | Ended (stage: died / capped / cleared) | Game s (median of clears) |", "| --- | --- | --- | --- |");
    for (const c of clears) for (const id of COLUMNS.map((x) => x.id)) if (c.columns[id]) lines.push(`| ${c.cell} ${id} | ${cellText(c.columns[id])} | ${c.ends[id]} | ${fmt(c.columns[id].medianFightS)} |`);
    lines.push("");
  }
  if (meta.fairness) lines.push(...renderFairness(meta.fairness));
  if (meta.buckets && Object.keys(meta.buckets).length) {
    lines.push("## Build buckets", "", "Docs per stage in the library, in the ordinary bucket (middle fifth by mass, then parts) and the top bucket (top tenth); a short bucket widens to three docs, so a small library makes them overlap (a doc in both).", "");
    lines.push("| Stage | Docs | Ordinary | Top | In both |", "| --- | --- | --- | --- | --- |");
    for (const [stage, b] of Object.entries(meta.buckets)) lines.push(`| ${stage} | ${b.docs} | ${b.ordinary} | ${b.top} | ${b.overlap}${b.overlap ? " (Expert top overlaps ordinary)" : ""} |`);
    lines.push("");
  }
  if (meta.shards) lines.push(`Shards: ${meta.shards.join(", ")}.`, "");
  if (meta.warnings?.length) lines.push(...meta.warnings.map((w) => "Warning: " + w), "");
  const incomplete = table.filter((c) => cellVerdict(c) === "incomplete").map((c) => c.cell);
  if (incomplete.length) lines.push(`Incomplete cells (over 10% of a column's jobs excluded as error or killed, no ✓/✗): ${incomplete.join(", ")}.`, "");
  const failing = table.filter((c) => cellVerdict(c) === "fail").map((c) => c.cell);
  const scope = meta.fairness ? " against a win-rate target" : "";
  lines.push(failing.length ? `Cells with a ✗${scope}: ${failing.join(", ")}.` : `No cell has a ✗${scope}.`, "");
  // The fairness marks are their own judgement and are summed apart, so the two sentences cannot disagree.
  if (meta.fairness) {
    const bad = meta.fairness.flatMap((p) => fairnessFails(p).map((f) => `${p.cell} ${p.column} ${f}`));
    lines.push(bad.length ? `Fairness lines with a ✗: ${bad.join("; ")}.` : "No fairness line has a ✗.", "");
  }
  return lines.join("\n");
}

// Where a column's w1clear runs ended, by stage: "s1: 2 died / 0 capped / 0 cleared, s2: ...".
function endsByColumn(grades) {
  const out = {};
  for (const [id, list] of Object.entries(grades)) {
    const wheres = [...new Set(list.filter((g) => g.end).map((g) => g.where))].sort();
    out[id] = wheres.map((where) => {
      const n = (end) => list.filter((g) => g.where === where && g.end === end).length;
      return `${where}: ${n("death")} died / ${n("cap")} capped / ${n("clear")} cleared`;
    }).join(", ") || "-";
  }
  return out;
}

// --- fairness: the three numbers wave 37 is judged by (difficulty-plan.md rows F1 to F3) -------------------------------

// The pass lines and the tell time live once, in fairness.json, which tools/bot_fairness.gd reads too.
export const FAIRNESS = fairnessLines;

const num = (x) => (typeof x === "number" && Number.isFinite(x) ? x : null);

// One run's `row.fairness` (tools/bot_fairness.gd record). A run recorded before the field, or a field missing, is null:
// not measured. It is never read as 0.
export function fairnessOf(run) {
  const f = run?.row?.fairness;
  if (!f || typeof f !== "object") return null;
  const hull = f.hull && typeof f.hull === "object" ? f.hull : {};
  const k = f.killing_hit && typeof f.killing_hit === "object" ? f.killing_hit : null;
  return {
    telegraphed: num(hull.telegraphed), untelegraphed: num(hull.untelegraphed), contact: num(hull.contact), unknown: num(hull.unknown),
    killing: k ? k.bucket ?? null : null,
    slowS: num(f.slow_s), fastS: num(f.fast_s), slowHull: num(f.slow_hull), fastHull: num(f.fast_hull),
    segments: f.first_hit && typeof f.first_hit === "object" ? Object.values(f.first_hit) : null,
  };
}

// Runs excluded the way the win table excludes them: no record, an unresumed doc, a harness kill.
const counted = (run) => !EXCLUDED.includes(run.grade?.result ?? "") && run.row?.resumed !== false && run.row != null;

// The runs of one cell and one arm, pooled. Hull and seconds are summed over the runs that measured them, so a long run counts
// for more than a short one. Each number is null when no run measured it, and the reason is kept for the table.
export function fairnessPool(runs) {
  const rows = runs.map(fairnessOf).filter(Boolean);
  const out = { runs: runs.length, measured: rows.length };
  const sum = (key) => rows.reduce((a, r) => a + (r[key] ?? 0), 0);
  const bucketed = rows.filter((r) => r.telegraphed != null && r.untelegraphed != null);
  const tel = bucketed.reduce((a, r) => a + r.telegraphed, 0);
  const unt = bucketed.reduce((a, r) => a + r.untelegraphed, 0);
  const hull = { telegraphed: tel, untelegraphed: unt, contact: sum("contact"), unknown: sum("unknown") };
  const whole = hull.telegraphed + hull.untelegraphed + hull.contact + hull.unknown;
  out.hull = hull;
  out.unknownShare = whole > 0 ? hull.unknown / whole : null;
  out.contactShare = whole > 0 ? hull.contact / whole : null;
  out.telegraphShare = tel + unt > 0 ? tel / (tel + unt) : null;
  // F1 carries no mark while the hull it could not match is over the line.
  out.shareMarked = out.telegraphShare != null && !(out.unknownShare != null && out.unknownShare > FAIRNESS.unknownMaxShare);
  const kills = rows.map((r) => r.killing).filter((b) => b === "telegraphed" || b === "untelegraphed");
  out.kills = kills.length;
  out.killsShown = kills.filter((b) => b === "telegraphed").length;
  out.killsOther = rows.map((r) => r.killing).filter((b) => b === "contact" || b === "unknown").length;
  const tax = rows.filter((r) => [r.slowS, r.fastS, r.slowHull, r.fastHull].every((x) => x != null));
  const slowS = tax.reduce((a, r) => a + r.slowS, 0);
  const fastS = tax.reduce((a, r) => a + r.fastS, 0);
  const slowH = tax.reduce((a, r) => a + r.slowHull, 0);
  const fastH = tax.reduce((a, r) => a + r.fastHull, 0);
  out.stopTax = null;
  out.stopTaxNote = !tax.length ? "not measured" : slowS <= 0 || fastS <= 0 ? "no time on one side of cruise" : fastH <= 0 ? "no hull lost at cruise" : null;
  if (!out.stopTaxNote) out.stopTax = slowH / slowS / (fastH / fastS);
  out.fastShare = slowS + fastS > 0 ? fastS / (slowS + fastS) : null;
  // F3: one reading per stage and for the boss that a pack was met in. A segment with no hit is the best case and reads as
  // infinitely late, so it can move the median; one a hit itself opened has no pack-to-hit time and is counted apart.
  const segs = rows.flatMap((r) => r.segments ?? []).filter((g) => g && g.contact);
  out.segments = segs.length;
  out.openedByHit = segs.filter((g) => g.opened_by_hit).length;
  const timed = segs.filter((g) => !g.opened_by_hit);
  out.noHit = timed.filter((g) => !g.hit).length;
  out.firstHitN = timed.length;
  const times = timed.map((g) => (g.hit ? num(g.first_hit_s) : Infinity)).filter((x) => x != null).sort((a, b) => a - b);
  const mid = times.length >> 1;
  out.firstHitS = !times.length ? null : times.length % 2 ? times[mid] : times[mid - 1] === times[mid] ? times[mid] : (times[mid - 1] + times[mid]) / 2;
  return out;
}

// One pool per cell and arm (the column), never across cells or across the arms that share a band name:
// [{ cell, column, ...pool }], or null when no run carries the field.
export function fairnessByCell(runs) {
  const groups = new Map();
  for (const r of runs.filter(counted)) {
    const key = `${r.cell}\u0000${r.column ?? r.band}`;
    if (!groups.has(key)) groups.set(key, { cell: r.cell, column: r.column ?? r.band, runs: [] });
    groups.get(key).runs.push(r);
  }
  const out = [...groups.values()].map((g) => ({ cell: g.cell, column: g.column, ...fairnessPool(g.runs) }));
  return out.some((p) => p.measured > 0) ? out : null;
}

// The numbers of one pool that miss their line (marked ones only), as "F1", "F2", "F3".
export function fairnessFails(p) {
  const out = [];
  if (p.shareMarked && (p.telegraphShare < FAIRNESS.telegraphShare - 1e-9 || (p.kills && p.killsShown !== p.kills))) out.push("F1");
  if (p.stopTax != null && p.stopTax < FAIRNESS.stopTax - 1e-9) out.push("F2");
  if (p.firstHitS != null && p.firstHitS < FAIRNESS.firstHitS - 1e-9) out.push("F3");
  return out;
}

export function renderFairness(fair) {
  const lines = ["## Fairness (F1 to F3, information beside the difficulty change)", "", `The lines are in scripts/challenge/fairness.json. F1 telegraph share: hull lost to a hit whose own source had a telegraph over the ball for at least ${FAIRNESS.tellS} s, over that plus hull from sources that publish telegraphs and had none in time; pass >= ${pct(FAIRNESS.telegraphShare)} and every killing hit shown. Contact hull (body contact and ram, no telegraph by design) is printed beside it and is outside the share; unknown is hull whose source has no telegraph owner to match, and F1 carries no mark while unknown is over ${pct(FAIRNESS.unknownMaxShare)} of hull. F2 stop tax: hull per second below cruise speed over hull per second at or above it; pass >= ${FAIRNESS.stopTax.toFixed(1)}; the share of time at cruise is printed beside it. F3 first hit: median seconds from first contact with a pack to the first hit, one reading per stage and per boss fight; pass >= ${FAIRNESS.firstHitS} s; a stage with no hit reads as later than any, and a hit that itself opened contact is counted apart. One line per cell and arm, with the runs behind it; runs graded error or unresumed are left out. "not measured" means no run carried the number; it is never read as zero.`, ""];
  const mark = (ok) => (ok === null ? "" : ok ? " ✓" : " ✗");
  for (const p of fair) {
    const f1 = p.telegraphShare == null ? "F1 not measured" : `F1 ${pct(p.telegraphShare)} of ${fmt(p.hull.telegraphed + p.hull.untelegraphed)} hull shown${p.shareMarked ? mark(p.telegraphShare >= FAIRNESS.telegraphShare - 1e-9) : " (no mark: unknown hull over the line)"}, killing hits shown ${p.kills ? `${p.killsShown} of ${p.kills}${p.shareMarked ? mark(p.killsShown === p.kills) : ""}` : "none counted"}${p.killsOther ? ` (${p.killsOther} killed by contact or unknown)` : ""}; contact ${fmt(p.hull.contact)} hull, unknown ${fmt(p.hull.unknown)} hull (${p.unknownShare == null ? "-" : pct(p.unknownShare)} of hull)`;
    const f2 = p.stopTax == null ? `F2 not measured (${p.stopTaxNote})` : `F2 stop tax ${p.stopTax.toFixed(2)}${mark(p.stopTax >= FAIRNESS.stopTax - 1e-9)}, ${pct(p.fastShare)} of time at cruise`;
    // An infinite median means at least half the readings took no hit: exactly half on an even split, over half otherwise.
    const noHitPart = p.noHit * 2 === p.firstHitN ? "no hit in half" : "no hit in over half";
    const f3 = p.firstHitS == null ? `F3 not measured (${p.openedByHit} opened by a hit)` : `F3 first hit ${Number.isFinite(p.firstHitS) ? fmt(p.firstHitS) + " s" : noHitPart} median over ${p.firstHitN} stage readings${mark(p.firstHitS >= FAIRNESS.firstHitS - 1e-9)}, ${p.noHit} of ${p.firstHitN} took no hit${p.openedByHit ? `, ${p.openedByHit} opened by a hit` : ""}`;
    lines.push(`- ${p.cell} ${p.column} (${p.measured} of ${p.runs} runs measured): ${f1}; ${f2}; ${f3}.`);
  }
  lines.push("");
  return lines;
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
export const SECONDS_PER_JOB = { boss: 335, warden: 330, world: 330, clear: 300 }; // wall s per job at 4 parallel on the 4-vCPU box, smoke medians; world is a guess (no sample before 19 Oct)

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
  for (const kind of ["boss", "warden", "world", "clear"]) {
    const r = runs.filter((x) => x.kind === kind);
    if (!r.length) continue;
    out[kind] = { jobs: r.length, medianWallS: median(r.map((x) => x.wallS)), maxWallS: Math.max(...r.map((x) => x.wallS ?? 0)), medianGameS: median(r.map((x) => x.row?.game_seconds)) };
  }
  return out;
}

// --- identity: plan hash, keys, merge checks -------------------------------------------------

// A cheap stable hash (FNV-1a, 64 bits as two 32-bit lanes) so lib.mjs stays free of node imports.
export function hashString(text) {
  let a = 0x811c9dc5;
  let b = 0x01000193 ^ text.length;
  for (let i = 0; i < text.length; i++) {
    a = Math.imul(a ^ text.charCodeAt(i), 0x01000193) >>> 0;
    b = Math.imul(b ^ text.charCodeAt(i), 0x85ebca6b) >>> 0;
  }
  return a.toString(16).padStart(8, "0") + b.toString(16).padStart(8, "0");
}

// The highest run tier a run can pick: src/core/run_tier.gd TOP (lib.test.mjs checks they agree).
export const MAX_RUN_TIER = 5;

// What makes two table runs the same experiment: the library, the cells, seeds, columns, personas, tune string and
// run tier. The shard is not in it: shards of one plan share a hash. Tier 0 adds nothing, so base-tier hashes stay put.
export function planHash(o) {
  const keys = ["libraryLabel", "libraryDigest", "cells", "only", "seeds", "columns", "persona", "wardenPersona", "parkPersona", "tune"];
  const parts = keys.map((k) => o[k] ?? null);
  if (o.tier) parts.push({ tier: o.tier });
  return hashString(JSON.stringify(parts));
}

export const jobKey = (job, { libraryLabel, plan, commit }) => `${libraryLabel ?? "-"}:${plan}:${(commit ?? "").slice(0, 8)}:${job.id}`;

// meta: { shard: "i/n" | null, plan_hash, commit, library }. Returns { errors, warnings }: errors refuse the merge.
export function checkMerge(metas, { allowMixed = false } = {}) {
  const errors = [];
  const warnings = [];
  const mixed = (what, values) => {
    const set = new Set(values);
    if (set.size <= 1) return;
    (allowMixed ? warnings : errors).push(`folders differ in ${what}: ${[...set].join(", ")}${allowMixed ? "" : " (use --allow-mixed to merge anyway)"}`);
  };
  if (metas.some((m) => !m)) errors.push("a folder has no meta.json (not a challenge run folder)");
  const ms = metas.filter(Boolean);
  mixed("plan hash", ms.map((m) => m.plan_hash));
  mixed("commit", ms.map((m) => m.commit));
  mixed("library", ms.map((m) => m.library));
  const shards = ms.map((m) => m.shard);
  if (shards.some((s) => s)) {
    const parsed = shards.map((s) => (s ? /^(\d+)\/(\d+)$/.exec(s) : null));
    if (parsed.some((p) => !p)) errors.push("some folders are sharded and some are not");
    else {
      const n = new Set(parsed.map((p) => p[2]));
      if (n.size > 1) errors.push("shard counts differ: " + [...n].join(", "));
      else {
        const count = Number(parsed[0][2]);
        const have = parsed.map((p) => Number(p[1]));
        for (let i = 1; i <= count; i++) if (!have.includes(i)) errors.push(`shard ${i}/${count} is missing`);
        if (new Set(have).size !== have.length) errors.push("a shard appears twice");
      }
    }
  }
  return { errors, warnings, shards: shards.filter(Boolean) };
}

// Bucket sizes per stage from the pickBuilds results.
export function bucketInfo(builds) {
  return Object.fromEntries(Object.entries(builds).map(([stage, b]) => [stage, { docs: b.ranked.length, ordinary: b.ordinary.length, top: b.top.length, overlap: b.overlap }]));
}

// Rows by a field, the last one winning.
export function dedupeBy(rows, field = "id") {
  const m = new Map();
  for (const r of rows) m.set(r[field], r);
  return [...m.values()];
}
