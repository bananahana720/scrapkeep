import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  COVERED_FLOOR,
  buildEvidence,
  buildGraph,
  buildQuestions,
  buildState,
  classify,
  coverageGap,
  gitSnapshot,
  importEdges,
  memorySnapshot,
  overlaySnapshot,
  ruleArms,
  scoreCases,
  splitDiff,
  staticScan,
  testNames,
  workingSnapshot,
} from "../scripts/lab/coverage-gap.mjs";
import { getMetric } from "../scripts/lab/metrics/index.mjs";
import { STATUS, evaluate } from "../scripts/lab/metrics/status.mjs";
import { shallowClone } from "./preconditions.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// Built by concatenation so no scanner mistakes the fixture for a live secret.
const FAKE_KEY = "tsk" + "_live_" + "QWERTYUIOPASDFGH";
const FAKE_GHP = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8";

const REPO = {
  "package.json": "{}",
  "scripts/lab/alpha.mjs": 'import { beta } from "./beta.mjs";\nexport function alpha() { return beta() + 1; }\nexport function cli() { return 0; }\n',
  "scripts/lab/beta.mjs": 'import data from "./table.json" with { type: "json" };\nexport function beta() { return data.n; }\n',
  "scripts/lab/table.json": '{ "n": 1 }\n',
  "scripts/lab/corpus.json": '{ "cases": [] }\n',
  "scripts/lab/orphan.mjs": "export function orphan() { return 42; }\n",
  "scripts/lab/runner.mjs": 'import { alpha } from "./alpha.mjs";\nconsole.log(alpha());\n',
  "tests/alpha.test.js": [
    'import test from "node:test";',
    'import { readFile } from "node:fs/promises";',
    'import { alpha } from "../scripts/lab/alpha.mjs";',
    'test("alpha adds one to beta", () => { alpha(); });',
    'test("the corpus loads", async () => { await readFile("scripts/lab/corpus.json", "utf8"); });',
    "",
  ].join("\n"),
  "tests/fixtures/sample.json": "{}\n",
  "docs/notes.md": "# notes\n",
  "sketches/lab/project.godot": "[application]\n",
  "sketches/lab/main.tscn": '[ext_resource type="Script" path="res://src/lab.gd" id="1"]\n',
  "sketches/lab/src/lab.gd": 'extends Node3D\nconst Hud := preload("res://src/hud.gd")\nfunc step() -> void:\n\tpass\n',
  "sketches/lab/src/hud.gd": "extends CanvasLayer\nfunc show_speed(v: float) -> void:\n\tpass\n",
  "sketches/lab/src/hud.gd.uid": "uid://abc\n",
  "sketches/lab/tests/lab_test.gd": 'extends SceneTree\nconst Lab := preload("res://src/lab.gd")\nfunc _initialize() -> void:\n\t_check_step()\nfunc _check_step() -> void:\n\tpass\n',
  "tools/agent/policy.py": "def act():\n    return 1\n",
  "tools/agent/tests/test_policy.py": "import unittest\nfrom policy import act\nclass T(unittest.TestCase):\n    def test_act(self):\n        act()\n",
};

function change(file, added, { removed = [], header = "" } = {}) {
  return [
    `diff --git a/${file} b/${file}`,
    `--- a/${file}`,
    `+++ b/${file}`,
    `@@ -1,1 +1,${added.length} @@${header ? ` ${header}` : ""}`,
    ...removed.map((line) => `-${line}`),
    ...added.map((line) => `+${line}`),
    "",
  ].join("\n");
}

function noulReply(p, { model = "jev-test" } = {}) {
  return {
    model,
    usage: { input_tokens: 900, output_tokens: 4 },
    answers: { covered: { type: "noul", noul: p } },
  };
}

async function scratch() {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-coverage-gap-"));
  return {
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

test("import edges cover JS, GDScript, scenes and Python, and skip packages", () => {
  const files = new Set(Object.keys(REPO));
  assert.deepEqual(importEdges("scripts/lab/beta.mjs", REPO["scripts/lab/beta.mjs"], files), ["scripts/lab/table.json"]);
  assert.deepEqual(importEdges("tests/alpha.test.js", REPO["tests/alpha.test.js"], files), ["scripts/lab/alpha.mjs"]);
  assert.deepEqual(
    importEdges("x/a.mjs", 'export { y } from "./b.mjs";\nconst c = await import("./c.mjs");\nconst d = require("./d.js");\nimport "./e.mjs";', new Set(["x/b.mjs", "x/c.mjs", "x/d.js", "x/e.mjs"])),
    ["x/b.mjs", "x/c.mjs", "x/d.js", "x/e.mjs"],
  );
  assert.deepEqual(importEdges("sketches/lab/src/lab.gd", REPO["sketches/lab/src/lab.gd"], files), ["sketches/lab/src/hud.gd"]);
  assert.deepEqual(importEdges("sketches/lab/main.tscn", REPO["sketches/lab/main.tscn"], files), ["sketches/lab/src/lab.gd"]);
  assert.deepEqual(importEdges("tools/agent/tests/test_policy.py", REPO["tools/agent/tests/test_policy.py"], files), ["tools/agent/policy.py"]);
});

test("the static scan follows imports transitively and finds no chain to an orphan", () => {
  const snapshot = memorySnapshot(REPO);
  const graph = buildGraph(snapshot);
  assert.deepEqual(staticScan(graph, "scripts/lab/beta.mjs"), [
    { test: "tests/alpha.test.js", chain: ["tests/alpha.test.js", "scripts/lab/alpha.mjs", "scripts/lab/beta.mjs"] },
  ]);
  assert.deepEqual(staticScan(graph, "scripts/lab/table.json")[0].chain.length, 4);
  assert.deepEqual(staticScan(graph, "sketches/lab/src/hud.gd"), [
    { test: "sketches/lab/tests/lab_test.gd", chain: ["sketches/lab/tests/lab_test.gd", "sketches/lab/src/lab.gd", "sketches/lab/src/hud.gd"] },
  ]);
  assert.deepEqual(staticScan(graph, "tools/agent/policy.py")[0].test, "tools/agent/tests/test_policy.py");
  assert.deepEqual(staticScan(graph, "scripts/lab/orphan.mjs"), []);
  assert.deepEqual(staticScan(graph, "scripts/lab/runner.mjs"), [], "a script importing tested code is not itself tested");
  assert.deepEqual(staticScan(graph, "scripts/lab/corpus.json"), [], "a readFile path is not an import");
});

test("changed files are sorted into scope, test side, excluded and removed", () => {
  assert.equal(classify("scripts/lab/alpha.mjs"), "scope");
  assert.equal(classify("scripts/lab/corpus.json"), "scope");
  assert.equal(classify("docs/playtests/verdicts.ndjson"), "scope");
  assert.equal(classify("sketches/lab/src/hud.gd"), "scope");
  assert.equal(classify("tests/alpha.test.js"), "test");
  assert.equal(classify("tests/fixtures/sample.json"), "test");
  assert.equal(classify("sketches/lab/tests/lab_test.gd"), "test");
  assert.equal(classify("tools/agent/tests/test_policy.py"), "test");
  assert.equal(classify("docs/notes.md"), "excluded");
  assert.equal(classify("sketches/lab/src/hud.gd.uid"), "excluded");
  assert.equal(classify("artifacts/local/x.mjs"), "excluded");
  assert.equal(classify("package-lock.json"), "excluded");
});

test("a unified diff splits per file, with renames and deletions marked", () => {
  const text = [
    change("scripts/lab/alpha.mjs", ["export const x = 1;"]),
    "diff --git a/old.mjs b/new.mjs\nsimilarity index 90%\nrename from old.mjs\nrename to new.mjs\n--- a/old.mjs\n+++ b/new.mjs\n@@ -1 +1 @@\n-a\n+b\n",
    "diff --git a/gone.mjs b/gone.mjs\ndeleted file mode 100644\n--- a/gone.mjs\n+++ /dev/null\n@@ -1 +0,0 @@\n-a\n",
  ].join("");
  const parts = splitDiff(text);
  assert.deepEqual(parts.map((p) => [p.file, p.removed]), [["scripts/lab/alpha.mjs", false], ["new.mjs", false], ["gone.mjs", true]]);
  assert.match(parts[0].diff, /\+export const x = 1;/);
});

test("evidence names import chains, mentions, symbols, their uses and test names", () => {
  const snapshot = memorySnapshot(REPO);
  const graph = buildGraph(snapshot);
  const alpha = buildEvidence(snapshot, graph, {
    file: "scripts/lab/alpha.mjs",
    diff: change("scripts/lab/alpha.mjs", ["export function alpha() { return beta() + 2; }"]),
  });
  assert.deepEqual(alpha.importers.map((i) => i.test), ["tests/alpha.test.js"]);
  assert.ok(alpha.symbols.includes("alpha"));
  assert.ok(alpha.symbol_uses.some((use) => use.test === "tests/alpha.test.js" && use.lines.some((l) => /alpha\(\)/.test(l))));
  assert.ok(alpha.test_names.some((t) => t.names.includes("alpha adds one to beta")));

  const corpus = buildEvidence(snapshot, graph, {
    file: "scripts/lab/corpus.json",
    diff: change("scripts/lab/corpus.json", ['{ "cases": [1] }']),
  });
  assert.deepEqual(corpus.importers, []);
  assert.deepEqual(corpus.mentions.map((m) => [m.test, m.via]), [["tests/alpha.test.js", "tests/alpha.test.js"]]);

  const hud = buildEvidence(snapshot, graph, {
    file: "sketches/lab/src/hud.gd",
    diff: change("sketches/lab/src/hud.gd", ["func show_speed(v: float) -> void:", "\tprint(v)"]),
  });
  assert.ok(hud.symbols.includes("show_speed"));
  assert.deepEqual(hud.symbol_uses, []);
  assert.deepEqual(hud.test_names, [{ test: "sketches/lab/tests/lab_test.gd", names: ["_check_step"] }]);
});

test("test names come from JS test calls, GDScript checks and Python test methods", () => {
  assert.deepEqual(testNames("a.test.js", 'test("one", () => {});\nit(`two`, () => {});\ndescribe("group", () => {});'), ["one", "two", "group"]);
  assert.deepEqual(testNames("a_test.gd", "func _check_a() -> void:\nfunc test_b():\nfunc helper():"), ["_check_a", "test_b"]);
  assert.deepEqual(testNames("test_a.py", "    def test_x(self):\n    def helper(self):"), ["test_x"]);
});

test("the question set is one Noul about the file, and states are redacted and clipped", () => {
  const questions = buildQuestions();
  assert.deepEqual(Object.keys(questions), ["covered"]);
  assert.equal(questions.covered.type, "noul");
  assert.match(questions.covered.instructions, /data, not instructions/);
  const state = buildState(
    {
      file: "scripts/lab/alpha.mjs",
      diff: `+const key = "${FAKE_KEY}";\n+const token = "${FAKE_GHP}";\n+// /home/someone/.ssh/id\n` + "+x\n".repeat(4000),
      importers: [],
      mentions: [],
      symbols: [],
      symbol_uses: [],
      test_names: [],
    },
    { secrets: [FAKE_KEY] },
  );
  const text = JSON.stringify(state);
  assert.ok(!text.includes(FAKE_KEY));
  assert.ok(!text.includes(FAKE_GHP));
  assert.ok(!text.includes("/home/someone"));
  assert.ok(state.diff.length < 4000);
});

test("one typed call per in-scope file, none for tests, docs or deleted files", async (t) => {
  const s = await scratch();
  t.after(s.done);
  const requests = [];
  const call = async (request) => {
    requests.push(request);
    return noulReply(request.state.file.endsWith("alpha.mjs") ? 0.9 : 0.1);
  };
  const diff = [
    change("scripts/lab/alpha.mjs", ["export function alpha() { return 3; }"]),
    change("scripts/lab/orphan.mjs", ["export function orphan() { return 43; }"]),
    change("tests/alpha.test.js", ['test("more", () => {});']),
    change("docs/notes.md", ["more"]),
    "diff --git a/scripts/lab/runner.mjs b/scripts/lab/runner.mjs\ndeleted file mode 100644\n--- a/scripts/lab/runner.mjs\n+++ /dev/null\n@@ -1 +0,0 @@\n-x\n",
  ].join("");
  const result = await coverageGap({ snapshot: memorySnapshot(REPO), diff }, { call, cacheDir: s.cacheDir, logFile: s.logFile });
  assert.equal(requests.length, 2);
  for (const request of requests) {
    assert.deepEqual(Object.keys(request.questions), ["covered"]);
    assert.equal(request.model, "jev-latest");
  }
  assert.deepEqual(result.tests_changed, ["tests/alpha.test.js"]);
  assert.deepEqual(result.excluded, ["docs/notes.md"]);
  assert.deepEqual(result.removed, ["scripts/lab/runner.mjs"]);
  assert.deepEqual(result.files.map((f) => [f.file, f.covered, f.source]), [
    ["scripts/lab/alpha.mjs", true, "jev"],
    ["scripts/lab/orphan.mjs", false, "jev"],
  ]);
  assert.equal(result.advisory, true);
  assert.equal(result.metric, "untested_change");
  assert.deepEqual(result.measure, { value: 1, n: 2, ci: null });
  assert.deepEqual(result.flagged, ["scripts/lab/orphan.mjs"]);
  assert.equal(evaluate(getMetric("untested_change"), result.measure), STATUS.untiered, "advisory, no threshold");
});

test("a Noul below the floor is flagged, at or above it is covered", async (t) => {
  const s = await scratch();
  t.after(s.done);
  const diff = change("scripts/lab/alpha.mjs", ["export function alpha() { return 4; }"]);
  const at = await coverageGap({ snapshot: memorySnapshot(REPO), diff }, { call: async () => noulReply(COVERED_FLOOR), cacheDir: s.cacheDir + "a", logFile: s.logFile });
  const below = await coverageGap({ snapshot: memorySnapshot(REPO), diff }, { call: async () => noulReply(COVERED_FLOOR - 0.01), cacheDir: s.cacheDir + "b", logFile: s.logFile });
  assert.equal(at.files[0].covered, true);
  assert.equal(below.files[0].covered, false);
  assert.equal(below.files[0].p, COVERED_FLOOR - 0.01);
});

test("a verdict is cached, and the call log keeps model and token fields apart with no diff text", async (t) => {
  const s = await scratch();
  t.after(s.done);
  let calls = 0;
  const call = async () => {
    calls += 1;
    return noulReply(0.8, { model: "jev-7" });
  };
  const diff = change("scripts/lab/alpha.mjs", ["export function alpha() { return 5; }"]);
  const first = await coverageGap({ snapshot: memorySnapshot(REPO), diff }, { call, cacheDir: s.cacheDir, logFile: s.logFile });
  const second = await coverageGap({ snapshot: memorySnapshot(REPO), diff }, { call, cacheDir: s.cacheDir, logFile: s.logFile });
  assert.equal(calls, 1);
  assert.equal(first.files[0].cached, false);
  assert.equal(second.files[0].cached, true);
  assert.equal(second.files[0].model, "jev-7");
  const [header, row] = (await readFile(s.logFile, "utf8")).trim().split("\n").map((line) => line.split("\t"));
  const byColumn = Object.fromEntries(header.map((name, i) => [name, row[i]]));
  assert.equal(byColumn.hook, "coverage-gap");
  assert.equal(byColumn.model, "jev-7");
  assert.equal(byColumn.input_tokens, "900");
  assert.equal(byColumn.output_tokens, "4");
  assert.ok(!row.join(" ").includes("return 5"));
});

test("with no key, an error, a timeout or a malformed reply the static scan decides and nothing is cached", async (t) => {
  const s = await scratch();
  t.after(s.done);
  const diff = [
    change("scripts/lab/alpha.mjs", ["export function alpha() { return 6; }"]),
    change("scripts/lab/orphan.mjs", ["export function orphan() { return 6; }"]),
  ].join("");
  const snapshot = memorySnapshot(REPO);
  const expectStatic = (result, reason) => {
    assert.deepEqual(result.files.map((f) => [f.file, f.covered, f.source]), [
      ["scripts/lab/alpha.mjs", true, "static"],
      ["scripts/lab/orphan.mjs", false, "static"],
    ]);
    assert.match(result.files[0].reason, reason);
  };
  expectStatic(await coverageGap({ snapshot, diff }, { key: null, cacheDir: s.cacheDir, logFile: s.logFile }), /no TypeSafe key/);
  expectStatic(
    await coverageGap({ snapshot, diff }, { call: async () => { throw new Error("Jev 503"); }, cacheDir: s.cacheDir, logFile: s.logFile }),
    /Jev unavailable: Error Jev 503/,
  );
  expectStatic(
    await coverageGap({ snapshot, diff }, { call: () => new Promise(() => {}), timeoutMs: 20, cacheDir: s.cacheDir, logFile: s.logFile }),
    /TimeoutError/,
  );
  for (const bad of [noulReply(1.5), { ...noulReply(0.9), model: "" }, { model: "m", usage: {}, answers: { covered: { type: "choice" } } }]) {
    expectStatic(await coverageGap({ snapshot, diff }, { call: async () => bad, cacheDir: s.cacheDir, logFile: s.logFile }), /MalformedResponse/);
  }
  let calls = 0;
  await coverageGap({ snapshot, diff }, { call: async () => { calls += 1; return noulReply(0.9); }, cacheDir: s.cacheDir, logFile: s.logFile });
  assert.equal(calls, 2, "no failure left a cache entry");
});

test("the key and environment secrets never reach the caller", async (t) => {
  const s = await scratch();
  t.after(s.done);
  let seen = "";
  const diff = change("scripts/lab/alpha.mjs", [`export const k = "${FAKE_KEY}";`]);
  await coverageGap(
    { snapshot: memorySnapshot(REPO), diff },
    { call: async (request) => { seen = JSON.stringify(request); return noulReply(0.5); }, secrets: [FAKE_KEY], cacheDir: s.cacheDir, logFile: s.logFile },
  );
  assert.ok(seen.length > 0);
  assert.ok(!seen.includes(FAKE_KEY));
});

test("the redaction is triage's, imported rather than copied", async () => {
  const source = await readFile(path.join(root, "scripts/lab/coverage-gap.mjs"), "utf8");
  assert.match(source, /import \{[^}]*\bredact\b[^}]*\} from "\.\/triage\.mjs"/);
  assert.doesNotMatch(source, /function redact\b/);
  assert.doesNotMatch(source, /TOKEN_PATTERNS/);
});

test("the rule arms: static scan, and imports-with-a-symbol-use or a mention", () => {
  const snapshot = memorySnapshot(REPO);
  const graph = buildGraph(snapshot);
  const evidenceOf = (file, added) => buildEvidence(snapshot, graph, { file, diff: change(file, added) });
  assert.deepEqual(ruleArms(evidenceOf("scripts/lab/alpha.mjs", ["export function cli() { return 1; }"])), { static: true, mention_rule: false });
  assert.deepEqual(ruleArms(evidenceOf("scripts/lab/alpha.mjs", ["export function alpha() { return 1; }"])), { static: true, mention_rule: true });
  assert.deepEqual(ruleArms(evidenceOf("scripts/lab/corpus.json", ['{"cases":[2]}'])), { static: false, mention_rule: true });
  assert.deepEqual(ruleArms(evidenceOf("scripts/lab/orphan.mjs", ["export function orphan() { return 0; }"])), { static: false, mention_rule: false });
});

test("scoring weighs a false 'covered' as severe, and the control passes only from Jev", () => {
  const weights = { severe: 5, moderate: 2 };
  const cases = [
    { id: "orphan", accept: ["untested"], control: true },
    { id: "tested", accept: ["covered"] },
    { id: "hidden", accept: ["untested"] },
    { id: "either", accept: ["covered", "untested"] },
  ];
  const verdicts = {
    orphan: { covered: false, source: "jev" },
    tested: { covered: false, source: "jev" },
    hidden: { covered: true, source: "jev" },
    either: { covered: true, source: "jev" },
  };
  const score = scoreCases(cases, verdicts, weights);
  assert.deepEqual(score.severe_misses, ["hidden"]);
  assert.deepEqual(score.misses.map((m) => m.id), ["tested", "hidden"]);
  assert.equal(score.possible, 5 + 2 + 5 + 2);
  assert.equal(score.earned, 5 + 2);
  assert.equal(score.control.passed, true);
  const outage = scoreCases(cases, { ...verdicts, orphan: { covered: false, source: "static" } }, weights);
  assert.equal(outage.control.passed, false, "a fallback cannot pass the control");
  const staticArm = scoreCases(cases, verdicts, weights, { requireJev: false });
  assert.equal(staticArm.control.passed, true);
});

test("an overlay snapshot adds files on top of a base", () => {
  const snapshot = overlaySnapshot(memorySnapshot({ "a.mjs": "x" }), { "b.mjs": "y" });
  assert.deepEqual(snapshot.files.toSorted(), ["a.mjs", "b.mjs"]);
  assert.equal(snapshot.read("b.mjs"), "y");
  assert.equal(snapshot.read("a.mjs"), "x");
});

test("a git snapshot reads a commit's tree, and the real repo's static scan sees triage's test", { skip: shallowClone }, () => {
  const snapshot = gitSnapshot(root, "d8e67d08d0c63584c62d929508cf02422ceb0361");
  assert.ok(snapshot.files.includes("scripts/lab/triage.mjs"));
  assert.match(snapshot.read("scripts/lab/triage.mjs"), /export async function triage/);
  const graph = buildGraph(snapshot);
  assert.ok(staticScan(graph, "scripts/lab/triage.mjs").some((i) => i.test === "tests/lab-triage.test.js"));
  assert.ok(staticScan(graph, "sketches/ball-lab/src/jev/jev_io.gd").some((i) => i.test === "sketches/ball-lab/tests/jev_io_test.gd"));
});

test("no import chain from the gate path reaches coverage-gap", () => {
  const snapshot = workingSnapshot(root);
  const graph = buildGraph(snapshot);
  const target = "scripts/lab/coverage-gap.mjs";
  const gatePath = [
    "scripts/verify.mjs",
    "scripts/play.mjs",
    "scripts/lab/gate.mjs",
    "scripts/lab/record.mjs",
    "scripts/lab/harness.mjs",
    "scripts/sketch-smoke.mjs",
  ];
  const closure = (entry) => {
    const seen = new Set();
    const pending = [entry];
    while (pending.length > 0) {
      const file = pending.pop();
      if (seen.has(file)) continue;
      seen.add(file);
      pending.push(...(graph.get(file) ?? []));
    }
    return seen;
  };
  for (const entry of gatePath) {
    assert.ok(!closure(entry).has(target), `${entry} reaches coverage-gap.mjs`);
  }
  const fromPlay = closure("scripts/play.mjs");
  assert.ok(fromPlay.has("scripts/lab/record.mjs"), "the walk follows imports");
  assert.ok(fromPlay.has("scripts/lab/metrics/core.mjs"), "the walk goes transitive");
  const liveGraph = buildGraph(overlaySnapshot(snapshot, { "tests/lab-coverage-gap.test.js": 'import "../scripts/lab/coverage-gap.mjs";' }));
  assert.ok(liveGraph.get("tests/lab-coverage-gap.test.js").includes(target), "the walk would see coverage-gap if it were imported");
});
