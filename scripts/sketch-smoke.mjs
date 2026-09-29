import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordedBinary =
  "/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64";
export const binary = process.env.GODOT_BIN || recordedBinary;
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
const TIMEOUT_MS = 120_000;
const SLOWEST = 10;

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

// Each headless Godot is one mostly single-threaded process, so tests run side by side.
// The pool sizes itself to the idle cores (other agents share this machine), keeps at
// least 2 and at most 8, and SMOKE_JOBS overrides it.
export function jobCount() {
  if (process.env.SMOKE_JOBS) return Math.max(1, Number(process.env.SMOKE_JOBS) || 1);
  const idle = os.cpus().length - os.loadavg()[0];
  return Math.min(8, Math.max(2, Math.floor(idle / 3)));
}

// A test that prints SKIP, or "N skipped" with N above zero, passed without checking
// something. The run still passes, but the summary lists it so a missing asset stays visible.
const skipWord = /\bSKIP\b/;
const skippedCount = /\b([1-9]\d*) skipped\b/;

export function skipLines(output) {
  return output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => skipWord.test(line) || skippedCount.test(line));
}

function report(label, status, output, ms) {
  const ok = status === 0 && !errorLine.test(output);
  const skips = skipLines(output);
  console.log(`${ok ? "PASS" : "FAIL"} ${label} exit=${status} ${(ms / 1000).toFixed(1)}s`);
  if (!ok) console.log(output.split("\n").slice(-40).join("\n"));
  return { label, ok, ms, skips };
}

// Import writes the sketch's .godot cache, so it runs alone before anything reads it.
function runSync(label, args) {
  const started = Date.now();
  const result = spawnSync(binary, args, { encoding: "utf8", timeout: TIMEOUT_MS });
  return report(label, result.status, (result.stdout || "") + (result.stderr || ""), Date.now() - started);
}

// Every test gets its own XDG_DATA_HOME, so user:// is never shared between parallel runs.
function runAsync(label, args) {
  return new Promise((resolve) => {
    const started = Date.now();
    const dataHome = mkdtempSync(path.join(os.tmpdir(), "sketch-smoke-"));
    const child = spawn(binary, args, { env: { ...process.env, XDG_DATA_HOME: dataHome } });
    let output = "";
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), TIMEOUT_MS);
    child.on("close", (code) => {
      clearTimeout(timer);
      rmSync(dataHome, { recursive: true, force: true });
      resolve(report(label, code, output, Date.now() - started));
    });
  });
}

async function pool(jobs, width) {
  const results = [];
  let next = 0;
  async function worker() {
    while (next < jobs.length) {
      const job = jobs[next++];
      results.push(await runAsync(job.label, job.args));
    }
  }
  await Promise.all(Array.from({ length: Math.min(width, jobs.length) }, worker));
  return results;
}

function chosenSketches(all) {
  const wanted = [];
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--sketch" && argv[i + 1]) wanted.push(argv[++i]);
  }
  if (wanted.length === 0) return all;
  const picked = all.filter((directory) => wanted.includes(path.basename(directory)));
  const missing = wanted.filter((name) => !picked.some((directory) => path.basename(directory) === name));
  if (missing.length > 0) {
    console.error(`sketch:smoke has no sketch named ${missing.join(", ")}`);
    process.exit(2);
  }
  return picked;
}

async function main() {
  const sketches = chosenSketches(sketchDirectories(path.join(root, "sketches")));
  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN`);
    process.exit(2);
  }
  if (sketches.length === 0) {
    console.log("sketch:smoke found no sketches/*/project.godot");
    return;
  }
  const width = jobCount();
  const started = Date.now();
  const results = [];
  const jobs = [];
  for (const directory of sketches) {
    const name = path.relative(root, directory);
    const base = ["--headless", "--path", directory];
    results.push(runSync(`${name} import`, [...base, "--import"]));
    jobs.push({ label: `${name} boot`, args: [...base, "--quit-after", "300"] });
    for (const script of testScripts(directory))
      jobs.push({ label: `${name} ${script}`, args: [...base, "--script", script] });
  }
  results.push(...(await pool(jobs, width)));
  const ok = results.every((result) => result.ok);
  const slowest = [...results].sort((a, b) => b.ms - a.ms).slice(0, SLOWEST);
  console.log(`slowest ${slowest.length}:`);
  for (const result of slowest) console.log(`  ${(result.ms / 1000).toFixed(1)}s ${result.label}`);
  const skipped = results.filter((result) => result.skips.length > 0);
  console.log(`skipped ${skipped.length} (passed without running every check; not a failure):`);
  for (const result of skipped) {
    console.log(`  ${result.label}`);
    for (const line of result.skips.slice(0, 3)) console.log(`    ${line}`);
  }
  console.log(
    `sketch:smoke ${ok ? "pass" : "fail"}: ${sketches.length} sketches, ${results.length} runs, ${width} at a time, ${((Date.now() - started) / 1000).toFixed(0)}s. Headless boot and sketch tests only; feel needs Andrew's play.`,
  );
  process.exit(ok ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
