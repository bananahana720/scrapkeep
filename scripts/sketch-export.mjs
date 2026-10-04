import { spawnSync } from "node:child_process";
import { cp, mkdir, readFile, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// npm run sketch:export: a Linux x86_64 release of sketches/core-loop under
// artifacts/local/core-loop-export/<run>/, the ACE stems beside it in music_ace/, booted
// headless for 300 frames. The stems are not in the pack (the packaging tool's .gdignore
// keeps Godot from importing them), so the sequencer finds them beside the executable.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
const binary = process.env.GODOT_BIN || recordedBinary;
const project = path.join(root, "sketches/core-loop");
const stemRoot = path.join(project, "assets/music_ace");
const manifestRel = "spillway/manifest.json";
const preset = "Linux x64";
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
  if (!existsSync(binary)) fail("Godot binary missing: " + binary);
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local/share");
  const template = path.join(dataHome, "godot/export_templates/4.7.2.stable/linux_release.x86_64");
  if (!existsSync(template)) fail("export template missing: " + template);

  const manifestPath = path.join(stemRoot, manifestRel);
  if (!existsSync(manifestPath)) fail("ACE manifest missing: " + manifestPath);
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  const missing = missingStems(manifest, path.dirname(manifestPath));
  if (missing.length > 0)
    fail(`${missing.length} stem file(s) named by the manifest are missing, first ${missing[0]}; run tools/ace/package_music.py`);

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

  await cp(stemRoot, path.join(outDir, "music_ace"), {
    recursive: true,
    filter: (source) => !source.endsWith(".import") && !source.endsWith(".gdignore"),
  });
  const stemCount = Object.keys(manifest.clips).length * manifest.stems.length;

  const boot = run(exe, ["--headless", "--quit-after", "300", "--music=ace", "--ace-check"], { cwd: outDir });
  const bootText = boot.stdout + boot.stderr;
  const failures = bootFailures(bootText);
  if (boot.status !== 0) failures.push("boot exit " + boot.status);
  if (failures.length > 0) fail(failures.join("; ") + "\n" + bootText.slice(-2000));

  const size = (await stat(exe)).size;
  console.log("executable: " + exe);
  console.log("pack size: " + size + " bytes (" + (size / 1048576).toFixed(1) + " MiB, pack embedded)");
  console.log("sidecar stems: " + stemCount + " in " + path.join(outDir, "music_ace"));
  console.log("boot tail:\n" + bootText.trim().split("\n").slice(-6).join("\n"));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
