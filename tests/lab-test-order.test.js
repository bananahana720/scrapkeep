import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  QUESTIONS_SHA,
  buildQuestions,
  buildState,
  firstFailRank,
  orderTests,
  referencesOf,
  scoreCases,
  scoreFiles,
  simulatedFirstFail,
  sketchInput,
  staticOrder,
} from "../scripts/lab/test-order.mjs";
import { applyOrder, requestOrder } from "../scripts/play.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const TESTS = [
  { id: "boot", refs: ["main.tscn"] },
  { id: "camera_test.gd", refs: ["src/lab.gd"] },
  { id: "jev_io_test.gd", refs: ["src/jev/jev_io.gd"] },
  { id: "slope_test.gd", refs: ["src/lab.gd", "src/field.gd"] },
];
const IDS = TESTS.map((t) => t.id);
const DIFF = [
  "diff --git a/src/jev/jev_io.gd b/src/jev/jev_io.gd",
  "--- a/src/jev/jev_io.gd",
  "+++ b/src/jev/jev_io.gd",
  "@@ -10,3 +10,3 @@",
  "-\treturn seq + 1",
  "+\treturn seq",
].join("\n");
const INPUT = { diff: DIFF, changed: ["src/jev/jev_io.gd"], tests: TESTS };

// Answers every question from a table keyed by test id; `skew` adds to the
// reverse block only, so an order gap is visible.
function replyFor(request, table, { skew = 0, model = "jev-test" } = {}) {
  const layout = buildQuestions(TESTS);
  assert.deepEqual(Object.keys(request.questions), [...layout.forward, ...layout.reverse]);
  const answers = {};
  layout.forward.forEach((key, i) => {
    answers[key] = { type: "noul", noul: table[layout.tests[i]] };
  });
  layout.reverse.forEach((key, i) => {
    const id = layout.tests[layout.tests.length - 1 - i];
    answers[key] = { type: "noul", noul: Math.min(1, table[id] + skew) };
  });
  return { model, usage: { input_tokens: 900, output_tokens: 40 }, answers };
}

const TABLE = { boot: 0.3, "camera_test.gd": 0.1, "jev_io_test.gd": 0.9, "slope_test.gd": 0.1 };

async function scratch() {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-test-order-"));
  return {
    dir,
    cacheDir: path.join(dir, "cache"),
    logFile: path.join(dir, "jev-calls.tsv"),
    done: () => rm(dir, { recursive: true, force: true }),
  };
}

test.beforeEach(() => {
  globalThis.__realFetch ??= globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("tests must never reach the network");
  };
});
test.afterEach(() => {
  globalThis.fetch = globalThis.__realFetch;
});

test("one Noul per test, asked in a forward block and then a reverse block", () => {
  const layout = buildQuestions(TESTS);
  assert.equal(layout.forward.length, TESTS.length);
  assert.equal(layout.reverse.length, TESTS.length);
  const keys = Object.keys(layout.questions);
  assert.deepEqual(keys, [...layout.forward, ...layout.reverse]);
  for (const [i, key] of layout.forward.entries()) {
    const mirror = layout.reverse[TESTS.length - 1 - i];
    assert.equal(layout.questions[key].type, "noul");
    assert.equal(layout.questions[key].instructions, layout.questions[mirror].instructions);
    assert.ok(layout.questions[key].instructions.includes(TESTS[i].id));
    for (const ref of TESTS[i].refs) {
      assert.ok(layout.questions[key].instructions.includes(ref));
    }
  }
  assert.match(QUESTIONS_SHA, /^[0-9a-f]{64}$/);
});

test("the order follows the averaged score, ties keep the current order, and the gap is reported", async () => {
  const s = await scratch();
  let seen = null;
  const result = await orderTests(INPUT, {
    call: async (request) => {
      seen = request;
      return replyFor(request, TABLE, { skew: 0.04 });
    },
    cacheDir: s.cacheDir,
    logFile: s.logFile,
  });
  assert.equal(result.source, "jev");
  assert.deepEqual(result.order, ["jev_io_test.gd", "boot", "camera_test.gd", "slope_test.gd"]);
  assert.ok(Math.abs(result.scores["jev_io_test.gd"].mean - 0.92) < 1e-9);
  assert.ok(Math.abs(result.order_gap.max - 0.04) < 1e-9);
  assert.ok(Math.abs(result.order_gap.mean - 0.04) < 1e-9);
  assert.deepEqual(Object.keys(seen.state).sort(), ["changed", "diff"]);
  assert.equal(result.model, "jev-test");
  assert.deepEqual(result.usage, { input_tokens: 900, output_tokens: 40 });
  await s.done();
});

test("every fallback keeps the current order and skips nothing", async () => {
  const s = await scratch();
  const deps = { cacheDir: s.cacheDir, logFile: s.logFile, timeoutMs: 50 };
  const cases = {
    "no key": { key: null },
    "call throws": { call: async () => { throw new Error("Jev 503"); } },
    timeout: { call: () => new Promise(() => {}) },
    "missing answer": {
      call: async (request) => {
        const reply = replyFor(request, TABLE);
        delete reply.answers[Object.keys(reply.answers)[0]];
        return reply;
      },
    },
    "out of range": {
      call: async (request) => {
        const reply = replyFor(request, TABLE);
        reply.answers[Object.keys(reply.answers)[1]].noul = 1.5;
        return reply;
      },
    },
    "wrong type": {
      call: async (request) => {
        const reply = replyFor(request, TABLE);
        reply.answers[Object.keys(reply.answers)[0]] = { type: "choice", choice: "yes" };
        return reply;
      },
    },
    "no model": {
      call: async (request) => ({ ...replyFor(request, TABLE), model: "" }),
    },
  };
  for (const [name, extra] of Object.entries(cases)) {
    const result = await orderTests(INPUT, { ...deps, ...extra });
    assert.equal(result.source, "rule", name);
    assert.deepEqual(result.order, IDS, name);
  }
  const empty = await orderTests(
    { ...INPUT, diff: "" },
    { ...deps, call: async () => assert.fail("an empty diff makes no call") },
  );
  assert.equal(empty.source, "rule");
  assert.deepEqual(empty.order, IDS);
  const garbage = await orderTests(null, { ...deps, call: async () => assert.fail("no call") });
  assert.equal(garbage.source, "rule");
  assert.deepEqual(garbage.order, []);
  assert.deepEqual(await readdir(s.cacheDir).catch(() => []), [], "a fallback is never cached");
  await s.done();
});

test("the diff is redacted before it is sent, hashed or cached, and the key never leaves", async () => {
  const s = await scratch();
  const key = "Zq8Vw3Lm9" + "Rt2Yp6Kd4OrderKey";
  const bearer = "Bearer " + "abcDEF123456" + "ghiJKL789012";
  const diff = `${DIFF}\n+# ${bearer}\n+# key ${key}\n+# at /home/someone/.config/x and ${root}/src/a.gd\n`;
  let sent = "";
  const result = await orderTests(
    { ...INPUT, diff },
    {
      call: async (request) => {
        sent = JSON.stringify(request);
        return replyFor(request, TABLE);
      },
      secrets: [key],
      cacheDir: s.cacheDir,
      logFile: s.logFile,
    },
  );
  assert.equal(result.source, "jev");
  for (const leaked of ["abcDEF123456ghiJKL789012", key, "/home/someone", root]) {
    assert.ok(!sent.includes(leaked), `sent ${leaked}`);
  }
  assert.ok(sent.includes("<repo>/src/a.gd"));
  const files = await readdir(s.cacheDir);
  assert.equal(files.length, 1);
  const cached = await readFile(path.join(s.cacheDir, files[0]), "utf8");
  assert.ok(!cached.includes("return seq"), "the cache holds answers, not the diff");
  const log = await readFile(s.logFile, "utf8");
  assert.ok(!log.includes("return seq") && !log.includes(key));
  await s.done();
});

test("a repeat save hits the cache and makes no call; the call log keeps token fields apart", async () => {
  const s = await scratch();
  let calls = 0;
  const deps = {
    call: async (request) => {
      calls += 1;
      return replyFor(request, TABLE);
    },
    cacheDir: s.cacheDir,
    logFile: s.logFile,
  };
  const first = await orderTests(INPUT, deps);
  const second = await orderTests(INPUT, deps);
  assert.equal(calls, 1);
  assert.equal(first.cached, false);
  assert.equal(second.cached, true);
  assert.deepEqual(second.order, first.order);
  const [header, row, ...rest] = (await readFile(s.logFile, "utf8")).trim().split("\n");
  assert.equal(rest.length, 0);
  const columns = header.split("\t");
  const cells = Object.fromEntries(row.split("\t").map((v, i) => [columns[i], v]));
  assert.equal(cells.hook, "test-order");
  assert.equal(cells.model, "jev-test");
  assert.equal(cells.input_tokens, "900");
  assert.equal(cells.output_tokens, "40");
  await s.done();
});

test("references come from GDScript preloads and JS relative imports", () => {
  const gd = [
    "extends SceneTree",
    'const Lab := preload("res://src/lab.gd")',
    'var io = load("res://src/jev/jev_io.gd")',
    'const Lab2 := preload("res://src/lab.gd")',
  ].join("\n");
  assert.deepEqual(referencesOf(gd, { kind: "gdscript" }), ["src/lab.gd", "src/jev/jev_io.gd"]);
  const js = [
    'import test from "node:test";',
    'import { a } from "../scripts/lab/stats.mjs";',
    'const m = await import("./fixtures/x.js");',
    'export { b } from "../scripts/play.mjs";',
  ].join("\n");
  assert.deepEqual(referencesOf(js, { kind: "js", file: "tests/x.test.js" }), [
    "scripts/lab/stats.mjs",
    "tests/fixtures/x.js",
    "scripts/play.mjs",
  ]);
});

test("the static baseline puts tests that load a changed file first, in current order", () => {
  assert.deepEqual(staticOrder(TESTS, ["src/lab.gd"]), [
    "camera_test.gd",
    "slope_test.gd",
    "boot",
    "jev_io_test.gd",
  ]);
  assert.deepEqual(staticOrder(TESTS, ["slope_test.gd"]), [
    "slope_test.gd",
    "boot",
    "camera_test.gd",
    "jev_io_test.gd",
  ]);
  assert.deepEqual(staticOrder(TESTS, []), IDS);
});

test("rank and simulated seconds to the first failing check", () => {
  const order = ["a", "b", "c", "d"];
  assert.equal(firstFailRank(order, ["c", "d"]), 3);
  assert.equal(firstFailRank(order, []), null);
  const durations = { a: 2, b: 3, c: 4, d: 1 };
  assert.equal(simulatedFirstFail(order, ["c"], durations, { jobs: 1, importS: 5 }), 14);
  // Two lanes: a runs 0-2, b 0-3, c starts at 2 and ends at 6.
  assert.equal(simulatedFirstFail(order, ["c"], durations, { jobs: 2, importS: 5 }), 11);
  assert.equal(simulatedFirstFail(order, ["d", "c"], durations, { jobs: 2, importS: 0 }), 4);
});

function scoredCase(id, extra = {}) {
  return {
    id,
    diff: DIFF,
    changed: ["src/jev/jev_io.gd"],
    tests: TESTS,
    failing: ["jev_io_test.gd"],
    durations: { boot: 3, "camera_test.gd": 4, "jev_io_test.gd": 2, "slope_test.gd": 5 },
    import_s: 6,
    ...extra,
  };
}

test("scoring compares Jev with the current and static orders; the control counts only Jev answers", () => {
  const cases = [
    scoredCase("c1", { control: { imports: "jev_io_test.gd", not: "camera_test.gd" } }),
    scoredCase("c2"),
  ];
  const jev = {
    c1: { source: "jev", order: ["jev_io_test.gd", "boot", "camera_test.gd", "slope_test.gd"] },
    c2: { source: "jev", order: ["boot", "jev_io_test.gd", "camera_test.gd", "slope_test.gd"] },
  };
  const summary = scoreCases(cases, jev);
  assert.equal(summary.cases, 2);
  assert.deepEqual(summary.mean_rank, { jev: 1.5, current: 3, static: 1 });
  assert.deepEqual(summary.jev_vs_current, { better: 2, same: 0, worse: 0 });
  assert.deepEqual(summary.jev_vs_static, { better: 0, same: 1, worse: 1 });
  assert.equal(summary.control.passed, true);
  const fallback = scoreCases(cases, { ...jev, c1: { source: "rule", order: IDS } });
  assert.equal(fallback.control.passed, false, "a fallback never passes the control");
  assert.deepEqual(fallback.control.failed, ["c1"]);
  const inverted = scoreCases(cases, {
    ...jev,
    c1: { source: "jev", order: ["camera_test.gd", "jev_io_test.gd", "boot", "slope_test.gd"] },
  });
  assert.equal(inverted.control.passed, false);
});

test("score mode caps live calls and retains the resolved model and token fields", async () => {
  const s = await scratch();
  const file = path.join(s.dir, "cases.json");
  await writeFile(
    file,
    JSON.stringify({ role: "check", cases: [scoredCase("a"), scoredCase("b", { diff: `${DIFF}\n+x` })] }),
  );
  const { report } = await scoreFiles([file], {
    out: path.join(s.dir, "out"),
    maxCalls: 1,
    cacheDir: s.cacheDir,
    logFile: s.logFile,
    key: "unused-key-for-test",
    live: async (request) => replyFor(request, TABLE, { model: "jev-9" }),
  });
  assert.equal(report.calls, 1);
  const set = report.sets["cases.json"];
  assert.equal(set.results.a.source, "jev");
  assert.equal(set.results.b.source, "rule", "the capped case falls back");
  assert.deepEqual(set.models, ["jev-9"]);
  assert.deepEqual(set.usage_totals, { input_tokens: 900, output_tokens: 40 });
  assert.ok(existsSync(path.join(s.dir, "out", "score.json")));
  await s.done();
});

test("a save's input is the uncommitted diff, new files whole, and each check's loads", async () => {
  const s = await scratch();
  const git = (...args) => {
    const r = spawnSync("git", args, {
      cwd: s.dir,
      encoding: "utf8",
      env: { ...process.env, GIT_AUTHOR_NAME: "t", GIT_AUTHOR_EMAIL: "t@localhost", GIT_COMMITTER_NAME: "t", GIT_COMMITTER_EMAIL: "t@localhost" },
    });
    assert.equal(r.status, 0, r.stderr);
  };
  await mkdir(path.join(s.dir, "src"), { recursive: true });
  await mkdir(path.join(s.dir, "tests"), { recursive: true });
  await writeFile(path.join(s.dir, "project.godot"), 'run/main_scene="res://main.tscn"\n');
  await writeFile(path.join(s.dir, "src/a.gd"), "func f():\n\treturn 1\n");
  await writeFile(path.join(s.dir, "tests/a_test.gd"), 'const A := preload("res://src/a.gd")\n');
  git("init", "-q");
  git("add", "-A");
  git("commit", "-q", "-m", "base");
  await writeFile(path.join(s.dir, "src/a.gd"), "func f():\n\treturn 2\n");
  await writeFile(path.join(s.dir, "tests/b_test.gd"), "extends SceneTree\n# new check\n");
  await writeFile(path.join(s.dir, "src/a.gd.uid"), "uid://x\n");
  const input = sketchInput(s.dir, ["boot", "a_test.gd", "b_test.gd"], "src/a.gd");
  assert.deepEqual(input.changed.sort(), ["src/a.gd", "tests/b_test.gd"]);
  assert.match(input.diff, /\+\treturn 2/);
  assert.match(input.diff, /\+# new check/);
  assert.deepEqual(input.tests, [
    { id: "boot", refs: ["main.tscn"] },
    { id: "a_test.gd", file: "tests/a_test.gd", refs: ["src/a.gd"] },
    { id: "b_test.gd", file: "tests/b_test.gd", refs: [] },
  ]);
  const staged = spawnSync("git", ["diff", "--cached", "--name-only"], { cwd: s.dir, encoding: "utf8" });
  assert.equal(staged.stdout, "", "the index is untouched");
  await s.done();
});

test("buildState clips a long diff and keeps the changed list", () => {
  const state = buildState({ diff: "x".repeat(50_000), changed: ["a.gd"] });
  assert.ok(state.diff.length < 10_000);
  assert.deepEqual(state.changed, ["a.gd"]);
});

test("watch accepts only a permutation of its checks, else keeps the current order", () => {
  const names = ["boot", "a.gd", "b.gd"];
  assert.deepEqual(applyOrder(names, ["b.gd", "boot", "a.gd"]), ["b.gd", "boot", "a.gd"]);
  for (const bad of [null, "boot", ["boot", "a.gd"], ["boot", "a.gd", "a.gd"], ["boot", "a.gd", "c.gd"], ["boot", "a.gd", "b.gd", "c.gd"]]) {
    assert.deepEqual(applyOrder(names, bad), names, JSON.stringify(bad));
  }
});

test("watch's order request falls back on a failed, silent or garbled child", async () => {
  const names = ["boot", "a.gd"];
  const run = (reply) => async () => reply;
  const ok = await requestOrder({ directory: "/x" }, names, "src/a.gd", {
    run: run({ status: 0, stdout: `${JSON.stringify({ order: ["a.gd", "boot"], source: "jev" })}\n` }),
  });
  assert.deepEqual(ok.order, ["a.gd", "boot"]);
  for (const reply of [
    { status: 1, stdout: "" },
    { status: 0, stdout: "not json" },
    { status: null, stdout: "" },
    { status: 0, stdout: JSON.stringify({ order: ["boot"] }) },
  ]) {
    const result = await requestOrder({ directory: "/x" }, names, "src/a.gd", { run: run(reply) });
    assert.deepEqual(result.order, names, JSON.stringify(reply));
    assert.equal(result.source, "current");
  }
  const thrown = await requestOrder({ directory: "/x" }, names, "src/a.gd", {
    run: async () => {
      throw new Error("spawn ENOENT");
    },
  });
  assert.deepEqual(thrown.order, names);
});

test("only watch asks for an order; the test verb never does", async () => {
  const source = await readFile(path.join(root, "scripts/play.mjs"), "utf8");
  const start = source.indexOf("async function watch(");
  const end = source.indexOf("\n}\n", start);
  assert.ok(start > 0 && end > start);
  const direct = [...source.matchAll(/(?<!function )\brequestOrder\(/g)];
  assert.deepEqual(direct, [], "requestOrder is reached only through orderFor");
  assert.match(source, /export function orderFor\([^)]*\{ request = requestOrder \}/);
  const calls = [...source.matchAll(/(?<!function )\borderFor\(/g)].map((m) => m.index);
  assert.ok(calls.length > 0);
  for (const index of calls) {
    assert.ok(index > start && index < end, "orderFor is called outside watch");
  }
});

// Follows static and dynamic relative import specifiers within the repo.
async function reachable(entry) {
  const seen = new Set();
  const pending = [path.join(root, entry)];
  const specifier =
    /(?:\bimport|\bexport)\s[^;]*?\bfrom\s*["']([^"']+)["']|\bimport\s*\(\s*["']([^"']+)["']\s*\)|\bimport\s+["']([^"']+)["']/g;
  while (pending.length > 0) {
    const file = pending.pop();
    if (seen.has(file)) continue;
    seen.add(file);
    const text = await readFile(file, "utf8");
    for (const match of text.matchAll(specifier)) {
      const target = match[1] ?? match[2] ?? match[3];
      if (!target.startsWith(".")) continue;
      const resolved = path.resolve(path.dirname(file), target);
      if (resolved.startsWith(root) && existsSync(resolved)) pending.push(resolved);
    }
  }
  return seen;
}

test("no import chain from the gate path reaches test-order", async () => {
  const target = path.join(root, "scripts/lab/test-order.mjs");
  for (const entry of [
    "scripts/verify.mjs",
    "scripts/play.mjs",
    "scripts/lab/gate.mjs",
    "scripts/lab/record.mjs",
    "scripts/lab/harness.mjs",
  ]) {
    assert.ok(!(await reachable(entry)).has(target), `${entry} reaches test-order.mjs`);
  }
  const fromPlay = await reachable("scripts/play.mjs");
  assert.ok(fromPlay.has(path.join(root, "scripts/lab/metrics/core.mjs")), "the walk goes transitive");
  assert.ok((await reachable("tests/lab-test-order.test.js")).has(target), "the walk would see it");
});

test("watch's order is the pre-registered score order; exact ties keep the current order", async () => {
  const s = await scratch();
  const table = { boot: 0.3, "camera_test.gd": 0.1, "jev_io_test.gd": 0.35, "slope_test.gd": 0.1 };
  const result = await orderTests(INPUT, {
    call: async (request) => replyFor(request, table),
    cacheDir: s.cacheDir,
    logFile: s.logFile,
  });
  assert.deepEqual(result.order, ["jev_io_test.gd", "boot", "camera_test.gd", "slope_test.gd"]);
  const test_order = await import("../scripts/lab/test-order.mjs");
  assert.equal(test_order.TIE_WIDTH, undefined, "the post-hoc tie-break is switched off");
  assert.equal(test_order.rankScores, undefined);
  await s.done();
});
