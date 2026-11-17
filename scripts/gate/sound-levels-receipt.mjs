#!/usr/bin/env node
// The receipt for the world 1 done read's row "sound-levels" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// It runs scripts/audio-gate.mjs's own loudness, true-peak and loop-seam checks (and its stale checks,
// so the audio measured is the audio the manifests describe) over every game music clip, as the engine
// mixes it: stems summed plus the manifest's level_db. The limits are audio-gate.mjs's: TARGET_LUFS
// within LUFS_TOL, true peak at or under MAX_TRUE_PEAK, a loop's wrap no bigger than its own 99.9th
// percentile sample step. True peak runs on every clip. Loudness runs on clips of MIN_LOUDNESS_SECONDS
// or more: the target is EBU R 128 integrated programme loudness (ITU-R BS.1770 gating), which a few
// seconds of stinger does not give a meaningful reading of. measured names how many clips each check covered.
//
// The plants run first, through the same judge, on a synthetic 20 s tone set to the target: the tone
// itself must pass, the tone 6 LU too loud must fail on loudness, the tone 15 dB up must fail on true
// peak, the tone looped a quarter cycle short must fail on its seam, and a 2 s clip (under the loudness
// length) at 0 dBTP must fail on true peak. plant_caught needs all five.
//
// The packed Oggs are gitignored. When a clip's stems are not on this machine the receipt does not
// pass, and when none are it says "no data" first (scripts/music/mx stems-sync copies them in).
//
//   node scripts/gate/sound-levels-receipt.mjs [--out <file>]
import { cleanHead } from "./sound-recipes-receipt.mjs";
import { realpathSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  LUFS_TOL, MAX_TRUE_PEAK, MIN_LOUDNESS_SECONDS, MUSIC_DIR, TARGET_LUFS,
  gain, gameTracks, hasFfmpeg, hashFindings, judge, measureGame, meter, readManifests,
} from "../audio-gate.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const LEVEL_KINDS = ["loudness", "peak", "seam", "stale"];
export const PLANT_RATE = 48000;
export const PLANT_SECONDS = 20;
// 240 Hz at 48 kHz is 200 samples a cycle, so 20 s holds whole cycles and the cosine loops cleanly.
export const PLANT_HZ = 240;
// The short plant: under MIN_LOUDNESS_SECONDS, so only true peak can catch it.
export const SHORT_SECONDS = 2;
export const LIMITS = `${TARGET_LUFS} LUFS within ${LUFS_TOL} LU, true peak at or under ${MAX_TRUE_PEAK} dBTP, loop wrap within the loop's own 99.9th-percentile step`;

export function tone(seconds = PLANT_SECONDS, rate = PLANT_RATE, hz = PLANT_HZ, amp = 0.1) {
  const frames = Math.round(seconds * rate);
  const out = new Float32Array(frames * 2);
  for (let f = 0; f < frames; f++) out[f * 2] = out[f * 2 + 1] = amp * Math.cos((2 * Math.PI * hz * f) / rate);
  return out;
}

// The four planted faults through audio-gate's judge. judgeFn and meterFn are injectable for tests.
export function runPlants({ judgeFn = judge, meterFn = meter } = {}) {
  const raw = tone();
  const { lufs } = meterFn(raw, PLANT_RATE);
  if (lufs === null || !Number.isFinite(lufs)) return { caught: false, what: "the plant tone could not be metered" };
  const level = gain(raw, TARGET_LUFS - lufs);
  const frames = level.length / 2;
  const kinds = (r) => r.found.map((f) => f.kind);
  const control = judgeFn("plant-control", level, PLANT_RATE, { loop: true, exit: frames, loopAt: 0 });
  const loud = judgeFn("plant-6LU-loud", gain(level, 6), PLANT_RATE);
  const hot = judgeFn("plant-15dB-hot", gain(level, 15), PLANT_RATE);
  const seam = judgeFn("plant-seam", level, PLANT_RATE, { loop: true, exit: frames - PLANT_RATE / PLANT_HZ / 4, loopAt: 0 });
  const short = judgeFn("plant-short-0dBTP", tone(SHORT_SECONDS, PLANT_RATE, PLANT_HZ, 1), PLANT_RATE);
  const checks = {
    control: control.found.length === 0,
    loudness: kinds(loud).includes("loudness"),
    peak: kinds(hot).includes("peak"),
    seam: kinds(seam).includes("seam"),
    short_peak: kinds(short).includes("peak"),
  };
  const caught = Object.values(checks).every(Boolean);
  const missed = Object.entries(checks).filter(([, ok]) => !ok).map(([k]) => k);
  const what = caught
    ? `plants caught: a stem 6 LU loud read ${loud.row.lufs} LUFS, 15 dB hot read ${hot.row.truePeak} dBTP, a loop a quarter cycle short read wrap ${seam.row.seamWrap} over ${seam.row.seamP999}, a ${SHORT_SECONDS} s clip at full scale read ${short.row.truePeak} dBTP; the clean tone passed`
    : `plants not caught: ${missed.join(", ")}`;
  return { caught, what };
}

// Pure: the receipt from the clips the manifests name, what audio-gate measured, and the plants.
export function buildReceipt({ head, clips, present, rows = [], found = [], plant, ffmpeg = true }) {
  const plantText = plant?.what ?? "plants not run";
  const caught = plant?.caught === true;
  if (!ffmpeg) return { head, pass: false, measured: `no data: ffmpeg not found, nothing measured; ${plantText}`, plant_caught: false };
  if (clips === 0) return { head, pass: false, measured: `no data: no ${MUSIC_DIR} manifest names a clip; ${plantText}`, plant_caught: caught };
  if (present === 0)
    return { head, pass: false, measured: `no data: 0 of ${clips} music clips have their stems on this machine (the Oggs are gitignored; scripts/music/mx stems-sync copies them); ${plantText}`, plant_caught: caught };
  const bad = found.filter((f) => LEVEL_KINDS.includes(f.kind));
  const loud = rows.filter((r) => typeof r.lufs === "number");
  const peaked = rows.filter((r) => typeof r.truePeak === "number");
  const seams = rows.filter((r) => r.seamWrap !== undefined).length;
  const lufsSpan = loud.length ? ` (${Math.min(...loud.map((r) => r.lufs))} to ${Math.max(...loud.map((r) => r.lufs))} LUFS)` : "";
  const peakTop = peaked.length ? ` (at most ${Math.max(...peaked.map((r) => r.truePeak))} dBTP)` : "";
  const parts = [`${rows.length} of ${clips} music clips measured: true peak on ${peaked.length}${peakTop}, loudness on ${loud.length}${lufsSpan} (${rows.length - loud.length} under ${MIN_LOUDNESS_SECONDS} s, skipped by EBU R 128 programme loudness), seams on ${seams} loops`];
  if (bad.length) parts.push(`${bad.length} over the limits (${LIMITS}): ${bad.slice(0, 4).map((f) => `${f.kind} ${f.where} ${f.what}`).join("; ")}${bad.length > 4 ? "; ..." : ""}`);
  if (present < clips) parts.push(`${clips - present} clip(s) not measured, their stems are not on this machine`);
  if (!bad.length && present === clips) parts.push(`every check that ran is inside the limits (${LIMITS})`);
  parts.push(plantText);
  return { head, pass: bad.length === 0 && present === clips && rows.length === clips && caught, measured: parts.join("; "), plant_caught: caught };
}

export function measure(project) {
  const ffmpeg = hasFfmpeg();
  const manifests = readManifests(project);
  const tracks = gameTracks(manifests);
  const present = tracks.filter((t) => t.files.length > 0 && t.files.every((f) => existsSync(f))).length;
  const plant = ffmpeg ? runPlants() : null;
  if (!ffmpeg || present === 0) return buildReceipt({ clips: tracks.length, present, plant, ffmpeg });
  const { rows, found } = measureGame(manifests);
  return buildReceipt({ clips: tracks.length, present, rows, found: [...found, ...hashFindings(project, manifests)], plant, ffmpeg });
}

function main(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) args[argv[i].replace(/^--/, "")] = argv[i + 1];
  // Always this checkout's own game folder: the head below is this checkout's, so no other folder may be measured.
  args.project = path.join(root, "sketches/core-loop");
  // The head comes from the checkout, and only a clean one: an edited manifest or hash list judges no commit.
  let head;
  try { head = cleanHead(root); } catch (e) { console.error(String(e.message ?? e)); return 2; }
  const receipt = { ...measure(path.resolve(args.project)), head };
  const ordered = { head: receipt.head, pass: receipt.pass, measured: receipt.measured, plant_caught: receipt.plant_caught };
  const text = JSON.stringify(ordered, null, 2) + "\n";
  if (args.out) writeFileSync(args.out, text);
  else process.stdout.write(text);
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
