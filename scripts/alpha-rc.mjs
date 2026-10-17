#!/usr/bin/env node
// npm run alpha:rc: the wave 21 release-candidate gate. One command runs every alpha check in order
// and writes one go/no-go page:
//   tree          the checkout is clean, so the page's commit is what every step tested
//   placeholders  node scripts/placeholder-gate.mjs --json (zero placeholders)
//   lint          node scripts/sketch-lint.mjs --sketch core-loop
//   smoke         node scripts/sketch-smoke.mjs --sketch core-loop --receipt gate (shipping defaults);
//                 a quarantined red test fails here, because a release candidate carries none
//   bots          node scripts/sketch-smoke.mjs --sketch core-loop --bots --receipt gate-bots
//   export        node scripts/sketch-export.mjs --win-proof (the four win proofs and the boss smoke);
//                 --cloud swaps in scripts/cloud/export-headless.mjs --win-proof (no stems, no boss smoke)
//   frametime     node scripts/frametime-check.mjs --log=<--capture csv>, a MangoHud capture newer than
//                 the commit (MangoHud logs carry no build id, so that is as close as the check gets)
//   redteam       --redteam=<this commit's findings.json>: a full pass (not --quick), no blocker, and
//                 every finding --carry-from=<last wave's findings.json> carried replayed as a carry- run
//   launch        Scrapkeep-<sha7>-x86_64.AppImage for this commit (default: found under
//                 artifacts/local/core-loop-export/; --appimage=<path> must carry the same sha in its
//                 name), cold launched with a fresh HOME and XDG profile and no Godot on PATH; passes when
//                 it prints SCRAPKEEP_MENU_READY within 5 s
// Each step ends pass, fail or not run. A missing or mismatched input, or a --skip=<id,...>, reads
// "not run", never pass. The verdict is GO only when every step passed; --cloud makes it a
// rehearsal at best, because cloud perf and the cloud export do not count.
// Output: artifacts/local/alpha-rc/<stamp>/ with RC.md, rc.json and one log per step.
// Exit 0 GO, 1 any step failed, 2 nothing failed but a step did not run (or a cloud rehearsal).
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const node = process.execPath;
export const MENU_READY = "SCRAPKEEP_MENU_READY";
export const LAUNCH_BUDGET_S = 5;
// The full smoke tier takes about 2 h on a 4-core cloud box; a hang still ends, four hours in.
const STEP_TIMEOUT_MS = 4 * 60 * 60_000;
const KILL_GRACE_MS = 3000;
const TAIL_LINES = 12;
const EXPORTS = path.join(root, "artifacts/local/core-loop-export");

export const STEP_IDS = ["tree", "placeholders", "lint", "smoke", "bots", "export", "frametime", "redteam", "launch"];

export function parseArgs(argv) {
  const args = {
    cloud: false,
    capture: null,
    redteam: null,
    carryFrom: null,
    appimage: null,
    launchSeconds: LAUNCH_BUDGET_S,
    skip: new Set(),
    out: null,
  };
  for (const arg of argv) {
    const [key, value] = arg.includes("=") ? [arg.slice(0, arg.indexOf("=")), arg.slice(arg.indexOf("=") + 1)] : [arg, null];
    if (key === "--cloud") args.cloud = true;
    else if (key === "--capture") args.capture = value;
    else if (key === "--redteam") args.redteam = value;
    else if (key === "--carry-from") args.carryFrom = value;
    else if (key === "--appimage") args.appimage = value;
    else if (key === "--out") args.out = value;
    else if (key === "--launch-seconds") {
      if (!(Number(value) > 0)) throw new Error("--launch-seconds needs a positive number");
      args.launchSeconds = Number(value);
    } else if (key === "--skip") {
      for (const id of (value ?? "").split(",").filter(Boolean)) {
        if (!STEP_IDS.includes(id)) throw new Error(`--skip: unknown step ${id} (steps: ${STEP_IDS.join(", ")})`);
        args.skip.add(id);
      }
    } else throw new Error(`unknown argument ${arg}`);
  }
  return args;
}

export const appImageName = (sha) => `Scrapkeep-${sha.slice(0, 7)}-x86_64.AppImage`;

function findFile(dir, name, depth = 3) {
  if (depth < 0 || !existsSync(dir)) return null;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isFile() && entry.name === name) return full;
    if (entry.isDirectory()) {
      const found = findFile(full, name, depth - 1);
      if (found) return found;
    }
  }
  return null;
}

// The AppImage this commit built, or why there is none: sketch-appimage names it by the short sha
// (a dirty export adds -dirty), and the installed Scrapkeep.AppImage carries no sha at all.
export function resolveAppImage(args, git, find = (name) => findFile(EXPORTS, name)) {
  if (!git.head) return { needs: "no git HEAD to match the AppImage against" };
  const want = appImageName(git.head);
  if (!args.appimage) {
    const found = find(want);
    return found ? { path: found } : { needs: `no ${want} under artifacts/local/core-loop-export (npm run sketch:export, then sketch:appimage)` };
  }
  if (!existsSync(args.appimage)) return { needs: `no AppImage at ${args.appimage}` };
  if (path.basename(args.appimage) !== want) return { needs: `${path.basename(args.appimage)} is not this commit's ${want}` };
  return { path: args.appimage };
}

function inputNeeds(file, flag, what) {
  if (!file) return `no ${flag}=<${what}> given`;
  return existsSync(file) ? null : `${what} ${file} not found`;
}

// The criterion each step proves, in the playbook's words.
export function buildPlan(args, git, { find } = {}) {
  const script = (file, ...rest) => ({ command: node, args: [path.join(root, "scripts", file), ...rest] });
  const appimage = resolveAppImage(args, git, find);
  let captureNeeds = inputNeeds(args.capture, "--capture", "MangoHud csv");
  if (!captureNeeds && git.commitTime && statSync(args.capture).mtimeMs < git.commitTime * 1000)
    captureNeeds = `capture ${path.basename(args.capture)} is older than the commit`;
  const plan = [
    { id: "tree", label: "Clean checkout", criterion: "the page names what was tested", inline: "tree" },
    { id: "placeholders", label: "Placeholder gate", criterion: "zero placeholders", ...script("placeholder-gate.mjs", "--json") },
    { id: "lint", label: "Lint", criterion: "no open blocker", ...script("sketch-lint.mjs", "--sketch", "core-loop") },
    { id: "smoke", label: "Smoke tests", criterion: "no open blocker", ...script("sketch-smoke.mjs", "--sketch", "core-loop", "--receipt", "gate") },
    { id: "bots", label: "Bot runs", criterion: "every world can be won", ...script("sketch-smoke.mjs", "--sketch", "core-loop", "--bots", "--receipt", "gate-bots") },
    args.cloud
      ? { id: "export", label: "Export proofs (cloud, no boss smoke)", criterion: "the shipped pack wins", ...script("cloud/export-headless.mjs", "--win-proof") }
      : { id: "export", label: "Export proofs", criterion: "the shipped pack wins", ...script("sketch-export.mjs", "--win-proof") },
    { id: "frametime", label: "Frame time", criterion: "frame times in budget", ...script("frametime-check.mjs", `--log=${args.capture}`), needs: captureNeeds },
    {
      id: "redteam",
      label: "Red team carry",
      criterion: "no open blocker",
      inline: "redteam",
      needs: inputNeeds(args.redteam, "--redteam", "findings.json") ?? inputNeeds(args.carryFrom, "--carry-from", "last wave's findings.json"),
    },
    { id: "launch", label: "AppImage cold launch", criterion: "opens from the app menu", inline: "launch", appimage: appimage.path, needs: appimage.needs ?? null },
  ];
  for (const step of plan) if (args.skip.has(step.id)) step.needs = "skipped with --skip";
  return plan;
}

const tail = (text, n = TAIL_LINES) => text.trimEnd().split("\n").slice(-n).join("\n");

// Interprets each sub-command's exit in its own terms; a tool that says "nothing measured" or
// "could not run" is not run.
export function judgeCommand(step, { exit, output, error }) {
  if (error) return { status: "fail", note: `could not start: ${error}` };
  if (step.id === "placeholders") {
    let count = null;
    try {
      count = JSON.parse(output.slice(output.indexOf("["))).length;
    } catch {}
    if (exit === 0) return { status: "pass", note: "0 placeholders" };
    return { status: "fail", note: count === null ? `exit ${exit}` : `${count} placeholders` };
  }
  if (step.id === "frametime" && exit === 2) return { status: "not run", note: "frame-time check measured nothing" };
  if ((step.id === "smoke" || step.id === "bots") && exit === 2) return { status: "not run", note: "sketch:smoke could not run (exit 2)" };
  if (exit === null) return { status: "fail", note: "timed out or killed" };
  if (exit !== 0) return { status: "fail", note: `exit ${exit}` };
  const quarantined = output.match(/^quarantined \(red\) (\d+)/m);
  if (quarantined) return { status: "fail", note: `${quarantined[1]} quarantined red test(s); a release candidate carries none` };
  return { status: "pass", note: "exit 0" };
}

export function judgeTree(git) {
  if (!git.head) return { status: "not run", note: "no git HEAD" };
  if (!git.clean) return { status: "fail", note: `dirty tree: ${git.dirty.slice(0, 5).join(", ")}${git.dirty.length > 5 ? ", ..." : ""}` };
  return { status: "pass", note: `clean at ${git.head.slice(0, 8)}` };
}

// A carried finding counts as replayed when this pass has a carry- run on its pilot and seed
// (scripts/redteam/lib.mjs planWave names replays "carry-<i>-<job id>").
export function judgeRedteam(findings, head, previous) {
  const shaped = (f) => f && Array.isArray(f.findings) && Array.isArray(f.runs) && typeof f.commit === "string";
  if (!shaped(findings) || findings.runs.length === 0) return { status: "fail", note: "--redteam is not a red team findings.json (findings, runs, commit)" };
  if (!shaped(previous) || !Array.isArray(previous.carry)) return { status: "fail", note: "--carry-from is not a red team findings.json with a carry list" };
  if (previous.commit === findings.commit || !(Number(previous.wave) < Number(findings.wave)))
    return { status: "fail", note: `--carry-from (wave ${previous.wave}) is not an earlier wave than --redteam (wave ${findings.wave})` };
  if (!head) return { status: "not run", note: "no git HEAD to match the findings against" };
  if (findings.commit !== head) return { status: "not run", note: `findings are for ${findings.commit.slice(0, 8) || "no commit"}, candidate is ${head.slice(0, 8)}` };
  if (findings.quick) return { status: "not run", note: "a --quick pass does not count for a release candidate" };
  const blockers = findings.findings.filter((f) => f.severity === "blocker");
  const majors = findings.findings.filter((f) => f.severity === "major").length;
  const replayed = new Set(findings.runs.filter((r) => String(r.id).startsWith("carry-")).map((r) => `${r.pilot}:${r.seed}`));
  const unreplayed = previous.carry.filter((c) => !replayed.has(`${c.pilot}:${c.seed}`));
  if (blockers.length) return { status: "fail", note: `${blockers.length} blocker(s): ${blockers.map((b) => b.title).join("; ")}` };
  if (unreplayed.length) return { status: "fail", note: `${unreplayed.length} carried finding(s) not replayed` };
  return { status: "pass", note: `0 blockers, ${majors} major(s), ${previous.carry.length} carried replayed, wave ${findings.wave ?? "?"}` };
}

export function freshProfile() {
  const home = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-rc-home-"));
  const env = { HOME: home };
  for (const [key, dir] of [["XDG_CONFIG_HOME", ".config"], ["XDG_DATA_HOME", ".local/share"], ["XDG_CACHE_HOME", ".cache"], ["XDG_STATE_HOME", ".local/state"]]) {
    env[key] = path.join(home, dir);
    mkdirSync(env[key], { recursive: true });
  }
  return { home, env };
}

// The player's machine has no Godot: drop GODOT_BIN and every PATH entry holding a godot binary.
export function launchEnv(env, profileEnv) {
  const pathDirs = (env.PATH ?? "").split(":").filter((dir) => {
    try {
      return !readdirSync(dir).some((name) => /^godot/i.test(name));
    } catch {
      return false;
    }
  });
  const { GODOT_BIN: _godot, ...rest } = env;
  return { ...rest, PATH: pathDirs.join(":"), ...profileEnv };
}

// SIGTERM to the whole process group, SIGKILL after a grace, resolved once the leader has exited.
function stopGroup(child) {
  return new Promise((resolve) => {
    const signal = (sig) => {
      try {
        process.kill(-child.pid, sig);
      } catch {}
    };
    if (child.exitCode !== null || child.signalCode !== null) {
      signal("SIGKILL");
      return resolve();
    }
    const force = setTimeout(() => signal("SIGKILL"), KILL_GRACE_MS);
    child.once("exit", () => {
      clearTimeout(force);
      signal("SIGKILL");
      resolve();
    });
    signal("SIGTERM");
  });
}

// Cold launch: a fresh profile, no Godot on PATH, and the menu-ready line inside the budget. Its own
// process group, so the stop reaches the game the AppImage runtime starts.
export function launchAppImage(appimage, { seconds = LAUNCH_BUDGET_S, env = process.env } = {}) {
  const profile = freshProfile();
  return new Promise((resolve) => {
    const started = Date.now();
    let output = "";
    let settled = false;
    const child = spawn(appimage, [], { env: launchEnv(env, profile.env), stdio: ["ignore", "pipe", "pipe"], detached: true });
    const finish = async (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      const ms = Date.now() - started;
      if (child.pid) await stopGroup(child);
      child.stdout?.destroy();
      child.stderr?.destroy();
      try {
        rmSync(profile.home, { recursive: true, force: true });
      } catch {}
      resolve({ ...result, output, ms });
    };
    const onData = (chunk) => {
      output += chunk;
      if (output.includes(MENU_READY)) finish({ status: "pass", note: `main menu in ${((Date.now() - started) / 1000).toFixed(1)} s on a fresh profile` });
    };
    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.on("error", (error) => finish({ status: "fail", note: `could not start: ${error.message}` }));
    child.on("exit", (code, signal) => finish({ status: "fail", note: `exited (${code ?? signal}) before the main menu` }));
    const timer = setTimeout(
      () => finish({ status: "fail", note: `no ${MENU_READY} line within ${seconds} s (slow boot, or a build without the menu-ready line)` }),
      seconds * 1000,
    );
  });
}

// Resolves on the leader's exit; a timeout stops the whole group, so Godot children go with it.
export function runProcess(step, timeoutMs = STEP_TIMEOUT_MS) {
  return new Promise((resolve) => {
    let output = "";
    let timedOut = false;
    const child = spawn(step.command, step.args, { cwd: root, stdio: ["ignore", "pipe", "pipe"], detached: true });
    const timer = setTimeout(() => {
      timedOut = true;
      stopGroup(child);
    }, timeoutMs);
    child.stdout.on("data", (c) => (output += c));
    child.stderr.on("data", (c) => (output += c));
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ exit: null, output, error: error.message });
    });
    let done = false;
    const settle = (code) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      child.stdout.destroy();
      child.stderr.destroy();
      resolve({ exit: timedOut ? null : code, output });
    };
    // close fires once the pipes have drained; an orphan holding them open gets a short grace.
    child.on("close", settle);
    child.on("exit", (code) => setTimeout(() => settle(code), 2000));
  });
}

export function verdict(results, { cloud = false } = {}) {
  if (results.some((r) => r.status === "fail")) return { verdict: "NO-GO", exit: 1 };
  if (results.some((r) => r.status === "not run")) return { verdict: "INCOMPLETE", exit: 2 };
  if (cloud) return { verdict: "REHEARSAL PASSED", exit: 2 };
  return { verdict: "GO", exit: 0 };
}

const MARK = { pass: "✅ pass", fail: "❌ fail", "not run": "⬜ not run" };
const cell = (text) => String(text).replaceAll("|", "\\|").replace(/\s*\n\s*/g, " ");

export function renderPage({ head, startedAt, cloud, results, outcome }) {
  const lines = [
    `# Release candidate: ${outcome.verdict}`,
    "",
    `Commit \`${head ?? "unknown"}\` · started ${startedAt}${cloud ? " · cloud rehearsal (perf and export do not count)" : ""}`,
    "",
    "| Check | Proves | Result | Detail | Time |",
    "| --- | --- | --- | --- | --- |",
    ...results.map((r) => `| ${r.label} | ${r.criterion} | ${MARK[r.status]} | ${cell(r.note)} | ${r.ms == null ? "" : `${Math.round(r.ms / 1000)} s`} |`),
    "",
    "A check that did not run is never a pass. Automated play does not stand in for Andrew's sitting.",
  ];
  for (const r of results.filter((x) => x.status === "fail" && x.tail)) lines.push("", `## ${r.label}: last lines`, "", "```", r.tail, "```");
  return lines.join("\n") + "\n";
}

export async function runAlphaRc(args, { git = gitState(), recheck = gitState, run = runProcess, launch = launchAppImage, find, log = console.log, outDir } = {}) {
  const startedAt = new Date().toISOString();
  const results = [];
  if (outDir) mkdirSync(outDir, { recursive: true });
  for (const step of buildPlan(args, git, { find })) {
    const base = { id: step.id, label: step.label, criterion: step.criterion };
    let result;
    if (step.needs) result = { ...base, status: "not run", note: step.needs, ms: null };
    else {
      log(`alpha:rc ▶ ${step.label}`);
      const started = Date.now();
      if (step.inline === "tree") result = { ...base, ...judgeTree(git), ms: 0 };
      else if (step.inline === "redteam") {
        try {
          const findings = JSON.parse(readFileSync(args.redteam, "utf8"));
          const previous = JSON.parse(readFileSync(args.carryFrom, "utf8"));
          result = { ...base, ...judgeRedteam(findings, git.head, previous), ms: Date.now() - started };
        } catch (error) {
          result = { ...base, status: "fail", note: `unreadable findings: ${error.message}`, ms: Date.now() - started };
        }
      } else if (step.inline === "launch") {
        const launched = await launch(step.appimage, { seconds: args.launchSeconds });
        result = { ...base, status: launched.status, note: launched.note, ms: launched.ms, output: launched.output };
      } else {
        const ran = await run(step);
        result = { ...base, ...judgeCommand(step, ran), ms: Date.now() - started, output: ran.output };
      }
      if (outDir && result.output != null) writeFileSync(path.join(outDir, `${step.id}.log`), result.output);
      if (result.status === "fail" && result.output) result.tail = tail(result.output);
      delete result.output;
    }
    log(`alpha:rc ${MARK[result.status]} ${step.label}: ${cell(result.note)}`);
    results.push(result);
  }
  const after = recheck?.();
  if (after && git.clean && !after.clean)
    results.push({ id: "tree-after", label: "Clean checkout after the run", criterion: "the page names what was tested", status: "fail", note: `a step changed tracked files: ${after.dirty.slice(0, 5).join(", ")}`, ms: 0 });
  const outcome = verdict(results, args);
  const page = renderPage({ head: git.head, startedAt, cloud: args.cloud, results, outcome });
  if (outDir) {
    writeFileSync(path.join(outDir, "RC.md"), page);
    writeFileSync(path.join(outDir, "rc.json"), JSON.stringify({ head: git.head, clean: git.clean, startedAt, cloud: args.cloud, verdict: outcome.verdict, results }, null, 2) + "\n");
  }
  return { results, outcome, page };
}

// Read before any step runs, so a step that dirties the tree cannot change what the page names.
// artifacts/local/ is gitignored, so the gate's own output never dirties it.
export function gitState(cwd = root) {
  const git = (...a) => spawnSync("git", ["-C", cwd, ...a], { encoding: "utf8" });
  const head = git("rev-parse", "HEAD");
  if (head.status !== 0) return { head: null, clean: false, dirty: [], commitTime: null };
  const status = git("status", "--porcelain");
  const dirty = status.status === 0 ? status.stdout.split("\n").filter(Boolean).map((l) => l.slice(3)) : ["(git status failed)"];
  const time = Number(git("log", "-1", "--format=%ct").stdout.trim());
  return { head: head.stdout.trim(), clean: dirty.length === 0, dirty, commitTime: Number.isFinite(time) && time > 0 ? time : null };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const outDir = args.out ?? path.join(root, "artifacts/local/alpha-rc", stamp);
  const { outcome, page } = await runAlphaRc(args, { outDir });
  console.log("\n" + page);
  console.log(`Page: ${path.join(outDir, "RC.md")}`);
  process.exitCode = outcome.exit;
}
