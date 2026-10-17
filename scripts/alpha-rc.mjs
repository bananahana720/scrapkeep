#!/usr/bin/env node
// npm run alpha:rc: the wave 21 release-candidate gate. One command runs every alpha check in order
// and writes one go/no-go page:
//   placeholders  node scripts/placeholder-gate.mjs --json (zero placeholders)
//   smoke         node scripts/sketch-smoke.mjs --sketch core-loop
//   bots          node scripts/sketch-smoke.mjs --sketch core-loop --bots
//   export        node scripts/sketch-export.mjs --win-proof (the four win proofs and the boss smoke);
//                 --cloud swaps in scripts/cloud/export-headless.mjs --win-proof (no stems, no boss smoke)
//   frametime     node scripts/frametime-check.mjs --log=<--capture csv> (a MangoHud capture of this build)
//   redteam       the red team's findings.json for this commit (--redteam=<file>): no blocker, and with
//                 --carry-from=<last wave's findings.json> every finding it carried replayed in this pass
//   launch        the AppImage (--appimage=<path>, default the installed one) cold launched with a
//                 fresh HOME and XDG profile; passes when it prints SCRAPKEEP_MENU_READY within 5 s
// Each step ends pass, fail or not run. A missing input (no capture, no findings, no AppImage) or a
// --skip=<id,...> reads "not run", never pass. The verdict is GO only when every step passed;
// --cloud makes it a rehearsal at best, because cloud perf and the cloud export do not count.
// Output: artifacts/local/alpha-rc/<stamp>/ with RC.md, rc.json and one log per step.
// Exit 0 GO, 1 any step failed, 2 nothing failed but a step did not run (or a cloud rehearsal).
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const node = process.execPath;
export const MENU_READY = "SCRAPKEEP_MENU_READY";
export const LAUNCH_BUDGET_S = 5;
const STEP_TIMEOUT_MS = 90 * 60_000;
const TAIL_LINES = 12;

export const STEP_IDS = ["placeholders", "smoke", "bots", "export", "frametime", "redteam", "launch"];

export function parseArgs(argv, env = process.env) {
  const args = {
    cloud: false,
    capture: null,
    redteam: null,
    carryFrom: null,
    appimage: path.join(env.HOME ?? os.homedir(), ".local/share/scrapkeep/Scrapkeep.AppImage"),
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

// The criterion each step proves, in the playbook's words.
export function buildPlan(args) {
  const script = (file, ...rest) => ({ command: node, args: [path.join(root, "scripts", file), ...rest] });
  const plan = [
    { id: "placeholders", label: "Placeholder gate", criterion: "zero placeholders", ...script("placeholder-gate.mjs", "--json") },
    { id: "smoke", label: "Smoke tests", criterion: "no open blocker", ...script("sketch-smoke.mjs", "--sketch", "core-loop") },
    { id: "bots", label: "Bot runs", criterion: "every world can be won", ...script("sketch-smoke.mjs", "--sketch", "core-loop", "--bots") },
    args.cloud
      ? { id: "export", label: "Export proofs (cloud, no boss smoke)", criterion: "the shipped pack wins", ...script("cloud/export-headless.mjs", "--win-proof") }
      : { id: "export", label: "Export proofs", criterion: "the shipped pack wins", ...script("sketch-export.mjs", "--win-proof") },
    {
      id: "frametime",
      label: "Frame time",
      criterion: "frame times in budget",
      ...script("frametime-check.mjs", `--log=${args.capture}`),
      needs: args.capture ? (existsSync(args.capture) ? null : `capture ${args.capture} not found`) : "no --capture=<MangoHud csv> given",
    },
    {
      id: "redteam",
      label: "Red team carry",
      criterion: "no open blocker",
      inline: "redteam",
      needs: args.redteam ? (existsSync(args.redteam) ? null : `findings ${args.redteam} not found`) : "no --redteam=<findings.json> given",
    },
    {
      id: "launch",
      label: "AppImage cold launch",
      criterion: "opens from the app menu",
      inline: "launch",
      needs: existsSync(args.appimage) ? null : `no AppImage at ${args.appimage}`,
    },
  ];
  for (const step of plan) if (args.skip.has(step.id)) step.needs = "skipped with --skip";
  return plan;
}

const tail = (text, n = TAIL_LINES) => text.trimEnd().split("\n").slice(-n).join("\n");

// Interprets each sub-command's exit in its own terms; a tool that says "nothing measured" is not run.
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
  if (exit === 0) return { status: "pass", note: "exit 0" };
  return { status: "fail", note: exit === null ? "timed out or killed" : `exit ${exit}` };
}

// A carried finding counts as replayed when this pass has a carry- run on its pilot and seed
// (scripts/redteam/lib.mjs planWave names replays "carry-<i>-<job id>").
export function judgeRedteam(findings, head, previous = null) {
  const blockers = (findings.findings ?? []).filter((f) => f.severity === "blocker");
  const majors = (findings.findings ?? []).filter((f) => f.severity === "major").length;
  if (head && findings.commit && !head.startsWith(findings.commit) && !findings.commit.startsWith(head))
    return { status: "not run", note: `findings are for ${findings.commit.slice(0, 8)}, candidate is ${head.slice(0, 8)}` };
  const replayed = new Set((findings.runs ?? []).filter((r) => String(r.id).startsWith("carry-")).map((r) => `${r.pilot}:${r.seed}`));
  const unreplayed = (previous?.carry ?? []).filter((c) => !replayed.has(`${c.pilot}:${c.seed}`));
  if (blockers.length) return { status: "fail", note: `${blockers.length} blocker(s): ${blockers.map((b) => b.title).join("; ")}` };
  if (unreplayed.length) return { status: "fail", note: `${unreplayed.length} carried finding(s) not replayed` };
  const carried = previous ? `, ${previous.carry?.length ?? 0} carried replayed` : ", no --carry-from given";
  return { status: "pass", note: `0 blockers, ${majors} major(s), wave ${findings.wave ?? "?"}${carried}` };
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

// Cold launch: a fresh profile, no Godot on PATH needed, and the menu-ready line inside the budget.
export function launchAppImage(appimage, { seconds = LAUNCH_BUDGET_S, env = process.env, spawnFn = spawn } = {}) {
  const profile = freshProfile();
  return new Promise((resolve) => {
    const started = Date.now();
    let output = "";
    let settled = false;
    // Its own process group, so the stop below reaches the game the AppImage runtime starts.
    const child = spawnFn(appimage, [], { env: { ...env, ...profile.env }, stdio: ["ignore", "pipe", "pipe"], detached: true });
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        process.kill(-child.pid, "SIGTERM");
      } catch {}
      child.stdout?.destroy();
      child.stderr?.destroy();
      rmSync(profile.home, { recursive: true, force: true });
      resolve({ ...result, output, ms: Date.now() - started });
    };
    const onData = (chunk) => {
      output += chunk;
      if (output.includes(MENU_READY)) {
        const ms = Date.now() - started;
        finish({ status: "pass", note: `main menu in ${(ms / 1000).toFixed(1)} s on a fresh profile` });
      }
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

export function runProcess(step, timeoutMs = STEP_TIMEOUT_MS) {
  return new Promise((resolve) => {
    let output = "";
    const child = spawn(step.command, step.args, { cwd: root, stdio: ["ignore", "pipe", "pipe"] });
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.stdout.on("data", (c) => (output += c));
    child.stderr.on("data", (c) => (output += c));
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ exit: null, output, error: error.message });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ exit: code, output });
    });
  });
}

export function verdict(results, { cloud = false } = {}) {
  if (results.some((r) => r.status === "fail")) return { verdict: "NO-GO", exit: 1 };
  if (results.some((r) => r.status === "not run")) return { verdict: "INCOMPLETE", exit: 2 };
  if (cloud) return { verdict: "REHEARSAL PASSED", exit: 2 };
  return { verdict: "GO", exit: 0 };
}

const MARK = { pass: "✅ pass", fail: "❌ fail", "not run": "⬜ not run" };

export function renderPage({ head, startedAt, cloud, results, outcome }) {
  const lines = [
    `# Release candidate: ${outcome.verdict}`,
    "",
    `Commit \`${head ?? "unknown"}\` · started ${startedAt}${cloud ? " · cloud rehearsal (perf and export do not count)" : ""}`,
    "",
    "| Check | Proves | Result | Detail | Time |",
    "| --- | --- | --- | --- | --- |",
    ...results.map((r) => `| ${r.label} | ${r.criterion} | ${MARK[r.status]} | ${r.note.replaceAll("|", "\\|")} | ${r.ms == null ? "" : `${Math.round(r.ms / 1000)} s`} |`),
    "",
    "A check that did not run is never a pass. Automated play does not stand in for Andrew's sitting.",
  ];
  for (const r of results.filter((x) => x.status === "fail" && x.tail)) lines.push("", `## ${r.label}: last lines`, "", "```", r.tail, "```");
  return lines.join("\n") + "\n";
}

export async function runAlphaRc(args, { run = runProcess, launch = launchAppImage, head = null, log = console.log, outDir } = {}) {
  const startedAt = new Date().toISOString();
  const results = [];
  if (outDir) mkdirSync(outDir, { recursive: true });
  for (const step of buildPlan(args)) {
    const base = { id: step.id, label: step.label, criterion: step.criterion };
    let result;
    if (step.needs) result = { ...base, status: "not run", note: step.needs, ms: null };
    else {
      log(`alpha:rc ▶ ${step.label}`);
      const started = Date.now();
      if (step.inline === "redteam") {
        try {
          const findings = JSON.parse(readFileSync(args.redteam, "utf8"));
          const previous = args.carryFrom ? JSON.parse(readFileSync(args.carryFrom, "utf8")) : null;
          result = { ...base, ...judgeRedteam(findings, head, previous), ms: Date.now() - started };
        } catch (error) {
          result = { ...base, status: "fail", note: `unreadable findings: ${error.message}`, ms: Date.now() - started };
        }
      } else if (step.inline === "launch") {
        const launched = await launch(args.appimage, { seconds: args.launchSeconds });
        result = { ...base, status: launched.status, note: launched.note, ms: launched.ms, output: launched.output };
      } else {
        const ran = await run(step);
        result = { ...base, ...judgeCommand(step, ran), ms: Date.now() - started, output: ran.output };
      }
      if (outDir && result.output != null) writeFileSync(path.join(outDir, `${step.id}.log`), result.output);
      if (result.status === "fail" && result.output) result.tail = tail(result.output);
      delete result.output;
    }
    log(`alpha:rc ${MARK[result.status]} ${step.label}: ${result.note}`);
    results.push(result);
  }
  const outcome = verdict(results, args);
  const page = renderPage({ head, startedAt, cloud: args.cloud, results, outcome });
  if (outDir) {
    writeFileSync(path.join(outDir, "RC.md"), page);
    writeFileSync(path.join(outDir, "rc.json"), JSON.stringify({ head, startedAt, cloud: args.cloud, verdict: outcome.verdict, results }, null, 2) + "\n");
  }
  return { results, outcome, page };
}

function gitHead() {
  try {
    const ref = readFileSync(path.join(root, ".git/HEAD"), "utf8").trim();
    if (!ref.startsWith("ref: ")) return ref;
    const refFile = path.join(root, ".git", ref.slice(5));
    if (existsSync(refFile)) return readFileSync(refFile, "utf8").trim();
    const packed = readFileSync(path.join(root, ".git/packed-refs"), "utf8");
    return packed.split("\n").find((l) => l.endsWith(" " + ref.slice(5)))?.split(" ")[0] ?? null;
  } catch {
    return null;
  }
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
  const { outcome, page } = await runAlphaRc(args, { head: gitHead(), outDir });
  console.log("\n" + page);
  console.log(`Page: ${path.join(outDir, "RC.md")}`);
  process.exitCode = outcome.exit;
}
