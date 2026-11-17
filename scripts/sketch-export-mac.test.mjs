import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  stampFailures,
  withSwappedFiles,
  APP_NAME,
  ASTC_SETTING,
  MAC_PRESET,
  appExecutable,
  astcProjectText,
  macBuildStamp,
  macPresetDrift,
  parseArgs,
  templatesDir,
} from "./sketch-export-mac.mjs";
import { parsePresets, selfPlayPresetText } from "./sketch-export.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const presetsText = readFileSync(path.join(root, "sketches/core-loop/export_presets.cfg"), "utf8");
const projectText = readFileSync(path.join(root, "sketches/core-loop/project.godot"), "utf8");

test("the committed Mac preset packs what the shipped Linux preset packs", () => {
  assert.deepEqual(macPresetDrift(parsePresets(presetsText)), []);
});

// Seeded controls: a filter that differs, an architecture change, or signing turned off each fail.
test("macPresetDrift names a filter, architecture or signing change", () => {
  const filter = presetsText.replace(
    /(name="macOS"[\s\S]*?exclude_filter=")tests\/\*, /,
    "$1",
  );
  assert.notEqual(filter, presetsText);
  assert.match(macPresetDrift(parsePresets(filter)).join("\n"), /^exclude_filter:/);
  const arch = presetsText.replace('binary_format/architecture="universal"', 'binary_format/architecture="x86_64"');
  assert.match(macPresetDrift(parsePresets(arch)).join("\n"), /binary_format\/architecture/);
  const signing = presetsText.replace("codesign/codesign=1", "codesign/codesign=0");
  assert.match(macPresetDrift(parsePresets(signing)).join("\n"), /codesign\/codesign/);
  assert.deepEqual(macPresetDrift({}), [`preset "${MAC_PRESET}" missing`]);
});

test("the self-play swap on the Mac preset drops tools/ there and leaves the Linux presets alone", () => {
  const swapped = selfPlayPresetText(presetsText, MAC_PRESET);
  const presets = parsePresets(swapped);
  assert.doesNotMatch(presets[MAC_PRESET].fields.exclude_filter, /tools\//);
  assert.match(presets["Linux x64"].fields.exclude_filter, /tools\/\*/);
  const before = presetsText.split("\n");
  assert.equal(swapped.split("\n").filter((line, i) => line !== before[i]).length, 1);
});

test("astcProjectText turns on ETC2/ASTC import once, inside [rendering]", () => {
  assert.ok(!projectText.includes(ASTC_SETTING), "the committed project leaves ETC2/ASTC import off");
  const on = astcProjectText(projectText);
  const lines = on.split("\n");
  const at = lines.indexOf(ASTC_SETTING);
  assert.ok(at > lines.indexOf("[rendering]"));
  assert.ok(!lines.slice(lines.indexOf("[rendering]") + 1, at).some((line) => line.startsWith("[")));
  assert.equal(astcProjectText(on), on);
  assert.equal(astcProjectText("[application]\n"), "[application]\n\n[rendering]\n\n" + ASTC_SETTING + "\n");
});

test("parseArgs reads --self-play and --stems-from and refuses anything else", () => {
  assert.deepEqual(parseArgs([]), { stemsFrom: null, selfPlay: false });
  assert.deepEqual(parseArgs(["--self-play", "--stems-from=/s"]), { stemsFrom: "/s", selfPlay: true });
  assert.deepEqual(parseArgs(["--stems-from", "/t"]).stemsFrom, "/t");
  assert.throws(() => parseArgs(["--win-proof"]), /unknown argument/);
});

test("templatesDir and appExecutable find the macOS paths", () => {
  assert.equal(templatesDir("/h"), "/h/Library/Application Support/Godot/export_templates");
  const app = "/o/" + APP_NAME;
  assert.equal(appExecutable(app, () => ["Scrapkeep", "music_ace"]), "/o/Scrapkeep.app/Contents/MacOS/Scrapkeep");
  assert.throws(() => appExecutable(app, () => []), /expected one executable/);
});

test("BUILD.txt names the stems, the self-play pack and what was not checked", () => {
  const text = macBuildStamp({ sha: "abc", dirty: false, stamp: "s", godot: "4.7.2", stems: "not copied: none", selfPlay: true, boot: "exit 0" });
  assert.match(text, /^commit: abc\n/);
  assert.match(text, /stems: not copied: none/);
  assert.match(text, /self-play pack/);
  assert.match(text, /not checked: .*win proof/);
  assert.doesNotMatch(macBuildStamp({ sha: "a", dirty: false, stamp: "s", godot: "g", stems: "x", selfPlay: false, boot: "b" }), /self-play/);
});

test("the stamp goes beside the executable and appExecutable skips it", () => {
  assert.equal(appExecutable("/o/" + APP_NAME, () => ["BUILD.txt", "Scrapkeep"]), "/o/Scrapkeep.app/Contents/MacOS/Scrapkeep");
  const inside = macBuildStamp({ sha: "abc", dirty: false, stamp: "s", godot: "g", stems: "x", selfPlay: false });
  assert.match(inside, /^commit: abc\ndirty: false\nbuilt: s\n/);
  assert.doesNotMatch(inside, /checked:/);
});

test("stampFailures wants the app to report this commit from its own BUILD.txt", () => {
  const sha = "90497047b5c085810154ba32e2d5866af8e1dd3b";
  assert.deepEqual(stampFailures(`x\nSCRAPKEEP_BUILD commit=${sha} dirty=false built=s source=export\n`, sha), []);
  assert.match(stampFailures("SCRAPKEEP_BUILD commit=unknown dirty=false built=unknown source=none\n", sha)[0], /commit=unknown source=none/);
  assert.match(stampFailures(`SCRAPKEEP_BUILD commit=${sha} dirty=false built= source=checkout\n`, sha)[0], /source=checkout/);
  assert.deepEqual(stampFailures("no stamp here", sha), ["no SCRAPKEEP_BUILD line in the boot output"]);
});

const swapFile = () => {
  const file = path.join(mkdtempSync(path.join(os.tmpdir(), "swap-")), "project.godot");
  writeFileSync(file, "original\n");
  return file;
};

test("withSwappedFiles restores the file after the body returns and after it throws", async () => {
  const file = swapFile();
  const seen = await withSwappedFiles([{ path: file, text: "swapped\n" }], () => readFileSync(file, "utf8"));
  assert.equal(seen, "swapped\n");
  assert.equal(readFileSync(file, "utf8"), "original\n");
  await assert.rejects(
    withSwappedFiles([{ path: file, text: "swapped\n" }], () => {
      throw new Error("export failed");
    }),
    /export failed/,
  );
  assert.equal(readFileSync(file, "utf8"), "original\n");
});

const moduleUrl = pathToFileURL(path.join(root, "scripts/sketch-export-mac.mjs")).href;
const childScript = (file, body) =>
  `const { withSwappedFiles } = await import(${JSON.stringify(moduleUrl)});\n` +
  `await withSwappedFiles([{ path: ${JSON.stringify(file)}, text: "swapped\\n" }], ${body});`;

// fail() calls process.exit inside the body, which skips finally; the exit listener must restore.
test("withSwappedFiles restores the file when the body exits the process", () => {
  const file = swapFile();
  const child = spawnSync(process.execPath, ["--input-type=module", "-e", childScript(file, "() => process.exit(1)")]);
  assert.equal(child.status, 1);
  assert.equal(readFileSync(file, "utf8"), "original\n");
});

test("withSwappedFiles restores the file when the process gets SIGTERM", async () => {
  const file = swapFile();
  const body = 'async () => { console.log("swapped"); await new Promise((r) => setTimeout(r, 30000)); }';
  const child = spawn(process.execPath, ["--input-type=module", "-e", childScript(file, body)], {
    stdio: ["ignore", "pipe", "inherit"],
  });
  await new Promise((resolve) => child.stdout.once("data", resolve));
  assert.equal(readFileSync(file, "utf8"), "swapped\n");
  child.kill("SIGTERM");
  const code = await new Promise((resolve) => child.once("exit", resolve));
  assert.equal(code, 143);
  assert.equal(readFileSync(file, "utf8"), "original\n");
});
