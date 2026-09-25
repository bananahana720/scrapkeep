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
  watch as watchFs,
  writeFileSync,
} from "node:fs";
import { cpus } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { binary, sketchDirectories, testScripts } from "./sketch-smoke.mjs";
import { createRun } from "./lab/record.mjs";
import { METRICS } from "./lab/metrics/index.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
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
// spillway-drop), else its only sketch (mobility-kit holds just its ball-lab).
// Copies of ball-lab carried along for reference stay addressable but never
// win a bare name match.
function pickPrimary(directories, treeName) {
  const named = directories.find((dir) => path.basename(dir) === treeName);
  if (named !== undefined) {
    return named;
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

export function catalogue(repoRoot) {
  const entries = [];
  const mainName = path.basename(repoRoot);
  for (const tree of worktrees(repoRoot)) {
    const directories = sketchDirectories(path.join(tree.path, "sketches"));
    const treeName = path.basename(tree.path);
    const primary = pickPrimary(directories, treeName);
    for (const directory of directories) {
      const sketch = path.basename(directory);
      const isPrimary = directory === primary;
      let id = `${treeName}/${sketch}`;
      if (isPrimary && treeName === mainName) {
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
        question: questionOf(directory),
      });
    }
  }
  return entries.sort((a, b) => a.id.localeCompare(b.id));
}

// Typed names are short and human: exact id, then a prefix, then a substring.
// A primary sketch outranks a reference copy, so "spillway" is the stage and
// not the ball lab sitting beside it.
export function resolve(entries, name) {
  const term = name.toLowerCase();
  const rounds = [
    (entry) => entry.id.toLowerCase() === term,
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

// Each check is a separate Godot boot costing about 7.7 s, nearly all of it
// startup, so wall clock is set by how many run at once rather than by the work.
// The checks share no state, so they fan out freely.
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
      resolve({
        label,
        ok: status === 0 && !errorLine.test(output),
        status,
        // Killed by a signal that was not our own timeout: the engine went
        // down rather than the check simply failing its assertions.
        crashed: signal !== null && !timedOut,
        output,
      });
    });
  });
}

async function inPool(jobs, limit) {
  const results = [];
  let next = 0;
  const width = Math.max(1, Math.min(limit, jobs.length));
  await Promise.all(
    Array.from({ length: width }, async () => {
      while (next < jobs.length) {
        const index = next++;
        results[index] = await jobs[index]();
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
    console.log(`${red("FAIL")} ${result.label} exit=${result.status}`);
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
async function testEntry(entry, limit) {
  const base = ["--headless", "--path", entry.directory];
  const importResult = await runHeadless(`${entry.id} import`, [
    ...base,
    "--import",
  ]);
  const results = [importResult];
  if (!reportCheck(importResult)) {
    return { ok: false, results };
  }
  const jobs = [
    () => runHeadless(`${entry.id} boot`, [...base, "--quit-after", "300"]),
  ];
  for (const script of testScripts(entry.directory)) {
    const name = script.replace("res://tests/", "");
    jobs.push(() =>
      runHeadless(`${entry.id} ${name}`, [...base, "--script", script]),
    );
  }
  let ok = true;
  for (const result of await inPool(jobs, limit)) {
    ok = reportCheck(result) && ok;
    results.push(result);
  }
  return { ok, results };
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
  if (flag === undefined) return 1;
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
      if (!byLabel.has(label)) byLabel.set(label, []);
      byLabel.get(label).push(ok ? "pass" : "fail");
    }
  }
  return byLabel;
}

// The fraction of checks whose outcome disagreed across the repeats it ran
// on; a rerun never turns a failure into a pass (metrics/core.mjs), so any
// disagreement at all counts as flake, not just fail-then-pass in that order.
export function flakeRate(byLabel) {
  let disagreeing = 0;
  for (const outcomes of byLabel.values()) {
    if (new Set(outcomes).size > 1) disagreeing += 1;
  }
  return {
    value: byLabel.size === 0 ? null : disagreeing / byLabel.size,
    n: byLabel.size,
    ci: null,
  };
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
  const flake = repeats > 1 ? flakeRate(aggregateOutcomes(repeatResults)) : null;
  return { measures, checks, flake, totalSeconds };
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
// A relative name is joined there; an absolute path is honoured as given so
// an explicit destination still works.
export function shotOutputPath(repoRoot, entry, requested) {
  const shotsDir = path.join(repoRoot, "artifacts", "local", "shots");
  if (requested !== undefined && path.isAbsolute(requested)) {
    return { shotsDir, out: requested };
  }
  const name = requested || `${entry.sketch}-spawn.png`;
  return { shotsDir, out: path.join(shotsDir, name) };
}

// A sketch's own sources and tests are the only inputs to its checks, so a
// change under its directory is the whole trigger. Godot rewrites .uid and
// .import files during an import pass; watching those would retrigger forever.
const ignored = /(\.uid|\.import|\.godot\/|~$)/;

async function watch(targets, limit) {
  const roots = targets.map((entry) => entry.directory);
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
    const { ok } = await testEntry(entry, limit);
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    if (ok) {
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
  console.log(dim("  Names match on any unambiguous prefix: play mobility"));
  console.log(
    dim("\n  Headless checks prove the systems run. Feel needs your play.\n"),
  );
}

function reportAmbiguity(name, hits) {
  if (hits.length === 0) {
    console.error(
      `No sketch matches "${name}". Run with no arguments to list them.`,
    );
  } else {
    console.error(`"${name}" matches more than one sketch:`);
    for (const entry of hits) {
      console.error(`  ${entry.id}`);
    }
  }
  process.exit(2);
}

function requireEntry(entries, name) {
  if (name === undefined) {
    console.error("Name a sketch. Run with no arguments to list them.");
    process.exit(2);
  }
  const found = resolve(entries, name);
  if (found.entry !== undefined) {
    return found.entry;
  } else {
    reportAmbiguity(name, found.ambiguous);
  }
}

async function main(argv) {
  const passthrough = argv.indexOf("--");
  const extra = passthrough === -1 ? [] : argv.slice(passthrough + 1);
  const words = passthrough === -1 ? argv : argv.slice(0, passthrough);
  const entries = catalogue(root);

  let command = words[0];
  let name = words[1];
  // A bare name is the common case: `scrapkeep mobility` should just play it.
  const verbs = ["play", "test", "watch", "shot", "list", "help"];
  if (command !== undefined && command.startsWith("--")) {
    command = "list";
  } else if (command !== undefined && !verbs.includes(command)) {
    name = command;
    command = "play";
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
    console.log(dim("  Esc frees the mouse, Esc again quits.\n"));
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
      const repeatResults = [];
      const repeatSeconds = [];
      const repeatOks = [];
      for (let i = 0; i < repeats; i++) {
        const started = Date.now();
        const { ok, results } = await runSuite(targets, limit);
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
      const verdict = overallOk ? green("pass") : red("fail");
      const repeatNote = repeats > 1 ? `, ${repeats} repeats` : "";
      console.log(
        `\nsketch tests ${verdict} in ${totalSeconds.toFixed(1)}s across ${targets.length} sketch(es), ${limit} at a time${repeatNote}.`,
      );
      console.log(dim("Headless boot and tests only; feel needs your play."));

      const run = await createRun({
        type: "suite",
        label: slugLabel(targetName ?? "all"),
        registry: METRICS,
        config: {
          target: targetName ?? "all",
          jobs: limit,
          repeat: repeats,
          checks,
        },
      });
      run.kpi("suite_wall_s", measures.suite_wall_s);
      run.kri("suite_pass", measures.suite_pass);
      run.kri("engine_crash", measures.engine_crash);
      if (flake !== null) run.kri("flake_rate", flake);
      const record = await run.finish({ result: overallOk ? "pass" : "fail" });
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
      const { shotsDir, out } = shotOutputPath(root, entry, words[2]);
      mkdirSync(shotsDir, { recursive: true });
      const scriptArgs = [
        "--path",
        entry.directory,
        "--script",
        "res://tools/shot.gd",
        "--",
        out,
        ...extra,
      ];
      const opener = findOnPath("claude-open");
      let result;
      if (opener !== null) {
        console.log(
          dim(
            "shot.gd needs a real window; opened via claude-open on workspace 10.\n",
          ),
        );
        result = spawnSync(opener, [binary, ...scriptArgs], {
          stdio: "inherit",
        });
      } else {
        console.log(
          dim("claude-open not found on PATH; running headless instead.\n"),
        );
        result = spawnSync(binary, ["--headless", ...scriptArgs], {
          stdio: "inherit",
        });
      }
      if (result.status === 0) {
        console.log(`${green("saved")} ${out}`);
      } else {
        process.exit(result.status === null ? 1 : result.status);
      }
    }
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url))
  main(process.argv.slice(2));
