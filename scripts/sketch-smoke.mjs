import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
export const binary = process.env.GODOT_BIN || recordedBinary;
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;

export function sketchDirectories(sketchRoot) {
  if (!existsSync(sketchRoot)) return [];
  return readdirSync(sketchRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(sketchRoot, entry.name))
    .filter((directory) => existsSync(path.join(directory, "project.godot")))
    .sort();
}

export function testScripts(directory) {
  const tests = path.join(directory, "tests");
  if (!existsSync(tests)) return [];
  return readdirSync(tests)
    .filter((name) => name.endsWith(".gd"))
    .sort()
    .map((name) => "res://tests/" + name);
}

function run(label, args) {
  const result = spawnSync(binary, args, {
    encoding: "utf8",
    timeout: 120_000,
  });
  const output = (result.stdout || "") + (result.stderr || "");
  const ok = result.status === 0 && !errorLine.test(output);
  console.log(`${ok ? "PASS" : "FAIL"} ${label} exit=${result.status}`);
  if (!ok) console.log(output.split("\n").slice(-40).join("\n"));
  return ok;
}

function main() {
  const sketches = sketchDirectories(path.join(root, "sketches"));
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
    process.exit(2);
  }
  if (sketches.length === 0) {
    console.log("sketch:smoke found no sketches/*/project.godot");
    return;
  }
  let ok = true;
  for (const directory of sketches) {
    const name = path.relative(root, directory);
    const base = ["--headless", "--path", directory];
    ok = run(`${name} import`, [...base, "--import"]) && ok;
    ok = run(`${name} boot`, [...base, "--quit-after", "300"]) && ok;
    for (const script of testScripts(directory))
      ok = run(`${name} ${script}`, [...base, "--script", script]) && ok;
  }
  console.log(
    `sketch:smoke ${ok ? "pass" : "fail"}: ${sketches.length} sketches. Headless boot and sketch tests only; feel needs Andrew's play.`,
  );
  process.exit(ok ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
