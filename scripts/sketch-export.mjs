import { spawnSync } from "node:child_process";
import { copyFile, cp, mkdir, readFile, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// npm run sketch:export: a Linux x86_64 release of sketches/core-loop under
// artifacts/local/core-loop-export/<run>/, the ACE stems beside it in music_ace/, booted
// headless for 300 frames. The stems are not in the pack, so the sequencer finds them beside
// the executable. They are gitignored and cannot be regenerated, so they are copied from
// --stems-from=<music_ace folder> (default: the main checkout's sketches/core-loop/assets/music_ace).
// --win-proof then exports the "Linux x64 proof" pack (the shipped recipe plus tools/) into the
// sibling <run>-win-proof/ and plays one skipper bot run on it from a fresh user:// with the
// editor binary, which fails unless the run is won. Release templates refuse --main-pack and
// --script, so this proves the exported pack, not the release template's runtime.

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

  const manifestPath = path.join(stemRoot, manifestRel);
  if (!existsSync(manifestPath)) fail("ACE manifest missing: " + manifestPath);
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
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
  const missing = missingStems(manifest, path.join(stemsFrom, "spillway"));
  if (missing.length > 0)
    fail(
      missingStemsMessage(missing, path.join(stemsFrom, "spillway"), fallback),
    );
  const folderManifest = path.join(stemsFrom, manifestRel);
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
  await copyFile(manifestPath, path.join(outDir, "music_ace", manifestRel));
  const stemCount = Object.keys(manifest.clips).length * manifest.stems.length;

  const boot = run(exe, ["--headless", "--quit-after", "300", "--music=ace", "--ace-check"], { cwd: outDir });
  const bootText = boot.stdout + boot.stderr;
  const failures = bootFailures(bootText);
  if (boot.status !== 0) failures.push("boot exit " + boot.status);
  if (failures.length > 0) fail(failures.join("; ") + "\n" + bootText.slice(-2000));

  const size = (await stat(exe)).size;
  console.log("executable: " + exe);
  console.log("pack size: " + size + " bytes (" + (size / 1048576).toFixed(1) + " MiB, pack embedded)");
  console.log("stems from: " + stemsFrom);
  console.log("sidecar stems: " + stemCount + " in " + path.join(outDir, "music_ace"));
  console.log("boot tail:\n" + bootText.trim().split("\n").slice(-6).join("\n"));
  if (args.winProof) await winProof(outDir);
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
  const state = path.join(proofDir, "state");
  for (const dir of ["data", "config", "cache"])
    await mkdir(path.join(state, dir), { recursive: true });
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

  const out = path.join(proofDir, "run");
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
      "--seeds=" + WIN_SEED,
    ],
    {
      cwd: proofDir,
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
    fail("win proof\n" + failures.join("\n") + "\n" + botText.slice(-2000));
  const row = JSON.parse(rowsText.trim());
  console.log(
    `win proof: ${row.outcome} at stage ${row.stage_reached}, ${row.ticks} ticks, ${row.wall_seconds} s wall, policy ${WIN_POLICY} seed ${WIN_SEED}, pack ${pack}`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
