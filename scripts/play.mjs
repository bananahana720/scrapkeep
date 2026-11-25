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
  const git = spawnSync("git", ["-C", repoRoot, "worktree", "list", "--porcelain"], {
    encoding: "utf8",
  });
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
    return directories[0];
  }
}

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
    const body = text.replace(/^#[^\n]*\n+/, "").split(/\n\s*\n/)[0] || "";
    const sentence = body.replace(/\s+/g, " ").trim().split(/\.\s/)[0];
    if (sentence.length > 10) {
      return sentence.slice(0, 150) + ".";
    } else {
      return "";
    }
  }
}

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

export function resolve(entries, name, cwdTree = null) {
  const term = name.toLowerCase();
  const exact = entries.filter(
    (entry) =>
      entry.id.toLowerCase() === term || `${entry.tree}/${entry.sketch}`.toLowerCase() === term,
  );
  const local = entries.filter(
    (entry) =>
      entry.sketch.toLowerCase() === term && cwdTree !== null && entry.treePath === cwdTree,
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

function runHeadless(label, args) {
  return new Promise((resolveRun) => {
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
      resolveRun({
        label,
        ok: verdict.ok,
        reason: verdict.reason,
        status,
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
        } catch {}
      }
    }),
  );
  return results;
}

const failureLog = path.join(root, "artifacts", "local", "sketch-tests");

function reportCheck(result) {
  if (result.ok) {
    console.log(`${green("PASS")} ${result.label}`);
  } else {
    console.log(
      `${red("FAIL")} ${result.label} exit=${result.status}${result.reason ? ` (${result.reason})` : ""}`,
    );
    console.log(result.output.split("\n").slice(-40).join("\n"));
    try {
      mkdirSync(failureLog, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, "-");
      const slug = result.label.replace(/[^a-z0-9]+/gi, "-");
      const file = path.join(failureLog, `${stamp}-${slug}.log`);
      writeFileSync(file, result.output);
      console.log(dim(`     full output: ${file}`));
    } catch {}
  }
  return result.ok;
}

export async function testEntry(
  entry,
  limit,
  {
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
    byName.set(name, () => run(`${entry.id} ${name}`, [...base, "--script", script]));
  }
  const jobs = [...byName.values()];
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
  return { ok, results, first_fail_s: firstFail };
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

export function slugLabel(text) {
  const slug = String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug === "" ? "run" : slug;
}

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

export async function runTestSuite({
  targets,
  limit,
  repeats,
  runOnce = () => runSuite(targets, limit),
}) {
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
  const totalSeconds = repeatSeconds.reduce((sum, s) => sum + s, 0);
  const checks = [...aggregateOutcomes(repeatResults)].map(([label, outcomes]) => ({
    label,
    outcomes,
  }));
  return { overallOk, totalSeconds, checks, repeatSeconds };
}

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

export function shotOutputPath(repoRoot, entry, requested, { tmpRoots = ["/tmp", tmpdir()] } = {}) {
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

export async function waitUntil(
  check,
  {
    timeoutMs = 30_000,
    intervalMs = 250,
    now = Date.now,
    sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms)),
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

const ignored = /(\.uid|\.import|\.godot\/|~$)/;

async function watch(targets, limit) {
  console.log(bold("\n  watching " + targets.map((e) => e.id).join(", ")));
  console.log(dim("  saves rerun that sketch's checks. Ctrl-C to stop.\n"));

  let running = false;
  let queued = null;

  async function fire(entry, reason) {
    if (running) {
      queued = entry;
      return;
    }
    running = true;
    const started = Date.now();
    console.log(`\n${cyan("→")} ${bold(entry.id)} ${dim(reason)}`);
    const result = await testEntry(entry, limit, { stream: true, started });
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    if (result.ok) {
      console.log(`${green("  GREEN")} ${entry.id} ${dim(seconds + "s")}`);
    } else {
      console.log(`${red("  RED")} ${entry.id} ${dim(seconds + "s")}`);
    }
    running = false;
    if (queued !== null) {
      const next = queued;
      queued = null;
      await fire(next, "queued while running");
    }
  }

  for (const entry of targets) {
    let debounce = null;
    watchFs(entry.directory, { recursive: true }, (_event, file) => {
      if (file === null || ignored.test(file)) {
        return;
      }
      clearTimeout(debounce);
      debounce = setTimeout(() => fire(entry, "changed " + file), 180);
    });
  }
  for (const entry of targets) {
    await fire(entry, "first run");
  }
  await new Promise(() => {});
}

function showList(entries, all) {
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
    const where = entry.branch === null ? dim("detached") : dim(`${entry.branch}@${entry.head}`);
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
    console.log(dim(`\n  ${hidden} secondary copy(s) hidden; list --all shows them.`));
  }
  console.log(dim("\n  play <name> | test [name] | watch [name] | shot <name> [out.png] | list"));
  console.log(dim("  Names match on any unambiguous prefix: play core-loop"));
  console.log(dim("\n  Headless checks prove the systems run. Feel needs your play.\n"));
}

function reportAmbiguity(name, hits, entries = []) {
  if (hits.length === 0) {
    const known = entries.filter((entry) => entry.primary).slice(0, 6);
    console.error(`No sketch matches "${name}". Run with no arguments to list them.`);
    for (const entry of known) {
      console.error(`  ${entry.id}`);
    }
  } else {
    const term = name.toLowerCase();
    const here = currentTree(root, process.cwd());
    const isExact = (entry) =>
      entry.id.toLowerCase() === term || entry.sketch.toLowerCase() === term;
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

async function main(argv) {
  const passthrough = argv.indexOf("--");
  const afterDashes = passthrough === -1 ? [] : argv.slice(passthrough + 1);
  const words = passthrough === -1 ? argv : argv.slice(0, passthrough);
  const entries = catalogue(root);

  let command = words[0];
  let name = words[1];
  let launchWords = words.slice(2);
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
    console.log(dim("  Controls are in the game; closing its window quits.\n"));
    const extra = [...launchWords, ...afterDashes];
    const result = spawnSync(binary, ["--path", entry.directory, ...extra], {
      stdio: "inherit",
    });
    process.exit(result.status === null ? 1 : result.status);
  } else if (command === "test" || command === "watch") {
    let targets = entries;
    if (name !== undefined && !name.startsWith("--")) {
      targets = [requireEntry(entries, name)];
    }
    const limit = jobLimit(words);
    if (command === "test") {
      const repeats = repeatCount(words);
      const { overallOk, totalSeconds } = await runTestSuite({
        targets,
        limit,
        repeats,
      });
      const verdict = overallOk ? green("pass") : red("fail");
      const repeatNote = repeats > 1 ? `, ${repeats} repeats` : "";
      console.log(
        `\nsketch tests ${verdict} in ${totalSeconds.toFixed(1)}s across ${targets.length} sketch(es), ${limit} at a time${repeatNote}.`,
      );
      console.log(dim("Headless boot and tests only; feel needs your play."));
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
        console.log(dim("shot.gd needs a real window; opened via claude-open on workspace 10.\n"));
        result = spawnSync(opener, [binary, ...scriptArgs], shotSpawnOptions());
      } else {
        console.log(dim("claude-open not found on PATH; running headless instead.\n"));
        result = spawnSync(binary, ["--headless", ...scriptArgs], shotSpawnOptions());
      }
      const failure = shotLaunchFailure(result);
      if (failure !== null) {
        console.error(failure.message);
        process.exit(failure.code);
        return;
      }
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
