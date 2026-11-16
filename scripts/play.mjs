// One entry point for the Godot sketches: find them across every worktree,
// launch one, run its headless checks, or render its spawn view.
//
// The sketches under review live in sibling worktrees, not in this checkout,
// so discovery walks `git worktree list` rather than this repo's sketches/
// directory alone. Binary resolution is imported from sketch-smoke so the
// pinned 4.7.2 path is stated in exactly one place.
import { spawn, spawnSync } from "node:child_process";
import {
  accessSync,
  constants,
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  rmSync,
  watch as watchFs,
  writeFileSync,
} from "node:fs";
import { cpus, tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { binary, judge, sketchDirectories, testScripts } from "./sketch-smoke.mjs";
import { createRun } from "./lab/record.mjs";
import { METRICS } from "./lab/metrics/index.mjs";
import { EXIT } from "./lab/metrics/status.mjs";
import { wilson } from "./lab/stats.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tty = process.stdout.isTTY === true;

function paint(code, text) {
  if (tty) {
    return `\u001b[${code}m${text}\u001b[0m`;
  } else {
    return text;
  }
}

const dim = (text) => paint("2", text);
const bold = (text) => paint("1", text);
const green = (text) => paint("32", text);
const red = (text) => paint("31", text);
const cyan = (text) => paint("36", text);

export function worktrees(repoRoot) {
  const git = spawnSync(
    "git",
    ["-C", repoRoot, "worktree", "list", "--porcelain"],
    { encoding: "utf8" },
  );
  if (git.status !== 0) {
    return [{ path: repoRoot, branch: null, head: null }];
  } else {
    const list = [];
    let current = null;
    for (const line of git.stdout.split("\n")) {
      if (line.startsWith("worktree ")) {
        current = { path: line.slice(9).trim(), branch: null, head: null };
        list.push(current);
      } else if (line.startsWith("HEAD ") && current !== null) {
        current.head = line.slice(5).trim().slice(0, 7);
      } else if (line.startsWith("branch ") && current !== null) {
        current.branch = line.slice(7).trim().replace("refs/heads/", "");
      }
    }
    return list;
  }
}

// A worktree's primary sketch is the one named after it (spillway-drop holds
// spillway-drop), else the longest sketch name the tree's name contains
// (mobility-kit-v2 holds mobility-kit, scrapkeep-lab-cable-bench holds
// cable-bench), else its core-loop sketch, else its only sketch. Copies of ball-lab carried along for
// reference stay addressable but never win a bare name match.
export function pickPrimary(directories, treeName) {
  const named = directories.find((dir) => path.basename(dir) === treeName);
  const contained = directories
    .filter((dir) => treeName.includes(path.basename(dir)))
    .sort((a, b) => path.basename(b).length - path.basename(a).length);
  if (named !== undefined) {
    return named;
  } else if (contained.length > 0) {
    return contained[0];
  } else if (directories.some((dir) => path.basename(dir) === "core-loop")) {
    return directories.find((dir) => path.basename(dir) === "core-loop");
  } else if (directories.length === 1) {
    return directories[0];
  } else {
    const notBallLab = directories.filter(
      (dir) => path.basename(dir) !== "ball-lab",
    );
    if (notBallLab.length === 1) {
      return notBallLab[0];
    } else {
      return directories[0];
    }
  }
}

// The question a sketch README puts in bold on its first screen. It is the
// reason to play that one rather than another, so it belongs in the list.
function questionOf(directory) {
  const readme = path.join(directory, "README.md");
  if (!existsSync(readme)) {
    return "";
  } else {
    const text = readFileSync(readme, "utf8").slice(0, 2000);
    const asked = text.match(/\*\*([^*]{12,160}\?)\*\*/);
    if (asked !== null) {
      return asked[1].replace(/\s+/g, " ").trim();
    }
    // No bolded question: fall back to the README's opening sentence.
    const body = text.replace(/^#[^\n]*\n+/, "").split(/\n\s*\n/)[0] || "";
    const sentence = body.replace(/\s+/g, " ").trim().split(/\.\s/)[0];
    if (sentence.length > 10) {
      return sentence.slice(0, 150) + ".";
    } else {
      return "";
    }
  }
}

// Ids must not depend on which checkout asks: `git worktree list` names the
// main worktree first, and only its primary sketch goes by the bare name.
export function catalogue(repoRoot) {
  const entries = [];
  const trees = worktrees(repoRoot);
  const mainPath = trees[0].path;
  for (const tree of trees) {
    const directories = sketchDirectories(path.join(tree.path, "sketches"));
    const treeName = path.basename(tree.path);
    const primary = pickPrimary(directories, treeName);
    for (const directory of directories) {
      const sketch = path.basename(directory);
      const isPrimary = directory === primary;
      let id = `${treeName}/${sketch}`;
      if (isPrimary && tree.path === mainPath) {
        id = sketch;
      } else if (isPrimary) {
        id = treeName;
      }
      entries.push({
        id,
        directory,
        sketch,
        tree: treeName,
        branch: tree.branch,
        head: tree.head,
        primary: isPrimary,
        main: tree.path === mainPath,
        treePath: tree.path,
        question: questionOf(directory),
      });
    }
  }
  return entries.sort((a, b) => a.id.localeCompare(b.id));
}

// The worktree the command was typed in: the deepest one whose path holds the
// current directory, since linked worktrees may sit inside the main checkout.
export function currentTree(repoRoot, cwd) {
  let best = null;
  for (const tree of worktrees(repoRoot)) {
    const relative = path.relative(tree.path, cwd);
    const inside = relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
    if (inside && (best === null || tree.path.length > best.length)) {
      best = tree.path;
    }
  }
  return best;
}

// Typed names are short and human. An exact id wins, except that a bare
// sketch name typed inside another worktree means that worktree's sketch.
// A name that is exactly a sketch's directory name then resolves in the
// current worktree, else in the first one; prefixes and substrings are tried
// only when no sketch has that directory name anywhere.
export function resolve(entries, name, cwdTree = null) {
  const term = name.toLowerCase();
  const exact = entries.filter(
    (entry) => entry.id.toLowerCase() === term || `${entry.tree}/${entry.sketch}`.toLowerCase() === term,
  );
  const local = entries.filter(
    (entry) => entry.sketch.toLowerCase() === term && cwdTree !== null && entry.treePath === cwdTree,
  );
  if (exact.length === 1 && !(exact[0].sketch.toLowerCase() === term && local.length === 1)) {
    return { entry: exact[0] };
  }
  const named = entries.filter((entry) => entry.sketch.toLowerCase() === term);
  if (named.length > 0) {
    const inCurrent = named.filter((entry) => cwdTree !== null && entry.treePath === cwdTree);
    const inMain = named.filter((entry) => entry.main);
    if (inCurrent.length === 1) {
      return { entry: inCurrent[0] };
    } else if (inMain.length === 1) {
      return { entry: inMain[0] };
    } else if (named.length === 1) {
      return { entry: named[0] };
    } else {
      return { ambiguous: named };
    }
  }
  const rounds = [
    (entry) => entry.id.toLowerCase().startsWith(term),
    (entry) => entry.id.toLowerCase().includes(term),
    (entry) => entry.sketch.toLowerCase().includes(term),
  ];
  for (const matches of rounds) {
    const hits = entries.filter(matches);
    if (hits.length === 1) {
      return { entry: hits[0] };
    } else if (hits.length > 1) {
      const primaries = hits.filter((entry) => entry.primary);
      if (primaries.length === 1) {
        return { entry: primaries[0] };
      } else {
        return { ambiguous: hits };
      }
    }
  }
  return { ambiguous: [] };
}

// Each check is a separate Godot boot, most of it startup rather than the
// check itself, so wall clock is set by how many run at once rather than by
// the work; a retained `--jobs=1` run of sketches/ball-lab measured about
// 3.5 s per check (CONTRIBUTING's `play` / `scrapkeep` row has the run id
// and command). The checks share no state, so they fan out freely.
function runHeadless(label, args) {
  return new Promise((resolve) => {
    const child = spawn(binary, args);
    let output = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, 120_000);
    child.stdout.on("data", (chunk) => (output += chunk));
    child.stderr.on("data", (chunk) => (output += chunk));
    child.on("close", (status, signal) => {
      clearTimeout(timer);
      const verdict = judge({ test: args.includes("--script"), status, output });
      resolve({
        label,
        ok: verdict.ok,
        reason: verdict.reason,
        status,
        // Killed by a signal that was not our own timeout: the engine went
        // down rather than the check simply failing its assertions.
        crashed: signal !== null && !timedOut,
        output,
      });
    });
  });
}

async function inPool(jobs, limit, onDone) {
  const results = [];
  let next = 0;
  const width = Math.max(1, Math.min(limit, jobs.length));
  await Promise.all(
    Array.from({ length: width }, async () => {
      while (next < jobs.length) {
        const index = next++;
        results[index] = await jobs[index]();
        try {
          onDone?.(results[index]);
        } catch {
          // A broken reporter must not stop the pool; the checks still
          // running would outlive watch as orphaned Godot processes.
        }
      }
    }),
  );
  return results;
}

// A failure under concurrency can be intermittent, and an intermittent failure
// whose output scrolled away is not diagnosable. Every failing check keeps its
// full output on disk so the next flake can be read rather than guessed at.
const failureLog = path.join(root, "artifacts", "local", "sketch-tests");

function reportCheck(result) {
  if (result.ok) {
    console.log(`${green("PASS")} ${result.label}`);
  } else {
    console.log(`${red("FAIL")} ${result.label} exit=${result.status}${result.reason ? ` (${result.reason})` : ""}`);
    console.log(result.output.split("\n").slice(-40).join("\n"));
    try {
      mkdirSync(failureLog, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, "-");
      const slug = result.label.replace(/[^a-z0-9]+/gi, "-");
      const file = path.join(failureLog, `${stamp}-${slug}.log`);
      writeFileSync(file, result.output);
      console.log(dim(`     full output: ${file}`));
    } catch {
      // Never let evidence capture take down the run that produced it.
    }
  }
  return result.ok;
}

// Import must land before anything else opens the project, so it runs alone.
// The result list always carries every check that actually ran, so a caller
// building a run record never has to guess which ones were skipped.
// `order`, when given, resolves to a proposed run order for the checks after
// import; anything but a permutation of them leaves the current order.
// `stream` is watch's: each check is reported the moment it finishes and the
// first failure prints one RED line timed from `started`, while the rest keep
// running. Without it (`scrapkeep test`) every check is reported in list order
// once the pool is done, as before.
export async function testEntry(
  entry,
  limit,
  {
    order,
    stream = false,
    started = Date.now(),
    run = runHeadless,
    report = reportCheck,
    log = console.log,
  } = {},
) {
  const base = ["--headless", "--path", entry.directory];
  const importResult = await run(`${entry.id} import`, [...base, "--import"]);
  const results = [importResult];
  if (!report(importResult)) {
    return { ok: false, results };
  }
  const byName = new Map([
    ["boot", () => run(`${entry.id} boot`, [...base, "--quit-after", "300"])],
  ]);
  for (const script of testScripts(entry.directory)) {
    const name = script.replace("res://tests/", "");
    byName.set(name, () =>
      run(`${entry.id} ${name}`, [...base, "--script", script]),
    );
  }
  let names = [...byName.keys()];
  let used;
  if (order !== undefined) {
    used = await order;
    names = applyOrder(names, used.order);
  }
  const jobs = names.map((name) => byName.get(name));
  let ok = true;
  let firstFail;
  const onDone = stream
    ? (result) => {
        ok = result.ok && ok;
        const firstHere = !result.ok && firstFail === undefined;
        if (firstHere) {
          firstFail = (Date.now() - started) / 1000;
        }
        report(result);
        if (firstHere) {
          log(`${red("  RED")} ${result.label} after ${firstFail.toFixed(1)} s`);
        }
      }
    : undefined;
  for (const result of await inPool(jobs, limit, onDone)) {
    if (!stream) {
      ok = report(result) && ok;
    }
    results.push(result);
  }
  return { ok, results, first_fail_s: firstFail, order: used };
}

async function runSuite(targets, limit) {
  let ok = true;
  const results = [];
  for (const entry of targets) {
    const entryResult = await testEntry(entry, limit);
    ok = entryResult.ok && ok;
    results.push(...entryResult.results);
  }
  return { ok, results };
}

export function jobLimit(words) {
  const flag = words.find((word) => word.startsWith("--jobs="));
  if (flag !== undefined) {
    return Math.max(1, Number.parseInt(flag.slice(7), 10) || 1);
  } else {
    // Each Godot boot is mostly single-threaded startup, so the useful width is
    // near the core count; leave two cores for the editor and the compositor.
    return Math.max(2, Math.min(8, cpus().length - 2));
  }
}

export function repeatCount(words) {
  const flag = words.find((word) => word.startsWith("--repeat="));
  if (flag === undefined) {
    return 1;
  }
  return Math.max(1, Number.parseInt(flag.slice(9), 10) || 1);
}

// A slug fit for record.mjs's type/label fields: lowercase, alphanumeric
// runs joined by a single dash, never empty.
export function slugLabel(text) {
  const slug = String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug === "" ? "run" : slug;
}

// One row per check label across every repeat it ran on. A check the import
// failure skipped on some repeat contributes no outcome for that repeat
// rather than a fabricated one, so its row is simply shorter.
export function aggregateOutcomes(repeatResults) {
  const byLabel = new Map();
  for (const results of repeatResults) {
    for (const { label, ok } of results) {
      if (!byLabel.has(label)) {
        byLabel.set(label, []);
      }
      byLabel.get(label).push(ok ? "pass" : "fail");
    }
  }
  return byLabel;
}

// The fraction of checks whose outcome disagreed across the repeats it ran
// on; a rerun never turns a failure into a pass (metrics/core.mjs), so any
// disagreement at all counts as flake, not just fail-then-pass in that order.
// n stays the number of distinct checks, not the number of repeats, so a
// Wilson interval on it is a real proportion estimate (N1).
export function flakeRate(byLabel) {
  let disagreeing = 0;
  for (const outcomes of byLabel.values()) {
    if (new Set(outcomes).size > 1) {
      disagreeing += 1;
    }
  }
  const n = byLabel.size;
  if (n === 0) {
    return { value: null, n: 0, ci: null };
  }
  const { lower, upper } = wilson(disagreeing, n);
  return { value: disagreeing / n, n, ci: [lower, upper] };
}

// Pure aggregation from N repeats of runSuite's results into the measures a
// `scrapkeep-run/1` record needs: no filesystem or Godot access, so this is
// unit-testable with synthetic results.
export function buildTestMeasures({ repeatResults, repeatSeconds, repeatOks }) {
  const repeats = repeatResults.length;
  const totalSeconds = repeatSeconds.reduce((sum, s) => sum + s, 0);
  const flat = repeatResults.flat();
  const crashCount = flat.filter((r) => r.crashed).length;
  const measures = {
    suite_wall_s: { value: totalSeconds / repeats, n: repeats, ci: null },
    suite_pass: {
      value: repeatOks.filter((ok) => !ok).length,
      n: repeats,
      ci: null,
    },
    engine_crash: { value: crashCount, n: flat.length, ci: null },
  };
  const checks = [...aggregateOutcomes(repeatResults)].map(
    ([label, outcomes]) => ({ label, outcomes }),
  );
  const flake =
    repeats > 1 ? flakeRate(aggregateOutcomes(repeatResults)) : null;
  return { measures, checks, flake, totalSeconds };
}

// createRun() runs before the repeat loop, not after: a run's provenance
// (started_at, id, head/dirty, the start source digest) has to be sampled
// before the suite work, or JL-01's mid-run source-change guard can never
// fire, because "start" would already include whatever the suite changed.
// An orphaned run directory from a crash between createRun() and finish() is
// harmless; buildIndex already skips a directory with no run.json.
export async function runTestSuite({
  targets,
  limit,
  repeats,
  label,
  runOnce = () => runSuite(targets, limit),
  createRunOptions = {},
}) {
  const { config: initialConfig, ...restOptions } = createRunOptions;
  const config = { ...(initialConfig ?? {}) };
  const run = await createRun({
    type: "suite",
    label,
    registry: METRICS,
    config,
    ...restOptions,
  });
  const repeatResults = [];
  const repeatSeconds = [];
  const repeatOks = [];
  for (let i = 0; i < repeats; i++) {
    const started = Date.now();
    const { ok, results } = await runOnce();
    repeatSeconds.push((Date.now() - started) / 1000);
    repeatResults.push(results);
    repeatOks.push(ok);
  }
  const overallOk = repeatOks.every(Boolean);
  const { measures, checks, flake, totalSeconds } = buildTestMeasures({
    repeatResults,
    repeatSeconds,
    repeatOks,
  });
  // A median needs the individual repeat times, not just their mean (N2).
  config.checks = checks;
  config.repeat_seconds = repeatSeconds;
  run.kpi("suite_wall_s", measures.suite_wall_s);
  run.kri("suite_pass", measures.suite_pass);
  run.kri("engine_crash", measures.engine_crash);
  if (flake !== null) {
    run.kri("flake_rate", flake);
  }
  const record = await run.finish({ result: overallOk ? "pass" : "fail" });
  return { record, overallOk, totalSeconds };
}

// Resolves an executable by name against PATH without shelling out, so it is
// deterministic under test with an injected env.
export function findOnPath(name, env = process.env) {
  const dirs = (env.PATH || "").split(path.delimiter).filter(Boolean);
  for (const dir of dirs) {
    const candidate = path.join(dir, name);
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      continue;
    }
  }
  return null;
}

// Default output lives under artifacts/local/shots/, never /tmp (audit A8).
// A relative name is joined there; an absolute path is honoured so an
// explicit destination still works. The refusal checks the resolved path, so
// `..` segments and `//tmp` cannot bring /tmp or os.tmpdir() back in (NB3).
export function shotOutputPath(
  repoRoot,
  entry,
  requested,
  { tmpRoots = ["/tmp", tmpdir()] } = {},
) {
  const shotsDir = path.join(repoRoot, "artifacts", "local", "shots");
  const name = requested || `${entry.sketch}-spawn.png`;
  const out = path.resolve(shotsDir, name);
  for (const tmp of tmpRoots.map((one) => path.resolve(one))) {
    if (out === tmp || out.startsWith(tmp + path.sep)) {
      throw new Error(
        `shot output "${name}" resolves to ${out}, which may not be under ${tmp} (audit A8)`,
      );
    }
  }
  return { shotsDir, out };
}

// Only the file wait below had a limit, and it starts after the launch
// returns, so a hung headless Godot hung the command (NB1).
export const SHOT_TIMEOUT_MS = 60_000;

export function shotSpawnOptions({ timeoutMs = SHOT_TIMEOUT_MS } = {}) {
  return { stdio: "inherit", timeout: timeoutMs, killSignal: "SIGKILL" };
}

export function shotLaunchFailure(result, timeoutMs = SHOT_TIMEOUT_MS) {
  if (result.error?.code === "ETIMEDOUT") {
    return {
      code: 1,
      message: `the shot process did not exit within ${timeoutMs / 1000} s and was killed`,
    };
  } else if (result.error !== undefined && result.error !== null) {
    return {
      code: 1,
      message: `the shot process could not start: ${result.error.message}`,
    };
  } else if (result.status !== 0) {
    const how =
      result.status === null
        ? `was killed by ${result.signal}`
        : `exited with status ${result.status}`;
    return { code: result.status ?? 1, message: `the shot process ${how}` };
  }
  return null;
}

// claude-open (audit-fixed shot routing) only dispatches the launch through
// hyprctl and returns before the spawned Godot process writes anything, so a
// zero exit there proves the dispatch succeeded, not that the shot landed.
// Polling for the output file itself is the only way to know it's done; the
// headless fallback gets the same wait for the same reason (B2).
export async function waitUntil(
  check,
  {
    timeoutMs = 30_000,
    intervalMs = 250,
    now = Date.now,
    sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  } = {},
) {
  const deadline = now() + timeoutMs;
  for (;;) {
    if (await check()) {
      return true;
    }
    if (now() >= deadline) {
      return false;
    }
    await sleep(intervalMs);
  }
}

export async function waitForShot(out, options = {}) {
  const { exists = existsSync, ...rest } = options;
  return waitUntil(() => exists(out), rest);
}

// A sketch's own sources and tests are the only inputs to its checks, so a
// change under its directory is the whole trigger. Godot rewrites .uid and
// .import files during an import pass; watching those would retrigger forever.
const ignored = /(\.uid|\.import|\.godot\/|~$)/;

// The only order watch will run is a permutation of its checks, so no answer
// can drop, add or repeat one.
export function applyOrder(names, proposed) {
  if (!Array.isArray(proposed) || proposed.length !== names.length) {
    return names;
  }
  const offered = new Set(proposed);
  if (
    offered.size !== names.length ||
    !names.every((name) => offered.has(name))
  ) {
    return names;
  }
  return proposed;
}

function runChild(args, timeoutMs) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, args, {
      stdio: ["ignore", "pipe", "ignore"],
    });
    let stdout = "";
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.on("error", () => {
      clearTimeout(timer);
      resolve({ status: null, stdout });
    });
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stdout });
    });
  });
}

// JL-23: Jev's run order comes from scripts/lab/test-order.mjs in a child
// process, not an import, so no module on the gate path loads it. It runs
// alongside the import pass, and any failure means the current order.
const testOrderScript = path.join(root, "scripts", "lab", "test-order.mjs");

// Stated where the user sees it, once per session (JL-23 review B1).
export function orderingNote(checks, jobs) {
  if (checks <= jobs) {
    return `ordering: ${checks} checks, ${jobs} at a time; every check starts at once, so the order changes nothing here (it matters only when checks outnumber jobs)`;
  }
  return `ordering: ${checks} checks, ${jobs} at a time; the order decides which checks run first`;
}

export async function requestOrder(
  entry,
  names,
  saved,
  { run = runChild, timeoutMs = 12_000 } = {},
) {
  const args = [testOrderScript, "order", "--dir", entry.directory];
  for (const name of names) {
    args.push("--check", name);
  }
  if (saved !== undefined) {
    args.push("--changed", saved);
  }
  try {
    const { status, stdout } = await run(args, timeoutMs);
    if (status !== 0) {
      return { order: names, source: "current", reason: `exit ${status}` };
    }
    const reply = JSON.parse(stdout.trim().split("\n").at(-1));
    const order = applyOrder(names, reply.order);
    if (order === names || reply.source !== "jev") {
      return {
        order: names,
        source: "current",
        reason: reply.reason ?? "not a permutation",
      };
    }
    return { order, source: "jev", gap: reply.order_gap?.max };
  } catch (error) {
    return { order: names, source: "current", reason: error.name };
  }
}

// Asking Jev costs a call and can change nothing when every check starts at
// once, so the order is requested only for a save whose checks outnumber jobs.
export function orderFor(entry, names, saved, limit, { request = requestOrder } = {}) {
  if (saved === undefined || names.length <= limit) {
    return undefined;
  }
  return request(entry, names, saved);
}

async function watch(targets, limit) {
  const roots = targets.map((entry) => entry.directory);
  console.log(bold("\n  watching " + targets.map((e) => e.id).join(", ")));
  console.log(dim("  saves rerun that sketch's checks. Ctrl-C to stop."));
  for (const entry of targets) {
    const checks = 1 + testScripts(entry.directory).length;
    console.log(dim(`  ${entry.id} ${orderingNote(checks, limit)}`));
  }
  console.log("");

  let running = false;
  let queued = null;

  async function fire(entry, reason, saved) {
    if (running) {
      queued = { entry, saved };
      return;
    }
    running = true;
    const started = Date.now();
    console.log(`\n${cyan("→")} ${bold(entry.id)} ${dim(reason)}`);
    // The first run has no save to judge, so it keeps the current order.
    const names = [
      "boot",
      ...testScripts(entry.directory).map((s) => s.replace("res://tests/", "")),
    ];
    const order = orderFor(entry, names, saved, limit);
    const result = await testEntry(entry, limit, {
      order,
      stream: true,
      started,
    });
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    if (result.ok) {
      console.log(`${green("  GREEN")} ${entry.id} ${dim(seconds + "s")}`);
    } else {
      console.log(`${red("  RED")} ${entry.id} ${dim(seconds + "s")}`);
    }
    // A failed import never waited for the order, and neither does this.
    const used = result.order;
    if (used !== undefined) {
      const note =
        used.source === "jev"
          ? `jev, forward/reverse gap ${used.gap?.toFixed(2)}`
          : `current (${used.reason})`;
      console.log(dim(`  order: ${note}`));
    }
    running = false;
    if (queued !== null) {
      const next = queued;
      queued = null;
      await fire(next.entry, "queued while running", next.saved);
    }
  }

  for (const entry of targets) {
    let debounce = null;
    watchFs(entry.directory, { recursive: true }, (_event, file) => {
      if (file === null || ignored.test(file)) {
        return;
      }
      clearTimeout(debounce);
      debounce = setTimeout(() => fire(entry, "changed " + file, file), 180);
    });
  }
  // Nothing has changed yet, so show the current colour before waiting.
  for (const entry of targets) {
    await fire(entry, "first run");
  }
  await new Promise(() => {});
}

function showList(entries, all) {
  // Reference copies of ball-lab ride along in every stage worktree. They are
  // addressable but they are not the thing to play, so the bare list hides them.
  let shown = entries;
  if (!all) {
    shown = entries.filter((entry) => entry.primary);
  }
  if (shown.length === 0) {
    console.log("No sketches found. Is a worktree missing?");
    return;
  }
  console.log(bold("\n  Scrapkeep sketches\n"));
  const width = Math.max(...shown.map((entry) => entry.id.length));
  for (const entry of shown) {
    const where =
      entry.branch === null
        ? dim("detached")
        : dim(`${entry.branch}@${entry.head}`);
    console.log(`  ${bold(entry.id.padEnd(width))}  ${where}`);
    if (entry.question !== "") {
      let line = entry.question;
      if (line.length > 92) {
        line = line.slice(0, 89) + "...";
      }
      console.log(`  ${" ".repeat(width)}  ${dim(line)}`);
    }
  }
  const hidden = entries.length - shown.length;
  if (hidden > 0) {
    console.log(
      dim(`\n  ${hidden} reference copy(s) hidden; list --all shows them.`),
    );
  }
  console.log(
    dim("\n  play <name> | test [name] | shot <name> [out.png] | list"),
  );
  console.log(
    dim(
      "  stats [--layer <layer>] | gate <run> --against <pin> | lab run | lab watch <scenario>",
    ),
  );
  console.log(dim("  Names match on any unambiguous prefix: play mobility"));
  console.log(
    dim("\n  Headless checks prove the systems run. Feel needs your play.\n"),
  );
}

function reportAmbiguity(name, hits, entries = []) {
  if (hits.length === 0) {
    const known = entries.filter((entry) => entry.primary).slice(0, 6);
    console.error(
      `No sketch matches "${name}". Run with no arguments to list them.`,
    );
    for (const entry of known) {
      console.error(`  ${entry.id}`);
    }
  } else {
    const term = name.toLowerCase();
    const here = currentTree(root, process.cwd());
    const isExact = (entry) => entry.id.toLowerCase() === term || entry.sketch.toLowerCase() === term;
    const nearness = (entry) => {
      if (here !== null && entry.treePath === here) {
        return 0;
      } else if (entry.main) {
        return 1;
      } else {
        return 2;
      }
    };
    const byNearness = (a, b) => nearness(a) - nearness(b);
    const ranked = [
      ...hits.filter(isExact).sort(byNearness),
      ...hits.filter((entry) => !isExact(entry)).sort(byNearness),
    ];
    console.error(`"${name}" matches more than one sketch:`);
    for (const entry of ranked.slice(0, 6)) {
      console.error(`  ${entry.id}`);
    }
    if (ranked.length > 6) {
      console.error(`  ...and ${ranked.length - 6} more`);
    }
    console.error(`Most likely: scrapkeep ${ranked[0].id}`);
  }
  process.exit(2);
}

function requireEntry(entries, name) {
  if (name === undefined) {
    console.error("Name a sketch. Run with no arguments to list them.");
    process.exit(2);
  }
  const found = resolve(entries, name, currentTree(root, process.cwd()));
  if (found.entry !== undefined) {
    return found.entry;
  } else {
    reportAmbiguity(name, found.ambiguous, entries);
  }
}

const labScripts = path.join(root, "scripts", "lab");
const LAB_VERBS = {
  stats: "stats-cli.mjs",
  gate: "gate.mjs",
  dash: "dash.mjs",
};
const LAB_SUBVERBS = {
  run: "harness.mjs",
  program: "program.mjs",
  verdicts: "verdicts.mjs",
  watch: "watch.mjs",
};

// The lab verbs need no Godot and no sketch catalogue, so they are routed
// before either is looked up. Arguments after the verb pass through as-is.
export function labRoute(words, { exists = existsSync } = {}) {
  const [verb, ...rest] = words;
  let file;
  let args = rest;
  if (Object.hasOwn(LAB_VERBS, verb)) {
    file = LAB_VERBS[verb];
  } else if (verb === "lab") {
    const [sub, ...subArgs] = rest;
    if (!Object.hasOwn(LAB_SUBVERBS, sub)) {
      return {
        exit: EXIT.usage,
        error: `Usage: scrapkeep lab run|program|verdicts|watch [args]${sub === undefined ? "" : ` (not "${sub}")`}`,
      };
    }
    file = LAB_SUBVERBS[sub];
    args = subArgs;
  } else {
    return null;
  }
  const script = path.join(labScripts, file);
  if (!exists(script)) {
    return {
      exit: EXIT.usage,
      error: `scripts/lab/${file} is not built yet on this checkout.`,
    };
  }
  return { script, args };
}

function runLab(route) {
  if (route.error !== undefined) {
    console.error(route.error);
    process.exit(route.exit);
  }
  const result = spawnSync(process.execPath, [route.script, ...route.args], {
    stdio: "inherit",
  });
  if (result.status === null) {
    // A lab script that could not finish measured nothing; exit 1 would read
    // as a red KRI, so this reports an invalid instrument as gate.mjs does.
    console.error(
      `${path.basename(route.script)} did not finish: ${result.error?.message ?? result.signal}`,
    );
    process.exit(EXIT.invalid);
  }
  process.exit(result.status);
}

async function main(argv) {
  const routed = labRoute(argv);
  if (routed !== null) {
    runLab(routed);
    return;
  }
  const passthrough = argv.indexOf("--");
  const afterDashes = passthrough === -1 ? [] : argv.slice(passthrough + 1);
  const words = passthrough === -1 ? argv : argv.slice(0, passthrough);
  const entries = catalogue(root);

  let command = words[0];
  let name = words[1];
  let launchWords = words.slice(2);
  // A bare name is the common case: `scrapkeep mobility` should just play it.
  const verbs = ["play", "test", "watch", "shot", "list", "help"];
  if (command !== undefined && command.startsWith("--")) {
    command = "list";
  } else if (command !== undefined && !verbs.includes(command)) {
    name = command;
    command = "play";
    launchWords = words.slice(1);
  }
  if (command === undefined) {
    command = "list";
  }

  if (!existsSync(binary)) {
    console.error(`Godot binary not found at ${binary}; set GODOT_BIN.`);
    process.exit(2);
  }

  if (command === "list" || command === "help") {
    showList(entries, words.includes("--all"));
    return;
  } else if (command === "play") {
    const entry = requireEntry(entries, name);
    console.log(`${cyan("▶")} ${bold(entry.id)} ${dim(entry.directory)}`);
    // Each sketch owns its own keys (core-loop's Esc opens a pause menu), so
    // the launcher states only what holds for every sketch.
    console.log(dim("  Controls are in the game; closing its window quits.\n"));
    // `scrapkeep core-loop --table=slice` is the documented form, so words
    // after the name reach Godot just as those after `--` do.
    const extra = [...launchWords, ...afterDashes];
    const result = spawnSync(binary, ["--path", entry.directory, ...extra], {
      stdio: "inherit",
    });
    process.exit(result.status === null ? 1 : result.status);
  } else if (command === "test" || command === "watch") {
    let targets = entries;
    // A leading `--jobs=`/`--repeat=` flag with no sketch name leaves `name`
    // holding that flag string, so only a non-flag `name` names a target.
    let targetName;
    if (name !== undefined && !name.startsWith("--")) {
      targets = [requireEntry(entries, name)];
      targetName = name;
    }
    const limit = jobLimit(words);
    if (command === "test") {
      const repeats = repeatCount(words);
      const sketches = targets.map((entry) => ({
        id: entry.id,
        tree: entry.tree,
        head: entry.head,
      }));
      const { record, overallOk, totalSeconds } = await runTestSuite({
        targets,
        limit,
        repeats,
        label: slugLabel(targetName ?? "all"),
        createRunOptions: {
          config: {
            target: targetName ?? "all",
            jobs: limit,
            repeat: repeats,
            sketches,
          },
        },
      });
      const verdict = overallOk ? green("pass") : red("fail");
      const repeatNote = repeats > 1 ? `, ${repeats} repeats` : "";
      console.log(
        `\nsketch tests ${verdict} in ${totalSeconds.toFixed(1)}s across ${targets.length} sketch(es), ${limit} at a time${repeatNote}.`,
      );
      console.log(dim("Headless boot and tests only; feel needs your play."));
      console.log(dim(`  run record: ${record.id}`));

      process.exit(overallOk ? 0 : 1);
    } else {
      await watch(targets, limit);
      return;
    }
  } else if (command === "shot") {
    const entry = requireEntry(entries, name);
    const tool = path.join(entry.directory, "tools", "shot.gd");
    if (!existsSync(tool)) {
      console.error(`${entry.id} has no tools/shot.gd.`);
      process.exit(2);
    } else {
      let paths;
      try {
        paths = shotOutputPath(root, entry, words[2]);
      } catch (error) {
        console.error(error.message);
        process.exit(2);
        return;
      }
      const { shotsDir, out } = paths;
      mkdirSync(shotsDir, { recursive: true });
      // A leftover file from a previous attempt would make a failed shot
      // look saved, since the wait below only checks that the path exists.
      rmSync(out, { force: true });
      const scriptArgs = [
        "--path",
        entry.directory,
        "--script",
        "res://tools/shot.gd",
        "--",
        out,
        ...afterDashes,
      ];
      const opener = findOnPath("claude-open");
      let result;
      if (opener !== null) {
        console.log(
          dim(
            "shot.gd needs a real window; opened via claude-open on workspace 10.\n",
          ),
        );
        result = spawnSync(opener, [binary, ...scriptArgs], shotSpawnOptions());
      } else {
        console.log(
          dim("claude-open not found on PATH; running headless instead.\n"),
        );
        result = spawnSync(
          binary,
          ["--headless", ...scriptArgs],
          shotSpawnOptions(),
        );
      }
      const failure = shotLaunchFailure(result);
      if (failure !== null) {
        console.error(failure.message);
        process.exit(failure.code);
        return;
      }
      // claude-open dispatches and returns before Godot writes the file, so
      // the exit code above only proves the launch was dispatched (B2).
      const saved = await waitForShot(out);
      if (saved) {
        console.log(`${green("saved")} ${out}`);
      } else {
        console.error(`shot.gd did not write ${out} within the timeout.`);
        process.exit(1);
      }
    }
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url))
  main(process.argv.slice(2));
