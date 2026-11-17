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
// MAPCHECK line checks is a miss unless a ruling parks it), and the plant was caught: every test printed its pinned
// number of PLANTED lines, each one judged FAIL (the planted fault failed its pass line). An OWED line not on WAITING,
// or one whose value moved, is a miss.
//
//   node scripts/gate/map-standard-receipt.mjs --out <file>
//   node scripts/gate/map-standard-receipt.mjs --logs <dir of <test>.log files>   (a test hook: prints, never passes)
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// cleanHead lives in sound-recipes-receipt.mjs until a shared gate module takes it.
import { cleanHead } from "./sound-recipes-receipt.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const MAPS = ["park_dam", "park_flume"];
// Each test that prints MAPCHECK lines for the two maps, with the PLANTED lines it prints that carry a verdict.
export const TESTS = {
  park_landmark_sight_test: 1,
  park_breath_test: 1,
  park_rhythm_test: 2,
  park_variety_test: 1,
  park_cover_tags_test: 2,
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
  5: ["shell_cover", "hard_rows_cover_share", "soft_cover_bodies"],
  6: ["feature_count_near_line"],
  7: ["height_bands_populated", "ride_climb_rows"],
  8: ["yard_rim_median_m"],
  9: ["hub_zones_3_bands"],
  10: ["marker_sight", "furnace_sight", "scrap_on_lines"],
};
// Gating MAPCHECK lines for park_dam and park_flume on a full run; a lost or added check moves it.
export const PINNED_LINES = 40;
// Items ruled to wait. Each names the line that parks it.
export const WAITING = [
  {
    map: "park_flume",
    measure: "yard_rim_median_m",
    status: "OWED",
    value: "-0.41",
    why: "the rebuilt concave flume yard is parked until after the sitting",
    cite: "project-guide/handoff/ROADMAP.md:27 (\"the rebuilt concave flume yard (the bowl test records it as OWED)\"); DECISIONS.md:320, ruling ct",
  },
];
// Halves of a point that no MAPCHECK line checks. Each is a miss unless `parked` cites the ruling or line that parks
// it; none is parked today. `closes` names the check that would close it.
export const OPEN_HALVES = [
  { point: 1, half: "1 picture (beam read from fixed chase-camera poses)", closes: "tools/map_sheet_capture.gd sheets read blind against a beam-hidden control" },
  { point: 5, half: "5 picture (safe ground and hostile marks read blind)", closes: "a blind 'where is safe' read of tools/danger_read_capture.gd stills, scored against its HAZARD-striped control" },
  { point: 5, half: "5 tagged cover (park_cover_tags_test reads layers only, so it passes by construction)", closes: "hard and soft tags on park rows and a shell-path cast per tagged row (audit unit 6)" },
  { point: 8, half: "8b silhouettes", closes: "tools/map_sheet_capture.gd silhouette mode, one machine hidden counted short" },
  { point: 8, half: "8c snags", closes: "a MAPCHECK line per map from tools/qa/snag_sweep.gd (0 snags per area)" },
];

const pointOf = (measure) => Number(Object.keys(POINTS).find((p) => POINTS[p].includes(measure)) ?? 0);
const waiting = (line) => WAITING.find((w) => w.map === line.map && w.measure === line.measure && w.status === line.status && w.value === line.value);

// The gating MAPCHECK lines of one log: {map, measure, value, line, status, text}.
export function mapLines(text) {
  return text.split("\n").filter((l) => l.startsWith("MAPCHECK ") && !/\breport INFO\b/.test(l)).map((l) => {
    const words = l.trim().split(/\s+/);
    const status = words.find((w) => w === "PASS" || w === "FAIL" || w === "OWED") ?? "NONE";
    const at = words.findIndex((w) => w.startsWith("pass"));
    return { map: words[1], measure: words[2], value: words[at - 1], line: words[at] ?? "", status, text: l.trim() };
  });
}

const plantLines = (text) => text.split("\n").filter((l) => l.startsWith("PLANTED ") && /\b(PASS|FAIL)\s*$/.test(l.trim()));

// logs: {"<test>": "<log text>"}.
// halves is a seam for the node tests; the receipt itself always judges OPEN_HALVES.
export function buildReceipt(logs, head, { halves = OPEN_HALVES } = {}) {
  const problems = [];
  let plantCaught = true;
  const plantNotes = [];
  const lines = [];
  for (const [test, plants] of Object.entries(TESTS)) {
    const text = logs[test] ?? "";
    if (!new RegExp(`^${test}: PASS \\(`, "m").test(text)) {
      const failed = text.split("\n").filter((l) => l.endsWith("-> FAIL"));
      problems.push(failed.length ? `${test}: ${failed.length} check(s) failed: ${failed[0].slice(0, 100)}` : `${test} did not finish`);
    }
    const planted = plantLines(text);
    const caught = planted.filter((l) => /\bFAIL\s*$/.test(l.trim())).length;
    if (planted.length < plants || caught !== planted.length) {
      plantCaught = false;
      plantNotes.push(`${test} ${caught} of ${planted.length} plants caught, pinned ${plants}`);
    }
    lines.push(...mapLines(text).filter((l) => MAPS.includes(l.map)));
  }
  const unmapped = lines.filter((l) => pointOf(l.measure) === 0);
  for (const l of unmapped) problems.push(`unmapped measure ${l.map} ${l.measure}`);
  const counts = {};
  const uncovered = [];
  for (const p of Object.keys(POINTS)) {
    counts[p] = MAPS.map((m) => lines.filter((l) => l.map === m && pointOf(l.measure) === Number(p)).length);
    MAPS.forEach((m, i) => { if (counts[p][i] === 0) uncovered.push(`point ${p} on ${m}`); });
  }
  const held = lines.filter((l) => l.status !== "PASS" && waiting(l));
  const misses = lines.filter((l) => l.status !== "PASS" && !waiting(l));
  const countedOk = lines.length === PINNED_LINES;
  const open = halves.filter((h) => !h.parked);
  const pass = problems.length === 0 && countedOk && uncovered.length === 0 && misses.length === 0 && open.length === 0 && plantCaught && lines.length > 0;

  const perPoint = Object.keys(POINTS).map((p) => `${p}:${counts[p].join("/")}`).join(" ");
  let measured = lines.length === 0
    ? "no MAPCHECK lines: the tests did not run"
    : `${lines.length} MAPCHECK lines (pinned ${PINNED_LINES}); lines per point dam/flume ${perPoint}`;
  if (!countedOk && lines.length) measured += "; the line count is off the pin: a check was lost or added";
  if (uncovered.length) measured += `; no check for ${uncovered.join(", ")}`;
  if (misses.length) measured += `; misses: ${misses.map((l) => `${l.map} ${l.measure} ${l.value} ${l.line} ${l.status}`).join(", ")}`;
  if (open.length) measured += `; open halves, no ruling parks them: ${open.map((h) => `${h.half} (closes with ${h.closes})`).join("; ")}`;
  if (held.length) measured += `; waiting: ${held.map((l) => `${l.map} ${l.measure} ${l.value} ${l.line} (${waiting(l).cite.split(" ")[0]})`).join(", ")}`;
  if (problems.length) measured += `; ${problems.join("; ")}`;
  if (!plantCaught) measured += `; plants not shown caught: ${plantNotes.join(", ")}`;
  return { head, pass, measured, plant_caught: plantCaught };
}

// Runs every test through the project's runner and returns {"<test>": "<log text>"}.
export function runTests(cwd) {
  const logs = mkdtempSync(path.join(os.tmpdir(), "map-standard-"));
  const args = [path.join(cwd, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop"];
  for (const test of Object.keys(TESTS)) args.push("--test", test);
  const run = spawnSync(process.execPath, args, { cwd, env: { ...process.env, SMOKE_LOG_DIR: logs }, encoding: "utf8", maxBuffer: 1 << 26 });
  const out = {};
  for (const test of Object.keys(TESTS)) {
    const file = path.join(logs, `${test}.log`);
    out[test] = existsSync(file) ? readFileSync(file, "utf8") : `runner exit ${run.status}, no ${test}.log`;
  }
  return out;
}

// The receipt for the checkout at cwd. run is injectable so the refusal can be tested without Godot.
export function produce({ cwd = root, run = runTests } = {}) {
  const head = cleanHead(cwd);
  return buildReceipt(run(cwd), head);
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  if (args.logs) {
    // A test hook: logs from anywhere judge no commit, so it never writes a passing receipt.
    const logs = {};
    for (const test of Object.keys(TESTS)) {
      const file = path.join(args.logs, `${test}.log`);
      logs[test] = existsSync(file) ? readFileSync(file, "utf8") : "";
    }
    const r = buildReceipt(logs, "0000000");
    process.stdout.write(JSON.stringify({ ...r, pass: false, measured: `logs only, not a receipt: ${r.measured}` }, null, 2) + "\n");
    return 1;
  }
  let receipt;
  try { receipt = produce(); } catch (e) { console.error(String(e.message ?? e)); return 2; }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
