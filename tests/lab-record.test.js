import test from "node:test";
import assert from "node:assert/strict";
import {
  appendFile,
  chmod,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { SCHEMA, createRun, rebuildIndex } from "../scripts/lab/record.mjs";
import { asRoot } from "./preconditions.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// The registry is JL-02's; these fixtures stand in for it in the two shapes
// the writer accepts, a list of definitions and a Map keyed by id.
const definitions = [
  { id: "suite_pass", layer: "stability", kind: "kri" },
  { id: "suite_wall_s", layer: "stability", kind: "kpi" },
  { id: "flake_rate", layer: "stability", kind: "kri" },
];
const registry = definitions;

function git(repository, ...args) {
  const result = spawnSync(
    "git",
    [
      "-c",
      "user.name=Lab Test",
      "-c",
      "user.email=lab@example.invalid",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd: repository, encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

// Each case gets a throwaway git repository for provenance and a separate
// runs root outside it, so a run directory never makes the tree dirty and no
// case touches the real artifacts/local/runs.
async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-lab-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  const runs = path.join(temporary, "runs");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  await writeFile(path.join(repository, "notes.txt"), "not a source\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  return {
    repository,
    runs,
    start: (options = {}) =>
      createRun({
        type: "ball-lab",
        label: "smoke",
        registry,
        root: runs,
        repository,
        sources: ["src"],
        ...options,
      }),
  };
}

test("a run claims an exclusive directory and a second claim of it fails", async (t) => {
  const { runs, start } = await fixture(t);
  const now = new Date("2026-09-25T10:15:00.123Z");
  const run = await start({ now, uuid: "0123456789abcdef" });
  assert.equal(run.id, "20260925T101500Z-ball-lab-smoke-01234567");
  assert.equal(run.directory, path.join(runs, run.id));
  const owner = JSON.parse(
    await readFile(path.join(run.directory, "run-owner.json"), "utf8"),
  );
  assert.equal(owner.type, "ball-lab");
  assert.equal(owner.pid, process.pid);
  await assert.rejects(start({ now, uuid: "0123456789abcdef" }), {
    code: "EEXIST",
  });
  const fresh = await start({ now });
  assert.match(fresh.id, /^20260925T101500Z-ball-lab-smoke-[0-9a-f]{8}$/);
  assert.notEqual(fresh.id, run.id);
});

test("a type or label that is not a plain slug is refused before any claim", async (t) => {
  const { runs, start } = await fixture(t);
  await assert.rejects(start({ label: "../escape" }), /label/);
  await assert.rejects(start({ type: "Ball Lab" }), /type/);
  await assert.rejects(start({ registry: undefined }), /registry/);
  await assert.rejects(readdir(runs), { code: "ENOENT" });
});

test("run.json carries the scrapkeep-run/1 record with provenance", async (t) => {
  const { repository, start } = await fixture(t);
  const run = await start({
    config: { trials: 3, jobs: 2 },
    versions: { godot: "4.6.1.stable" },
    instrument: { questions_sha: "abc", model: "jev-1", gate_version: 1 },
  });
  run.kpi("suite_wall_s", { value: 41.5, n: 3, ci: null });
  run.kri("suite_pass", { value: 1, n: 3, ci: [0.44, 1] });
  run.finding({
    summary: "stuck against the east wall",
    repro: "npm run play -- ball-lab --seed 7",
  });
  run.limit("Automated play does not establish human feel.");
  run.jev({ model: "jev-1", usage: { input_tokens: 500, output_tokens: 12 } });
  run.jev({
    model: "jev-1",
    usage: {
      input_tokens: 40,
      output_tokens: 10,
      cache_read_input_tokens: 460,
      cache_creation_input_tokens: 0,
    },
  });
  run.jev({ model: "jev-1", cached: true });
  const record = await run.finish({ result: "pass" });
  const written = JSON.parse(
    await readFile(path.join(run.directory, "run.json"), "utf8"),
  );
  assert.deepEqual(written, record);
  assert.equal(record.schema, SCHEMA);
  assert.equal(SCHEMA, "scrapkeep-run/1");
  assert.equal(record.id, run.id);
  assert.equal(record.type, "ball-lab");
  assert.equal(record.label, "smoke");
  assert.equal(record.result, "pass");
  assert.equal(record.seq, 0);
  assert.ok(Date.parse(record.started_at) <= Date.parse(record.finished_at));
  const { provenance } = record;
  assert.equal(provenance.head, git(repository, "rev-parse", "HEAD"));
  assert.equal(provenance.branch, "lab");
  assert.equal(provenance.dirty, false);
  assert.equal("files" in provenance.sources, false);
  assert.equal(provenance.sources.start, provenance.sources.end);
  assert.equal(provenance.sources.matched, true);
  assert.deepEqual(provenance.sources.changed, []);
  const sidecar = JSON.parse(
    await readFile(path.join(run.directory, "sources.json"), "utf8"),
  );
  assert.deepEqual(Object.keys(sidecar.start), ["src/tuning.txt"]);
  assert.deepEqual(Object.keys(sidecar.end), ["src/tuning.txt"]);
  assert.deepEqual(provenance.versions, {
    node: process.version,
    godot: "4.6.1.stable",
  });
  assert.deepEqual(provenance.instrument, {
    questions_sha: "abc",
    model: "jev-1",
    gate_version: 1,
  });
  assert.deepEqual(provenance.jev, {
    model: "jev-1",
    calls: 2,
    cache_hits: 1,
    input_tokens: 540,
    output_tokens: 22,
    cache_read_input_tokens: 460,
    cache_creation_input_tokens: 0,
  });
  assert.deepEqual(record.config, { trials: 3, jobs: 2 });
  assert.deepEqual(record.kpis, {
    suite_wall_s: { value: 41.5, n: 3, ci: null },
  });
  assert.deepEqual(record.kris, {
    suite_pass: { value: 1, n: 3, ci: [0.44, 1] },
  });
  assert.deepEqual(record.findings, [
    {
      summary: "stuck against the east wall",
      repro: "npm run play -- ball-lab --seed 7",
    },
  ]);
  assert.deepEqual(record.limits, [
    "Automated play does not establish human feel.",
  ]);
  await assert.rejects(run.finish({ result: "pass" }), /finished/);
});

test("a dirty tree is recorded, and a source change during the run forces inconclusive", async (t) => {
  const { repository, start } = await fixture(t);
  await writeFile(path.join(repository, "notes.txt"), "edited\n");
  const run = await start();
  assert.equal(run.provenance.dirty, true);
  await appendFile(path.join(repository, "src/tuning.txt"), "speed = 5\n");
  await writeFile(path.join(repository, "src/new.txt"), "untracked source\n");
  const record = await run.finish({ result: "pass" });
  assert.equal(record.result, "inconclusive");
  assert.equal(record.provenance.sources.matched, false);
  assert.notEqual(
    record.provenance.sources.start,
    record.provenance.sources.end,
  );
  assert.deepEqual(record.provenance.sources.changed, [
    "src/new.txt",
    "src/tuning.txt",
  ]);
  assert.match(record.limits.at(-1), /2 source files changed.*pass/);
});

test("metric ids are checked against the injected registry", async (t) => {
  const { start } = await fixture(t);
  const run = await start({
    registry: new Map(definitions.map((one) => [one.id, one])),
  });
  assert.throws(() => run.kpi("not_a_metric", { value: 1, n: 1, ci: null }), {
    message: /unknown metric id "not_a_metric"/,
  });
  assert.throws(() => run.kri("lever_effect", { value: 1, n: 1, ci: null }), {
    message: /unknown metric id/,
  });
  assert.throws(() => run.kri("flake_rate", { value: 0.1, n: -1, ci: null }));
  assert.throws(() => run.kri("flake_rate", { value: "0.1", n: 3, ci: null }));
  assert.throws(() =>
    run.kri("flake_rate", { value: 0.1, n: 3, ci: [0.2, 0.1] }),
  );
  assert.throws(() => run.kri("flake_rate", { value: 0.1, n: 3 }));
  run.kri("flake_rate", { value: null, n: 0, ci: null });
  assert.throws(
    () => run.kri("flake_rate", { value: 0, n: 1, ci: null }),
    /already recorded/,
  );
  assert.throws(() => run.finding({ summary: "no way to reproduce" }), /repro/);
  run.jev({ model: "jev-1", cached: true });
  assert.throws(() => run.jev({ model: "jev-2", cached: true }), /model/);
  await assert.rejects(run.finish({ result: "great" }), /result/);
});

test("index.ndjson is append-only and rebuildIndex reproduces it byte for byte", async (t) => {
  const { runs, start } = await fixture(t);
  const index = path.join(runs, "index.ndjson");
  const first = await start({ label: "first" });
  await first.finish({ result: "pass" });
  const afterOne = await readFile(index, "utf8");
  assert.equal(afterOne.split("\n").length, 2);
  const line = JSON.parse(afterOne);
  assert.equal(line.id, first.id);
  assert.equal(line.seq, 0);

  const unfinished = await start({ label: "unfinished" });
  const batch = await Promise.all(
    ["a", "b", "c", "d"].map((label) => start({ label })),
  );
  await Promise.all(batch.map((run) => run.finish({ result: "fail" })));
  const afterFive = await readFile(index, "utf8");
  assert.ok(afterFive.startsWith(afterOne));
  assert.equal(afterFive.trimEnd().split("\n").length, 5);
  assert.deepEqual(
    afterFive
      .trimEnd()
      .split("\n")
      .map((one) => JSON.parse(one).seq),
    [0, 1, 2, 3, 4],
  );
  assert.ok(!afterFive.includes(unfinished.id));

  assert.equal(await rebuildIndex({ root: runs }), afterFive);
  await rm(index);
  assert.equal(await rebuildIndex({ root: runs, write: true }), afterFive);
  assert.equal(await readFile(index, "utf8"), afterFive);
  assert.deepEqual(
    (await readdir(runs)).filter((name) => name.includes("lock")),
    [],
  );
});

test("a run started after the index was deleted rebuilds it before appending", async (t) => {
  const { runs, start } = await fixture(t);
  const index = path.join(runs, "index.ndjson");
  await (await start({ label: "one" })).finish({ result: "pass" });
  await (await start({ label: "two" })).finish({ result: "pass" });
  await rm(index);
  const third = await start({ label: "three" });
  const record = await third.finish({ result: "pass" });
  assert.equal(record.seq, 2);
  assert.equal(
    await rebuildIndex({ root: runs }),
    await readFile(index, "utf8"),
  );
});

test("an injected uuid must look like a hex id", async (t) => {
  const { start } = await fixture(t);
  await assert.rejects(start({ uuid: "../../escape" }), /uuid/);
  await assert.rejects(start({ uuid: "short" }), /uuid/);
  const run = await start({ uuid: "0123456789abcdef" });
  assert.match(run.id, /0123456789abcdef$|01234567$/);
});

test("seq is max(seq)+1 of the parsed index, and a missing trailing newline is repaired before the append", async (t) => {
  const { runs, start } = await fixture(t);
  const index = path.join(runs, "index.ndjson");
  await (await start({ label: "one" })).finish({ result: "pass" });
  const original = await readFile(index, "utf8");
  assert.ok(original.endsWith("\n"));
  // Simulate a hand-edited index: seq bumped ahead and the trailing newline
  // dropped, as a killed writer or a manual edit could leave it.
  const corrupted = JSON.stringify({ ...JSON.parse(original), seq: 5 });
  await writeFile(index, corrupted);
  const record = await (
    await start({ label: "two" })
  ).finish({
    result: "pass",
  });
  assert.equal(record.seq, 6);
  const repaired = await readFile(index, "utf8");
  const lines = repaired
    .trimEnd()
    .split("\n")
    .map((one) => JSON.parse(one));
  assert.deepEqual(
    lines.map((one) => one.seq),
    [5, 6],
  );
  assert.ok(repaired.endsWith("\n"));
});

test("finished is set only after the locked write succeeds", { skip: asRoot }, async (t) => {
  const { start } = await fixture(t);
  const run = await start();
  await chmod(run.directory, 0o500);
  try {
    await assert.rejects(run.finish({ result: "pass" }), /EACCES|EPERM/);
  } finally {
    await chmod(run.directory, 0o700);
  }
  // The failed write never set `finished`, so a retry is a normal finish
  // rather than an "already finished" error.
  const record = await run.finish({ result: "pass" });
  assert.equal(record.result, "pass");
  await assert.rejects(run.finish({ result: "pass" }), /finished/);
});

test("a retry after a failed write records the source-mismatch limit once", { skip: asRoot }, async (t) => {
  const { repository, start } = await fixture(t);
  const run = await start();
  run.limit("caller limit");
  await appendFile(path.join(repository, "src/tuning.txt"), "speed = 5\n");
  await chmod(run.directory, 0o500);
  try {
    await assert.rejects(run.finish({ result: "pass" }), /EACCES|EPERM/);
  } finally {
    await chmod(run.directory, 0o700);
  }
  const record = await run.finish({ result: "pass" });
  assert.equal(record.result, "inconclusive");
  assert.equal(record.provenance.sources.reported_result, "pass");
  assert.equal(record.limits.length, 2, record.limits.join("\n"));
  assert.equal(record.limits[0], "caller limit");
  assert.match(
    record.limits[1],
    /1 source files changed.*"pass".*"inconclusive"/,
  );
  const onDisk = JSON.parse(
    await readFile(path.join(run.directory, "run.json"), "utf8"),
  );
  assert.deepEqual(onDisk.limits, record.limits);
});

test("a truncated final index line is dropped and repaired, not treated as a parse error", async (t) => {
  const { runs, start } = await fixture(t);
  const index = path.join(runs, "index.ndjson");
  await (await start({ label: "one" })).finish({ result: "pass" });
  await (await start({ label: "two" })).finish({ result: "pass" });
  const original = await readFile(index, "utf8");
  const lines = original.trimEnd().split("\n");
  assert.equal(lines.length, 2);
  // Simulate a process killed mid-write of the second entry: its line is cut
  // off partway through valid JSON, with no trailing newline. This is not a
  // complete-but-stale line (that case is covered above); it cannot parse.
  const truncated = `${lines[0]}\n${lines[1].slice(0, -6)}`;
  await writeFile(index, truncated);

  const record = await (
    await start({ label: "three" })
  ).finish({
    result: "pass",
  });
  assert.equal(record.seq, 1);
  const repaired = await readFile(index, "utf8");
  const repairedLines = repaired.trimEnd().split("\n");
  assert.equal(repairedLines[0], lines[0]);
  assert.deepEqual(
    repairedLines.map((one) => JSON.parse(one).seq),
    [0, 1],
  );
  assert.ok(repaired.endsWith("\n"));
});

test("finish() refuses a concurrent second call instead of racing it into a duplicate write", async (t) => {
  const { repository, start } = await fixture(t);
  const run = await start();
  // A source change during the run forces the mismatch limit line, so a
  // double execution would double it if the guard did not hold.
  await writeFile(path.join(repository, "src/new.txt"), "changed\n");

  const [first, second] = await Promise.allSettled([
    run.finish({ result: "pass" }),
    run.finish({ result: "pass" }),
  ]);
  const ok = [first, second].find((one) => one.status === "fulfilled");
  const bad = [first, second].find((one) => one.status === "rejected");
  assert.ok(ok, "exactly one concurrent call should succeed");
  assert.ok(bad, "exactly one concurrent call should be rejected");
  assert.match(bad.reason.message, /already (running|finished)/);
  assert.equal(ok.value.result, "inconclusive");
  assert.equal(
    ok.value.limits.filter((line) => line.includes("source files changed"))
      .length,
    1,
  );
  await assert.rejects(run.finish({ result: "pass" }), /already finished/);
});

test("rebuildIndex on a missing runs root returns an empty index", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-lab-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const missing = path.join(temporary, "never-created");
  assert.equal(await rebuildIndex({ root: missing }), "");
});

test("the record writer imports Node built-ins only", async () => {
  const source = await readFile(
    path.join(root, "scripts/lab/record.mjs"),
    "utf8",
  );
  const specifiers = [...source.matchAll(/^import[^"]*"([^"]+)";$/gm)].map(
    (match) => match[1],
  );
  assert.ok(specifiers.length > 0);
  for (const specifier of specifiers)
    assert.match(specifier, /^node:/, specifier);
});
