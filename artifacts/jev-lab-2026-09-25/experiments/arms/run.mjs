// JL-28 runner: the scripted and random arms on every cell of design.json,
// batch seed 2, launched from this worktree. PREREGISTRATION.md pins the
// sha256 of design.json, analyze.mjs and this file.
//
//   node run.mjs --dry-run   prints the batch plan and the checks; runs nothing
//   node run.mjs --live      refuses unless every pin and precondition holds,
//                            then runs once: canary, batches, analysis
import { spawn, spawnSync } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { binary as GODOT } from "../../../../scripts/sketch-smoke.mjs";
import { sha256 } from "./analyze.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "../../../..");
export const PREREGISTRATION = path.join(here, "PREREGISTRATION.md");
export const INPUTS = ["design.json", "analyze.mjs", "run.mjs"];
const LAUNCH = "scripts/lab/godot-launch.mjs";
const GATE = "scripts/lab/gate.mjs";

const design = JSON.parse(readFileSync(path.join(here, "design.json"), "utf8"));

export function hashes() {
  return Object.fromEntries(INPUTS.map((name) => [name, sha256(readFileSync(path.join(here, name)))]));
}

// The pre-registration lists each input as "`<file>` sha256 `<hex>`".
export function lockMismatches() {
  const text = existsSync(PREREGISTRATION) ? readFileSync(PREREGISTRATION, "utf8") : "";
  return Object.entries(hashes())
    .filter(([name, hex]) => !text.includes(`\`${name}\` sha256 \`${hex}\``))
    .map(([name, hex]) => `${name} sha256 ${hex} is not pinned in PREREGISTRATION.md`);
}

const git = (cwd, ...args) => {
  const out = spawnSync("git", ["-C", cwd, ...args], { encoding: "utf8" });
  return out.status === 0 ? out.stdout.trim() : null;
};

const sketchDir = (name) => path.resolve(REPO, design.sketches[name].path);

export function launchArgs({ sketch, scenario, arm, mode, n, seed, callCap, root }) {
  return [
    LAUNCH, scenario, "--arm", arm, "-n", String(n), "--seed", String(seed), "--mode", mode,
    ...(callCap === undefined ? [] : ["--call-cap", String(callCap)]),
    "--root", root,
    ...(design.sketches[sketch].repository === "self" ? [] : ["--sketch", sketchDir(sketch)]),
  ];
}

export function plan(outDir) {
  const batches = [];
  for (const cell of design.cells) {
    for (const arm of design.arms) {
      const key = `${cell.id}-${arm}`;
      const root = path.join(outDir, "runs", key);
      batches.push({
        order: batches.length + 1,
        key,
        cell: cell.id,
        class: cell.class,
        arm,
        sketch: cell.sketch,
        scenario: cell.scenario,
        mode: cell.mode,
        n: cell.n,
        trial_seeds: [design.batch_seed * design.trial_seed_stride, design.batch_seed * design.trial_seed_stride + cell.n - 1],
        call_cap: cell.n * (cell.limit_s + 2),
        root,
        est_s: (cell.est_s_per_20[arm] * cell.n) / 20,
        args: launchArgs({ ...cell, arm, seed: design.batch_seed, callCap: cell.n * (cell.limit_s + 2), root }),
      });
    }
  }
  return batches;
}

// List scheduling in plan order on `workers` slots; returns the makespan.
export function makespan(batches, workers) {
  const free = new Array(workers).fill(0);
  for (const b of batches) {
    free.sort((x, y) => x - y);
    free[0] += b.est_s;
  }
  return Math.max(...free);
}

export function preconditions() {
  const checks = [];
  const add = (name, ok, detail) => checks.push({ name, ok, detail });
  const status = git(REPO, "status", "--porcelain");
  add("harness worktree clean", status === "", status === "" ? "clean" : status);
  const tree = git(REPO, "rev-parse", "HEAD:sketches/ball-lab");
  add("ball-lab tree equals the pin subject", tree === design.sketches["ball-lab"].tree_oid, tree);
  for (const [name, s] of Object.entries(design.sketches)) {
    if (s.repository === "self") continue;
    const repo = path.resolve(REPO, s.repository);
    const head = git(repo, "rev-parse", "HEAD");
    add(`${name} head`, head === s.head, head);
    const branch = git(repo, "branch", "--show-current");
    add(`${name} branch`, branch === s.branch, branch);
    const dirty = git(repo, "status", "--porcelain");
    add(`${name} worktree clean`, dirty === "", dirty === "" ? "clean" : dirty);
    const proto = git(repo, "rev-parse", s.proto_ref);
    add(`${s.proto_ref} unchanged`, proto === s.proto_head, proto);
    add(`${name} project`, existsSync(path.join(sketchDir(name), "project.godot")), sketchDir(name));
  }
  add("godot binary", existsSync(GODOT), GODOT);
  add("canary pin", existsSync(path.join(REPO, design.canary.pin, "pin.json")), design.canary.pin);
  return checks;
}

export function provenance() {
  const stages = {};
  for (const [name, s] of Object.entries(design.sketches)) {
    if (s.repository === "self") continue;
    const repo = path.resolve(REPO, s.repository);
    stages[name] = {
      head: git(repo, "rev-parse", "HEAD"),
      status: git(repo, "status", "--porcelain"),
      proto: { [s.proto_ref]: git(repo, "rev-parse", s.proto_ref) },
    };
  }
  return {
    at: new Date().toISOString(),
    head: git(REPO, "rev-parse", "HEAD"),
    status: git(REPO, "status", "--porcelain"),
    ball_lab_tree: git(REPO, "rev-parse", "HEAD:sketches/ball-lab"),
    preregistration_sha256: existsSync(PREREGISTRATION) ? sha256(readFileSync(PREREGISTRATION)) : null,
    inputs: hashes(),
    stages,
    node: process.version,
    godot: GODOT,
  };
}

const minutes = (s) => `${(s / 60).toFixed(1)} min`;

function dryRun() {
  const out = path.join(REPO, design.out_root, "<start>");
  const batches = plan(out);
  const mismatches = lockMismatches();
  console.log(`JL-28 dry run: no batch, canary or gate runs. ${new Date().toISOString()}`);
  console.log(`inputs: ${Object.entries(hashes()).map(([n, h]) => `${n} ${h}`).join("; ")}`);
  console.log(mismatches.length === 0 ? "pins: every input matches PREREGISTRATION.md" : `pins: ${mismatches.join("; ")}`);
  for (const c of preconditions()) console.log(`precondition ${c.ok ? "ok  " : "FAIL"} ${c.name}: ${c.detail}`);
  const canaryRoot = path.join(out, "canary");
  const k = design.canary;
  console.log(`\ncanary (not counted): node ${launchArgs({ ...k, seed: k.seed, root: canaryRoot }).join(" ")}`);
  console.log(`  then: node ${GATE} <canary run dir> --against ${k.pin}   (must exit 0, else stop before any counted batch)`);
  console.log(`\n| # | batch | class | sketch | scenario | mode | arm | n | trial seeds | call cap | est s |`);
  console.log(`| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |`);
  for (const b of batches) {
    console.log(`| ${b.order} | ${b.key} | ${b.class} | ${b.sketch} | ${b.scenario} | ${b.mode} | ${b.arm} | ${b.n} | ${b.trial_seeds[0]}..${b.trial_seeds[1]} | ${b.call_cap} | ${b.est_s.toFixed(0)} |`);
  }
  console.log("\ncommands, in launch order:");
  for (const b of batches) console.log(`  ${b.order}. node ${b.args.join(" ")}`);
  const trials = batches.reduce((s, b) => s + b.n, 0);
  const sequential = batches.reduce((s, b) => s + b.est_s, 0);
  const confirmatory = design.cells.filter((c) => c.class === "confirmatory").map((c) => c.id);
  console.log(`\nbatches ${batches.length} (+1 canary), trials ${trials} (+${k.n} canary), cells ${design.cells.length}, confirmatory ${confirmatory.length}: ${confirmatory.join(", ")}`);
  console.log(`estimate (unverified-computed from prior batch wall times): sequential ${minutes(sequential)}; ${design.concurrency} at a time ${minutes(makespan(batches, design.concurrency))} plus the canary`);
  console.log("No run was made.");
  return 0;
}

function runProcess(args, logBase) {
  return new Promise((resolve) => {
    const stdout = openSync(`${logBase}.stdout.txt`, "w");
    const stderr = openSync(`${logBase}.stderr.txt`, "w");
    const started = new Date().toISOString();
    const child = spawn(process.execPath, args, { cwd: REPO, stdio: ["ignore", stdout, stderr] });
    child.on("close", (code, signal) => {
      closeSync(stdout);
      closeSync(stderr);
      const text = readFileSync(`${logBase}.stdout.txt`, "utf8");
      const match = /^run record: (\S+) at (.+)$/m.exec(text);
      resolve({ exit: code, signal, started, finished: new Date().toISOString(), run_dir: match === null ? null : match[2].trim() });
    });
  });
}

async function live() {
  const refusals = [...lockMismatches(), ...preconditions().filter((c) => !c.ok).map((c) => `precondition ${c.name}: ${c.detail}`)];
  if (refusals.length > 0) {
    for (const r of refusals) console.error(`refused: ${r}`);
    return 2;
  }
  const outRoot = path.join(REPO, design.out_root);
  mkdirSync(outRoot, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const out = path.join(outRoot, stamp);
  try {
    writeFileSync(path.join(outRoot, "STARTED.json"), JSON.stringify({ stamp, at: new Date().toISOString() }) + "\n", { flag: "wx" });
  } catch {
    console.error(`refused: ${path.join(outRoot, "STARTED.json")} exists; JL-28 runs once`);
    return 2;
  }
  mkdirSync(path.join(out, "logs"), { recursive: true });
  const before = provenance();
  writeFileSync(path.join(out, "provenance-before.json"), JSON.stringify(before, null, 2) + "\n");
  const k = design.canary;
  const canaryRoot = path.join(out, "canary");
  mkdirSync(canaryRoot, { recursive: true });
  const canary = await runProcess(launchArgs({ ...k, seed: k.seed, root: canaryRoot }), path.join(out, "logs", "00-canary"));
  const gate = canary.run_dir === null ? null : await runProcess([GATE, canary.run_dir, "--against", path.join(REPO, k.pin)], path.join(out, "logs", "00-canary-gate"));
  writeFileSync(path.join(out, "canary.json"), JSON.stringify({ canary, gate }, null, 2) + "\n");
  if (canary.exit !== 0 || gate === null || gate.exit !== 0) {
    console.error(`canary failed (launch exit ${canary.exit}, gate exit ${gate?.exit ?? "not run"}); no counted batch was launched`);
    writeFileSync(path.join(out, "provenance-after.json"), JSON.stringify(provenance(), null, 2) + "\n");
    return 3;
  }
  const batches = plan(out);
  const manifest = path.join(out, "batches.ndjson");
  writeFileSync(manifest, "");
  let next = 0;
  const worker = async () => {
    while (next < batches.length) {
      const b = batches[next];
      next += 1;
      mkdirSync(b.root, { recursive: true });
      console.log(`start ${b.order}/${batches.length} ${b.key}`);
      const result = await runProcess(b.args, path.join(out, "logs", `${String(b.order).padStart(2, "0")}-${b.key}`));
      appendFileSync(manifest, JSON.stringify({ order: b.order, cell: b.cell, arm: b.arm, exit: result.exit, signal: result.signal, started: result.started, finished: result.finished, run_dir: result.run_dir === null ? null : path.relative(out, result.run_dir) }) + "\n");
      console.log(`done  ${b.order}/${batches.length} ${b.key} exit ${result.exit}`);
    }
  };
  await Promise.all(Array.from({ length: design.concurrency }, worker));
  const after = provenance();
  after.preconditions = preconditions();
  writeFileSync(path.join(out, "provenance-after.json"), JSON.stringify(after, null, 2) + "\n");
  const analysis = spawnSync(process.execPath, [path.join(here, "analyze.mjs"), "--manifest", manifest, "--head", before.head, "--out", path.join(out, "analysis")], { cwd: REPO, encoding: "utf8" });
  writeFileSync(path.join(out, "logs", "99-analysis.stdout.txt"), analysis.stdout);
  writeFileSync(path.join(out, "logs", "99-analysis.stderr.txt"), analysis.stderr);
  console.log(analysis.stdout);
  console.log(`output: ${out}`);
  return analysis.status;
}

async function main(argv) {
  const { values } = parseArgs({ args: argv, options: { "dry-run": { type: "boolean", default: false }, live: { type: "boolean", default: false } } });
  if (values["dry-run"] === values.live) {
    console.error("Pass exactly one of --dry-run or --live.");
    return 2;
  }
  return values["dry-run"] ? dryRun() : live();
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
