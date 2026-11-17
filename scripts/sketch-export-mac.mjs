import { spawnSync } from "node:child_process";
import { cp, mkdir, readFile, symlink, writeFile } from "node:fs/promises";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkPreset } from "./export-include-check.mjs";
import { STEM_HASHES, stemHashMismatches } from "./audio-gate.mjs";
import {
  bootFailures,
  defaultStemsFrom,
  missingStems,
  parsePresets,
  selfPlayPresetText,
  trackedManifests,
} from "./sketch-export.mjs";

// npm run sketch:export-mac: a macOS release of sketches/core-loop on the Mac Studio, as
// artifacts/local/core-loop-export-mac/<run>/Scrapkeep.app with BUILD.txt in Contents/Resources, ad-hoc
// signed (no Apple identity, no notarization), then booted headless for 300 frames, which must report
// this commit. Every Godot launch runs with HOME
// in a scratch folder under the run (Godot on macOS ignores XDG_DATA_HOME; scripts/godot-home.mjs),
// and the export finds the installed templates through a link in that scratch HOME, so the player's
// ~/Library/Application Support/Godot is read for templates only and never written.
// --self-play keeps tools/ in the pack (the frame-time self-play needs res://tools/self_play.gd) by
// swapping the "macOS" exclude_filter for the export alone, as sketch-export.mjs does on Linux.
// The ACE stems are gitignored. When every stem the tracked manifests name is in --stems-from (default:
// the main checkout's assets/music_ace) and matches STEMS.sha256, they copy into
// Scrapkeep.app/Contents/MacOS/music_ace (the game looks beside its executable) and the boot checks
// ACE_CHECK; otherwise the app ships with its synth music and BUILD.txt says why.
// Not run here, unlike the Linux export: the release placeholder gate, the Vulkan boss smoke, the
// park-table boot and the win proof. BUILD.txt lists them.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const project = path.join(root, "sketches/core-loop");
const stemRoot = path.join(project, "assets/music_ace");
export const MAC_PRESET = "macOS";
const SHIPPED_PRESET = "Linux x64";
export const APP_NAME = "Scrapkeep.app";
const TEMPLATE_VERSION = "4.7.2.stable";
const errorLine = /^(SCRIPT ERROR|ERROR)\b/m;

export function parseArgs(argv) {
  let stemsFrom = null;
  let selfPlay = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--self-play") selfPlay = true;
    else if (arg.startsWith("--stems-from=")) stemsFrom = arg.slice("--stems-from=".length);
    else if (arg === "--stems-from" && i + 1 < argv.length) stemsFrom = argv[++i];
    else throw new Error("unknown argument: " + arg);
  }
  return { stemsFrom, selfPlay };
}

// The Mac preset must pack what the shipped Linux preset packs, and stay universal (the installed 4.7.2 templates hold no arm64-only binary), ad-hoc signed and
// unnotarized. Returns one line per difference; empty means in step.
export function macPresetDrift(presets) {
  const mac = presets[MAC_PRESET];
  const shipped = presets[SHIPPED_PRESET];
  if (!mac || !shipped) return [`preset "${mac ? SHIPPED_PRESET : MAC_PRESET}" missing`];
  const drift = [];
  for (const key of ["export_filter", "include_filter", "exclude_filter", "script_export_mode"])
    if (mac.fields[key] !== shipped.fields[key])
      drift.push(`${key}: ${mac.fields[key]} mac, ${shipped.fields[key]} shipped`);
  const want = {
    "binary_format/architecture": '"universal"',
    "codesign/codesign": "1",
    "notarization/notarization": "0",
  };
  for (const [key, value] of Object.entries(want))
    if (mac.options[key] !== value) drift.push(`${key}: ${mac.options[key]}, want ${value}`);
  return drift;
}

// Godot refuses a universal or arm64 macOS export unless the project imports ETC2/ASTC textures. Turning that
// on in project.godot would make every Linux import build ASTC copies too, so the Mac export sets it
// for its own import and export only and restores the file (as --self-play does with the preset).
export const ASTC_SETTING = "textures/vram_compression/import_etc2_astc=true";
export function astcProjectText(text) {
  if (text.split("\n").includes(ASTC_SETTING)) return text;
  const lines = text.split("\n");
  const at = lines.indexOf("[rendering]");
  if (at < 0) return text.replace(/\n*$/, "\n\n[rendering]\n\n" + ASTC_SETTING + "\n");
  lines.splice(at + 1, 0, "", ASTC_SETTING);
  return lines.join("\n");
}

// The files the export swaps must match git before it starts: a run killed with SIGKILL can leave
// the ETC2/ASTC line in, and the restore would then write that back. porcelain is
// `git status --porcelain -- <files>`; returns the problem, or null when both are clean.
export const SWAPPED_FILES = ["sketches/core-loop/project.godot", "sketches/core-loop/export_presets.cfg"];
export function swapFilesProblem(porcelain) {
  const changed = porcelain.split("\n").filter((line) => line.trim()).map((line) => line.slice(3));
  if (changed.length === 0) return null;
  return `${changed.join(", ")} differ from git; an earlier export may have been killed mid-swap. Check with git diff and restore the file (git restore <path>) before exporting.`;
}

// Where Godot on macOS looks for export templates under a given HOME.
export function templatesDir(home) {
  return path.join(home, "Library/Application Support/Godot/export_templates");
}

// The one file in Contents/MacOS that is not the stem folder is the game's executable.
export function appExecutable(app, list = readdirSync) {
  const dir = path.join(app, "Contents/MacOS");
  const files = list(dir).filter((name) => name !== "music_ace");
  if (files.length !== 1) throw new Error(`expected one executable in ${dir}, found ${files.length}`);
  return path.join(dir, files[0]);
}

// BUILD.txt. In a .app src/core/build_stamp.gd reads Contents/Resources/BUILD.txt (codesign refuses
// a data file in Contents/MacOS), so one copy goes there (boot null: written before the boot) and
// the full one beside the app.
export function macBuildStamp({ sha, dirty, stamp, godot, stems, selfPlay, boot = null }) {
  return (
    [
      "commit: " + sha,
      "dirty: " + dirty,
      "built: " + stamp,
      "godot: " + godot,
      "target: macOS universal .app (runs native arm64 on Apple silicon), ad-hoc signed, not notarized",
      "stems: " + stems,
      ...(selfPlay ? ["self-play pack (tools/ included); not the shipped pack"] : []),
      ...(boot
        ? [
            "checked: export include filter, preset drift against Linux x64, ad-hoc seal (codesign --verify --strict), headless boot 300 frames reporting this commit (" + boot + ")",
            "not checked: release placeholder gate, Vulkan boss smoke, park-table boot, win proof, a windowed launch by a person, Gatekeeper on another Mac",
          ]
        : []),
    ].join("\n") + "\n"
  );
}

// The boot must print the stamp it was given: build_stamp.gd's "SCRAPKEEP_BUILD commit=<sha> ...".
export function stampFailures(output, sha) {
  const line = /^SCRAPKEEP_BUILD commit=(\S+) .*source=(\S+)/m.exec(output);
  if (!line) return ["no SCRAPKEEP_BUILD line in the boot output"];
  if (line[1] !== sha || line[2] !== "export")
    return [`the app reports commit=${line[1]} source=${line[2]}, want commit=${sha} source=export`];
  return [];
}

// Writes each {path, text} for the length of body and puts every file back afterwards: in finally,
// on process.exit (fail() included) and on SIGINT or SIGTERM (exit 130 or 143). SIGKILL cannot be
// caught; git status then shows the change.
export async function withSwappedFiles(changes, body) {
  const saved = changes.map(({ path: file }) => ({ file, text: readFileSync(file, "utf8") }));
  const restore = () => {
    for (const { file, text } of saved) writeFileSync(file, text);
  };
  const onSignal = { SIGINT: () => process.exit(130), SIGTERM: () => process.exit(143) };
  process.once("exit", restore);
  for (const [signal, handler] of Object.entries(onSignal)) process.once(signal, handler);
  try {
    for (const { path: file, text } of changes) writeFileSync(file, text);
    return await body();
  } finally {
    restore();
    process.removeListener("exit", restore);
    for (const [signal, handler] of Object.entries(onSignal)) process.removeListener(signal, handler);
  }
}

function run(command, args, options = {}) {
  return spawnSync(command, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, timeout: 900_000, ...options });
}

function fail(message) {
  console.error("sketch:export-mac FAIL: " + message);
  process.exit(1);
}

// Copies the stems into the app when every one is present and hashes as cut; otherwise returns why not.
async function stems(stemsFrom, app) {
  const tracks = trackedManifests(stemRoot);
  const manifests = {};
  for (const track of tracks)
    manifests[track] = JSON.parse(await readFile(path.join(stemRoot, track, "manifest.json"), "utf8"));
  for (const track of tracks) {
    const missing = missingStems(manifests[track], path.join(stemsFrom, track));
    if (missing.length > 0)
      return { copied: false, line: `not copied: ${missing.length} named stem file(s) missing from ${path.join(stemsFrom, track)} (first ${missing[0]}); the app plays its synth music` };
  }
  const named = tracks.flatMap((track) =>
    Object.values(manifests[track].clips ?? {}).flatMap((clip) => Object.values(clip.files ?? {}).map((f) => `${track}/${f}`)),
  );
  const rejected = stemHashMismatches(path.join(stemRoot, STEM_HASHES), stemsFrom, named);
  if (rejected === null || rejected.length > 0)
    return { copied: false, line: `not copied: stems in ${stemsFrom} do not match ${STEM_HASHES}` };
  const dest = path.join(app, "Contents/MacOS/music_ace");
  await cp(stemsFrom, dest, { recursive: true, filter: (s) => !s.endsWith(".import") && !s.endsWith(".gdignore") });
  let count = 0;
  for (const track of tracks) {
    await mkdir(path.join(dest, track), { recursive: true });
    await cp(path.join(stemRoot, track, "manifest.json"), path.join(dest, track, "manifest.json"));
    count += Object.keys(manifests[track].clips).length * manifests[track].stems.length;
  }
  return { copied: true, line: `${count} from ${stemsFrom} into Contents/MacOS/music_ace` };
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    fail(error.message);
  }
  if (process.platform !== "darwin") fail("the Mac export runs on macOS; on Linux use npm run sketch:export");
  const binary = process.env.GODOT_BIN;
  if (!binary || !existsSync(binary)) fail("set GODOT_BIN to the Godot 4.7.2 editor binary: " + binary);
  const realTemplates = path.join(templatesDir(os.homedir()), TEMPLATE_VERSION);
  if (!existsSync(path.join(realTemplates, "macos.zip"))) fail("export template missing: " + path.join(realTemplates, "macos.zip"));

  const swapStatus = run("git", ["-C", root, "status", "--porcelain", "--", ...SWAPPED_FILES]);
  if (swapStatus.status !== 0) fail("git status failed\n" + swapStatus.stderr);
  const swapProblem = swapFilesProblem(swapStatus.stdout);
  if (swapProblem) fail(swapProblem);

  const presetPath = path.join(project, "export_presets.cfg");
  const presetText = await readFile(presetPath, "utf8");
  const drift = macPresetDrift(parsePresets(presetText));
  if (drift.length > 0) fail(`preset "${MAC_PRESET}" drifted from "${SHIPPED_PRESET}"\n` + drift.join("\n"));
  const included = checkPreset({ sketch: project, presetText, presetName: MAC_PRESET });
  if (included.problems.length > 0) fail(`export include check "${MAC_PRESET}"\n` + included.problems.join("\n"));

  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const outDir = path.join(root, "artifacts/local/core-loop-export-mac", stamp + (args.selfPlay ? "-selfplay" : ""));
  const home = path.join(outDir, "home");
  await mkdir(templatesDir(home), { recursive: true });
  await symlink(realTemplates, path.join(templatesDir(home), TEMPLATE_VERSION));
  const env = { ...process.env, HOME: home, XDG_DATA_HOME: home };

  // project.godot (and, with --self-play, the preset) change for the import and export alone;
  // withSwappedFiles puts them back on success, failure and interruption.
  const projectPath = path.join(project, "project.godot");
  const projectText = await readFile(projectPath, "utf8");
  const app = path.join(outDir, APP_NAME);
  const swaps = [{ path: projectPath, text: astcProjectText(projectText) }];
  if (args.selfPlay) swaps.push({ path: presetPath, text: selfPlayPresetText(presetText, MAC_PRESET) });
  const exported = await withSwappedFiles(swaps, () => {
    const imported = run(binary, ["--headless", "--path", project, "--editor", "--import"], { env });
    if (imported.status !== 0) fail("editor import failed\n" + (imported.stdout + imported.stderr).slice(-2000));
    return run(binary, ["--headless", "--path", project, "--export-release", MAC_PRESET, app], { env });
  });
  const exportText = exported.stdout + exported.stderr;
  await writeFile(path.join(outDir, "export.log"), exportText);
  if (exported.status !== 0 || errorLine.test(exportText) || !existsSync(app)) fail("export failed\n" + exportText.slice(-2000));
  const exe = appExecutable(app);

  const common = run("git", ["-C", root, "rev-parse", "--path-format=absolute", "--git-common-dir"]);
  if (common.status !== 0) fail("git common dir not found\n" + common.stderr);
  const stemsFrom = path.resolve(args.stemsFrom ?? defaultStemsFrom(common.stdout.trim()));
  const stemResult = await stems(stemsFrom, app);

  // The stamp goes in Contents/Resources, where the game reads it in a .app. Adding files after
  // Godot signed the bundle breaks its seal, so the app is signed again, ad-hoc (no identity),
  // keeping Godot's entitlements and hardened-runtime flags, and the seal is verified. Stems in
  // Contents/MacOS/music_ace have not been tried; codesign may refuse them as it did BUILD.txt there.
  const sha = run("git", ["-C", root, "rev-parse", "HEAD"]).stdout.trim();
  const dirty = run("git", ["-C", root, "status", "--porcelain", "--untracked-files=no"]).stdout.trim() !== "";
  const godot = run(binary, ["--version"], { env }).stdout.trim();
  const stampFields = { sha, dirty, stamp, godot, stems: stemResult.line, selfPlay: args.selfPlay };
  await writeFile(path.join(app, "Contents/Resources/BUILD.txt"), macBuildStamp(stampFields));
  const signed = run("codesign", ["--force", "--sign", "-", "--preserve-metadata=entitlements,flags,runtime", app]);
  if (signed.status !== 0) fail("ad-hoc re-sign failed\n" + signed.stderr);
  const verified = run("codesign", ["--verify", "--strict", app]);
  if (verified.status !== 0) fail("codesign --verify failed\n" + verified.stderr);

  const bootHome = path.join(outDir, "boot-home");
  await mkdir(bootHome, { recursive: true });
  const bootArgs = ["--headless", "--quit-after", "300", ...(stemResult.copied ? ["--music=ace", "--ace-check"] : [])];
  const boot = run(exe, bootArgs, { cwd: outDir, env: { ...process.env, HOME: bootHome, XDG_DATA_HOME: bootHome } });
  const bootText = boot.stdout + boot.stderr;
  await writeFile(path.join(outDir, "boot.log"), bootText);
  const failures = stemResult.copied ? bootFailures(bootText) : errorLine.test(bootText) ? ["SCRIPT ERROR or ERROR line in the boot output"] : [];
  failures.push(...stampFailures(bootText, sha));
  if (boot.status !== 0) failures.push("boot exit " + boot.status);
  if (failures.length > 0) fail(failures.join("; ") + "\n" + bootText.slice(-2000));

  await writeFile(path.join(outDir, "BUILD.txt"), macBuildStamp({ ...stampFields, boot: `exit 0, ${bootArgs.join(" ")}` }));
  console.log("app: " + app);
  console.log("executable: " + exe);
  console.log("stems: " + stemResult.line);
  console.log("boot tail:\n" + bootText.trim().split("\n").slice(-4).join("\n"));
  console.log("BUILD.txt: " + path.join(outDir, "BUILD.txt"));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
