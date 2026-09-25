// Labels JL-23 cases by execution: apply a mutation to a scratch copy, run the
// real checks, and record which failed and how long each took. No Jev call.
// usage: node label.mjs <mutations.json> <out-dir>
import { spawn, spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import path from "node:path";

import { referencesOf, sketchInput } from "../../../../../scripts/lab/test-order.mjs";
import { binary } from "../../../../../scripts/sketch-smoke.mjs";

const repo = path.resolve(import.meta.dirname, "../../../../..");
const work = path.join(import.meta.dirname, "..", "work");
const BASE = "d8e67d08d0c63584c62d929508cf02422ceb0361";
const errorLine = /^(SCRIPT ERROR|ERROR|FAIL)\b/m;
const gitEnv = { ...process.env, GIT_AUTHOR_NAME: "label", GIT_AUTHOR_EMAIL: "label@localhost", GIT_COMMITTER_NAME: "label", GIT_COMMITTER_EMAIL: "label@localhost" };

function sh(cmd, args, cwd) {
  const r = spawnSync(cmd, args, { cwd, encoding: "utf8", env: gitEnv, maxBuffer: 1 << 28 });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(" ")} failed: ${r.stderr}`);
  return r.stdout;
}

function timed(cmd, args, cwd) {
  return new Promise((resolve) => {
    const started = Date.now();
    const child = spawn(cmd, args, { cwd });
    let output = "";
    const timer = setTimeout(() => child.kill("SIGKILL"), 180_000);
    child.stdout.on("data", (c) => (output += c));
    child.stderr.on("data", (c) => (output += c));
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, output, seconds: (Date.now() - started) / 1000 });
    });
  });
}

async function pool(jobs, width) {
  const out = [];
  let next = 0;
  await Promise.all(Array.from({ length: width }, async () => {
    while (next < jobs.length) {
      const i = next++;
      out[i] = await jobs[i]();
    }
  }));
  return out;
}

function applyEdits(dir, edits) {
  for (const edit of edits) {
    const file = path.join(dir, edit.file);
    if (edit.create !== undefined) {
      mkdirSync(path.dirname(file), { recursive: true });
      writeFileSync(file, edit.create);
      continue;
    }
    const text = readFileSync(file, "utf8");
    const count = text.split(edit.find).length - 1;
    if (count !== 1) throw new Error(`${edit.file}: find occurs ${count} times`);
    writeFileSync(file, text.replace(edit.find, () => edit.replace));
  }
}

function commitBase(dir) {
  sh("git", ["init", "-q"], dir);
  sh("git", ["add", "-A"], dir);
  sh("git", ["commit", "-q", "-m", "base"], dir);
}

function pickControl(tests, changed, failing) {
  const touched = new Set(changed);
  const imports = (t) => touched.has(t.file ?? t.id) || t.refs.some((r) => touched.has(r));
  const x = tests.find((t) => failing.includes(t.id) && imports(t));
  const y = tests.find((t) => !failing.includes(t.id) && !imports(t));
  return x && y ? { imports: x.id, not: y.id } : undefined;
}

async function labelGodot(m) {
  const dir = path.join(work, "g", m.id);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(path.dirname(dir), { recursive: true });
  cpSync(path.join(repo, "sketches/ball-lab"), dir, { recursive: true, filter: (src) => !src.includes("/.godot") });
  commitBase(dir);
  applyEdits(dir, m.edits);
  const scripts = readdirSync(path.join(dir, "tests")).filter((n) => n.endsWith(".gd")).sort();
  const names = ["boot", ...scripts];
  const input = sketchInput(dir, names, m.saved);
  const base = ["--headless", "--path", dir];
  const imp = await timed(binary, [...base, "--import"], dir);
  const importOk = imp.status === 0 && !errorLine.test(imp.output);
  const runs = await pool(names.map((n) => () =>
    timed(binary, n === "boot" ? [...base, "--quit-after", "300"] : [...base, "--script", `res://tests/${n}`], dir)), 8);
  const failing = [];
  const durations = {};
  names.forEach((n, i) => {
    durations[n] = Number(runs[i].seconds.toFixed(2));
    if (!(runs[i].status === 0 && !errorLine.test(runs[i].output))) failing.push(n);
  });
  return { ...input, import_ok: importOk, import_s: Number(imp.seconds.toFixed(2)), failing, durations };
}

let nodeTree = null;
function ensureNodeTree() {
  if (nodeTree) return nodeTree;
  const dir = path.join(work, "n-tree");
  if (!existsSync(path.join(dir, ".git"))) {
    rmSync(dir, { recursive: true, force: true });
    mkdirSync(dir, { recursive: true });
    const tar = spawnSync("sh", ["-c", `git -C '${repo}' archive ${BASE} -- . ':!artifacts' ':!*.png' | tar -x -C '${dir}'`], { encoding: "utf8" });
    if (tar.status !== 0) throw new Error(tar.stderr);
    commitBase(dir);
    symlinkSync("/home/andrew/Projects/scrapkeep/node_modules", path.join(dir, "node_modules"));
  }
  nodeTree = dir;
  return dir;
}

async function labelNode(m) {
  const dir = ensureNodeTree();
  sh("git", ["checkout", "-q", "--", "."], dir);
  sh("git", ["clean", "-qfd", "-e", "node_modules"], dir);
  applyEdits(dir, m.edits);
  const list = (sub) => readdirSync(path.join(dir, sub)).filter((n) => n.endsWith(".test.js")).sort().map((n) => `${sub}/${n}`);
  const files = [...list("tests"), ...list("tools/jev-player/tests")];
  const tests = files.map((f) => ({ id: f, file: f, refs: referencesOf(readFileSync(path.join(dir, f), "utf8"), { kind: "js", file: f }) }));
  const changed = [...new Set([
    ...sh("git", ["diff", "HEAD", "--name-only"], dir).split("\n"),
    ...sh("git", ["ls-files", "--others", "--exclude-standard"], dir).split("\n"),
  ].filter(Boolean))];
  sh("git", ["add", "-N", "."], dir);
  const diff = sh("git", ["diff", "HEAD"], dir);
  sh("git", ["reset", "-q"], dir);
  const runs = await pool(files.map((f) => () => timed(process.execPath, ["--test", f], dir)), 8);
  const failing = [];
  const durations = {};
  files.forEach((f, i) => {
    durations[f] = Number(runs[i].seconds.toFixed(2));
    if (runs[i].status !== 0) failing.push(f);
  });
  sh("git", ["checkout", "-q", "--", "."], dir);
  sh("git", ["clean", "-qfd", "-e", "node_modules"], dir);
  return { diff, changed, tests, import_ok: true, import_s: 0, failing, durations };
}

const [specFile, outDir] = process.argv.slice(2);
const spec = JSON.parse(readFileSync(specFile, "utf8"));
mkdirSync(outDir, { recursive: true });
const labelled = [];
for (const m of spec.mutations) {
  const started = Date.now();
  const got = m.universe === "godot" ? await labelGodot(m) : await labelNode(m);
  const item = {
    id: m.id,
    set: m.set,
    universe: m.universe,
    source: m.source,
    description: m.description,
    ...got,
  };
  item.control = pickControl(item.tests, item.changed, item.failing);
  labelled.push(item);
  console.log(`${m.id} [${m.set}] ${m.universe}: import ${got.import_ok ? "ok" : "FAILED"}, failing ${JSON.stringify(got.failing)}, control ${JSON.stringify(item.control)} (${((Date.now() - started) / 1000).toFixed(0)} s)`);
  writeFileSync(path.join(outDir, "labelled.json"), `${JSON.stringify(labelled, null, 2)}\n`);
}
