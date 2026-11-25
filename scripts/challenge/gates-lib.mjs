import { median } from "./lib.mjs";

export const STAGES = [1, 2, 3, 4, 5, 6];
export const SEEDS = [1, 2, 3, 4, 5];
export const RUNS_PER_SEED = 3;

export const RULES = {
  gate1: { deathWithinS: 120 },
  gate2: { windowS: 120, lowerShare: 0.8, ratioMax: 0.75, minContested: 10 },
  gate4: { clearMin: 0.85 },
  instrument: { circleShareMin: 0.8, ridePerS: 30 },
};
export const MIN_VALID = 2;
export const INCOMPLETE_SHARE = 0.1;

export const ARMS = {
  orbit: { policy: "orbit", args: [], rep0: 0, gates: ["g1", "g2"], instrument: "orbit" },
  orbit_rut: {
    policy: "orbit",
    args: ["--plant=rut=1"],
    rep0: 0,
    gates: ["g1"],
    instrument: "orbit",
  },
  orbit_passive: {
    policy: "orbit",
    args: ["--plant=packs_passive=1"],
    rep0: 0,
    gates: ["g1"],
    instrument: "orbit",
  },
  terrain: { policy: "terrain", args: [], rep0: 0, gates: ["g2"], instrument: "terrain" },
  orbit_dmg2: {
    policy: "orbit",
    args: ["--plant=damage=2"],
    rep0: 0,
    gates: ["g2"],
    instrument: "orbit",
  },
  orbit_b: { policy: "orbit", args: [], rep0: 0, gates: ["g2"], instrument: "orbit" },
  deaf: {
    policy: "skipper",
    args: ["--band=expert", "--attempt=1", "--bot-no-mix=1"],
    rep0: 0,
    gates: ["g4"],
    instrument: "deaf",
  },
  deaf_hidden: {
    policy: "skipper",
    args: ["--band=expert", "--attempt=1", "--bot-no-mix=1", "--plant=hide_pack_telegraphs=1"],
    rep0: 0,
    gates: ["g4"],
    instrument: "deaf",
  },
};
export const GATE_ARMS = {
  g1: { real: "orbit", positive: "orbit_rut", negative: "orbit_passive" },
  g2: {
    real: ["terrain", "orbit"],
    positive: ["orbit", "orbit_dmg2"],
    negative: ["orbit", "orbit_b"],
  },
  g4: { real: "deaf", positive: "deaf", negative: "deaf_hidden" },
};

const FIGHT_LIMIT_S = 240;
export const STAGE_LIMIT_S = 600;

export function planGateJobs({
  arms = Object.keys(ARMS),
  stages = STAGES,
  seeds = SEEDS,
  runs = RUNS_PER_SEED,
  tune = "",
  stageLimit = STAGE_LIMIT_S,
} = {}) {
  const jobs = [];
  for (const arm of arms) {
    const def = ARMS[arm];
    if (!def) throw new Error("unknown arm " + arm);
    for (const stage of stages) {
      for (const seed of seeds) {
        for (let r = 0; r < runs; r++) {
          const rep = def.rep0 + r;
          const runSeed = seed;
          const args = [...def.args, "--cell=gate-" + arm];
          if (stage !== 1) args.push("--from-stage=" + stage);
          args.push(
            "--until=" + stage,
            "--fight-limit=" + FIGHT_LIMIT_S,
            "--stage-limit=" + stageLimit,
            "--ticks=" + (stageLimit + 100) * 90,
          );
          if (tune) args.push("--tune=" + tune);
          jobs.push({
            id: `${arm}-s${stage}-seed${seed}-r${rep}`,
            arm,
            stage,
            seed,
            rep,
            runSeed,
            policy: def.policy,
            args,
          });
        }
      }
    }
  }
  return jobs;
}

export function gateBotArgs(job, out) {
  return [
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
    "--seeds=" + job.runSeed,
    "--table=park",
    "--gate=1",
    ...job.args,
  ];
}

const num = (x) => (typeof x === "number" && Number.isFinite(x) ? x : null);

export const DEATHS = ["died", "lost"];
export const CLEARS = ["until", "won"];

export function summarizeRun(row, job) {
  const base = {
    id: job.id,
    arm: job.arm,
    stage: job.stage,
    seed: job.seed,
    rep: job.rep,
    void: null,
  };
  if (!row) return { ...base, void: "no record" };
  const note = (row.stages ?? []).find((s) => s.stage === job.stage) ?? null;
  if (!note)
    return { ...base, outcome: row.outcome ?? null, void: "no stage note for stage " + job.stage };
  const out = {
    ...base,
    outcome: row.outcome,
    died: DEATHS.includes(row.outcome),
    cleared: CLEARS.includes(row.outcome),
    first_contact_s: num(note.first_contact_s),
    first_hit_s: num(note.first_hit_s),
    exit_s: num(note.exit_s),
    hull_lost_120s: num(note.hull_lost_120s),
    alive_120s: num(note.alive_120s),
    fight_s: num(note.fight_s) ?? 0,
    circle_s: num(note.circle_s) ?? 0,
    circle_share: num(note.circle_share),
    line_rides: num(note.line_rides) ?? 0,
    lines_in_reach: num(note.lines_in_reach),
    telegraph_reads: num(note.telegraph_reads) ?? 0,
    dodges: num(note.evasions) ?? 0,
  };
  out.death_after_hit_s =
    out.died && out.exit_s != null && out.first_hit_s != null ? out.exit_s - out.first_hit_s : null;
  out.hull_per_min =
    out.hull_lost_120s != null && out.alive_120s != null && out.alive_120s > 0
      ? out.hull_lost_120s / (out.alive_120s / 60)
      : null;
  out.void = instrumentVoid(out, ARMS[job.arm]?.instrument);
  return out;
}

export function instrumentVoid(s, kind) {
  if (kind === "orbit") {
    if (!(s.alive_120s > 0)) return "orbit: no contact window recorded";
    const share = s.circle_share ?? s.circle_s / s.alive_120s;
    if (share < RULES.instrument.circleShareMin)
      return `orbit: circle_share ${share.toFixed(2)} < ${RULES.instrument.circleShareMin}`;
  } else if (kind === "terrain") {
    if (s.lines_in_reach === 0)
      return "terrain: no line within reach on this stage (instrument void)";
    if (!(s.alive_120s > 0)) return "terrain: no contact window recorded";
    const need = Math.max(1, s.alive_120s / RULES.instrument.ridePerS);
    if (s.line_rides < need)
      return `terrain: ${s.line_rides} line rides in a ${s.alive_120s.toFixed(0)} s window, need ${need.toFixed(1)}`;
  }
  return null;
}

const key = (s) => `${s.stage}:${s.seed}`;

function cells(runs, stages = STAGES, seeds = SEEDS) {
  const by = new Map();
  for (const s of runs) {
    if (!by.has(key(s))) by.set(key(s), { valid: [], voided: [] });
    by.get(key(s))[s.void ? "voided" : "valid"].push(s);
  }
  const out = [];
  for (const stage of stages) {
    for (const seed of seeds) {
      const c = by.get(`${stage}:${seed}`) ?? { valid: [], voided: [] };
      out.push({ stage, seed, valid: c.valid, voided: c.voided, void: c.valid.length < MIN_VALID });
    }
  }
  return out;
}

const voidList = (runs) => runs.filter((s) => s.void).map((s) => ({ id: s.id, why: s.void }));

export function gate1(runs, { stages = STAGES, seeds = SEEDS } = {}) {
  const perStage = [];
  for (const stage of stages) {
    const cs = cells(
      runs.filter((s) => s.stage === stage),
      [stage],
      seeds,
    );
    const valid = cs.flatMap((c) => c.valid);
    const notDied = valid.filter((s) => !s.died);
    const noHit = valid.filter((s) => s.died && s.death_after_hit_s == null);
    const seedMedians = cs
      .filter((c) => !c.void)
      .map((c) =>
        median(c.valid.filter((s) => s.death_after_hit_s != null).map((s) => s.death_after_hit_s)),
      );
    const med = median(seedMedians);
    const voidCells = cs.filter((c) => c.void).length;
    let status;
    if (notDied.length) status = "fail";
    else if (voidCells || noHit.length) status = "void";
    else status = med != null && med <= RULES.gate1.deathWithinS ? "pass" : "fail";
    perStage.push({
      stage,
      runs: valid.length,
      notDied: notDied.length,
      notDiedOutcomes: [...new Set(notDied.map((s) => s.outcome))],
      medianDeathAfterHitS: med,
      voidCells,
      status,
    });
  }
  return {
    gate: "gate1",
    verdict: roll(perStage.map((p) => p.status)),
    stages: perStage,
    voided: voidList(runs),
  };
}

function roll(statuses) {
  if (statuses.includes("fail")) return "FAIL";
  if (statuses.includes("void")) return "VOID";
  return "PASS";
}

export function gate2(a, b, { stages = STAGES, seeds = SEEDS } = {}) {
  const ca = cells(a, stages, seeds);
  const cb = cells(b, stages, seeds);
  const pairs = [];
  let voidPairs = 0;
  ca.forEach((x, i) => {
    const y = cb[i];
    if (x.void || y.void) return void voidPairs++;
    const va = median(x.valid.map((s) => s.hull_per_min));
    const vb = median(y.valid.map((s) => s.hull_per_min));
    if (va == null || vb == null) return void voidPairs++;
    pairs.push({ stage: x.stage, seed: x.seed, a: va, b: vb });
  });
  const contested = pairs.filter((p) => p.a !== p.b);
  const decide = (lo, hi) => {
    const lower = contested.filter((p) => p[lo] < p[hi]).length;
    const ratios = contested.map((p) => (p[hi] === 0 ? Number.MAX_VALUE : p[lo] / p[hi]));
    const need = Math.ceil(RULES.gate2.lowerShare * contested.length - 1e-9);
    const ratio = median(ratios);
    const wins =
      contested.length >= RULES.gate2.minContested &&
      lower >= need &&
      ratio <= RULES.gate2.ratioMax;
    const reachable =
      lower + voidPairs >=
        Math.ceil(RULES.gate2.lowerShare * (contested.length + voidPairs) - 1e-9) &&
      contested.length + voidPairs >= RULES.gate2.minContested;
    return { lower, need, pooledMedianRatio: ratio, wins, reachable };
  };
  const forA = decide("a", "b");
  const forB = decide("b", "a");
  const winner = forA.wins ? "A" : forB.wins ? "B" : "none";
  const full = voidPairs === 0 && pairs.length === stages.length * seeds.length;
  return {
    gate: "gate2",
    verdict: forA.wins ? "PASS" : full || !forA.reachable ? "FAIL" : "VOID",
    winner,
    pairs: pairs.length,
    contested: contested.length,
    ties: pairs.length - contested.length,
    voidPairs,
    A: forA,
    B: forB,
    voided: voidList([...a, ...b]),
    ratioOfMedians:
      median(pairs.map((p) => p.a)) != null && median(pairs.map((p) => p.b))
        ? median(pairs.map((p) => p.a)) / median(pairs.map((p) => p.b))
        : null,
  };
}

export function gate4(
  runs,
  {
    stages = STAGES,
    seeds = SEEDS,
    perStage = seeds.length * RUNS_PER_SEED,
    auditFree = true,
    onBeatRates = null,
  } = {},
) {
  const rows = [];
  for (const stage of stages) {
    const mine = runs.filter((s) => s.stage === stage);
    const valid = mine.filter((s) => !s.void);
    const clears = valid.filter((s) => s.cleared).length;
    const excluded = Math.max(0, perStage - valid.length);
    const rate = valid.length ? clears / valid.length : null;
    const status0 =
      excluded / perStage > INCOMPLETE_SHARE
        ? "void"
        : rate >= RULES.gate4.clearMin
          ? "pass"
          : "fail";
    let status = status0;
    let beat = null;
    if (onBeatRates && onBeatRates[stage] != null && rate != null) {
      beat = {
        onBeat: onBeatRates[stage],
        withinTenPoints: Math.abs(rate - onBeatRates[stage]) <= 0.1,
      };
      if (!beat.withinTenPoints && status === "pass") status = "fail";
    }
    rows.push({ stage, n: valid.length, clears, excluded, rate, status, beat });
  }
  const statuses = rows.map((r) => r.status);
  let verdict = roll(statuses);
  if (!auditFree) verdict = "VOID";
  return {
    gate: "gate4",
    verdict,
    stages: rows,
    auditFree,
    onBeat: onBeatRates ? "checked" : "pending (gate 3's on-beat arm does not exist yet)",
    voided: voidList(runs),
  };
}

export const AUDIO_READS = [
  /\baudio\b/i,
  /\bbeat_offset_s\b/,
  /\bbeat\b/i,
  /\bmusic_clock\b/,
  /\bAudioServer\b/,
  /\bAudioStream/,
  /presentation\.audio/,
  /\bengine\.clock\b/,
  /\bSimClock\b/,
];
export function stripComments(gd) {
  return gd
    .split("\n")
    .map((line) => {
      let inString = null;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (inString) {
          if (ch === "\\") i++;
          else if (ch === inString) inString = null;
        } else if (ch === '"' || ch === "'") inString = ch;
        else if (ch === "#") return line.slice(0, i);
      }
      return line;
    })
    .join("\n");
}
export function driverAudioReads(gd) {
  const code = stripComments(gd);
  const hits = [];
  code.split("\n").forEach((line, i) => {
    for (const re of AUDIO_READS)
      if (re.test(line)) hits.push({ line: i + 1, text: line.trim(), rule: String(re) });
  });
  return hits;
}

export function withControls(
  real,
  positive,
  negative,
  { positiveWant = "PASS", negativeWant = "FAIL" } = {},
) {
  const ok = (r, want) => r.verdict === want;
  const controls = {
    positive: { want: positiveWant, got: positive.verdict, ok: ok(positive, positiveWant) },
    negative: { want: negativeWant, got: negative.verdict, ok: ok(negative, negativeWant) },
  };
  const broken = !controls.positive.ok || !controls.negative.ok;
  return {
    real,
    positive,
    negative,
    controls,
    broken,
    reading: broken
      ? "BROKEN (a control read wrong; fix the gate before reading the arms)"
      : real.verdict,
  };
}

export const PARKED = ["gate4"];

export function evaluateGates(
  byArm,
  { auditFree = true, stages = STAGES, seeds = SEEDS, runs = RUNS_PER_SEED } = {},
) {
  const arm = (name) => byArm[name] ?? [];
  const opt = { stages, seeds };
  const g1 = withControls(
    gate1(arm("orbit"), opt),
    gate1(arm("orbit_rut"), opt),
    gate1(arm("orbit_passive"), opt),
  );
  const g2 = withControls(
    gate2(arm("terrain"), arm("orbit"), opt),
    gate2(arm("orbit"), arm("orbit_dmg2"), opt),
    gate2(arm("orbit"), arm("orbit_b"), opt),
  );
  const g4opt = { ...opt, perStage: seeds.length * runs, auditFree };
  const deaf = gate4(arm("deaf"), g4opt);
  const g4 = withControls(deaf, deaf, gate4(arm("deaf_hidden"), g4opt));
  const ev = { gate1: g1, gate2: g2, gate4: g4 };
  for (const g of PARKED) ev[g].parked = true;
  return ev;
}

export function groupByArm(summaries) {
  const out = {};
  for (const s of summaries) (out[s.arm] ??= []).push(s);
  return out;
}

const pct = (x) => (x == null ? "-" : (100 * x).toFixed(0) + "%");
const f1 = (x) => (x == null ? "-" : Number.isFinite(x) ? x.toFixed(1) : String(x));
const f2 = (x) => (x == null ? "-" : Number.isFinite(x) ? x.toFixed(2) : String(x));

export function renderGates(ev, meta = {}) {
  const L = [
    "# Anti-kiting gates (G-A)",
    "",
    `Rules: board comment 6367573974. ${meta.when ?? ""} ${meta.commit ? "commit " + meta.commit.slice(0, 8) : ""}`.trim(),
    "",
  ];
  const line = (name, c) =>
    L.push(
      `| ${name} | ${c.real.verdict} | ${c.controls.positive.got} (want ${c.controls.positive.want}) | ${c.controls.negative.got} (want ${c.controls.negative.want}) | ${c.reading}${c.parked ? " (PARKED)" : ""} |`,
    );
  L.push(
    "| Gate | Real arm | Positive control | Negative control | Reading |",
    "| --- | --- | --- | --- | --- |",
  );
  line("1 circling loses", ev.gate1);
  line("2 terrain beats circling", ev.gate2);
  line("4 sight-only clears", ev.gate4);
  L.push("");
  const stageTable = (title, g, cols) => {
    L.push(
      `## ${title}`,
      "",
      "| Stage | " + cols.map((c) => c[0]).join(" | ") + " | Status |",
      "| --- |" + cols.map(() => " --- |").join("") + " --- |",
    );
    for (const r of g.stages)
      L.push(`| ${r.stage} | ${cols.map((c) => c[1](r)).join(" | ")} | ${r.status} |`);
    L.push("");
  };
  for (const [label, g] of [
    ["Gate 1, real (orbit)", ev.gate1.real],
    ["Gate 1, positive (orbit, rut plant)", ev.gate1.positive],
    ["Gate 1, negative (orbit, packs passive)", ev.gate1.negative],
  ]) {
    stageTable(label, g, [
      ["Valid runs", (r) => r.runs],
      ["Not died", (r) => `${r.notDied} ${r.notDiedOutcomes.join("/")}`],
      ["Median death after first hit (s)", (r) => f1(r.medianDeathAfterHitS)],
      ["Void seeds", (r) => r.voidCells],
    ]);
  }
  L.push("## Gate 2", "");
  for (const [label, g] of [
    ["real (A terrain, B orbit)", ev.gate2.real],
    ["positive (A orbit, B orbit x2 damage)", ev.gate2.positive],
    ["negative (A orbit, B orbit again)", ev.gate2.negative],
  ]) {
    L.push(
      `- ${label}: ${g.verdict}, winner ${g.winner}; pairs ${g.pairs} (${g.voidPairs} void); A lower in ${g.A.lower} (need ${g.A.need}), pooled median A/B ${f2(g.A.pooledMedianRatio)} (need 0.75 or less)`,
    );
  }
  L.push("");
  for (const [label, g] of [
    ["Gate 4, real = positive (Expert default driver, --bot-no-mix=1)", ev.gate4.real],
    ["Gate 4, negative (pack telegraphs hidden)", ev.gate4.negative],
  ]) {
    stageTable(label, g, [
      ["Valid runs", (r) => r.n],
      ["Cleared", (r) => r.clears],
      ["Excluded", (r) => r.excluded],
      ["Clear rate", (r) => pct(r.rate)],
    ]);
  }
  L.push(
    `Gate 4 audio-read check: ${ev.gate4.real.auditFree ? "the driver reads no audio or beat state" : "FAILED, the driver reads audio or beat state"}. On-beat follow-on: ${ev.gate4.real.onBeat}.`,
    "",
  );
  const voids = Object.entries(meta.voidByArm ?? {}).filter(([, v]) => v.length);
  if (voids.length) {
    L.push("## Void runs (instrument check failed or no record)", "");
    for (const [armName, v] of voids)
      for (const x of v.slice(0, 40)) L.push(`- ${armName} ${x.id}: ${x.why}`);
    L.push("");
  }
  return L.join("\n");
}
