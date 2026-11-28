import { spawnSync } from "node:child_process";
import { copyFile, cp, mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { existsSync, readdirSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkPreset } from "./export-include-check.mjs";
import { STEM_HASHES, stemHashMismatches } from "./audio-gate.mjs";
import { isMain } from "./lib/cli.mjs";
import {
  GODOT_VERSION,
  resolveGodotBinary,
  scratchGodotEnv,
  withScratchGodotEnv,
} from "./godot-home.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const binary = resolveGodotBinary();
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
  {
    label: "win proof (park)",
    seed: PARK_SEED,
    pilot: PARK_PILOT,
    table: "park",
    dir: "park",
    tries: 3,
    timeoutS: 1800,
  },
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
    else if (arg.startsWith("--stems-from=")) stemsFrom = arg.slice("--stems-from=".length);
    else if (arg === "--stems-from" && i + 1 < argv.length) stemsFrom = argv[++i];
    else throw new Error("unknown argument: " + arg);
  }
  return { stemsFrom, winProof, bossSmokeOnly, selfPlay };
}

export function defaultStemsFrom(gitCommonDir) {
  return path.join(path.dirname(gitCommonDir), "sketches/core-loop/assets/music_ace");
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
      current[line.slice(0, line.indexOf("="))] = line.slice(line.indexOf("=") + 1);
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
  if (!shipped || !proof) return [`preset "${shipped ? proofPreset : preset}" missing`];
  const drift = [];
  const own = new Set(["name", "runnable", "exclude_filter"]);
  for (const part of ["fields", "options"]) {
    const keys = new Set([...Object.keys(shipped[part]), ...Object.keys(proof[part])]);
    for (const key of keys) {
      if (part === "fields" && own.has(key)) continue;
      if (shipped[part][key] !== proof[part][key])
        drift.push(`${part} ${key}: ${shipped[part][key]} shipped, ${proof[part][key]} proof`);
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
  if (want !== got) drift.push(`exclude_filter: proof "${got}", want "${want}"`);
  return drift;
}

// The win proof runs the exported pack on the editor binary, a debug-features build, which loads
// each GDExtension's linux debug library relative to its working directory. The pack carries no
export function proofLibraries(files) {
  return files.filter((rel) => /^addons\/[^/]+\/.*\.linux\.debug\.x86_64\.so$/.test(rel));
}

export function winProofFailures(output, status, rowsText) {
  const failures = [];
  if (status !== 0) failures.push("bot run exited " + status);
  if (errorLine.test(output)) failures.push("SCRIPT ERROR or ERROR line in the bot run output");
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
    failures.push(`outcome ${row.outcome} at stage ${row.stage_reached}, not won`);
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
  headless = false,
}) {
  if (headless) {
    return (
      [
        "commit: " + sha,
        "built: " + stamp + " in a cloud container (scripts/cloud/export-headless.mjs)",
        "godot: " + godot,
        "stems: none (ACE stems live on Andrew's machine)",
        "boss smoke: not run (needs a Vulkan GPU)",
        winProof ?? "win proof: not run",
      ].join("\n") + "\n"
    );
  }
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

export function bossSmokeCommand({ queue, binary, project, boss, crash = false }) {
  return {
    command: queue,
    args: [
      "--gpu",
      "1",
      "--need",
      "3000",
      "--name",
      "boss-smoke-" + boss,
      "--display",
      "--shared",
      "--timeout",
      String(BOSS_SMOKE_QUEUE_WAIT_S),
      "--",
      "timeout",
      "-k",
      "10",
      String(BOSS_SMOKE_TIMEOUT_S),
      "sh",
      "-c",
      'exec "$0" --gpu-index "$SCRAPKEEP_GPU_INDEX" "$@"',
      binary,
      "--rendering-driver",
      "vulkan",
      "--display-driver",
      "x11",
      "--audio-driver",
      "Dummy",
      "--path",
      project,
      "--resolution",
      "1280x720",
      "--script",
      crash ? BOSS_SMOKE_CRASH_SCRIPT : BOSS_SMOKE_SCRIPT,
      "--",
      "--boss=" + boss,
    ],
  };
}

export function bossSmokeCrash(env) {
  const value = env.SCRAPKEEP_BOSS_SMOKE_CRASH;
  if (!value) return null;
  if (!BOSS_SMOKE.includes(value))
    throw new Error(`SCRAPKEEP_BOSS_SMOKE_CRASH=${value} is not one of ${BOSS_SMOKE.join(", ")}`);
  return value;
}

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
  const pass = lines.findIndex(
    (line) => line.startsWith(`BOSS_SMOKE boss=${boss} `) && line.trim().endsWith(" PASS"),
  );
  if (pass < 0) failures.push(`${boss}: no BOSS_SMOKE PASS line`);
  for (const line of pass < 0 ? lines : lines.slice(0, pass))
    if (/^(SCRIPT ERROR|ERROR)\b/.test(line) || /VK_ERROR|vulkan[^\n]*(error|fail)/i.test(line))
      failures.push(`${boss}: ${line.trim()}`);
  const device = output.match(deviceLine);
  if (!device) failures.push(`${boss}: no "Using Device" line`);
  else if (device[1] !== "Vulkan") failures.push(`${boss}: renderer ${device[1]}, not Vulkan`);
  return failures;
}

const runText = ({ status, signal, wall }) =>
  `${exitText(status, signal)}, ${(wall / 1000).toFixed(1)} s wall`;

export function bossSmokeLine(boss, output, run) {
  const lines = output.split("\n");
  const pass = lines.find((line) => line.startsWith(`BOSS_SMOKE boss=${boss} `)) ?? "";
  const ticks = pass.match(/ticks=(\d+)/)?.[1] ?? "?";
  const stage = pass.match(/stage=(\d+)/)?.[1] ?? "?";
  const device = output.match(deviceLine)?.[2] ?? "unknown device";
  const after = lines
    .slice(lines.indexOf(pass) + 1)
    .filter((line) => /^(SCRIPT ERROR|ERROR)\b/.test(line)).length;
  return (
    `boss smoke ${boss}: PASS, ${runText(run)}, stage ${stage} arena, ${ticks} ticks, Vulkan on ${device}` +
    (after > 0 ? `, ${after} teardown error lines` : "")
  );
}

export function bossSmokeFailLine(boss, failures, run) {
  const reasons = failures.map((failure) => failure.slice(`${boss}: `.length));
  return `boss smoke ${boss}: FAIL, ${runText(run)}: ${reasons.join("; ")}`;
}

export function runBossSmoke({
  runner,
  queue,
  binary,
  project,
  bosses = BOSS_SMOKE,
  crash = null,
  now = Date.now,
}) {
  const lines = [];
  const failures = [];
  for (const boss of bosses) {
    const { command, args } = bossSmokeCommand({
      queue,
      binary,
      project,
      boss,
      crash: boss === crash,
    });
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
      "6. World 1 sitting (stages 1-2): ./core-loop.x86_64 -- --profile=sitting (all pilots, save untouched) or --profile=sitting-earned (fresh profile). Add --final-world=last for full-alpha (all 6 stages).",
    ].join("\n") + "\n"
  );
}

export function nextStepLine() {
  return "next: npm run sketch:appimage packs and installs the launcher; then open Scrapkeep from the app menu (or run ~/.local/share/scrapkeep/Scrapkeep.AppImage) and check its window groups under the one icon.";
}

export function packageName(sha7, dirty = false, selfPlay = false) {
  return "scrapkeep-core-loop-" + sha7 + (dirty ? "-dirty" : "") + (selfPlay ? "-selfplay" : "");
}

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

export function winProofEnv(
  state,
  repoRoot = root,
  baseEnv = process.env,
  platform = process.platform,
) {
  return {
    ...isolatedXdgEnv(baseEnv, state, platform),
    ...(repoRoot ? { SCRAPKEEP_REPO_ROOT: repoRoot } : {}),
  };
}

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

export const EXPORT_TEMPLATE_REL = "godot/export_templates/4.7.2.stable/linux_release.x86_64";

export function resolveExportTemplate({
  env = process.env,
  home = os.homedir(),
  exists = existsSync,
} = {}) {
  const candidates = [];
  if (env.XDG_DATA_HOME) candidates.push(path.join(env.XDG_DATA_HOME, EXPORT_TEMPLATE_REL));
  const fallback = path.join(home, ".local/share", EXPORT_TEMPLATE_REL);
  if (!candidates.includes(fallback)) candidates.push(fallback);
  return candidates.find((candidate) => exists(candidate)) ?? null;
}

export function isolatedXdgEnv(baseEnv, stateDir, platform = process.platform) {
  return scratchGodotEnv(stateDir, { baseEnv, platform });
}

export function withIsolatedXdg(
  fn,
  { baseEnv = process.env, tmpRoot = os.tmpdir(), platform = process.platform } = {},
) {
  return withScratchGodotEnv(fn, {
    prefix: "scrapkeep-export-xdg-",
    tmpRoot,
    baseEnv,
    platform,
  });
}

function fail(message) {
  console.error("sketch:export FAIL: " + message);
  process.exit(1);
}

function failCloud(message) {
  console.error("cloud export: " + message);
  process.exit(1);
}

function runCloud(command, args, options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    ...options,
  });
}

async function copyProofLibraries(projectDir, destDir) {
  const addons = path.join(projectDir, "addons");
  const addonFiles = existsSync(addons)
    ? readdirSync(addons, { recursive: true }).map((rel) =>
        path.join("addons", String(rel)).split(path.sep).join("/"),
      )
    : [];
  for (const rel of proofLibraries(addonFiles)) {
    await mkdir(path.join(destDir, path.dirname(rel)), { recursive: true });
    await copyFile(path.join(projectDir, rel), path.join(destDir, rel));
  }
}

export async function runLinuxExport({
  winProof: runProof = false,
  selfPlay = false,
  stemsFrom: stemsFromArg = null,
  bossSmokeOnly = false,
  headless = false,
  binary: binaryArg,
  projectDir = project,
  repoRoot = root,
  outBase = headless ? "artifacts/local/cloud-export" : "artifacts/local/core-loop-export",
  stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, ""),
  env = process.env,
  platform = process.platform,
  runCmd = headless ? runCloud : run,
  exists = existsSync,
  log = console.log,
  failFn = headless ? failCloud : fail,
  copyAddons = copyProofLibraries,
  readFileFn = readFile,
  writeFileFn = writeFile,
  mkdirFn = mkdir,
} = {}) {
  const bin = binaryArg ?? (headless ? resolveGodotBinary({ env, requireExplicit: true }) : binary);
  if (!bin || !exists(bin)) {
    failFn(
      headless
        ? `set GODOT_BIN to the Godot ${GODOT_VERSION} editor (the cloud SessionStart hook does)`
        : "Godot binary missing: " + (bin ?? "(not found; set GODOT_BIN)"),
    );
  }
  const outputOf = (result) => (result.stdout ?? "") + (result.stderr ?? "");
  const checkHeadlessStep = (label, result, extra = []) => {
    const text = outputOf(result);
    const problems = [...extra];
    if (result.status !== 0) problems.push("exit " + result.status);
    if (errorLine.test(text)) problems.push("SCRIPT ERROR or ERROR line in the output");
    if (problems.length > 0) failFn(label + ": " + problems.join("; ") + "\n" + text.slice(-2000));
    log("PASS " + label);
    return text;
  };

  let crash = null;
  let templateDataHome = null;
  let tracks = [];
  const manifests = {};
  let stemsFrom = null;
  let presetText = "";
  const stemDir = path.join(projectDir, "assets/music_ace");

  if (!headless) {
    try {
      crash = bossSmokeCrash(env);
    } catch (error) {
      failFn(error.message);
    }
    if (crash) log(`boss smoke: crash control on for ${crash} (SCRAPKEEP_BOSS_SMOKE_CRASH)`);
    if (bossSmokeOnly) {
      bossSmoke(crash);
      return;
    }
    const template = resolveExportTemplate({ env, exists });
    if (!template)
      failFn(
        "export template missing: " + path.join(os.homedir(), ".local/share", EXPORT_TEMPLATE_REL),
      );
    templateDataHome = path.resolve(template, "../../../..");

    tracks = trackedManifests(stemDir);
    if (!tracks.includes("spillway"))
      failFn("ACE manifest missing: " + path.join(stemDir, manifestRel));
    for (const track of tracks)
      manifests[track] = JSON.parse(
        await readFileFn(path.join(stemDir, track, "manifest.json"), "utf8"),
      );
    const common = runCmd("git", [
      "-C",
      repoRoot,
      "rev-parse",
      "--path-format=absolute",
      "--git-common-dir",
    ]);
    if (common.status !== 0) failFn("git common dir not found\n" + common.stderr);
    const fallback = defaultStemsFrom(common.stdout.trim());
    stemsFrom = path.resolve(stemsFromArg ?? fallback);
    for (const track of tracks) {
      const missing = missingStems(manifests[track], path.join(stemsFrom, track), exists);
      if (missing.length > 0)
        failFn(missingStemsMessage(missing, path.join(stemsFrom, track), fallback));
      const manifestPath = path.join(stemDir, track, "manifest.json");
      const folderManifest = path.join(stemsFrom, track, "manifest.json");
      if (exists(folderManifest)) {
        const [tracked, found] = await Promise.all([
          readFileFn(manifestPath),
          readFileFn(folderManifest),
        ]);
        if (!tracked.equals(found))
          failFn(
            `stem folder manifest differs from the tracked manifest: ${folderManifest} vs ${manifestPath}`,
          );
      }
    }

    const named = tracks.flatMap((track) =>
      Object.values(manifests[track].clips ?? {}).flatMap((clip) =>
        Object.values(clip.files ?? {}).map((f) => `${track}/${f}`),
      ),
    );
    const rejected = stemHashMismatches(path.join(stemDir, STEM_HASHES), stemsFrom, named);
    if (rejected === null)
      failFn(
        `no ${STEM_HASHES} in ${stemDir}; the packed stems cannot be compared to what was cut (scripts/music/mx stem-hashes writes it)`,
      );
    if (rejected.length > 0)
      failFn(
        `${rejected.length} stem file(s) in ${stemsFrom} do not match ${STEM_HASHES}:\n` +
          rejected.map((r) => `  ${r.file}: ${r.why}`).join("\n"),
      );

    presetText = await readFileFn(path.join(projectDir, "export_presets.cfg"), "utf8");
    for (const name of [preset, proofPreset]) {
      const included = checkPreset({ sketch: projectDir, presetText, presetName: name });
      if (included.problems.length > 0)
        failFn(`export include check "${name}"\n` + included.problems.join("\n"));
    }
  }

  const outDir = path.join(repoRoot, outBase, stamp);
  const exe = path.join(outDir, "core-loop.x86_64");

  const runPipeline = async (xdgEnv) => {
    const imported = runCmd(
      bin,
      ["--headless", "--path", projectDir, "--editor", "--import"],
      xdgEnv ? { env: xdgEnv } : {},
    );
    if (headless) {
      checkHeadlessStep("editor import", imported);
    } else if (imported.status !== 0 || errorLine.test(outputOf(imported))) {
      failFn("editor import failed\n" + outputOf(imported).slice(-2000));
    }

    const gate = runCmd(
      bin,
      [
        "--headless",
        "--path",
        projectDir,
        "--script",
        "res://tests/release_gate_placeholder_test.gd",
      ],
      { env: { ...(xdgEnv ?? env), SCRAPKEEP_RELEASE_GATE: "1" } },
    );
    const gateFailures = releaseGateFailures(outputOf(gate), gate.status);
    if (gateFailures.length > 0) failFn("release gate\n" + gateFailures.join("\n"));
    if (headless) log("PASS release gate");

    let smokeRun = null;
    if (!headless) {
      const placeholders = runCmd(process.execPath, [
        path.join(repoRoot, "scripts/placeholder-gate.mjs"),
        "--project",
        projectDir,
        "--limit",
        "0",
      ]);
      const placeholderLine = outputOf(placeholders).trim().split("\n").pop() || "no output";
      log("placeholder report (not blocking): " + placeholderLine);
      smokeRun = bossSmoke(crash);
    }

    await mkdirFn(outDir, { recursive: true });
    const presetPath = path.join(projectDir, "export_presets.cfg");
    const restorePreset = () => writeFileSync(presetPath, presetText);
    let exported;
    try {
      if (!headless && selfPlay) {
        process.once("exit", restorePreset);
        for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, () => process.exit(128));
        await writeFileFn(presetPath, selfPlayPresetText(presetText));
      }
      exported = runCmd(
        bin,
        ["--headless", "--path", projectDir, "--export-release", preset, exe],
        xdgEnv ? { env: { ...xdgEnv, XDG_DATA_HOME: templateDataHome } } : {},
      );
    } finally {
      if (!headless && selfPlay) {
        restorePreset();
        process.removeListener("exit", restorePreset);
      }
    }
    if (headless) {
      checkHeadlessStep("export Linux x64", exported, exists(exe) ? [] : ["no executable"]);
    } else {
      const exportText = outputOf(exported);
      if (exported.status !== 0 || errorLine.test(exportText) || !exists(exe))
        failFn("export failed\n" + exportText.slice(-2000));
    }

    let stemsCopied = 0;
    if (!headless) {
      await cp(stemsFrom, path.join(outDir, "music_ace"), {
        recursive: true,
        filter: (source) => !source.endsWith(".import") && !source.endsWith(".gdignore"),
      });
      for (const track of tracks) {
        await mkdirFn(path.join(outDir, "music_ace", track), { recursive: true });
        await copyFile(
          path.join(stemDir, track, "manifest.json"),
          path.join(outDir, "music_ace", track, "manifest.json"),
        );
        stemsCopied += Object.keys(manifests[track].clips).length * manifests[track].stems.length;
      }
    }

    const bootArgs = headless
      ? ["--headless", "--quit-after", "300"]
      : ["--headless", "--quit-after", "300", "--music=ace", "--ace-check"];
    const bootOpts = xdgEnv ? { cwd: outDir, env: xdgEnv } : { cwd: outDir };
    const boot = runCmd(exe, bootArgs, bootOpts);
    const bootOutput = outputOf(boot);
    if (headless) {
      checkHeadlessStep("boot 300 frames", boot);
    } else {
      const failures = bootFailures(bootOutput);
      if (boot.status !== 0) failures.push("boot exit " + boot.status);
      if (failures.length > 0) failFn(failures.join("; ") + "\n" + bootOutput.slice(-2000));
    }

    const parkBoot = runCmd(exe, ["--headless", "--table=park", "--quit-after", "600"], bootOpts);
    if (headless) {
      checkHeadlessStep("park table boot 600 frames", parkBoot);
    } else {
      const parkText = outputOf(parkBoot);
      const parkErrors = parkText
        .split("\n")
        .filter((line) => /^(SCRIPT ERROR|ERROR)\b/.test(line));
      if (parkBoot.status !== 0 || parkErrors.length > 0)
        failFn(
          "park table boot exit " +
            parkBoot.status +
            "\n" +
            parkErrors.join("\n") +
            "\n" +
            parkText.slice(-1000),
        );
    }
    return { smoke: smokeRun, bootText: bootOutput, stemCount: stemsCopied };
  };

  const { smoke, bootText, stemCount } = headless
    ? await runPipeline(null)
    : await withIsolatedXdg(runPipeline, { baseEnv: env, platform });

  const proofOptions = {
    binary: bin,
    projectDir,
    repoRoot,
    runCmd,
    failFn,
    exists,
    copyAddons,
    readFileFn,
    mkdirFn,
    baseEnv: env,
    platform,
    checkDrift: !headless,
    checkExisting: !headless,
    includeRepoRoot: !headless,
    onPackPass: headless ? (res) => checkHeadlessStep("export Linux x64 proof pack", res) : null,
    onProofPass: headless ? (line) => log("PASS " + line) : null,
  };

  if (headless) {
    const proofLine = runProof ? await winProof(outDir, proofOptions) : null;
    const head = runCmd("git", ["-C", repoRoot, "rev-parse", "HEAD"]);
    const sha = outputOf(head).trim();
    await writeFileFn(
      path.join(outDir, "BUILD.txt"),
      buildStamp({
        sha,
        stamp,
        godot: "4.7.2.stable",
        winProof: proofLine,
        headless: true,
      }),
    );
    log("executable: " + exe);
    return { exe, outDir, sha, proofLine };
  }

  const head = runCmd("git", ["-C", repoRoot, "rev-parse", "HEAD"]);
  if (head.status !== 0) failFn("git HEAD not found\n" + head.stderr);
  const sha = head.stdout.trim();
  const sha7 = sha.slice(0, 7);
  const status = runCmd("git", ["-C", repoRoot, "status", "--porcelain", "--untracked-files=no"]);
  if (status.status !== 0) failFn("git status failed\n" + status.stderr);
  const dirty = status.stdout.trim() !== "";
  const version = sha7 + (dirty ? "-dirty" : "");
  const proofLine = runProof ? await winProof(outDir, proofOptions) : null;
  await writeFileFn(
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
      selfPlay,
    }),
  );
  await writeFileFn(path.join(outDir, "HOW-TO-RUN.txt"), howToRun({ sha7: version }));
  const tar = runCmd("tar", tarArgs(outDir, sha7, dirty, selfPlay));
  if (tar.status !== 0) failFn("tar failed\n" + tar.stderr);
  const tarball = path.join(path.dirname(outDir), packageName(sha7, dirty, selfPlay) + ".tar.gz");

  const size = (await stat(exe)).size;
  log("version: " + version + " " + stamp);
  log("package: " + tarball + " (" + ((await stat(tarball)).size / 1048576).toFixed(1) + " MiB)");
  log("executable: " + exe);
  log("pack size: " + size + " bytes (" + (size / 1048576).toFixed(1) + " MiB, pack embedded)");
  log("stems from: " + stemsFrom);
  log("sidecar stems: " + stemCount + " in " + path.join(outDir, "music_ace"));
  log("boot tail:\n" + bootText.trim().split("\n").slice(-6).join("\n"));
  if (proofLine) log(proofLine);
  if (selfPlay)
    log("self-play: pack carries tools/ (launch with -- --self-play); not the shipped pack");
  log(nextStepLine());
  return { exe, outDir, tarball, sha, proofLine };
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    fail(error.message);
  }
  await runLinuxExport(args);
}

async function winProof(
  outDir,
  {
    binary: bin = binary,
    projectDir = project,
    repoRoot = root,
    runCmd = run,
    failFn = fail,
    exists = existsSync,
    copyAddons = copyProofLibraries,
    readFileFn = readFile,
    mkdirFn = mkdir,
    baseEnv = process.env,
    platform = process.platform,
    checkDrift = true,
    checkExisting = true,
    includeRepoRoot = true,
    onPackPass = null,
    onProofPass = null,
  } = {},
) {
  if (checkDrift) {
    const drift = proofPresetDrift(
      parsePresets(await readFileFn(path.join(projectDir, "export_presets.cfg"), "utf8")),
    );
    if (drift.length > 0)
      failFn("proof preset drifted from the shipped preset\n" + drift.join("\n"));
  }
  const proofDir = outDir + "-win-proof";
  if (checkExisting && exists(proofDir)) failFn("win proof folder already exists: " + proofDir);
  await mkdirFn(proofDir, { recursive: true });
  const pack = path.join(proofDir, "proof.pck");
  const exported = runCmd(bin, [
    "--headless",
    "--path",
    projectDir,
    "--export-pack",
    proofPreset,
    pack,
  ]);
  if (onPackPass) {
    onPackPass(exported);
  } else {
    const exportText = (exported.stdout ?? "") + (exported.stderr ?? "");
    if (exported.status !== 0 || errorLine.test(exportText) || !exists(pack))
      failFn("proof pack export failed\n" + exportText.slice(-2000));
  }
  await copyAddons(projectDir, proofDir);

  const lines = [];
  for (const proof of WIN_PROOFS) {
    const base = path.join(proofDir, proof.dir);
    const result = await playProofTries(proof, (attempt) =>
      playWinProof((proof.tries ?? 1) > 1 ? path.join(base, "try-" + attempt) : base, pack, proof, {
        binary: bin,
        runCmd,
        repoRoot,
        baseEnv,
        platform,
        includeRepoRoot,
        readFileFn,
        exists,
        mkdirFn,
      }),
    );
    if (!result.ok) failFn(proof.label + "\n" + result.failure);
    if (onProofPass) onProofPass(result.line);
    lines.push(result.line);
  }
  return lines.join("\n");
}

async function playWinProof(
  base,
  pack,
  proof,
  {
    binary: bin = binary,
    runCmd = run,
    repoRoot = root,
    baseEnv = process.env,
    platform = process.platform,
    includeRepoRoot = true,
    readFileFn = readFile,
    exists = existsSync,
    mkdirFn = mkdir,
  } = {},
) {
  const state = path.join(base, "state");
  for (const dir of ["data", "config", "cache"])
    await mkdirFn(path.join(state, dir), { recursive: true });
  const out = path.join(base, "run");
  const bot = runCmd(
    bin,
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
      env: winProofEnv(state, includeRepoRoot ? repoRoot : null, baseEnv, platform),
    },
  );
  const botText = (bot.stdout ?? "") + (bot.stderr ?? "");
  const rowsPath = path.join(out, "bots.ndjson");
  const rowsText = exists(rowsPath) ? await readFileFn(rowsPath, "utf8") : "";
  const failures = winProofFailures(botText, bot.status, rowsText);
  if (failures.length > 0)
    return {
      ok: false,
      failure: failures.join("\n") + "\n" + botText.slice(-2000),
      summary: failures[0],
    };
  return { ok: true, line: winProofLine(JSON.parse(rowsText.trim()), pack, proof) };
}

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
  const note =
    tries > 1
      ? ` (try ${outcomes.length} of ${tries}${earlier.length ? "; " + earlier.join("; ") : ""})`
      : "";
  return { ok: true, line: last.line + note, outcomes };
}

if (isMain(import.meta.url)) await main();
