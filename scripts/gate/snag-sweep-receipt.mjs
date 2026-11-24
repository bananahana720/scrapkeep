#!/usr/bin/env node
// The receipt for the world 1 done read's row "snag-sweep" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// Grades the merged JSON reports produced by sketches/core-loop/tools/qa/snag_sweep.gd for
// park_dam and park_flume, plus the control log from sketches/core-loop/tests/snag_sweep_test.gd.
// Passes only when both maps are complete with matching map names, skipped share <= 0.20, 0 static
// snags (piece/ground/other in classes_places/places/snags; moving bodies are judged by their own
// phase tests), 0 tile seams, the control log caught its planted 0.3 m lip snag, AND a planted copy
// of the dam JSON with 1 snag injected fails the exact same map grader (plant_caught).
//
//   node scripts/gate/snag-sweep-receipt.mjs --dam <park_dam.json> --flume <park_flume.json> \
//     --control-log <snag_sweep_test.log> --head <sha> [--out <file>] [--mapcheck]
import { existsSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { withoutTeardownNoise } from "../sketch-smoke.mjs";

export const COMMIT = /^[0-9a-f]{7,40}$/;
export const MAX_SKIP = 0.2;
export const STATIC_CLASSES = ["piece", "ground", "other"];
export const CONTROL_CHECKS = [
  "planted lip: at least one snag",
  "the snag is at the lip, on the lip's collider, and is drawn",
  "same lanes, lip removed: no snag",
];

const isFiniteNum = (v) => typeof v === "number" && Number.isFinite(v);

export function gradeMapReport(data, expectedMap) {
  const problems = [];
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return {
      ok: false,
      map: expectedMap,
      snagCount: null,
      staticSnags: null,
      seamSnags: null,
      movingSnags: 0,
      skipShare: null,
      lanesRun: 0,
      lanesSkipped: 0,
      problems: [`${expectedMap}: report is not a JSON object`],
    };
  }
  if (data.map !== expectedMap) {
    problems.push(`${expectedMap}: report map is "${data.map ?? ""}", expected "${expectedMap}"`);
  }
  if (data.complete !== true) {
    problems.push(
      `${expectedMap}: complete is ${String(data.complete)} (killed or unfinished run)`,
    );
  }
  if (!isFiniteNum(data.pieces_total) || data.pieces_total <= 0) {
    problems.push(`${expectedMap}: missing or zero pieces_total (${String(data.pieces_total)})`);
  } else if (!isFiniteNum(data.pieces_in_shard) || data.pieces_in_shard !== data.pieces_total) {
    problems.push(
      `${expectedMap}: swept ${data.pieces_in_shard ?? 0} of ${data.pieces_total} pieces (unmerged or duplicate shard)`,
    );
  }
  const lanesRun = isFiniteNum(data.lanes_run) && data.lanes_run >= 0 ? data.lanes_run : null;
  const lanesSkipped =
    isFiniteNum(data.lanes_skipped) && data.lanes_skipped >= 0 ? data.lanes_skipped : null;
  let skipShare = null;
  if (lanesRun === null || lanesSkipped === null || lanesRun + lanesSkipped === 0) {
    problems.push(`${expectedMap}: missing or zero lane counts`);
  } else {
    skipShare = lanesSkipped / (lanesRun + lanesSkipped);
    if (skipShare > MAX_SKIP + 1e-9) {
      problems.push(
        `${expectedMap}: skipped share ${(skipShare * 100).toFixed(1)}% exceeds ${Math.round(MAX_SKIP * 100)}% (${lanesSkipped}/${lanesRun + lanesSkipped})`,
      );
    }
  }

  const classes = data.classes_places;
  const hasClasses =
    Boolean(classes) &&
    typeof classes === "object" &&
    STATIC_CLASSES.every((k) => isFiniteNum(classes[k]) && classes[k] >= 0);
  if (!hasClasses) {
    problems.push(`${expectedMap}: missing or invalid classes_places counts`);
  }
  if (!Array.isArray(data.places)) {
    problems.push(`${expectedMap}: missing places array`);
  }
  if (!Array.isArray(data.seams)) {
    problems.push(`${expectedMap}: missing seams array`);
  }

  const classStatic = hasClasses ? STATIC_CLASSES.reduce((sum, k) => sum + classes[k], 0) : 0;
  const placeStatic = Array.isArray(data.places)
    ? data.places.filter((p) => p?.class !== "moving").length
    : 0;
  const rawStatic = Array.isArray(data.snags)
    ? data.snags.filter((s) => s?.class !== "moving").length
    : 0;
  const staticSnags = Math.max(
    classStatic,
    placeStatic,
    rawStatic > 0 && Math.max(classStatic, placeStatic) === 0 ? rawStatic : 0,
  );
  const seamPlaces = Array.isArray(data.seams) ? data.seams.length : 0;
  const rawControls = Array.isArray(data.controls) ? data.controls.length : 0;
  const seamSnags = Math.max(seamPlaces, rawControls > 0 && seamPlaces === 0 ? rawControls : 0);
  const movingSnags =
    hasClasses && isFiniteNum(classes.moving)
      ? classes.moving
      : Array.isArray(data.places)
        ? data.places.filter((p) => p?.class === "moving").length
        : 0;
  const snagCount = staticSnags + seamSnags;
  if (staticSnags > 0) {
    problems.push(
      `${expectedMap}: ${staticSnags} static snag(s) (piece=${classes?.piece ?? "?"}, ground=${classes?.ground ?? "?"}, other=${classes?.other ?? "?"})`,
    );
  }
  if (seamSnags > 0) {
    problems.push(`${expectedMap}: ${seamSnags} open-ground seam snag(s)`);
  }
  return {
    ok: problems.length === 0 && snagCount === 0,
    map: expectedMap,
    snagCount,
    staticSnags,
    seamSnags,
    movingSnags,
    skipShare,
    lanesRun: lanesRun ?? 0,
    lanesSkipped: lanesSkipped ?? 0,
    problems,
  };
}

export function gradeControlLog(logText, { platform = process.platform } = {}) {
  const cleaned = withoutTeardownNoise(String(logText ?? ""), platform);
  const lines = cleaned.split("\n");
  const problems = [];
  const failedLines = lines.filter((l) => l.trimEnd().endsWith("-> FAIL"));
  const errorLines = lines.filter((l) => /^(?:\s*SCRIPT ERROR|ERROR)\b/.test(l));
  const verdict = /^snag_sweep_test: PASS \((\d+) checks(?:, (\d+) skipped)?\)/m.exec(cleaned);
  if (!verdict) problems.push("snag_sweep_test did not print PASS");
  else if (verdict[2] && Number(verdict[2]) > 0) {
    problems.push(`snag_sweep_test skipped ${verdict[2]} check(s)`);
  }
  if (failedLines.length > 0) {
    problems.push(`snag_sweep_test had ${failedLines.length} FAIL line(s)`);
  }
  if (errorLines.length > 0) {
    problems.push(`snag_sweep_test had ${errorLines.length} error line(s)`);
  }
  for (const check of CONTROL_CHECKS) {
    const passed = lines.some((l) => l.startsWith(`[${check}]`) && l.trimEnd().endsWith("-> PASS"));
    if (!passed) problems.push(`control log missing PASS for "${check}"`);
  }
  return { ok: problems.length === 0, problems };
}

// Clones a dam report and injects one static piece snag so the exact same map grader must reject it.
export function injectPlantedSnag(damData) {
  const base =
    damData && typeof damData === "object" && !Array.isArray(damData)
      ? structuredClone(damData)
      : {
          map: "park_dam",
          complete: true,
          pieces_total: 1,
          pieces_in_shard: 1,
          lanes_run: 10,
          lanes_skipped: 0,
          snags: [],
          controls: [],
          classes_raw: { piece: 0, ground: 0, other: 0, moving: 0 },
          places: [],
          classes_places: { piece: 0, ground: 0, other: 0, moving: 0 },
          seams: [],
        };
  const plantedPlace = {
    at: [0, 0, 0],
    hit: "/root/Game/Stage1/ParkRows/PlantedLip/Collider",
    class: "piece",
    count: 1,
    pieces: 1,
    worst_loss: 0.75,
    speed_before: 14.0,
    speed_after: 3.5,
    drawn: true,
  };
  const plantedRaw = {
    at: [0, 0, 0],
    hit: plantedPlace.hit,
    piece: plantedPlace.hit,
    class: "piece",
    lane: "ride",
    speed_before: 14.0,
    speed_after: 3.5,
    visible: true,
  };
  base.places = Array.isArray(base.places) ? [...base.places, plantedPlace] : [plantedPlace];
  base.snags = Array.isArray(base.snags) ? [...base.snags, plantedRaw] : [plantedRaw];
  const cp =
    base.classes_places && typeof base.classes_places === "object" ? base.classes_places : {};
  base.classes_places = {
    piece: (isFiniteNum(cp.piece) ? cp.piece : 0) + 1,
    ground: isFiniteNum(cp.ground) ? cp.ground : 0,
    other: isFiniteNum(cp.other) ? cp.other : 0,
    moving: isFiniteNum(cp.moving) ? cp.moving : 0,
  };
  const cr = base.classes_raw && typeof base.classes_raw === "object" ? base.classes_raw : {};
  base.classes_raw = {
    piece: (isFiniteNum(cr.piece) ? cr.piece : 0) + 1,
    ground: isFiniteNum(cr.ground) ? cr.ground : 0,
    other: isFiniteNum(cr.other) ? cr.other : 0,
    moving: isFiniteNum(cr.moving) ? cr.moving : 0,
  };
  return base;
}

export function formatMapcheckLines(damGrade, flumeGrade) {
  return [damGrade, flumeGrade].map(
    (g) => `MAPCHECK ${g.map} snags ${g.snagCount ?? "?"} pass<=0 ${g.ok ? "PASS" : "FAIL"}`,
  );
}

export function evaluate({ dam, flume, controlLog, head, platform = process.platform }) {
  const damGrade = gradeMapReport(dam, "park_dam");
  const flumeGrade = gradeMapReport(flume, "park_flume");
  const controlGrade = gradeControlLog(controlLog, { platform });
  const plantedDamGrade = gradeMapReport(injectPlantedSnag(dam), "park_dam");
  const plantedDamCaught = !plantedDamGrade.ok && (plantedDamGrade.snagCount ?? 0) >= 1;
  const plantCaught = controlGrade.ok && plantedDamCaught;
  const pass = damGrade.ok && flumeGrade.ok && plantCaught;
  const mapcheckLines = formatMapcheckLines(damGrade, flumeGrade);

  const problems = [...damGrade.problems, ...flumeGrade.problems, ...controlGrade.problems];
  const plantNote = plantCaught
    ? "plant: snag_sweep_test caught 0.3 m lip and grader caught injected dam snag"
    : !controlGrade.ok
      ? `plant: control log failed (${controlGrade.problems[0]})`
      : "plant: injected dam snag was not caught by map grader";
  const measured =
    problems.length === 0 && plantCaught
      ? `park_dam 0 snags (${damGrade.lanesRun} lanes, ${(damGrade.skipShare * 100).toFixed(1)}% skipped), park_flume 0 snags (${flumeGrade.lanesRun} lanes, ${(flumeGrade.skipShare * 100).toFixed(1)}% skipped); ${plantNote}`
      : `${problems.join("; ")}; ${plantNote}`;
  return {
    receipt: { head, pass, measured, plant_caught: plantCaught },
    damGrade,
    flumeGrade,
    controlGrade,
    mapcheckLines,
  };
}

export function buildReceipt(inputs) {
  return evaluate(inputs).receipt;
}

export function produce({ damPath, flumePath, controlLogPath, head, platform = process.platform }) {
  if (!damPath || !flumePath || !controlLogPath || !head) {
    throw new Error(
      "usage: snag-sweep-receipt.mjs --dam <park_dam.json> --flume <park_flume.json> --control-log <snag_sweep_test.log> --head <sha> [--out <file>] [--mapcheck]",
    );
  }
  if (!COMMIT.test(head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${head}"`);
  }
  for (const [label, file] of [
    ["--dam", damPath],
    ["--flume", flumePath],
    ["--control-log", controlLogPath],
  ]) {
    if (!existsSync(file)) throw new Error(`${label} file not found: ${file}`);
  }
  let dam;
  let flume;
  try {
    dam = JSON.parse(readFileSync(damPath, "utf8"));
  } catch (e) {
    throw new Error(`cannot parse --dam JSON (${damPath}): ${e?.message ?? e}`);
  }
  try {
    flume = JSON.parse(readFileSync(flumePath, "utf8"));
  } catch (e) {
    throw new Error(`cannot parse --flume JSON (${flumePath}): ${e?.message ?? e}`);
  }
  const controlLog = readFileSync(controlLogPath, "utf8");
  return evaluate({ dam, flume, controlLog, head, platform });
}

export function parseArgs(argv) {
  const args = {
    damPath: null,
    flumePath: null,
    controlLogPath: null,
    head: null,
    out: null,
    mapcheck: false,
  };
  const take = (i, flag) => {
    const val = argv[i + 1];
    if (val === undefined || val === "" || val.startsWith("--")) {
      throw new Error(`${flag} requires a value`);
    }
    return val;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--dam") args.damPath = take(i++, a);
    else if (a.startsWith("--dam=")) args.damPath = a.slice("--dam=".length);
    else if (a === "--flume") args.flumePath = take(i++, a);
    else if (a.startsWith("--flume=")) args.flumePath = a.slice("--flume=".length);
    else if (a === "--control-log") args.controlLogPath = take(i++, a);
    else if (a.startsWith("--control-log=")) args.controlLogPath = a.slice("--control-log=".length);
    else if (a === "--head") args.head = take(i++, a);
    else if (a.startsWith("--head=")) args.head = a.slice("--head=".length);
    else if (a === "--out") args.out = take(i++, a);
    else if (a.startsWith("--out=")) args.out = a.slice("--out=".length);
    else if (a === "--mapcheck") args.mapcheck = true;
    else throw new Error(`unknown argument: ${a}`);
  }
  if (!args.damPath || !args.flumePath || !args.controlLogPath || !args.head) {
    throw new Error(
      "usage: snag-sweep-receipt.mjs --dam <park_dam.json> --flume <park_flume.json> --control-log <snag_sweep_test.log> --head <sha> [--out <file>] [--mapcheck]",
    );
  }
  if (!COMMIT.test(args.head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${args.head}"`);
  }
  return args;
}

function main(argv) {
  let args;
  let result;
  try {
    args = parseArgs(argv);
    result = produce(args);
  } catch (e) {
    console.error(String(e?.message ?? e));
    return 2;
  }
  const text = JSON.stringify(result.receipt, null, 2) + "\n";
  if (args.out) {
    mkdirSync(path.dirname(path.resolve(args.out)), { recursive: true });
    writeFileSync(args.out, text);
    process.stdout.write(result.mapcheckLines.join("\n") + "\n");
  } else if (args.mapcheck) {
    process.stdout.write(result.mapcheckLines.join("\n") + "\n");
  } else {
    process.stdout.write(text);
  }
  return result.receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
