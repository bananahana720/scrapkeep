import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  CAUSES,
  FLAKE_LIKE,
  buildQuestions,
  buildState,
  cacheKey,
  loadCorpus,
  redact,
  rerunAdvisory,
  ruleVerdict,
  scoreCases,
  triage,
} from "../scripts/lab/triage.mjs";
import { aggregateOutcomes, flakeRate } from "../scripts/play.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CORPUS = path.join(root, "scripts/lab/triage-corpus.json");

// Built by concatenation so no scanner mistakes the fixture for a live secret.
const FAKE = {
  bearer: "Bearer " + "abcDEF123456" + "ghiJKL789012mno",
  sk: "sk-" + "ant-api03-" + "Zx9Yw8Vu7Ts6Rq5Po4Nm3Lk2",
  ghp: "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8",
  jwt:
    "eyJ" + "hbGciOiJIUzI1NiJ9" + ".eyJ" + "zdWIiOiIxMjM0In0" + ".c2lnbmF0dXJlLXZhbHVl",
  envSecret: "tsk" + "_live_" + "QWERTYUIOPASDFGH",
};

function jevReply(cause, rerunP, { model = "jev-test", confidence = 0.8 } = {}) {
  const probabilities = Object.fromEntries(
    CAUSES.map((name) => [name, name === cause ? 0.8 : 0.05]),
  );
  return {
    model,
    usage: { input_tokens: 400, output_tokens: 10 },
    answers: {
      cause: { type: "choice", choice: cause, confidence, probabilities },
      rerun: { type: "noul", noul: rerunP },
    },
  };
}

async function scratch() {
  const dir = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-triage-"));
  return {
    dir,
    cacheDir: path.join(dir, "cache"),
    logFile: path.join(dir, "jev-calls.tsv"),
    done: () => rm(dir, { recursive: true, force: true }),
  };
}

const INPUT = {
  check: "tests/check-docs.test.js",
  log: "✖ a valid fixture passes\n  Error: Unknown system error -122, write\n",
  diff: "",
};

test.beforeEach(() => {
  globalThis.__realFetch ??= globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("tests must never reach the network");
  };
});
test.afterEach(() => {
  globalThis.fetch = globalThis.__realFetch;
});

test("redaction strips keys, tokens, bearer headers, one-time codes and emails", () => {
  const text = [
    `Authorization: ${FAKE.bearer}`,
    `using key ${FAKE.sk}`,
    `remote token ${FAKE.ghp}`,
    `session ${FAKE.jwt}`,
    "TYPESAFE_API_KEY=abc123def456ghi789",
    "api_key: 'hunter2hunter2'",
    "password=correct-horse",
    "Your verification code is 482913.",
    "OTP: 7730",
    "Co-Authored-By: Someone <someone@example.com>",
  ].join("\n");
  const out = redact(text, { secrets: [] });
  for (const leaked of [
    FAKE.bearer.slice(7),
    FAKE.sk,
    FAKE.ghp,
    FAKE.jwt,
    "abc123def456ghi789",
    "hunter2hunter2",
    "correct-horse",
    "482913",
    "7730",
    "someone@example.com",
  ]) {
    assert.ok(!out.includes(leaked), `leaked ${leaked}`);
  }
  assert.match(out, /Authorization: Bearer <redacted>/);
});

test("redaction keeps token counts, exit codes and test durations", () => {
  const text = [
    "cache_read_input_tokens: 6716243,",
    "output_tokens: 76726",
    "Error code: -122",
    "exit code is 1",
    "duration_ms 4405.176349",
  ].join("\n");
  assert.equal(redact(text, { secrets: [] }), text);
});

test("redaction removes known secret values from the environment verbatim", () => {
  const out = redact(`the key ${FAKE.envSecret} was echoed`, {
    secrets: [FAKE.envSecret],
  });
  assert.ok(!out.includes(FAKE.envSecret));
});

test("redaction keeps repo paths relative and strips other home paths", () => {
  const repoRoot = "/home/someone/Projects/scrapkeep-wt-JL-19";
  const text = [
    "at file:///home/someone/Projects/scrapkeep-wt-JL-19/tests/a.test.js:4:1",
    "copyfile '/home/someone/Projects/scrapkeep-wt-JL-07/tests/fixtures/x.md'",
    "main checkout /home/someone/Projects/scrapkeep/src/orchard/scene.js",
    "read /home/someone/.config/typesafe/.env",
    "godot at /Users/other/Applications/Godot.app",
    "tmp dir /tmp/scrapkeep-docs-7ds8lp/repo/BACKLOG.md",
    "head 1c20a2c1cafb0ea612925c49860e552f945beeca",
  ].join("\n");
  const out = redact(text, { repoRoot, secrets: [] });
  assert.ok(!out.includes("/home/someone"), out);
  assert.ok(!out.includes("/Users/other"), out);
  assert.match(out, /<repo>\/tests\/a\.test\.js:4:1/);
  assert.match(out, /<repo>\/tests\/fixtures\/x\.md/);
  assert.match(out, /<repo>\/src\/orchard\/scene\.js/);
  assert.ok(!out.includes(".config/typesafe"), out);
  assert.match(out, /\/tmp\/scrapkeep-docs-7ds8lp\/repo\/BACKLOG\.md/);
  assert.match(out, /1c20a2c1cafb0ea612925c49860e552f945beeca/);
});

test("the state Jev sees is redacted and clipped before any call", async () => {
  const s = await scratch();
  let seen;
  const log = `${"noise line\n".repeat(4000)}Authorization: ${FAKE.bearer}\n✖ the failing test\n`;
  await triage(
    { check: "tests/x.test.js", log, diff: `+const key = "${FAKE.sk}";\n` },
    {
      call: async (request) => {
        seen = JSON.stringify(request);
        return jevReply("real_regression", 0.1);
      },
      cacheDir: s.cacheDir,
      logFile: s.logFile,
    },
  );
  assert.ok(seen !== undefined, "the injected caller was used");
  assert.ok(!seen.includes(FAKE.sk));
  assert.ok(!seen.includes(FAKE.bearer.slice(7)));
  assert.ok(seen.includes("the failing test"), "the tail of the log survives");
  const state = buildState({ check: "c", log, diff: "" });
  assert.ok(state.log.length < log.length, "the log is clipped");
  await s.done();
});

test("one typed call asks a five-way Choice and a rerun Noul", () => {
  const questions = buildQuestions();
  assert.deepEqual(Object.keys(questions).sort(), ["cause", "rerun"]);
  assert.equal(questions.cause.type, "choice");
  assert.deepEqual(Object.keys(questions.cause.criteria), CAUSES);
  assert.deepEqual(CAUSES, [
    "timing_flake",
    "real_regression",
    "engine_crash",
    "test_bug",
    "infra",
  ]);
  assert.equal(questions.rerun.type, "noul");
});

test("a Jev verdict composes cause and rerun safety; only flake-like causes may rerun", async () => {
  const s = await scratch();
  const deps = { cacheDir: s.cacheDir, logFile: s.logFile };
  const flake = await triage(INPUT, {
    ...deps,
    call: async () => jevReply("infra", 0.9),
  });
  assert.equal(flake.source, "jev");
  assert.equal(flake.cause, "infra");
  assert.equal(flake.rerun_safe, true);
  assert.equal(flake.model, "jev-test");
  assert.deepEqual(flake.usage, { input_tokens: 400, output_tokens: 10 });

  const regression = await triage(
    { ...INPUT, log: "AssertionError: 3 !== 4" },
    { ...deps, call: async () => jevReply("real_regression", 0.95) },
  );
  assert.equal(regression.cause, "real_regression");
  assert.equal(regression.rerun_safe, false, "a regression is never rerun-safe");

  const doubtful = await triage(
    { ...INPUT, log: "timeout after 5000ms" },
    { ...deps, call: async () => jevReply("timing_flake", 0.3) },
  );
  assert.equal(doubtful.rerun_safe, false, "a low rerun Noul keeps it unsafe");
  assert.deepEqual([...FLAKE_LIKE].sort(), ["infra", "timing_flake"]);
  await s.done();
});

test("the fallback is conservative when Jev is unavailable", async () => {
  const s = await scratch();
  const deps = { cacheDir: s.cacheDir, logFile: s.logFile };
  const cases = {
    "no key": { key: null },
    "API error": {
      call: async () => {
        throw new Error("Jev 503: unavailable");
      },
    },
    timeout: { call: () => new Promise(() => {}), timeoutMs: 50 },
    malformed: { call: async () => ({ model: "x", usage: {}, answers: {} }) },
    "off-menu choice": {
      call: async () => {
        const reply = jevReply("infra", 0.9);
        reply.answers.cause.choice = "cosmic_rays";
        return reply;
      },
    },
  };
  for (const [name, extra] of Object.entries(cases)) {
    const started = Date.now();
    const verdict = await triage(
      { ...INPUT, log: `${INPUT.log}${name}` },
      { ...deps, ...extra },
    );
    assert.equal(verdict.source, "rule", name);
    assert.equal(verdict.cause, "real_regression", name);
    assert.equal(verdict.rerun_safe, false, name);
    assert.ok(verdict.reason.length > 0, name);
    assert.ok(Date.now() - started < 2000, `${name} did not wait on Jev`);
  }
  assert.deepEqual(ruleVerdict().cause, "real_regression");
  await s.done();
});

test("verdicts are cached by redacted input; fallbacks are not", async () => {
  const s = await scratch();
  let calls = 0;
  const deps = {
    cacheDir: s.cacheDir,
    logFile: s.logFile,
    call: async () => {
      calls += 1;
      return jevReply("timing_flake", 0.8);
    },
  };
  const first = await triage(INPUT, deps);
  const second = await triage(INPUT, deps);
  assert.equal(calls, 1);
  assert.equal(first.cached, false);
  assert.equal(second.cached, true);
  assert.equal(second.cause, "timing_flake");
  await triage({ ...INPUT, log: `${INPUT.log}other` }, deps);
  assert.equal(calls, 2);

  const failing = { ...deps, call: async () => { throw new Error("down"); } };
  await triage({ ...INPUT, log: "fresh" }, failing);
  const healed = await triage({ ...INPUT, log: "fresh" }, deps);
  assert.equal(healed.source, "jev", "a fallback never poisons the cache");

  const a = cacheKey(buildState({ check: "c", log: `x ${FAKE.sk}`, diff: "" }));
  const b = cacheKey(buildState({ check: "c", log: `x ${FAKE.ghp}`, diff: "" }));
  assert.equal(a, b, "the key is taken over the redacted state");
  assert.match(a, /^[0-9a-f]{64}$/);
  await s.done();
});

test("every call is logged like the hooks' jev-calls.tsv, without the log text", async () => {
  const s = await scratch();
  await triage(INPUT, {
    cacheDir: s.cacheDir,
    logFile: s.logFile,
    call: async () => jevReply("infra", 0.9),
  });
  await triage({ ...INPUT, log: "boom" }, {
    cacheDir: s.cacheDir,
    logFile: s.logFile,
    call: async () => {
      throw new Error("Jev 500");
    },
  });
  const [header, ...rows] = (await readFile(s.logFile, "utf8")).trim().split("\n");
  const columns = header.split("\t");
  assert.deepEqual(columns.slice(0, 10), [
    "ts",
    "hook",
    "ms",
    "input_tokens",
    "questions",
    "model",
    "question_versions",
    "input_sha256",
    "request",
    "server_request",
  ]);
  assert.equal(rows.length, 2);
  const first = Object.fromEntries(rows[0].split("\t").map((v, i) => [columns[i], v]));
  assert.equal(first.hook, "triage");
  assert.equal(first.input_tokens, "400");
  assert.equal(first.output_tokens, "10");
  assert.equal(first.model, "jev-test");
  assert.equal(first.questions, "cause,rerun");
  const text = await readFile(s.logFile, "utf8");
  assert.ok(!text.includes("Unknown system error"), "no log text in the call log");
  assert.match(rows[1], /Error/);
  await s.done();
});

test("a rerun joins the outcome list for flake_rate and never turns the result into a pass", async () => {
  const flaky = { cause: "infra", rerun_safe: true };
  const advisory = rerunAdvisory(flaky, { rerun: "pass" });
  assert.equal(advisory.rerun_suggested, true);
  assert.deepEqual(advisory.outcomes, ["fail", "pass"]);
  assert.equal(advisory.result, "fail");
  assert.equal(advisory.counts_toward, "flake_rate");

  const byLabel = aggregateOutcomes([
    [{ label: "tests/check-docs.test.js", ok: false }],
    [{ label: "tests/check-docs.test.js", ok: true }],
  ]);
  assert.deepEqual(byLabel.get("tests/check-docs.test.js"), advisory.outcomes);
  assert.equal(flakeRate(byLabel).value, 1, "the disagreement counts as flake");

  const steady = rerunAdvisory(flaky, { rerun: "fail" });
  assert.deepEqual(steady.outcomes, ["fail", "fail"]);
  assert.equal(steady.result, "fail");

  const regression = rerunAdvisory({ cause: "real_regression", rerun_safe: false }, {});
  assert.equal(regression.rerun_suggested, false);
  assert.deepEqual(regression.outcomes, ["fail"]);
  assert.equal(regression.result, "fail");
  assert.throws(() => rerunAdvisory(flaky, { original: "pass" }), /failed check/);
});

test("the authored corpus is labelled, weighted and redacted, with a control", async () => {
  const corpus = await loadCorpus(CORPUS);
  assert.ok(corpus.weights.severe > corpus.weights.moderate);
  assert.ok(corpus.weights.moderate > corpus.weights.minor);
  assert.match(corpus.severity_rule, /regression/);
  const ids = new Set();
  for (const item of corpus.cases) {
    assert.ok(!ids.has(item.id), `duplicate ${item.id}`);
    ids.add(item.id);
    assert.ok(CAUSES.includes(item.cause), item.id);
    assert.ok(item.accept.includes(item.cause), item.id);
    assert.ok(item.accept.every((cause) => CAUSES.includes(cause)), item.id);
    assert.ok(item.severity in corpus.weights, item.id);
    assert.ok([true, false, null].includes(item.rerun_safe), item.id);
    assert.ok(typeof item.provenance === "string", item.id);
    assert.equal(redact(item.log), item.log, `${item.id} log is pre-redacted`);
    assert.equal(redact(item.diff), item.diff, `${item.id} diff is pre-redacted`);
    if (item.cause === "real_regression") {
      assert.equal(item.severity, "severe", `${item.id} regression is severe`);
      assert.equal(item.rerun_safe, false, item.id);
    }
  }
  const controls = corpus.cases.filter((item) => item.control === true);
  assert.ok(controls.length >= 1);
  for (const control of controls) {
    assert.deepEqual(control.accept, ["real_regression"]);
    assert.match(control.diff, /assert\(false\)/);
  }
  const real = corpus.cases.filter((item) => item.provenance.startsWith("real"));
  assert.ok(real.length >= 4, "real failure excerpts are included");
  for (const cause of CAUSES) {
    assert.ok(corpus.cases.some((item) => item.cause === cause), `covers ${cause}`);
  }
});

test("scoring weights misses and names a regression called a flake as severe", () => {
  const weights = { severe: 5, moderate: 2, minor: 1 };
  const cases = [
    { id: "r1", cause: "real_regression", accept: ["real_regression"], rerun_safe: false, severity: "severe" },
    { id: "r2", cause: "real_regression", accept: ["real_regression"], rerun_safe: false, severity: "severe" },
    { id: "f1", cause: "infra", accept: ["infra", "timing_flake"], rerun_safe: true, severity: "moderate" },
    { id: "c1", cause: "real_regression", accept: ["real_regression"], rerun_safe: false, severity: "severe", control: true },
    { id: "b1", cause: "test_bug", accept: ["test_bug"], rerun_safe: null, severity: "moderate" },
  ];
  const verdicts = {
    r1: { cause: "timing_flake", rerun_safe: true, source: "jev" },
    r2: { cause: "real_regression", rerun_safe: false, source: "jev" },
    f1: { cause: "timing_flake", rerun_safe: true, source: "jev" },
    c1: { cause: "test_bug", rerun_safe: false, source: "jev" },
    b1: { cause: "test_bug", rerun_safe: true, source: "jev" },
  };
  const summary = scoreCases(cases, verdicts, weights);
  assert.equal(summary.possible, 5 + 5 + 2 + 5 + 2);
  assert.equal(summary.earned, 5 + 2 + 2);
  assert.deepEqual(summary.severe_misses, ["r1"]);
  assert.deepEqual(summary.control, { passed: false, failed: ["c1"] });
  assert.equal(summary.cause_agreement, 3 / 5);
  assert.equal(summary.fallbacks, 0);
});

test("nothing on the gate path imports triage", async () => {
  const gatePath = [
    "scripts/verify.mjs",
    "scripts/play.mjs",
    "scripts/lab/gate.mjs",
    "scripts/lab/record.mjs",
    "scripts/lab/harness.mjs",
  ];
  for (const file of gatePath) {
    const text = await readFile(path.join(root, file), "utf8");
    assert.ok(!text.includes("triage"), `${file} must not depend on triage`);
  }
  const lab = await readdir(path.join(root, "scripts/lab"));
  assert.ok(lab.includes("triage.mjs"));
});
