import { spawnSync } from "node:child_process";
import {
  copyFile,
  cp,
  mkdir,
  readFile,
  stat,
  writeFile,
} from "node:fs/promises";
import { existsSync, readdirSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkPreset } from "./export-include-check.mjs";
import { STEM_HASHES, stemHashMismatches } from "./audio-gate.mjs";

// npm run sketch:export: a Linux x86_64 release of sketches/core-loop under
// artifacts/local/core-loop-export/<run>/, the ACE stems beside it in music_ace/, booted
// headless for 300 frames. The stems are not in the pack, so the sequencer finds them beside
// the executable. They are gitignored and cannot be regenerated, so they are copied from
// --stems-from=<music_ace folder> (default: the main checkout's sketches/core-loop/assets/music_ace).
// --self-play exports the same pack with tools/ kept in (package name ends -selfplay), so the
// launch flag --self-play can load res://tools/self_play.gd; the default pack leaves tools/ out.
// --win-proof then exports the "Linux x64 proof" pack (the shipped recipe plus tools/) into the
// sibling <run>-win-proof/ and plays three skipper bot runs on it, each from a fresh user://, with
// the editor binary: seed 1 as rolled (Rivet), seed 11 pinned to the remembered cannon, then seed 1
// pinned to Tally (wave 11, GP7).
// Either run not won fails the export. Release templates refuse --main-pack and
// --script, so this proves the exported pack, not the release template's runtime.
// The proof runs before packaging, so a failed proof leaves no tarball. BUILD.txt records the
// proof lines, or "win proof: not run" without the flag. A dirty tree adds -dirty to the package name.
// After the headless release gate, the boss smoke boots the project on Vulkan once per boss on a
// hidden display through tools/coordinator/gpu_queue.sh (card 1, shared), enters that world's last
// stage and arena as the bot does and runs 300 ticks (tools/look_harness.gd --boss=): a crash, a
// missing PASS line, a non-Vulkan device or an error line before the PASS fails the export, because
// the headless gate cannot see the Forward+ light crash class (wave 11, the Waking boss entry).
// Each boss waits at most BOSS_SMOKE_QUEUE_WAIT_S for the card, runs at most BOSS_SMOKE_TIMEOUT_S
// under timeout(1) and prints one PASS or FAIL line with its exit (124 names the timeout, 128+N the
// signal) and wall time. --boss-smoke-only runs just this step. SCRAPKEEP_BOSS_SMOKE_CRASH=<boss> is
// the positive control: that boss boots tools/boss_smoke_crash.gd, which enters the arena, prints its
// PASS line and then aborts, so the step must fail on the exit alone. Unset, nothing crashes.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
const binary = process.env.GODOT_BIN || recordedBinary;
const project = path.join(root, "sketches/core-loop");
const stemRoot = path.join(project, "assets/music_ace");
const manifestRel = "spillway/manifest.json";
const preset = "Linux x64";
const proofPreset = "Linux x64 proof";
const WIN_POLICY = "skipper";
const WIN_STAGE = 6;
const WIN_SEED = 1;
const CANNON_SEED = 11;
const CANNON_PILOT = "remembered_cannon";
// Tally on seed 1 is the first of seeds 1 to 4 she wins in bot_six_tally_test (wave 11, GP7).
const TALLY_SEED = 1;
const TALLY_PILOT = "tally";
const PARK_SEED = 2;
const PARK_PILOT = "pylon_engineer";
export const WIN_PROOFS = [
  { label: "win proof", seed: WIN_SEED, dir: "" },
  {
    label: "win proof (cannon)",
    seed: CANNON_SEED,
    pilot: CANNON_PILOT,
    dir: "cannon",
  },
  { label: "win proof (tally)", seed: TALLY_SEED, pilot: TALLY_PILOT, dir: "tally" },
  // The park table (--table=park) reads its ground from assets/park/*/*.bin, which the shipped
  // recipe once dropped (wave-14 release), so its proof is mandatory. PARK-WIN (2026-10-16):
  // pylon_engineer seed 1, skipper policy, from stage 1, won stage 6 twice out of two. The wave-15
  // export (2026-10-17) then won 1 of 3 on one pack, so it passes on its first win in 3 tries.
  // 2026-10-19 (Systems B w18): seed 2, not 1. The proof checks packaging, not balance, and the new
  // Highdraft plating pack draft_plate puts Sable's nemesis on seed 1 (it stalls at stage 5).
  // 2026-10-23 (C17 dry run): the w18 park run is about 92,000 ticks, twice a world run, and won
  // in 1060 s wall on a cloud box, past the 900 s every proof had; headless at --fixed-fps 90 runs
  // near real time, so a faster GPU does not shorten it.
  { label: "win proof (park)", seed: PARK_SEED, pilot: PARK_PILOT, table: "park", dir: "park", tries: 3, timeoutS: 1800 },
];
export const WIN_PROOF_TIMEOUT_S = 900;
export const winProofTimeoutMs = (proof) => (proof.timeoutS ?? WIN_PROOF_TIMEOUT_S) * 1000;
const errorLine = /^(SCRIPT ERROR|ERROR)\b/m;
export const BOSS_SMOKE = ["bowl", "waking", "mind"];
export const BOSS_SMOKE_QUEUE_WAIT_S = 600;
export const BOSS_SMOKE_TIMEOUT_S = 300;
export const BOSS_SMOKE_CRASH_SCRIPT = "res://tools/boss_smoke_crash.gd";
const BOSS_SMOKE_SCRIPT = "res://tools/look_harness.gd";
const gpuQueue = path.join(project, "tools/coordinator/gpu_queue.sh");

export function missingStems(manifest, directory, exists = existsSync) {
  const missing = [];
  for (const clip of Object.values(manifest.clips ?? {})) {
    for (const stem of manifest.stems ?? []) {
      const file = clip.files?.[stem];
      if (!file) missing.push(`(no ${stem} file named)`);
      else if (!exists(path.join(directory, file))) missing.push(file);
    }
  }
  return missing;
}

// Every ACE track with a committed manifest ships: zones, bosses, title and summary.
export function trackedManifests(directory, list = readdirSync, exists = existsSync) {
  return list(directory)
    .filter((track) => exists(path.join(directory, track, "manifest.json")))
    .sort();
}

export function parseArgs(argv) {
  let stemsFrom = null;
  let winProof = false;
  let bossSmokeOnly = false;
  let selfPlay = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--win-proof") winProof = true;
    else if (arg === "--boss-smoke-only") bossSmokeOnly = true;
    else if (arg === "--self-play") selfPlay = true;
    else if (arg.startsWith("--stems-from="))
      stemsFrom = arg.slice("--stems-from=".length);
    else if (arg === "--stems-from" && i + 1 < argv.length)
      stemsFrom = argv[++i];
    else throw new Error("unknown argument: " + arg);
  }
  return { stemsFrom, winProof, bossSmokeOnly, selfPlay };
}

export function defaultStemsFrom(gitCommonDir) {
  return path.join(
    path.dirname(gitCommonDir),
    "sketches/core-loop/assets/music_ace",
  );
}

export function missingStemsMessage(missing, directory, fallback) {
  return `${missing.length} stem file(s) named by the manifest are missing from ${directory}, first ${missing[0]}. The ACE stems are gitignored and cannot be regenerated; pass --stems-from=<music_ace folder that holds spillway/*.ogg> (default: ${fallback}).`;
}

export function bootFailures(output) {
  const failures = [];
  if (errorLine.test(output)) failures.push("SCRIPT ERROR or ERROR line in the boot output");
  const check = /^ACE_CHECK ready=(\w+) clips=(\d+) streams=(\d+)/m.exec(output);
  if (!check) failures.push("no ACE_CHECK line in the boot output");
  else if (check[1] !== "true") failures.push("the sequencer reported the stems not ready");
  return failures;
}

export function releaseGateFailures(output, status) {
  const lines = output.split("\n").map((line) => line.trim());
  const failed = lines.filter((line) => /-> FAIL$|: FAIL\b/.test(line));
  if (status !== 0 || failed.length > 0) {
    return failed.length > 0 ? failed : [`release gate exited ${status} with no FAIL line`];
  }
  return lines.some((line) => /^release_gate_placeholder_test: PASS\b/.test(line))
    ? []
    : ["no release_gate_placeholder_test PASS line in the gate output"];
}

const unquote = (value) => value.replace(/^"(.*)"$/, "$1");

export function parsePresets(text) {
  const sections = {};
  let current = null;
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    const header = /^\[(.+)\]$/.exec(line);
    if (header) current = sections[header[1]] = {};
    else if (current && line.indexOf("=") > 0)
      current[line.slice(0, line.indexOf("="))] = line.slice(
        line.indexOf("=") + 1,
      );
  }
  const presets = {};
  for (const [id, fields] of Object.entries(sections)) {
    if (id.endsWith(".options") || fields.name === undefined) continue;
    presets[unquote(fields.name)] = {
      fields,
      options: sections[id + ".options"] ?? {},
    };
  }
  return presets;
}

export function proofPresetDrift(presets) {
  const shipped = presets[preset];
  const proof = presets[proofPreset];
  if (!shipped || !proof)
    return [`preset "${shipped ? proofPreset : preset}" missing`];
  const drift = [];
  const own = new Set(["name", "runnable", "exclude_filter"]);
  for (const part of ["fields", "options"]) {
    const keys = new Set([
      ...Object.keys(shipped[part]),
      ...Object.keys(proof[part]),
    ]);
    for (const key of keys) {
      if (part === "fields" && own.has(key)) continue;
      if (shipped[part][key] !== proof[part][key])
        drift.push(
          `${part} ${key}: ${shipped[part][key]} shipped, ${proof[part][key]} proof`,
        );
    }
  }
  const list = (value) =>
    unquote(value ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  const want = list(shipped.fields.exclude_filter)
    .filter((item) => item !== "tools/*")
    .join(", ");
  const got = list(proof.fields.exclude_filter).join(", ");
  if (want !== got)
    drift.push(`exclude_filter: proof "${got}", want "${want}"`);
  return drift;
}

// The win proof runs the exported pack on the editor binary, a debug-features build, which loads
// each GDExtension's linux debug library relative to its working directory. The pack carries no
// libraries, so these copy beside it (wave-13 close: Terrain3D's library was missing and every
// proof printed three ERROR lines). files is the project's paths relative to the sketch.
export function proofLibraries(files) {
  return files.filter((rel) => /^addons\/[^/]+\/.*\.linux\.debug\.x86_64\.so$/.test(rel));
}

export function winProofFailures(output, status, rowsText) {
  const failures = [];
  if (status !== 0) failures.push("bot run exited " + status);
  if (errorLine.test(output))
    failures.push("SCRIPT ERROR or ERROR line in the bot run output");
  const rows = (rowsText ?? "").split("\n").filter((line) => line.trim());
  if (rows.length !== 1) {
    failures.push(`expected one bots.ndjson row, found ${rows.length}`);
    return failures;
  }
  let row;
  try {
    row = JSON.parse(rows[0]);
  } catch {
    failures.push("bots.ndjson row is not JSON");
    return failures;
  }
  if (row.outcome !== "won")
    failures.push(
      `outcome ${row.outcome} at stage ${row.stage_reached}, not won`,
    );
  else if (row.stage_reached !== WIN_STAGE)
    failures.push(`won at stage ${row.stage_reached}, not stage ${WIN_STAGE}`);
  return failures;
}

export function buildStamp({
  sha,
  dirty,
  stamp,
  godot,
  stems,
  stemsFrom,
  winProof,
  bossSmoke,
  selfPlay = false,
}) {
  return (
    [
      "commit: " + sha,
      "dirty: " + dirty,
      "built: " + stamp,
      "godot: " + godot,
      "stems: " + stems + " from " + stemsFrom,
      ...(selfPlay ? ["self-play pack (tools/ included)"] : []),
      ...(bossSmoke ? [bossSmoke] : []),
      winProof ?? "win proof: not run (pass --win-proof)",
    ].join("\n") + "\n"
  );
}

// One boss boot: the GPU queue on card 1 with its own hidden display (waiting at most
// BOSS_SMOKE_QUEUE_WAIT_S for the card), then timeout(1) around Godot on Vulkan with the card index
// the queue exports, and no sound (an export on the PC must not play through its speakers).
// crash swaps in the positive-control entry script.
export function bossSmokeCommand({ queue, binary, project, boss, crash = false }) {
  return {
    command: queue,
    args: [
      "--gpu", "1", "--need", "3000", "--name", "boss-smoke-" + boss, "--display", "--shared",
      "--timeout", String(BOSS_SMOKE_QUEUE_WAIT_S), "--",
      "timeout", "-k", "10", String(BOSS_SMOKE_TIMEOUT_S),
      "sh", "-c", 'exec "$0" --gpu-index "$SCRAPKEEP_GPU_INDEX" "$@"', binary,
      "--rendering-driver", "vulkan", "--display-driver", "x11", "--audio-driver", "Dummy", "--path", project,
      "--resolution", "1280x720", "--script", crash ? BOSS_SMOKE_CRASH_SCRIPT : BOSS_SMOKE_SCRIPT,
      "--", "--boss=" + boss,
    ],
  };
}

// The positive control is off unless SCRAPKEEP_BOSS_SMOKE_CRASH names one boss; a typo stops the
// export rather than silently testing nothing.
export function bossSmokeCrash(env) {
  const value = env.SCRAPKEEP_BOSS_SMOKE_CRASH;
  if (!value) return null;
  if (!BOSS_SMOKE.includes(value))
    throw new Error(`SCRAPKEEP_BOSS_SMOKE_CRASH=${value} is not one of ${BOSS_SMOKE.join(", ")}`);
  return value;
}

// 124 is timeout(1) giving up; above 128 a shell reports the signal that ended the child.
export function exitText(status, signal) {
  if (signal) return `signal ${signal}`;
  if (status === 124) return `exit 124 (timed out after ${BOSS_SMOKE_TIMEOUT_S} s)`;
  if (status > 128) {
    const name = Object.entries(os.constants.signals).find(([, n]) => n === status - 128)?.[0];
    if (name) return `exit ${status} (${name})`;
  }
  return `exit ${status}`;
}

const deviceLine = /^(\S+) [\d.]+ - [^-]+ - Using Device #\d+: (.+)$/m;

export function bossSmokeFailures(boss, output, status, signal = null) {
  const failures = [];
  if (signal) failures.push(`${boss}: killed by ${signal}`);
  else if (status !== 0) failures.push(`${boss}: ${exitText(status, null)}`);
  const lines = output.split("\n");
  const pass = lines.findIndex((line) => line.startsWith(`BOSS_SMOKE boss=${boss} `) && line.trim().endsWith(" PASS"));
  if (pass < 0) failures.push(`${boss}: no BOSS_SMOKE PASS line`);
  for (const line of pass < 0 ? lines : lines.slice(0, pass))
    if (/^(SCRIPT ERROR|ERROR)\b/.test(line) || /VK_ERROR|vulkan[^\n]*(error|fail)/i.test(line))
      failures.push(`${boss}: ${line.trim()}`);
  const device = output.match(deviceLine);
  if (!device) failures.push(`${boss}: no "Using Device" line`);
  else if (device[1] !== "Vulkan") failures.push(`${boss}: renderer ${device[1]}, not Vulkan`);
  return failures;
}

// Error lines after the PASS line come from teardown; they are kept in the line, not failed.
const runText = ({ status, signal, wall }) => `${exitText(status, signal)}, ${(wall / 1000).toFixed(1)} s wall`;

export function bossSmokeLine(boss, output, run) {
  const lines = output.split("\n");
  const pass = lines.find((line) => line.startsWith(`BOSS_SMOKE boss=${boss} `)) ?? "";
  const ticks = pass.match(/ticks=(\d+)/)?.[1] ?? "?";
  const stage = pass.match(/stage=(\d+)/)?.[1] ?? "?";
  const device = output.match(deviceLine)?.[2] ?? "unknown device";
  const after = lines.slice(lines.indexOf(pass) + 1).filter((line) => /^(SCRIPT ERROR|ERROR)\b/.test(line)).length;
  return `boss smoke ${boss}: PASS, ${runText(run)}, stage ${stage} arena, ${ticks} ticks, Vulkan on ${device}` + (after > 0 ? `, ${after} teardown error lines` : "");
}

export function bossSmokeFailLine(boss, failures, run) {
  const reasons = failures.map((failure) => failure.slice(`${boss}: `.length));
  return `boss smoke ${boss}: FAIL, ${runText(run)}: ${reasons.join("; ")}`;
}

// Every boss runs and prints its line, so one crash does not hide the others' state.
export function runBossSmoke({ runner, queue, binary, project, bosses = BOSS_SMOKE, crash = null, now = Date.now }) {
  const lines = [];
  const failures = [];
  for (const boss of bosses) {
    const { command, args } = bossSmokeCommand({ queue, binary, project, boss, crash: boss === crash });
    const started = now();
    const result = runner(command, args);
    const run = { status: result.status, signal: result.signal ?? null, wall: now() - started };
    const output = (result.stdout ?? "") + (result.stderr ?? "");
    const found = bossSmokeFailures(boss, output, result.status, run.signal);
    if (found.length > 0) {
      failures.push(...found);
      lines.push(bossSmokeFailLine(boss, found, run));
    } else lines.push(bossSmokeLine(boss, output, run));
  }
  return { lines, failures };
}

export function howToRun({ sha7 }) {
  return (
    [
      "Scrapkeep core-loop alpha (" + sha7 + ")",
      "",
      "1. Extract the archive anywhere.",
      "2. Keep the music_ace folder next to core-loop.x86_64. Without it the game plays its built-in synth music instead of the recorded stems.",
      "3. Run ./core-loop.x86_64 from any directory.",
      "4. Saves live in ~/.local/share/godot/app_userdata/core-loop/. For a fresh first launch, rename that folder first and rename it back afterwards to keep your progress.",
      "5. On the title, press H for how to play and the controls.",
      "6. To open all six pilots for a sitting, leaving your save alone: ./core-loop.x86_64 -- --profile=sitting",
    ].join("\n") + "\n"
  );
}

// Printed last, so the export is not the end of the road: the AppImage wraps this tarball.
export function nextStepLine() {
  return "next: npm run sketch:appimage packs and installs the launcher; then open Scrapkeep from the app menu (or run ~/.local/share/scrapkeep/Scrapkeep.AppImage) and check its window groups under the one icon.";
}

export function packageName(sha7, dirty = false, selfPlay = false) {
  return "scrapkeep-core-loop-" + sha7 + (dirty ? "-dirty" : "") + (selfPlay ? "-selfplay" : "");
}

// --self-play: the shipped preset with tools/ kept in, so the launch flag --self-play finds
// res://tools/self_play.gd (and the bot driver it preloads). Only the exclude_filter line of the
// shipped preset changes; the default pack keeps tools/* out. name picks another preset (the Mac
// export passes "macOS").
export function selfPlayPresetText(presetText, name = preset) {
  const lines = presetText.split("\n");
  const start = lines.findIndex((line) => line === `name="${name}"`);
  if (start < 0) throw new Error(`preset "${name}" missing`);
  for (let i = start + 1; i < lines.length && !lines[i].startsWith("["); i++) {
    if (!lines[i].startsWith("exclude_filter=")) continue;
    const kept = lines[i]
      .slice("exclude_filter=".length)
      .replace(/^"|"$/g, "")
      .split(",")
      .map((item) => item.trim())
      .filter((item) => item && item !== "tools/*");
    lines[i] = `exclude_filter="${kept.join(", ")}"`;
    return lines.join("\n");
  }
  throw new Error(`preset "${name}" has no exclude_filter`);
}

// The bot_run.gd arguments after "--" for one proof; the local and cloud exports both build from this,
// so a proof field such as table cannot reach one export and not the other.
export function winProofBotArgs(proof, out) {
  return [
    "--out=" + out,
    "--policy=" + WIN_POLICY,
    "--seeds=" + proof.seed,
    ...(proof.pilot ? ["--pilot=" + proof.pilot] : []),
    ...(proof.table ? ["--table=" + proof.table] : []),
  ];
}

export function winProofLine(row, pack, proof = WIN_PROOFS[0]) {
  const pilot = proof.pilot ? ` pilot ${proof.pilot}` : "";
  const table = proof.table ? ` table ${proof.table}` : "";
  return `${proof.label}: ${row.outcome} at stage ${row.stage_reached}, ${row.ticks} ticks, ${row.wall_seconds} s wall, policy ${WIN_POLICY} seed ${proof.seed}${pilot}${table}, pack ${pack}`;
}

export function tarArgs(outDir, sha7, dirty = false, selfPlay = false) {
  const parent = path.dirname(outDir);
  const stamp = path.basename(outDir);
  const name = packageName(sha7, dirty, selfPlay);
  return [
    "-czf",
    path.join(parent, name + ".tar.gz"),
    "-C",
    parent,
    "--transform=s,^" + stamp + "," + name + ",",
    stamp,
  ];
}

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 600_000,
    ...options,
  });
}

// Prints every boss line, then fails the export if any boss failed. The outer timeout only backs up
// the queue wait and timeout(1), so it should never be the one that fires.
function bossSmoke(crash) {
  const smoke = runBossSmoke({
    runner: (command, args) =>
      run(command, args, { timeout: (BOSS_SMOKE_QUEUE_WAIT_S + BOSS_SMOKE_TIMEOUT_S + 60) * 1000 }),
    queue: gpuQueue,
    binary,
    project,
    crash,
  });
  for (const line of smoke.lines) console.log(line);
  if (smoke.failures.length > 0) fail("boss smoke\n" + smoke.failures.join("\n"));
  return smoke;
}

function fail(message) {
  console.error("sketch:export FAIL: " + message);
  process.exit(1);
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    fail(error.message);
  }
  if (!existsSync(binary)) fail("Godot binary missing: " + binary);
  let crash = null;
  try {
    crash = bossSmokeCrash(process.env);
  } catch (error) {
    fail(error.message);
  }
  if (crash) console.log(`boss smoke: crash control on for ${crash} (SCRAPKEEP_BOSS_SMOKE_CRASH)`);
  if (args.bossSmokeOnly) {
    bossSmoke(crash);
    return;
  }
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share");
  const template = path.join(dataHome, "godot/export_templates/4.7.2.stable/linux_release.x86_64");
  if (!existsSync(template)) fail("export template missing: " + template);

  const tracks = trackedManifests(stemRoot);
  if (!tracks.includes("spillway")) fail("ACE manifest missing: " + path.join(stemRoot, manifestRel));
  const manifests = {};
  for (const track of tracks)
    manifests[track] = JSON.parse(await readFile(path.join(stemRoot, track, "manifest.json"), "utf8"));
  const common = run("git", [
    "-C",
    root,
    "rev-parse",
    "--path-format=absolute",
    "--git-common-dir",
  ]);
  if (common.status !== 0) fail("git common dir not found\n" + common.stderr);
  const fallback = defaultStemsFrom(common.stdout.trim());
  const stemsFrom = path.resolve(args.stemsFrom ?? fallback);
  for (const track of tracks) {
    const missing = missingStems(manifests[track], path.join(stemsFrom, track));
    if (missing.length > 0)
      fail(
        missingStemsMessage(missing, path.join(stemsFrom, track), fallback),
      );
    const manifestPath = path.join(stemRoot, track, "manifest.json");
    const folderManifest = path.join(stemsFrom, track, "manifest.json");
    if (existsSync(folderManifest)) {
      const [tracked, found] = await Promise.all([
        readFile(manifestPath),
        readFile(folderManifest),
      ]);
      if (!tracked.equals(found))
        fail(
          `stem folder manifest differs from the tracked manifest: ${folderManifest} vs ${manifestPath}`,
        );
    }
  }

  // The Oggs are gitignored, so a folder can hold a stale mix under the right file name. Every stem the
  // tracked manifests name must match STEMS.sha256, and each rejected file is named.
  const named = tracks.flatMap((track) =>
    Object.values(manifests[track].clips ?? {}).flatMap((clip) =>
      Object.values(clip.files ?? {}).map((f) => `${track}/${f}`),
    ),
  );
  const rejected = stemHashMismatches(path.join(stemRoot, STEM_HASHES), stemsFrom, named);
  if (rejected === null)
    fail(`no ${STEM_HASHES} in ${stemRoot}; the packed stems cannot be compared to what was cut (scripts/music/mx stem-hashes writes it)`);
  if (rejected.length > 0)
    fail(
      `${rejected.length} stem file(s) in ${stemsFrom} do not match ${STEM_HASHES}:\n` +
        rejected.map((r) => `  ${r.file}: ${r.why}`).join("\n"),
    );

  // Raw data files the game opens must reach the pack (RELEASE-PARK); see export-include-check.mjs.
  const presetText = await readFile(path.join(project, "export_presets.cfg"), "utf8");
  for (const name of [preset, proofPreset]) {
    const included = checkPreset({ sketch: project, presetText, presetName: name });
    if (included.problems.length > 0)
      fail(`export include check "${name}"\n` + included.problems.join("\n"));
  }

  const imported = run(binary, ["--headless", "--path", project, "--editor", "--import"]);
  if (imported.status !== 0 || errorLine.test(imported.stdout + imported.stderr))
    fail("editor import failed\n" + (imported.stdout + imported.stderr).slice(-2000));

  const gate = run(
    binary,
    ["--headless", "--path", project, "--script", "res://tests/release_gate_placeholder_test.gd"],
    { env: { ...process.env, SCRAPKEEP_RELEASE_GATE: "1" } },
  );
  const gateFailures = releaseGateFailures(gate.stdout + gate.stderr, gate.status);
  if (gateFailures.length > 0) fail("release gate\n" + gateFailures.join("\n"));

  // Report only until wave 20 (Andrew, 2026-10-16): print the placeholder count, never block on it.
  const placeholders = run(process.execPath, [path.join(root, "scripts/placeholder-gate.mjs"), "--project", project, "--limit", "0"]);
  const placeholderLine = ((placeholders.stdout ?? "") + (placeholders.stderr ?? "")).trim().split("\n").pop() || "no output";
  console.log("placeholder report (not blocking): " + placeholderLine);

  const smoke = bossSmoke(crash);

  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const outDir = path.join(root, "artifacts/local/core-loop-export", stamp);
  await mkdir(outDir, { recursive: true });
  const exe = path.join(outDir, "core-loop.x86_64");
  // --self-play swaps the shipped preset's exclude_filter for the export alone and restores the
  // file at once, so the checkout is clean for the dirty check below. The restore also runs on any
  // exit (fail() included) and on SIGINT/SIGTERM, so an interrupted export leaves the file as it was.
  const presetPath = path.join(project, "export_presets.cfg");
  const restorePreset = () => writeFileSync(presetPath, presetText);
  let exported;
  try {
    if (args.selfPlay) {
      process.once("exit", restorePreset);
      for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, () => process.exit(128));
      await writeFile(presetPath, selfPlayPresetText(presetText));
    }
    exported = run(binary, ["--headless", "--path", project, "--export-release", preset, exe]);
  } finally {
    if (args.selfPlay) {
      restorePreset();
      process.removeListener("exit", restorePreset);
    }
  }
  const exportText = exported.stdout + exported.stderr;
  if (exported.status !== 0 || errorLine.test(exportText) || !existsSync(exe))
    fail("export failed\n" + exportText.slice(-2000));

  await cp(stemsFrom, path.join(outDir, "music_ace"), {
    recursive: true,
    filter: (source) => !source.endsWith(".import") && !source.endsWith(".gdignore"),
  });
  let stemCount = 0;
  for (const track of tracks) {
    await mkdir(path.join(outDir, "music_ace", track), { recursive: true });
    await copyFile(path.join(stemRoot, track, "manifest.json"), path.join(outDir, "music_ace", track, "manifest.json"));
    stemCount += Object.keys(manifests[track].clips).length * manifests[track].stems.length;
  }

  const boot = run(exe, ["--headless", "--quit-after", "300", "--music=ace", "--ace-check"], { cwd: outDir });
  const bootText = boot.stdout + boot.stderr;
  const failures = bootFailures(bootText);
  if (boot.status !== 0) failures.push("boot exit " + boot.status);
  if (failures.length > 0) fail(failures.join("; ") + "\n" + bootText.slice(-2000));

  // The park table reads assets/park/*.bin from the pack; a dropped file prints a park_terrain
  // ERROR and the run still exits 0, so the boot output is scanned (RELEASE-PARK).
  const parkBoot = run(exe, ["--headless", "--table=park", "--quit-after", "600"], { cwd: outDir });
  const parkText = parkBoot.stdout + parkBoot.stderr;
  const parkErrors = parkText.split("\n").filter((line) => /^(SCRIPT ERROR|ERROR)\b/.test(line));
  if (parkBoot.status !== 0 || parkErrors.length > 0)
    fail("park table boot exit " + parkBoot.status + "\n" + parkErrors.join("\n") + "\n" + parkText.slice(-1000));

  const head = run("git", ["-C", root, "rev-parse", "HEAD"]);
  if (head.status !== 0) fail("git HEAD not found\n" + head.stderr);
  const sha = head.stdout.trim();
  const sha7 = sha.slice(0, 7);
  const status = run("git", [
    "-C",
    root,
    "status",
    "--porcelain",
    "--untracked-files=no",
  ]);
  if (status.status !== 0) fail("git status failed\n" + status.stderr);
  const dirty = status.stdout.trim() !== "";
  const version = sha7 + (dirty ? "-dirty" : "");
  const proofLine = args.winProof ? await winProof(outDir) : null;
  await writeFile(
    path.join(outDir, "BUILD.txt"),
    buildStamp({
      sha,
      dirty,
      stamp,
      godot: "4.7.2.stable",
      stems: stemCount,
      stemsFrom,
      winProof: proofLine,
      bossSmoke: smoke.lines.join("\n"),
      selfPlay: args.selfPlay,
    }),
  );
  await writeFile(
    path.join(outDir, "HOW-TO-RUN.txt"),
    howToRun({ sha7: version }),
  );
  const tar = run("tar", tarArgs(outDir, sha7, dirty, args.selfPlay));
  if (tar.status !== 0) fail("tar failed\n" + tar.stderr);
  const tarball = path.join(
    path.dirname(outDir),
    packageName(sha7, dirty, args.selfPlay) + ".tar.gz",
  );

  const size = (await stat(exe)).size;
  console.log("version: " + version + " " + stamp);
  console.log(
    "package: " +
      tarball +
      " (" +
      ((await stat(tarball)).size / 1048576).toFixed(1) +
      " MiB)",
  );
  console.log("executable: " + exe);
  console.log("pack size: " + size + " bytes (" + (size / 1048576).toFixed(1) + " MiB, pack embedded)");
  console.log("stems from: " + stemsFrom);
  console.log("sidecar stems: " + stemCount + " in " + path.join(outDir, "music_ace"));
  console.log("boot tail:\n" + bootText.trim().split("\n").slice(-6).join("\n"));
  if (proofLine) console.log(proofLine);
  if (args.selfPlay) console.log("self-play: pack carries tools/ (launch with -- --self-play); not the shipped pack");
  console.log(nextStepLine());
}

async function winProof(outDir) {
  const drift = proofPresetDrift(
    parsePresets(
      await readFile(path.join(project, "export_presets.cfg"), "utf8"),
    ),
  );
  if (drift.length > 0)
    fail("proof preset drifted from the shipped preset\n" + drift.join("\n"));
  const proofDir = outDir + "-win-proof";
  if (existsSync(proofDir))
    fail("win proof folder already exists: " + proofDir);
  await mkdir(proofDir, { recursive: true });
  const pack = path.join(proofDir, "proof.pck");
  const exported = run(binary, [
    "--headless",
    "--path",
    project,
    "--export-pack",
    proofPreset,
    pack,
  ]);
  const exportText = exported.stdout + exported.stderr;
  if (exported.status !== 0 || errorLine.test(exportText) || !existsSync(pack))
    fail("proof pack export failed\n" + exportText.slice(-2000));

  const lines = [];
  for (const proof of WIN_PROOFS) {
    const base = path.join(proofDir, proof.dir);
    const result = await playProofTries(proof, (attempt) =>
      playWinProof((proof.tries ?? 1) > 1 ? path.join(base, "try-" + attempt) : base, pack, proof),
    );
    if (!result.ok) fail(proof.label + "\n" + result.failure);
    lines.push(result.line);
  }
  return lines.join("\n");
}

async function playWinProof(base, pack, proof) {
  const state = path.join(base, "state");
  for (const dir of ["data", "config", "cache"])
    await mkdir(path.join(state, dir), { recursive: true });
  const addons = path.join(project, "addons");
  const addonFiles = existsSync(addons)
    ? readdirSync(addons, { recursive: true }).map((rel) => path.join("addons", String(rel)).split(path.sep).join("/"))
    : [];
  for (const rel of proofLibraries(addonFiles)) {
    await mkdir(path.join(path.dirname(pack), path.dirname(rel)), { recursive: true });
    await copyFile(path.join(project, rel), path.join(path.dirname(pack), rel));
  }
  const out = path.join(base, "run");
  const bot = run(
    binary,
    [
      "--headless",
      "--fixed-fps",
      "90",
      "--main-pack",
      pack,
      "--script",
      "res://tools/bot_run.gd",
      "--",
      ...winProofBotArgs(proof, out),
    ],
    {
      cwd: path.dirname(pack),
      timeout: winProofTimeoutMs(proof),
      env: {
        ...process.env,
        XDG_DATA_HOME: path.join(state, "data"),
        XDG_CONFIG_HOME: path.join(state, "config"),
        XDG_CACHE_HOME: path.join(state, "cache"),
      },
    },
  );
  const botText = bot.stdout + bot.stderr;
  const rowsPath = path.join(out, "bots.ndjson");
  const rowsText = existsSync(rowsPath) ? await readFile(rowsPath, "utf8") : "";
  const failures = winProofFailures(botText, bot.status, rowsText);
  if (failures.length > 0)
    return { ok: false, failure: failures.join("\n") + "\n" + botText.slice(-2000), summary: failures[0] };
  return { ok: true, line: winProofLine(JSON.parse(rowsText.trim()), pack, proof) };
}

// A proof with `tries` passes on its first won try (park, 2026-10-17: seed 1 Pylon wins the stage-6
// Mind about half the time, and the proof exists to show the export ships a winnable park table).
// Every try's outcome goes in the summary line.
export async function playProofTries(proof, playOnce) {
  const tries = proof.tries ?? 1;
  const outcomes = [];
  for (let attempt = 1; attempt <= tries; attempt++) {
    const outcome = await playOnce(attempt);
    outcomes.push(outcome);
    if (outcome.ok) break;
  }
  const last = outcomes[outcomes.length - 1];
  if (!last.ok) return { ok: false, failure: last.failure, outcomes };
  const earlier = outcomes.slice(0, -1).map((o, i) => `try ${i + 1}: ${o.summary}`);
  const note = tries > 1 ? ` (try ${outcomes.length} of ${tries}${earlier.length ? "; " + earlier.join("; ") : ""})` : "";
  return { ok: true, line: last.line + note, outcomes };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
