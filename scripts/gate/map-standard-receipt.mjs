#!/usr/bin/env node
// The receipt for the world 1 done read's row "map-standard" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It runs the park tests that print MAPCHECK lines for the dam and the flume itself, through the project's runner
// (scripts/sketch-smoke.mjs, so Godot's HOME is a scratch folder), on this checkout, and takes the head from cleanHead
// (sound-recipes-receipt.mjs: git rev-parse HEAD, refusing uncommitted tracked changes and untracked game files).
// Each MAPCHECK line is `MAPCHECK <map> <measure> ... PASS|FAIL|OWED`; `report INFO` lines carry detail only.
// The receipt passes only when every test finished with no failed check, the gating lines for park_dam and park_flume
// number the pinned count, every one of the ten map points (ruling ct) has at least one gating line on each map, every
// gating line passes or is on WAITING (an item ruled to wait, matched on its status and value, with the line that parks
// it), no line is a measure this file does not map to a point, no half of a point is left open (OPEN_HALVES: a half no
// MAPCHECK line checks is a miss unless a ruling parks it; all four Wave 46B non-MAPCHECK halves are verified in
// VERIFIED_HALVES and recorded in project-guide/handoff/shared/world1/map-audit.md), and the plant was caught: every
// test printed its pinned number of PLANTED lines, each one judged FAIL (the planted fault failed its pass line). An
// OWED line not on WAITING, or one whose value moved, is a miss. Optional `--snag-receipt <file>` also verifies the 8c
// snag-sweep receipt live on the same head.
//
//   node scripts/gate/map-standard-receipt.mjs --out <file> [--snag-receipt <snag-sweep.json>]
//   node scripts/gate/map-standard-receipt.mjs --logs <dir of <test>.log files>   (a test hook: prints, never passes)
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// cleanHead lives in sound-recipes-receipt.mjs until a shared gate module takes it.
import { cleanHead } from "./sound-recipes-receipt.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const COMMIT = /^[0-9a-f]{7,40}$/;
export const MAPS = ["park_dam", "park_flume"];
// Each test that prints MAPCHECK lines for the two maps, with the PLANTED lines it prints that carry a verdict.
export const TESTS = {
  park_landmark_sight_test: 1,
  park_breath_test: 1,
  park_rhythm_test: 2,
  park_variety_test: 2,
  park_cover_tags_test: 3,
  park_feature_census_test: 3,
  park_fight_bowl_test: 2,
  site_markers_test: 0,
  park_scrap_lines_test: 0,
};
// The ten points of the map standard (ruling ct; project-guide/handoff/shared/world1/map-audit.md section G) and the
// MAPCHECK measures that check each one.
export const POINTS = {
  1: ["open_sight_share", "line_sight_share"],
  2: ["line_quiet_share"],
  3: ["rhythm_switches", "longest_heavy_s"],
  4: ["layout_sets", "rogue_sites_drawn", "modifiers_drawn"],
  5: ["shell_cover", "hard_rows_cover_share", "hard_rows_shell_cast_share", "soft_cover_bodies"],
  6: ["feature_count_near_line"],
  7: ["height_bands_populated", "ride_climb_rows"],
  8: ["yard_rim_median_m"],
  9: ["hub_zones_3_bands"],
  10: ["marker_sight", "furnace_sight", "scrap_on_lines"],
};
// Gating MAPCHECK lines for park_dam and park_flume on a full run; a lost or added check moves it.
export const PINNED_LINES = 42;
// Items ruled to wait. Empty since W46-02 (PR #1193, cd8fd6154) built the concave flume yard bowl and
// park_fight_bowl_test.gd pruned OWED := {} (park_flume yard_rim_median_m reads 3.52 m >= 2.0 m PASS).
export const WAITING = [];
// Halves of a point that no MAPCHECK line checks. Each is a miss unless `parked` cites the ruling or line that parks
// it. Empty since Wave 46B closed all four remaining halves (see VERIFIED_HALVES and map-audit.md section G).
export const OPEN_HALVES = [];
// Non-MAPCHECK halves closed and verified in Wave 46B, with exact commits, checks, and audit citations.
export const VERIFIED_HALVES = [
  {
    point: 1,
    half: "1 picture (beam read from fixed chase-camera poses)",
    check:
      "tools/map_sheet_capture.gd (--mode=beam, --control=1) + tests/map_sheet_capture_test.gd",
    commit: "5cd419a8c",
    capture_commit: "5a5a0d916",
    verdict:
      "PASS 4/4 sheets separated blind against beam-hidden controls (ahana RTX 4080, fresh Gemini 4 Neon high): dam-beam 8/8 poses visible, panels 7-8 at 150 m and 46 m read as translucent feathered light/glow with signage, concrete seams and rainbow visible through it (PF-28 cleared); flume-beam 5/8 poses 2-6 visible with penstock tower prominently visible at 50 m; controls 0/8",
    cite: "project-guide/handoff/shared/world1/map-audit.md (Wave 46B verification receipts); PR #1271",
  },
  {
    point: 5,
    half: "5 picture (safe ground and hostile marks read blind)",
    check: "tools/danger_read_capture.gd + planted 45-deg HAZARD-striped yard fence control",
    commit: "e3ca2506d",
    capture_commit: "e3ca2506d",
    verdict:
      "PASS 14/14 exact blind reads (ahana RTX 4080, fresh Gemini 4 Neon high) across boil, lobber, slag and charge (inside, inside-plain, outside), stock yard-inside (NON_HOSTILE_WALL, CLEAR), and planted yard-hazard-control (AMBIGUOUS, hostile stripes caught blind)",
    cite: "project-guide/handoff/shared/world1/map-audit.md (Wave 46B verification receipts)",
  },
  {
    point: 8,
    half: "8b silhouettes (black machines vs 1-hidden control)",
    check:
      "tools/map_sheet_capture.gd (--mode=silhouette, --control=1) + tests/map_sheet_capture_test.gd",
    commit: "5cd419a8c",
    capture_commit: "5a5a0d916",
    verdict:
      "PASS 24/24 exact panel counts blind (ahana RTX 4080, fresh Gemini 4 Neon high): [3, 5, 2, 4, 3, 5] on dam and flume, [2, 4, 1, 3, 2, 4] on both 1-hidden controls (12/12 controls counted one short); re-shot at cf8d91461 with CrewLamps hidden and flume pose 2 unclipped",
    cite: "project-guide/handoff/shared/world1/map-audit.md (Wave 46B verification receipts); PR #1271",
  },
  {
    point: 8,
    half: "8c snags (riding lines & open-ground tile seams)",
    check:
      "tools/qa/snag_sweep.gd + tests/snag_sweep_test.gd + scripts/gate/snag-sweep-receipt.mjs --mapcheck",
    commit: "ebf3e7f75",
    capture_commit: "73daadfe0",
    verdict:
      "PASS 4-shard sweep: park_dam 0 ride snags, 0 seams (513 lanes, 0.2% skipped); park_flume 0 ride snags, 0 seams (1100 lanes, 0.0% skipped); planted 0.3 m ride lip, open-ground seam and injected dam snag caught; independently enforced as the snag-sweep sitting gate row",
    cite: "project-guide/handoff/shared/world1/map-audit.md (Wave 46B verification receipts); PR #1273; scripts/world1-bands.rows.json (snag-sweep)",
  },
];

const pointOf = (measure) =>
  Number(Object.keys(POINTS).find((p) => POINTS[p].includes(measure)) ?? 0);
const findWaiting = (waitingList, line) =>
  waitingList.find(
    (w) =>
      w.map === line.map &&
      w.measure === line.measure &&
      w.status === line.status &&
      w.value === line.value,
  );

function checkSnagReceipt(snagReceipt, head) {
  if (!snagReceipt || typeof snagReceipt !== "object" || Array.isArray(snagReceipt)) {
    return {
      ok: false,
      plantOk: true,
      problem: "8c snag-sweep receipt is not a JSON object",
      note: null,
    };
  }
  if (typeof snagReceipt.head !== "string" || !COMMIT.test(snagReceipt.head)) {
    return {
      ok: false,
      plantOk: true,
      problem: "8c snag-sweep receipt names no valid commit head",
      note: null,
    };
  }
  if (typeof head !== "string" || !COMMIT.test(head)) {
    return {
      ok: false,
      plantOk: true,
      problem: "8c snag-sweep receipt has no valid checkout head to match",
      note: null,
    };
  }
  if (!(head.startsWith(snagReceipt.head) || snagReceipt.head.startsWith(head))) {
    return {
      ok: false,
      plantOk: true,
      problem: `8c snag-sweep receipt head ${snagReceipt.head.slice(0, 9)} does not match ${head.slice(0, 9)}`,
      note: null,
    };
  }
  if (snagReceipt.plant_caught !== true) {
    return {
      ok: false,
      plantOk: false,
      problem: "8c snag-sweep receipt plant was not shown caught",
      note: null,
    };
  }
  if (snagReceipt.pass !== true) {
    const detail =
      typeof snagReceipt.measured === "string" && snagReceipt.measured
        ? `: ${snagReceipt.measured.slice(0, 120)}`
        : "";
    return {
      ok: false,
      plantOk: true,
      problem: `8c snag-sweep receipt failed${detail}`,
      note: null,
    };
  }
  return {
    ok: true,
    plantOk: true,
    problem: null,
    note: `8c snag-sweep receipt verified (${snagReceipt.head.slice(0, 9)})`,
  };
}

// The gating MAPCHECK lines of one log: {map, measure, value, line, status, text}.
export function mapLines(text) {
  return text
    .split("\n")
    .filter((l) => l.startsWith("MAPCHECK ") && !/\breport INFO\b/.test(l))
    .map((l) => {
      const words = l.trim().split(/\s+/);
      const status = words.find((w) => w === "PASS" || w === "FAIL" || w === "OWED") ?? "NONE";
      const at = words.findIndex((w) => w.startsWith("pass"));
      return {
        map: words[1],
        measure: words[2],
        value: words[at - 1],
        line: words[at] ?? "",
        status,
        text: l.trim(),
      };
    });
}

const plantLines = (text) =>
  text.split("\n").filter((l) => l.startsWith("PLANTED ") && /\b(PASS|FAIL)\s*$/.test(l.trim()));

// logs: {"<test>": "<log text>"}.
// halves and waiting are seams for the node tests; the receipt itself always judges OPEN_HALVES and WAITING.
// snagReceipt optionally verifies the 8c snag-sweep receipt live against the same head.
export function buildReceipt(
  logs,
  head,
  { halves = OPEN_HALVES, waiting: waitingList = WAITING, snagReceipt = undefined } = {},
) {
  const problems = [];
  let plantCaught = true;
  const plantNotes = [];
  const lines = [];
  for (const [test, plants] of Object.entries(TESTS)) {
    const text = logs[test] ?? "";
    if (!new RegExp(`^${test}: PASS \\(`, "m").test(text)) {
      const failed = text.split("\n").filter((l) => l.endsWith("-> FAIL"));
      problems.push(
        failed.length
          ? `${test}: ${failed.length} check(s) failed: ${failed[0].slice(0, 100)}`
          : `${test} did not finish`,
      );
    }
    const planted = plantLines(text);
    const caught = planted.filter((l) => /\bFAIL\s*$/.test(l.trim())).length;
    if (planted.length < plants || caught !== planted.length) {
      plantCaught = false;
      plantNotes.push(`${test} ${caught} of ${planted.length} plants caught, pinned ${plants}`);
    }
    lines.push(...mapLines(text).filter((l) => MAPS.includes(l.map)));
  }
  let snagNote = null;
  if (snagReceipt !== undefined) {
    const snag = checkSnagReceipt(snagReceipt, head);
    if (!snag.plantOk) {
      plantCaught = false;
      plantNotes.push("8c snag-sweep plant not caught");
    }
    if (!snag.ok) problems.push(snag.problem);
    else snagNote = snag.note;
  }
  const unmapped = lines.filter((l) => pointOf(l.measure) === 0);
  for (const l of unmapped) problems.push(`unmapped measure ${l.map} ${l.measure}`);
  const counts = {};
  const uncovered = [];
  for (const p of Object.keys(POINTS)) {
    counts[p] = MAPS.map(
      (m) => lines.filter((l) => l.map === m && pointOf(l.measure) === Number(p)).length,
    );
    MAPS.forEach((m, i) => {
      if (counts[p][i] === 0) uncovered.push(`point ${p} on ${m}`);
    });
  }
  const held = lines.filter((l) => l.status !== "PASS" && findWaiting(waitingList, l));
  const misses = lines.filter((l) => l.status !== "PASS" && !findWaiting(waitingList, l));
  const countedOk = lines.length === PINNED_LINES;
  const open = halves.filter((h) => !h.parked);
  const pass =
    problems.length === 0 &&
    countedOk &&
    uncovered.length === 0 &&
    misses.length === 0 &&
    open.length === 0 &&
    plantCaught &&
    lines.length > 0;

  const perPoint = Object.keys(POINTS)
    .map((p) => `${p}:${counts[p].join("/")}`)
    .join(" ");
  let measured =
    lines.length === 0
      ? "no MAPCHECK lines: the tests did not run"
      : `${lines.length} MAPCHECK lines (pinned ${PINNED_LINES}); lines per point dam/flume ${perPoint}`;
  if (snagNote) measured += `; ${snagNote}`;
  if (!countedOk && lines.length)
    measured += "; the line count is off the pin: a check was lost or added";
  if (uncovered.length) measured += `; no check for ${uncovered.join(", ")}`;
  if (misses.length)
    measured += `; misses: ${misses.map((l) => `${l.map} ${l.measure} ${l.value} ${l.line} ${l.status}`).join(", ")}`;
  if (open.length)
    measured += `; open halves, no ruling parks them: ${open.map((h) => `${h.half} (closes with ${h.closes})`).join("; ")}`;
  if (held.length)
    measured += `; waiting: ${held.map((l) => `${l.map} ${l.measure} ${l.value} ${l.line} (${findWaiting(waitingList, l).cite.split(" ")[0]})`).join(", ")}`;
  if (problems.length) measured += `; ${problems.join("; ")}`;
  if (!plantCaught) measured += `; plants not shown caught: ${plantNotes.join(", ")}`;
  return { head, pass, measured, plant_caught: plantCaught };
}

// Runs every test through the project's runner and returns {"<test>": "<log text>"}.
export function runTests(cwd) {
  const logs = mkdtempSync(path.join(os.tmpdir(), "map-standard-"));
  try {
    const args = [path.join(cwd, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop"];
    for (const test of Object.keys(TESTS)) args.push("--test", test);
    const run = spawnSync(process.execPath, args, {
      cwd,
      env: { ...process.env, SMOKE_LOG_DIR: logs },
      encoding: "utf8",
      maxBuffer: 1 << 26,
    });
    const out = {};
    for (const test of Object.keys(TESTS)) {
      const file = path.join(logs, `${test}.log`);
      out[test] = existsSync(file)
        ? readFileSync(file, "utf8")
        : `runner exit ${run.status}, no ${test}.log`;
    }
    return out;
  } finally {
    rmSync(logs, { recursive: true, force: true });
  }
}

// The receipt for the checkout at cwd. run is injectable so the refusal can be tested without Godot.
export function produce({ cwd = root, run = runTests, snagReceipt = undefined } = {}) {
  const head = cleanHead(cwd);
  return buildReceipt(run(cwd), head, { snagReceipt });
}

export function parseArgs(argv) {
  const args = { out: null, logs: null, snagReceipt: null };
  const take = (i, flag) => {
    const val = argv[i + 1];
    if (val === undefined || val === "" || val.startsWith("--")) {
      throw new Error(`${flag} requires a value`);
    }
    return val;
  };
  const takeEq = (a, flag) => {
    const val = a.slice(flag.length + 1);
    if (val === "") throw new Error(`${flag} requires a value`);
    return val;
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--out") args.out = take(i++, a);
    else if (a.startsWith("--out=")) args.out = takeEq(a, "--out");
    else if (a === "--logs") args.logs = take(i++, a);
    else if (a.startsWith("--logs=")) args.logs = takeEq(a, "--logs");
    else if (a === "--snag-receipt") args.snagReceipt = take(i++, a);
    else if (a.startsWith("--snag-receipt=")) args.snagReceipt = takeEq(a, "--snag-receipt");
    else throw new Error(`unknown argument: ${a}`);
  }
  return args;
}

function readSnagReceipt(file) {
  if (!existsSync(file)) throw new Error(`--snag-receipt file not found: ${file}`);
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch (e) {
    throw new Error(`cannot parse --snag-receipt JSON (${file}): ${e?.message ?? e}`);
  }
}

function main(argv) {
  let args;
  let snagReceipt = undefined;
  try {
    args = parseArgs(argv);
    if (args.snagReceipt) snagReceipt = readSnagReceipt(args.snagReceipt);
  } catch (e) {
    console.error(String(e?.message ?? e));
    return 2;
  }
  if (args.logs) {
    // A test hook: logs from anywhere judge no commit, so it never writes a passing receipt.
    const logs = {};
    for (const test of Object.keys(TESTS)) {
      const file = path.join(args.logs, `${test}.log`);
      logs[test] = existsSync(file) ? readFileSync(file, "utf8") : "";
    }
    const r = buildReceipt(logs, "0000000", { snagReceipt });
    process.stdout.write(
      JSON.stringify(
        { ...r, pass: false, measured: `logs only, not a receipt: ${r.measured}` },
        null,
        2,
      ) + "\n",
    );
    return 1;
  }
  let receipt;
  try {
    receipt = produce({ snagReceipt });
  } catch (e) {
    console.error(String(e?.message ?? e));
    return 2;
  }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  process.exit(main(process.argv.slice(2)));
