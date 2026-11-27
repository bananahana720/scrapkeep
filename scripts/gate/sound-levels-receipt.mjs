#!/usr/bin/env node
import { cleanHead } from "./sound-recipes-receipt.mjs";
import { realpathSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Worker, isMainThread, parentPort, workerData } from "node:worker_threads";

import {
  LUFS_TOL,
  MAX_TRUE_PEAK,
  MIN_LOUDNESS_SECONDS,
  MUSIC_DIR,
  TARGET_LUFS,
  gain,
  gameTracks,
  hasFfmpeg,
  hashFindings,
  judge,
  measureGame,
  measureGameAsync,
  meter,
  readManifests,
  resolveJobs,
} from "../audio-gate.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const LEVEL_KINDS = ["loudness", "peak", "seam", "stale"];
export const PLANT_RATE = 48000;
export const PLANT_SECONDS = 20;
export const PLANT_HZ = 240;
export const SHORT_SECONDS = 2;
export const LIMITS = `${TARGET_LUFS} LUFS within ${LUFS_TOL} LU, true peak at or under ${MAX_TRUE_PEAK} dBTP, loop wrap within the loop's own 99.9th-percentile step`;

export function tone(seconds = PLANT_SECONDS, rate = PLANT_RATE, hz = PLANT_HZ, amp = 0.1) {
  const frames = Math.round(seconds * rate);
  const out = new Float32Array(frames * 2);
  for (let f = 0; f < frames; f++)
    out[f * 2] = out[f * 2 + 1] = amp * Math.cos((2 * Math.PI * hz * f) / rate);
  return out;
}

const PLANT_WORKER_FLAG = "soundLevelsPlantWorker";
const SELF_URL = new URL(import.meta.url);

function summarizePlants({ control, loud, hot, seam, short }) {
  const kinds = (r) => r.found.map((f) => f.kind);
  const checks = {
    control: control.found.length === 0,
    loudness: kinds(loud).includes("loudness"),
    peak: kinds(hot).includes("peak"),
    seam: kinds(seam).includes("seam"),
    short_peak: kinds(short).includes("peak"),
  };
  const caught = Object.values(checks).every(Boolean);
  const missed = Object.entries(checks)
    .filter(([, ok]) => !ok)
    .map(([k]) => k);
  const what = caught
    ? `plants caught: a stem 6 LU loud read ${loud.row.lufs} LUFS, 15 dB hot read ${hot.row.truePeak} dBTP, a loop a quarter cycle short read wrap ${seam.row.seamWrap} over ${seam.row.seamP999}, a ${SHORT_SECONDS} s clip at full scale read ${short.row.truePeak} dBTP; the clean tone passed`
    : `plants not caught: ${missed.join(", ")}`;
  return { caught, what };
}

export function runPlants({ judgeFn = judge, meterFn = meter } = {}) {
  const raw = tone();
  const { lufs } = meterFn(raw, PLANT_RATE);
  if (lufs === null || !Number.isFinite(lufs))
    return { caught: false, what: "the plant tone could not be metered" };
  const level = gain(raw, TARGET_LUFS - lufs);
  const frames = level.length / 2;
  const control = judgeFn("plant-control", level, PLANT_RATE, {
    loop: true,
    exit: frames,
    loopAt: 0,
  });
  const loud = judgeFn("plant-6LU-loud", gain(level, 6), PLANT_RATE);
  const hot = judgeFn("plant-15dB-hot", gain(level, 15), PLANT_RATE);
  const seam = judgeFn("plant-seam", level, PLANT_RATE, {
    loop: true,
    exit: frames - PLANT_RATE / PLANT_HZ / 4,
    loopAt: 0,
  });
  const short = judgeFn(
    "plant-short-0dBTP",
    tone(SHORT_SECONDS, PLANT_RATE, PLANT_HZ, 1),
    PLANT_RATE,
  );
  return summarizePlants({ control, loud, hot, seam, short });
}

function send(port, msg) {
  // oxlint-disable-next-line unicorn/require-post-message-target-origin -- Node worker_threads MessagePort, not window.postMessage
  port.postMessage(msg);
}

let workerRawTone = null;
function runPlantTask(task) {
  if (task.kind === "meter") {
    workerRawTone ??= tone();
    return meter(workerRawTone, PLANT_RATE);
  }
  if (task.kind === "short") {
    return judge("plant-short-0dBTP", tone(SHORT_SECONDS, PLANT_RATE, PLANT_HZ, 1), PLANT_RATE);
  }
  workerRawTone ??= tone();
  const level = gain(workerRawTone, TARGET_LUFS - task.lufs);
  const frames = level.length / 2;
  if (task.kind === "control")
    return judge("plant-control", level, PLANT_RATE, { loop: true, exit: frames, loopAt: 0 });
  if (task.kind === "loud") return judge("plant-6LU-loud", gain(level, 6), PLANT_RATE);
  if (task.kind === "hot") return judge("plant-15dB-hot", gain(level, 15), PLANT_RATE);
  if (task.kind === "seam")
    return judge("plant-seam", level, PLANT_RATE, {
      loop: true,
      exit: frames - PLANT_RATE / PLANT_HZ / 4,
      loopAt: 0,
    });
  throw new Error(`unknown plant task kind: ${task.kind}`);
}

export async function runPlantsAsync({ jobs } = {}) {
  const workers = resolveJobs(jobs);
  if (workers <= 1) return runPlants();
  const poolSize = Math.min(workers, 4);
  const pool = [];
  const idle = [];
  const pending = [];
  let fatalError = null;

  const failAll = (err) => {
    const error = err instanceof Error ? err : new Error(String(err));
    if (!fatalError) fatalError = error;
    for (const w of pool) {
      const cur = w._current;
      w._current = null;
      if (cur) cur.reject(error);
    }
    while (pending.length) pending.shift().reject(error);
  };

  const runOnPool = (task) =>
    new Promise((resolve, reject) => {
      if (fatalError) {
        reject(fatalError);
        return;
      }
      const assign = (worker) => {
        worker._current = { resolve, reject };
        send(worker, { task });
      };
      const free = idle.pop();
      if (free) assign(free);
      else pending.push({ assign, reject });
    });

  try {
    for (let i = 0; i < poolSize; i++) {
      const worker = new Worker(SELF_URL, {
        workerData: { [PLANT_WORKER_FLAG]: true },
        execArgv: [],
      });
      worker._current = null;
      worker.on("message", (msg) => {
        const cur = worker._current;
        worker._current = null;
        if (cur) {
          if (msg.ok) cur.resolve(msg.result);
          else cur.reject(new Error(msg.error));
        }
        const next = pending.shift();
        if (next) next.assign(worker);
        else idle.push(worker);
      });
      worker.on("error", failAll);
      worker.on("exit", (code) => {
        if (code !== 0) failAll(new Error(`sound-levels plant worker exited with code ${code}`));
      });
      pool.push(worker);
      idle.push(worker);
    }

    const [{ lufs }, short] = await Promise.all([
      runOnPool({ kind: "meter" }),
      runOnPool({ kind: "short" }),
    ]);
    if (lufs === null || !Number.isFinite(lufs))
      return { caught: false, what: "the plant tone could not be metered" };
    const [control, loud, hot, seam] = await Promise.all([
      runOnPool({ kind: "control", lufs }),
      runOnPool({ kind: "loud", lufs }),
      runOnPool({ kind: "hot", lufs }),
      runOnPool({ kind: "seam", lufs }),
    ]);
    return summarizePlants({ control, loud, hot, seam, short });
  } finally {
    await Promise.allSettled(pool.map((w) => w.terminate()));
  }
}

export function buildReceipt({
  head,
  clips,
  present,
  rows = [],
  found = [],
  plant,
  ffmpeg = true,
}) {
  const plantText = plant?.what ?? "plants not run";
  const caught = plant?.caught === true;
  if (!ffmpeg)
    return {
      head,
      pass: false,
      measured: `no data: ffmpeg not found, nothing measured; ${plantText}`,
      plant_caught: false,
    };
  if (clips === 0)
    return {
      head,
      pass: false,
      measured: `no data: no ${MUSIC_DIR} manifest names a clip; ${plantText}`,
      plant_caught: caught,
    };
  if (present === 0)
    return {
      head,
      pass: false,
      measured: `no data: 0 of ${clips} music clips have their stems on this machine (the Oggs are gitignored; scripts/music/mx stems-sync copies them); ${plantText}`,
      plant_caught: caught,
    };
  const bad = found.filter((f) => LEVEL_KINDS.includes(f.kind));
  const loud = rows.filter((r) => typeof r.lufs === "number");
  const peaked = rows.filter((r) => typeof r.truePeak === "number");
  const seams = rows.filter((r) => r.seamWrap !== undefined).length;
  const lufsSpan = loud.length
    ? ` (${Math.min(...loud.map((r) => r.lufs))} to ${Math.max(...loud.map((r) => r.lufs))} LUFS)`
    : "";
  const peakTop = peaked.length
    ? ` (at most ${Math.max(...peaked.map((r) => r.truePeak))} dBTP)`
    : "";
  const parts = [
    `${rows.length} of ${clips} music clips measured: true peak on ${peaked.length}${peakTop}, loudness on ${loud.length}${lufsSpan} (${rows.length - loud.length} under ${MIN_LOUDNESS_SECONDS} s, skipped by EBU R 128 programme loudness), seams on ${seams} loops`,
  ];
  if (bad.length)
    parts.push(
      `${bad.length} over the limits (${LIMITS}): ${bad
        .slice(0, 4)
        .map((f) => `${f.kind} ${f.where} ${f.what}`)
        .join("; ")}${bad.length > 4 ? "; ..." : ""}`,
    );
  if (present < clips)
    parts.push(`${clips - present} clip(s) not measured, their stems are not on this machine`);
  if (!bad.length && present === clips)
    parts.push(`every check that ran is inside the limits (${LIMITS})`);
  parts.push(plantText);
  return {
    head,
    pass: bad.length === 0 && present === clips && rows.length === clips && caught,
    measured: parts.join("; "),
    plant_caught: caught,
  };
}

export function measure(project, { plant: providedPlant } = {}) {
  const ffmpeg = hasFfmpeg();
  const manifests = readManifests(project);
  const tracks = gameTracks(manifests);
  const present = tracks.filter(
    (t) => t.files.length > 0 && t.files.every((f) => existsSync(f)),
  ).length;
  const plant = providedPlant !== undefined ? providedPlant : ffmpeg ? runPlants() : null;
  if (!ffmpeg || present === 0)
    return buildReceipt({ clips: tracks.length, present, plant, ffmpeg });
  const { rows, found } = measureGame(manifests);
  return buildReceipt({
    clips: tracks.length,
    present,
    rows,
    found: [...found, ...hashFindings(project, manifests)],
    plant,
    ffmpeg,
  });
}

export async function measureAsync(project, { jobs, plant: providedPlant } = {}) {
  const workers = resolveJobs(jobs);
  const ffmpeg = hasFfmpeg();
  const manifests = readManifests(project);
  const tracks = gameTracks(manifests);
  const present = tracks.filter(
    (t) => t.files.length > 0 && t.files.every((f) => existsSync(f)),
  ).length;
  const resolvePlant = () =>
    providedPlant !== undefined
      ? Promise.resolve(providedPlant)
      : ffmpeg
        ? runPlantsAsync({ jobs: workers })
        : Promise.resolve(null);
  if (!ffmpeg || present === 0) {
    const plant = await resolvePlant();
    return buildReceipt({ clips: tracks.length, present, plant, ffmpeg });
  }
  const [plant, { rows, found }] = await Promise.all([
    resolvePlant(),
    measureGameAsync(manifests, { jobs: workers }),
  ]);
  return buildReceipt({
    clips: tracks.length,
    present,
    rows,
    found: [...found, ...hashFindings(project, manifests)],
    plant,
    ffmpeg,
  });
}

export function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = (flag) =>
      arg === flag && i + 1 < argv.length
        ? argv[++i]
        : arg.startsWith(flag + "=")
          ? arg.slice(flag.length + 1)
          : null;
    let v;
    if ((v = value("--out")) !== null) {
      if (!v) throw new Error("--out requires a path");
      args.out = v;
    } else if ((v = value("--jobs")) !== null) args.jobs = resolveJobs(v);
    else throw new Error("unknown argument: " + arg);
  }
  return args;
}

async function main(argv) {
  let args;
  try {
    args = parseArgs(argv);
  } catch (e) {
    console.error(String(e.message ?? e));
    return 2;
  }
  args.project = path.join(root, "sketches/core-loop");
  let head;
  try {
    head = cleanHead(root);
  } catch (e) {
    console.error(String(e.message ?? e));
    return 2;
  }
  const receipt = {
    ...(await measureAsync(path.resolve(args.project), { jobs: args.jobs })),
    head,
  };
  const ordered = {
    head: receipt.head,
    pass: receipt.pass,
    measured: receipt.measured,
    plant_caught: receipt.plant_caught,
  };
  const text = JSON.stringify(ordered, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (!isMainThread && workerData?.[PLANT_WORKER_FLAG] === true && parentPort) {
  parentPort.on("message", (msg) => {
    try {
      const result = runPlantTask(msg.task);
      send(parentPort, { ok: true, result });
    } catch (err) {
      send(parentPort, { ok: false, error: err instanceof Error ? err.message : String(err) });
    }
  });
}

if (
  isMainThread &&
  process.argv[1] &&
  realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)
)
  process.exit(await main(process.argv.slice(2)));
