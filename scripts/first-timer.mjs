// FIRST-TIMER audit (alpha-status ambition map, unit 8): every mechanic a run needs is taught
// on screen before the first time it is needed. tools/first_timer.gd plays one headless bot run
// per pilot on a fresh profile and records first ticks; this file holds the mechanic table,
// judges each probe and exits 1 when a needed mechanic comes before its lesson.
//
//   node scripts/first-timer.mjs [--pilots=all|id,id] [--seed=1] [--stages=2] [--jobs=3]
//     [--out=artifacts/local/first-timer] [--from=<dir of probe-*.json>] [--scrap-at=<seconds>] [--table=park]
//
// --scrap-at ends each run with a death that many seconds into stage 1, the only way the
// skipper reaches the retry row; the rows after it read "not reached" in that pass.
// --table picks the stage table; it defaults to park, the maps a launched game plays (a test-mode
// game with no --table plays the legacy default table, game.gd _chosen_table).
// --from re-judges saved probes without running Godot. Writes report.json and report.md to --out.

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { binary } from "./sketch-smoke.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches", "core-loop");

export const PILOTS = ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"];
export const PILOT_NAMES = {
  pylon_engineer: "Sable",
  runner_gunner: "Rivet",
  demolitions_caster: "Kest",
  tarn: "Tarn",
  tally: "Tally",
  remembered_cannon: "Cannon",
};

// A lesson that lands this soon after the need still counts: the plate and prompts draw on
// the tick after the bus fact that changes them. 0.5 s at the probe's 90 Hz.
export const GRACE_TICKS = 45;

// needed: required (the run cannot go on without it) or optional (fails nothing, still listed).
// need: the probe's need id that marks the first time it matters. teach: probe teach ids, any of
// which counts; a card: id is the pilot's class card, seen once before the run.
export const MECHANICS = [
  {
    id: "roll",
    name: "Roll and steer the ball",
    needed: "required",
    need: "stage_entered",
    teach: ["prompt:roll"],
  },
  {
    id: "warden",
    name: "Break the Warden at the beacon",
    needed: "required",
    need: "warden_engaged",
    teach: ["objective:find_warden", "objective:break_clamp_crews", "objective:break_guard", "objective:break_warden"],
  },
  {
    id: "slam",
    name: "Slam the open core",
    needed: "required",
    need: "warden_staggered",
    teach: ["prompt:slam", "card:smash"],
  },
  {
    id: "gates",
    name: "Roll through a reward gate",
    needed: "required",
    need: "reward_offered",
    teach: ["objective:roll_gate"],
  },
  {
    id: "boss",
    name: "Stagger Brindle and smash the opening",
    needed: "required",
    need: "boss_staggered",
    teach: ["objective:break_guard", "objective:smash_core", "objective:shoot_magnets", "objective:break_brindle"],
    note: "On the park table Brindle's plate names each phase's loop from the arena's first frame (phase 1: \"Shoot magnets, then cockpit\", objectives.gd STEPS); the legacy table carried it over from the Warden fights.",
  },
  {
    id: "retry",
    name: "Run again after being scrapped",
    needed: "required",
    need: "dead",
    teach: ["screen:run_over"],
    note: "A death with no earned save ends the run (no free retry), so the lesson is RUN OVER itself: its line naming what scrapped you and its Run again key. A run with no death reads \"not reached\"; --scrap-at=<s> scraps each pilot that many seconds into stage 1 to measure it.",
  },
  {
    id: "harpoon",
    name: "Harpoon an enemy",
    needed: "optional",
    need: "harpoon_used",
    teach: ["prompt:harpoon", "card:harpoon"],
  },
  {
    id: "grapple",
    name: "Hook the world and swing",
    needed: "optional",
    need: "grapple_used",
    teach: ["prompt:harpoon", "prompt:letgo"],
  },
  {
    id: "grip",
    name: "Wall grip: stay fast and walls hold",
    needed: "optional",
    need: "grip_used",
    teach: ["prompt:tip_grip"],
    note: "Optional because it is a bonus, not a gate: the run goes on without carving. Taught by the first-meet tip (ui/field_tips.gd), queued when the ball first carves a wall and counted once its toast has been on screen 0.4 s; another tip or toast up at the time delays it.",
  },
  {
    id: "jam",
    name: "Jam fields lock slots 2 and 3",
    needed: "optional",
    need: "jam_hit",
    teach: ["prompt:tip_jam"],
    note: "Optional: the jammer's mat sits in a Dig stage the two-stage bot run may not enter, and a fast ball slips its pulse. Taught by the first-meet tip, queued when a pulse first jams the ball.",
  },
  {
    id: "cast",
    name: "Cast times: a knock drops a cast",
    needed: "optional",
    need: "cast_started",
    teach: ["prompt:tip_cast"],
    note: "Optional: only some slot abilities carry a cast time and the bot seldom picks them. Taught by the first-meet tip from the drop when the bar already holds a slot with a cast time (Tally's Gather Plate), else when a cast first starts. It waits behind any tip met now (the radio's, the grip's) and behind a Warden fight, so a cast-slot pilot can cast before the tip shows and the audit reads it late.",
  },
  {
    id: "radio",
    name: "Radio dial: . next, , back, / skip",
    needed: "optional",
    need: "radio_live",
    teach: ["prompt:tip_radio"],
    note: "Optional: the run goes on without touching the radio; the dial only changes the music. Taught by the first-meet tip, which waits for the drop's stage card to clear and then counts once its toast has been on screen 0.4 s, so it comes a few seconds after the dial's first frame and the audit reads it late.",
  },
  {
    id: "stake",
    name: "Relay stakes: hold E at the mast",
    needed: "optional",
    need: "relay_met",
    teach: ["prompt:tip_stake"],
    note: "Optional: a relay is a park site the bot does not seek out. Taught by the first-meet tip from 30 m of a stake post; the probe counts the post met at E's 18 m lock reach, which a fast ball can reach before the tip has been up 0.4 s.",
  },
  {
    id: "companion",
    name: "SPIL-9: the next ram calls it in",
    needed: "optional",
    need: "companion_full",
    teach: ["prompt:tip_companion"],
    note: "Optional: the halo only charges with a companion seated, and a run starts without one. Taught by the first-meet tip, queued when the halo fills.",
  },
  {
    id: "active",
    name: "Actives on F",
    needed: "optional",
    need: "active_racked",
    teach: ["prompt:tip_active"],
    note: "Optional by design: actives are off by default (--actives), so a default run never racks one. Taught by the first-meet tip, queued when one is first racked.",
  },
  {
    id: "scrap",
    name: "Scrap makes you heavier",
    needed: "optional",
    need: "scrap_collected",
    teach: [],
    note: "The \"Scrap = heft\" first-run callout (ui/callouts.gd) was retired with the old HUD (design-v3/LEGIBILITY.md item 33) and nothing replaced it.",
  },
  {
    id: "shop",
    name: "Buy from Moss with cogs",
    needed: "optional",
    need: "bay_entered",
    teach: [],
    note: "The bay is labelled \"Moss's workshop\"; nothing says what cogs buy or how to buy.",
  },
  {
    id: "camp",
    name: "Camp between runs",
    needed: "optional",
    need: null,
    teach: [],
    note: "Outside a run: the title page's Camp button (K). The probe does not reach it.",
  },
];

// One mechanic in one probe: {verdict, need_tick, teach_id, teach_tick, stage}.
// verdict: ok, card_only, late, never, not_reached.
export function judge(mechanic, probe) {
  const need = mechanic.need ? probe.needed?.[mechanic.need] : undefined;
  const lessons = mechanic.teach
    .map((id) => ({ id, ...(probe.taught?.[id] ?? {}) }))
    .filter((lesson) => Number.isInteger(lesson.tick))
    .sort((a, b) => a.tick - b.tick);
  const first = lessons[0];
  if (!need) {
    return { verdict: "not_reached", need_tick: null, teach_id: first?.id ?? null, teach_tick: first?.tick ?? null, stage: null };
  }
  const inTime = lessons.filter((lesson) => lesson.tick <= need.tick + GRACE_TICKS);
  const inRun = inTime.find((lesson) => !lesson.id.startsWith("card:"));
  const chosen = inRun ?? inTime[0] ?? first;
  const verdict = inRun ? "ok" : inTime.length ? "card_only" : first ? "late" : "never";
  return { verdict, need_tick: need.tick, teach_id: chosen?.id ?? null, teach_tick: chosen?.tick ?? null, stage: need.stage };
}

export const FAILING = new Set(["late", "never"]);

export function audit(probes) {
  const rows = MECHANICS.map((mechanic) => {
    const runs = probes.map((probe) => ({ pilot: probe.pilot, hz: probe.tick_hz || 90, ...judge(mechanic, probe) }));
    const failed = mechanic.needed === "required" && runs.some((run) => FAILING.has(run.verdict));
    return { ...mechanic, runs, failed };
  });
  return { ok: !rows.some((row) => row.failed), rows };
}

const VERDICT_WORDS = {
  ok: "taught in time",
  card_only: "only on the pilot card",
  late: "needed before it is taught",
  never: "never taught",
  not_reached: "not reached",
};

const seconds = (tick, hz) => (tick === null ? "" : tick < 0 ? "before the run" : `${(tick / hz).toFixed(1)} s`);

export function markdown(result, probes) {
  const lines = [
    "# FIRST-TIMER audit",
    "",
    `Result: ${result.ok ? "PASS" : "FAIL"}. Runs: ${probes.map((p) => `${PILOT_NAMES[p.pilot] ?? p.pilot} seed ${p.seed} to stage ${p.stage_reached}`).join(", ")}.`,
    "",
    "| Mechanic | Needed | Verdict per pilot | First needed | First taught by |",
    "|---|---|---|---|---|",
  ];
  for (const row of result.rows) {
    const verdicts = row.runs.map((run) => `${PILOT_NAMES[run.pilot] ?? run.pilot}: ${VERDICT_WORDS[run.verdict]}`).join("; ");
    const sample = row.runs.find((run) => run.need_tick !== null) ?? row.runs[0];
    lines.push(
      `| ${row.name}${row.failed ? " **FAIL**" : ""} | ${row.needed} | ${verdicts} | ${sample ? seconds(sample.need_tick, sample.hz) : ""} | ${sample?.teach_id ?? "nothing"} ${sample ? seconds(sample.teach_tick, sample.hz) : ""} |`,
    );
  }
  lines.push("");
  for (const row of result.rows.filter((r) => r.note)) lines.push(`- ${row.name}: ${row.note}`);
  return lines.join("\n") + "\n";
}

export function parseArgs(argv) {
  const args = { pilots: "all", seed: 1, stages: 2, jobs: 3, out: path.join(root, "artifacts", "local", "first-timer"), from: null, "scrap-at": null, table: "park" };
  for (const arg of argv) {
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (!match || !(match[1] in args)) throw new Error(`first-timer: unknown argument ${arg}`);
    args[match[1]] = ["seed", "stages", "jobs", "scrap-at"].includes(match[1]) ? Number(match[2]) : match[2];
  }
  if (args["scrap-at"] !== null && !(args["scrap-at"] > 0)) throw new Error("first-timer: --scrap-at takes seconds above zero");
  args.pilots = args.pilots === "all" ? PILOTS : args.pilots.split(",");
  for (const pilot of args.pilots) if (!PILOTS.includes(pilot)) throw new Error(`first-timer: unknown pilot ${pilot}`);
  return args;
}

function probe(pilot, args) {
  const out = path.join(args.out, `probe-${pilot}-${args.seed}.json`);
  const argv = ["--headless", "--fixed-fps", "90", "--path", sketch, "--script", "res://tools/first_timer.gd", "--",
    `--out=${out}`, `--seed=${args.seed}`, `--pilot=${pilot}`, `--stages=${args.stages}`, `--table=${args.table}`];
  if (args["scrap-at"] !== null) argv.push(`--scrap-at=${args["scrap-at"]}`);
  return new Promise((resolve, reject) => {
    const child = spawn(binary, argv, { stdio: ["ignore", "pipe", "pipe"] });
    let tail = "";
    const keep = (chunk) => (tail = (tail + chunk).slice(-4000));
    child.stdout.on("data", keep);
    child.stderr.on("data", keep);
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0 || !existsSync(out)) reject(new Error(`first-timer: ${pilot} probe exited ${code}\n${tail}`));
      else resolve(JSON.parse(readFileSync(out, "utf8")));
    });
  });
}

async function runProbes(args) {
  const queue = [...args.pilots];
  const probes = [];
  const worker = async () => {
    while (queue.length) {
      const pilot = queue.shift();
      console.log(`first-timer: probing ${pilot}`);
      probes.push(await probe(pilot, args));
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, args.jobs) }, worker));
  return probes.sort((a, b) => PILOTS.indexOf(a.pilot) - PILOTS.indexOf(b.pilot));
}

function readProbes(dir) {
  return readdirSync(dir)
    .filter((name) => /^probe-[^.]*\.json$/.test(name))
    .map((name) => JSON.parse(readFileSync(path.join(dir, name), "utf8")))
    .sort((a, b) => PILOTS.indexOf(a.pilot) - PILOTS.indexOf(b.pilot));
}

export async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  mkdirSync(args.out, { recursive: true });
  const probes = args.from ? readProbes(args.from) : await runProbes(args);
  if (!probes.length) throw new Error("first-timer: no probes");
  const result = audit(probes);
  const page = markdown(result, probes);
  writeFileSync(path.join(args.out, "report.json"), JSON.stringify({ ...result, probes }, null, 2) + "\n");
  writeFileSync(path.join(args.out, "report.md"), page);
  console.log(page);
  for (const row of result.rows.filter((r) => r.failed)) console.error(`FAIL first-timer: ${row.name}`);
  return result.ok ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().then(
    (code) => process.exit(code),
    (error) => {
      console.error(error.message);
      process.exit(2);
    },
  );
}
