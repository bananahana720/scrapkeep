import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { requireGodotBinary } from "./godot-home.mjs";
import { isMain } from "./lib/cli.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sketch = path.join(root, "sketches", "core-loop");

export const PILOTS = [
  "pylon_engineer",
  "runner_gunner",
  "demolitions_caster",
  "tarn",
  "tally",
  "remembered_cannon",
];
export const PILOT_NAMES = {
  pylon_engineer: "Sable",
  runner_gunner: "Rivet",
  demolitions_caster: "Kest",
  tarn: "Tarn",
  tally: "Tally",
  remembered_cannon: "Cannon",
};

export const GRACE_TICKS = 45;

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
    teach: [
      "objective:find_warden",
      "objective:break_clamp_crews",
      "objective:break_guard",
      "objective:break_warden",
    ],
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
    teach: ["objective:break_guard", "objective:smash_core", "objective:shoot_magnets"],
    note: "On the park table Brindle's plate names each phase's loop from the arena's first frame (phase 1: \"Shoot magnets, then cockpit\", objectives.gd's boss rows); the legacy table carried it over from the Warden fights.",
  },
  {
    id: "retry",
    name: "Run again after being scrapped",
    needed: "required",
    need: "dead",
    teach: ["screen:run_over"],
    note: 'A death with no earned save ends the run (no free retry), so the lesson is RUN OVER itself: its line naming what scrapped you and its Run again key. A run with no death reads "not reached"; --scrap-at=<s> scraps each pilot that many seconds into stage 1 to measure it.',
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
    note: "Optional because it is a bonus, not a gate: the run goes on without carving. Taught by the first-meet tip (ui/field_tips.gd), queued when the ball first ends a real carve (events.carved, 0.3 s or more) that touched a wall face, not a dune or a seam hop, and counted once its toast has been on screen 0.4 s; another tip or toast up at the time delays it.",
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
    note: "Optional: only some slot abilities carry a cast time and the bot seldom picks them. Taught by the first-meet tip when a cast first starts (not from the drop: pass E paces the opening to one tip in its first 20 s). It waits behind a Warden fight, so the audit can read it late.",
  },
  {
    id: "radio",
    name: "Radio dial: . next, , back, / skip",
    needed: "optional",
    need: "radio_live",
    teach: ["prompt:tip_radio"],
    note: "Optional: the run goes on without touching the radio; the dial only changes the music. Taught by the first-meet tip once the run has cleared a stage (pass E: never needed in the opening); the dial draws its own keys while the tip is up. It counts once its toast has been on screen 0.4 s, so the audit reads it after the dial's first frame.",
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
    note: "Optional: a run starts with an active racked (the actives launch option is on by default, tuning.gd), but nothing needs one. Taught by the first-meet tip, queued when one is racked and the run has met a fight (a hit taken or a kill), so it comes in the first fight, not on the drop.",
  },
  {
    id: "scrap",
    name: "Scrap makes you heavier",
    needed: "optional",
    need: "scrap_collected",
    teach: [],
    note: 'The "Scrap = heft" first-run callout (ui/callouts.gd) was retired with the old HUD (design-v3/LEGIBILITY.md item 33) and nothing replaced it.',
  },
  {
    id: "shop",
    name: "Buy from Moss with cogs",
    needed: "optional",
    need: "bay_entered",
    teach: [],
    note: 'The bay is labelled "Moss\'s workshop"; nothing says what cogs buy or how to buy.',
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

export function judge(mechanic, probe) {
  const need = mechanic.need ? probe.needed?.[mechanic.need] : undefined;
  const lessons = mechanic.teach
    .map((id) => ({ id, ...(probe.taught?.[id] ?? {}) }))
    .filter((lesson) => Number.isInteger(lesson.tick))
    .sort((a, b) => a.tick - b.tick);
  const first = lessons[0];
  if (!need) {
    return {
      verdict: "not_reached",
      need_tick: null,
      teach_id: first?.id ?? null,
      teach_tick: first?.tick ?? null,
      stage: null,
    };
  }
  const inTime = lessons.filter((lesson) => lesson.tick <= need.tick + GRACE_TICKS);
  const inRun = inTime.find((lesson) => !lesson.id.startsWith("card:"));
  const chosen = inRun ?? inTime[0] ?? first;
  const verdict = inRun ? "ok" : inTime.length ? "card_only" : first ? "late" : "never";
  return {
    verdict,
    need_tick: need.tick,
    teach_id: chosen?.id ?? null,
    teach_tick: chosen?.tick ?? null,
    stage: need.stage,
  };
}

export const FAILING = new Set(["late", "never"]);

export function audit(probes) {
  const rows = MECHANICS.map((mechanic) => {
    const runs = probes.map((probe) => ({
      pilot: probe.pilot,
      hz: probe.tick_hz || 90,
      ...judge(mechanic, probe),
    }));
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

const seconds = (tick, hz) =>
  tick === null ? "" : tick < 0 ? "before the run" : `${(tick / hz).toFixed(1)} s`;

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
    const verdicts = row.runs
      .map((run) => `${PILOT_NAMES[run.pilot] ?? run.pilot}: ${VERDICT_WORDS[run.verdict]}`)
      .join("; ");
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
  const args = {
    pilots: "all",
    seed: 1,
    stages: 2,
    jobs: 3,
    out: path.join(root, "artifacts", "local", "first-timer"),
    from: null,
    "scrap-at": null,
    table: "park",
  };
  for (const arg of argv) {
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (!match || !(match[1] in args)) throw new Error(`first-timer: unknown argument ${arg}`);
    args[match[1]] = ["seed", "stages", "jobs", "scrap-at"].includes(match[1])
      ? Number(match[2])
      : match[2];
  }
  if (args["scrap-at"] !== null && !(args["scrap-at"] > 0))
    throw new Error("first-timer: --scrap-at takes seconds above zero");
  args.pilots = args.pilots === "all" ? PILOTS : args.pilots.split(",");
  for (const pilot of args.pilots)
    if (!PILOTS.includes(pilot)) throw new Error(`first-timer: unknown pilot ${pilot}`);
  return args;
}

function probe(pilot, args, binary) {
  const out = path.join(args.out, `probe-${pilot}-${args.seed}.json`);
  const argv = [
    "--headless",
    "--fixed-fps",
    "90",
    "--path",
    sketch,
    "--script",
    "res://tools/first_timer.gd",
    "--",
    `--out=${out}`,
    `--seed=${args.seed}`,
    `--pilot=${pilot}`,
    `--stages=${args.stages}`,
    `--table=${args.table}`,
  ];
  if (args["scrap-at"] !== null) argv.push(`--scrap-at=${args["scrap-at"]}`);
  return new Promise((resolve, reject) => {
    const child = spawn(binary, argv, { stdio: ["ignore", "pipe", "pipe"] });
    let tail = "";
    const keep = (chunk) => (tail = (tail + chunk).slice(-4000));
    child.stdout.on("data", keep);
    child.stderr.on("data", keep);
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0 || !existsSync(out))
        reject(new Error(`first-timer: ${pilot} probe exited ${code}\n${tail}`));
      else resolve(JSON.parse(readFileSync(out, "utf8")));
    });
  });
}

async function runProbes(args) {
  const binary = requireGodotBinary();
  mkdirSync(args.out, { recursive: true });
  const queue = [...args.pilots];
  const probes = [];
  const worker = async () => {
    while (queue.length) {
      const pilot = queue.shift();
      console.log(`first-timer: probing ${pilot}`);
      probes.push(await probe(pilot, args, binary));
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
  const probes = args.from ? readProbes(args.from) : await runProbes(args);
  if (!probes.length) throw new Error("first-timer: no probes");
  mkdirSync(args.out, { recursive: true });
  const result = audit(probes);
  const page = markdown(result, probes);
  writeFileSync(
    path.join(args.out, "report.json"),
    JSON.stringify({ ...result, probes }, null, 2) + "\n",
  );
  writeFileSync(path.join(args.out, "report.md"), page);
  console.log(page);
  for (const row of result.rows.filter((r) => r.failed))
    console.error(`FAIL first-timer: ${row.name}`);
  return result.ok ? 0 : 1;
}

if (isMain(import.meta.url)) {
  main().then(
    (code) => process.exit(code),
    (error) => {
      console.error(error.message);
      process.exit(2);
    },
  );
}
