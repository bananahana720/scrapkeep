import { spawnSync } from "node:child_process";
import {
  copyFile,
  cp,
  mkdir,
  readFile,
  stat,
  writeFile,
} from "node:fs/promises";
import { existsSync, readdirSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// npm run sketch:export: a Linux x86_64 release of sketches/core-loop under
// artifacts/local/core-loop-export/<run>/, the ACE stems beside it in music_ace/, booted
// headless for 300 frames. The stems are not in the pack, so the sequencer finds them beside
// the executable. They are gitignored and cannot be regenerated, so they are copied from
// --stems-from=<music_ace folder> (default: the main checkout's sketches/core-loop/assets/music_ace).
// --win-proof then exports the "Linux x64 proof" pack (the shipped recipe plus tools/) into the
// sibling <run>-win-proof/ and plays two skipper bot runs on it, each from a fresh user://, with
// the editor binary: seed 1 as rolled (Rivet), then seed 11 pinned to the remembered cannon.
// Either run not won fails the export. Release templates refuse --main-pack and
// --script, so this proves the exported pack, not the release template's runtime.
// The proof runs before packaging, so a failed proof leaves no tarball. BUILD.txt records the
// proof lines, or "win proof: not run" without the flag. A dirty tree adds -dirty to the package name.

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
const WIN_SEED = 1;
const CANNON_SEED = 11;
const CANNON_PILOT = "remembered_cannon";
export const WIN_PROOFS = [
  { label: "win proof", seed: WIN_SEED, dir: "" },
  {
    label: "win proof (cannon)",
    seed: CANNON_SEED,
    pilot: CANNON_PILOT,
    dir: "cannon",
  },
];
const errorLine = /^(SCRIPT ERROR|ERROR)\b/m;

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
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--win-proof") winProof = true;
    else if (arg.startsWith("--stems-from="))
      stemsFrom = arg.slice("--stems-from=".length);
    else if (arg === "--stems-from" && i + 1 < argv.length)
      stemsFrom = argv[++i];
    else throw new Error("unknown argument: " + arg);
  }
  return { stemsFrom, winProof };
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
}) {
  return (
    [
      "commit: " + sha,
      "dirty: " + dirty,
      "built: " + stamp,
      "godot: " + godot,
      "stems: " + stems + " from " + stemsFrom,
      winProof ?? "win proof: not run (pass --win-proof)",
    ].join("\n") + "\n"
  );
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
    ].join("\n") + "\n"
  );
}

export function packageName(sha7, dirty = false) {
  return "scrapkeep-core-loop-" + sha7 + (dirty ? "-dirty" : "");
}

export function winProofLine(row, pack, proof = WIN_PROOFS[0]) {
  const pilot = proof.pilot ? ` pilot ${proof.pilot}` : "";
  return `${proof.label}: ${row.outcome} at stage ${row.stage_reached}, ${row.ticks} ticks, ${row.wall_seconds} s wall, policy ${WIN_POLICY} seed ${proof.seed}${pilot}, pack ${pack}`;
}

export function tarArgs(outDir, sha7, dirty = false) {
  const parent = path.dirname(outDir);
  const stamp = path.basename(outDir);
  const name = packageName(sha7, dirty);
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

  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const outDir = path.join(root, "artifacts/local/core-loop-export", stamp);
  await mkdir(outDir, { recursive: true });
  const exe = path.join(outDir, "core-loop.x86_64");
  const exported = run(binary, ["--headless", "--path", project, "--export-release", preset, exe]);
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
    }),
  );
  await writeFile(
    path.join(outDir, "HOW-TO-RUN.txt"),
    howToRun({ sha7: version }),
  );
  const tar = run("tar", tarArgs(outDir, sha7, dirty));
  if (tar.status !== 0) fail("tar failed\n" + tar.stderr);
  const tarball = path.join(
    path.dirname(outDir),
    packageName(sha7, dirty) + ".tar.gz",
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
  for (const proof of WIN_PROOFS)
    lines.push(await playWinProof(path.join(proofDir, proof.dir), pack, proof));
  return lines.join("\n");
}

async function playWinProof(base, pack, proof) {
  const state = path.join(base, "state");
  for (const dir of ["data", "config", "cache"])
    await mkdir(path.join(state, dir), { recursive: true });
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
      "--out=" + out,
      "--policy=" + WIN_POLICY,
      "--seeds=" + proof.seed,
      ...(proof.pilot ? ["--pilot=" + proof.pilot] : []),
    ],
    {
      cwd: path.dirname(pack),
      timeout: 900_000,
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
    fail(proof.label + "\n" + failures.join("\n") + "\n" + botText.slice(-2000));
  return winProofLine(JSON.parse(rowsText.trim()), pack, proof);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
