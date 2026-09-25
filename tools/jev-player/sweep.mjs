// Cache-economy sweep.
//
// Cable Bench asks one question: does a rising difficulty clock make "one more
// cache" a real decision, or do you just take everything? A decision is only
// real if the answer changes somewhere. So hold the situation fixed and move
// one axis at a time, ask the same question at every point, and look for the
// flip. A curve that never crosses means the cache is either always worth it
// or never worth it, and either way it is not a decision.
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { decide } from "./decide.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..");

// The live cost curve from sketches/cable-bench: 25 * tier^1.25.
const cost = (tier) => Math.round(25 * Math.pow(tier, 1.25));

const SURPLUS = [
  { label: "barely", factor: 1.05 },
  { label: "comfortable", factor: 1.5 },
  { label: "flush", factor: 2.5 },
];

const THREAT = [
  { label: "clear", threats: [] },
  {
    label: "pressured",
    threats: [{ kind: "chaser", distance_m: 26, closing: true }],
  },
];

function buildState(tier, surplus, threat) {
  const price = cost(tier);
  return {
    self: {
      speed_ms: 14.0,
      speed_tier: "cruise",
      grounded: true,
      hp: 82,
      air_jump_available: true,
    },
    stage: {
      name: "cable-bench",
      time_s: 45 * tier,
      tier,
      tier_rises_every_s: 45,
      note: "The difficulty tier rises on its own timer whether you act or not.",
    },
    scrap: { held: Math.round(price * surplus.factor) },
    threats: threat.threats,
    objective: { kind: "reach_exit", distance_m: 200, charge_started: false },
  };
}

function buildOptions(tier) {
  const price = cost(tier);
  return [
    {
      id: "take_cache",
      why: `You are already rolling over the cache. Opening it costs ${price} scrap and about one second of stopping; it grants one random permanent stacking buff (+10% cruise, +1 m/s jump, -15% boost cooldown, +25% impact damage, or +20 max HP)`,
    },
    {
      id: "push_objective",
      why: "Skip it and keep driving for the forge apron",
    },
    {
      id: "sweep_scrap",
      why: "Detour onto the nearest scrap line and bank more before deciding",
    },
  ];
}

async function main() {
  const points = [];
  for (const tier of [1, 2, 3, 4, 5]) {
    for (const surplus of SURPLUS) {
      for (const threat of THREAT) {
        points.push({ tier, surplus, threat });
      }
    }
  }
  // Three samples per point, because a single draw near a flip is noise.
  const REPEATS = 3;
  const jobs = [];
  for (const point of points) {
    for (let run = 0; run < REPEATS; run++) {
      jobs.push(point);
    }
  }
  console.log(
    `Sweeping ${points.length} states x ${REPEATS} samples = ${jobs.length} decisions.\n`,
  );

  const answers = await Promise.all(
    jobs.map(async (point) => {
      const result = await decide(
        buildState(point.tier, point.surplus, point.threat),
        buildOptions(point.tier),
      );
      return { ...point, ...result };
    }),
  );

  const table = new Map();
  for (const answer of answers) {
    const key = `${answer.tier}|${answer.surplus.label}|${answer.threat.label}`;
    const cell = table.get(key) || { takes: 0, total: 0, greed: [] };
    cell.total += 1;
    if (answer.intent === "take_cache") {
      cell.takes += 1;
    }
    cell.greed.push(answer.greedy);
    table.set(key, cell);
  }

  console.log("tier  cost  surplus       threat      takes  mean greed");
  const rows = [];
  for (const point of points) {
    const key = `${point.tier}|${point.surplus.label}|${point.threat.label}`;
    const cell = table.get(key);
    const meanGreed = cell.greed.reduce((a, b) => a + b, 0) / cell.greed.length;
    rows.push({
      tier: point.tier,
      cost: cost(point.tier),
      surplus: point.surplus.label,
      threat: point.threat.label,
      takeRate: cell.takes / cell.total,
      meanGreed,
    });
    console.log(
      `${String(point.tier).padEnd(6)}${String(cost(point.tier)).padEnd(6)}${point.surplus.label.padEnd(14)}${point.threat.label.padEnd(12)}${cell.takes}/${cell.total}    ${meanGreed.toFixed(2)}`,
    );
  }

  const everTaken = rows.filter((r) => r.takeRate > 0.5);
  const neverTaken = rows.filter((r) => r.takeRate === 0);
  console.log(
    `\nStates where the cache is taken: ${everTaken.length}/${rows.length}`,
  );
  console.log(
    `States where it is never taken: ${neverTaken.length}/${rows.length}`,
  );
  if (everTaken.length === 0) {
    console.log(
      "\nVERDICT: no state in the sweep takes the cache. The decision is not a decision; the cache economy is priced above what the clock will bear.",
    );
  } else if (neverTaken.length === 0) {
    console.log(
      "\nVERDICT: every state takes the cache. The decision is not a decision in the other direction; nothing makes skipping attractive.",
    );
  } else {
    console.log(
      "\nVERDICT: the answer flips inside the sweep, so there is a real decision. The boundary rows above are where it turns.",
    );
  }

  const out = path.join(root, "artifacts", "local", "jev-player");
  mkdirSync(out, { recursive: true });
  const report = path.join(out, "cache-economy-sweep.json");
  writeFileSync(
    report,
    JSON.stringify(
      { when: new Date().toISOString(), repeats: REPEATS, rows },
      null,
      2,
    ),
  );
  console.log(`\nReport: ${report}`);
  console.log(
    "Model judgement on constructed states, not play. It says where the stated economy reads as worth it, not whether taking it is fun.",
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
