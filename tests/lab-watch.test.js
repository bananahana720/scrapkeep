// JL-31: `scrapkeep lab watch`. Watch mode reuses the real harness with a
// flag, writes a side file the Godot overlay reads, runs Jev as a demo when its
// preflight fails, caps a session's Jev calls, is refused by the gate, and a
// replay page plays any retained trial. Every decideFn and preflight here is a
// stub and every directory lives under mkdtemp, so nothing leaves the machine.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { offeredOptions } from "../tools/jev-player/decide.mjs";
import { ARMS } from "../tools/jev-player/protocol/protocol.mjs";
import {
  GODOT_BINARY,
  godotLaunch,
  watchPaths,
} from "../scripts/lab/godot-launch.mjs";
import { fakeGodot, runBatch } from "../scripts/lab/harness.mjs";
import {
  INTENT,
  PAGE,
  SOURCE,
  STATUS,
  WATCH,
} from "../scripts/lab/metrics/status.mjs";
import { buildReplay, REPLAY_CSP_BASE } from "../scripts/lab/replay.mjs";
import {
  decisionLine,
  plannedPreflightCalls,
  repoRelative,
  runWatch,
  WATCH_DEFAULTS,
} from "../scripts/lab/watch.mjs";
import { labRoute } from "../scripts/play.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const gateScript = path.join(root, "scripts/lab/gate.mjs");
const MODEL = "jev-stub-resolved";
const USAGE = {
  input_tokens: 700,
  output_tokens: 11,
  cache_read_input_tokens: 5,
  cache_creation_input_tokens: 2,
};

// Answers the last offered option with a skewed distribution, so the chosen
// option and the probabilities differ from a uniform draw.
function stubDecide({ confidence = 0.8 } = {}) {
  const calls = [];
  const decideFn = async (state, options) => {
    calls.push({ state, options });
    const offered = offeredOptions({ state, options });
    const pick = offered.at(-1).id;
    const probabilities = Object.fromEntries(
      offered.map((option) => [
        option.id,
        option.id === pick ? 0.7 : 0.3 / Math.max(1, offered.length - 1),
      ]),
    );
    return {
      gatedOut: [],
      intent: confidence >= 0.05 ? pick : "push_objective",
      lowConfidence: confidence < 0.05,
      rawIntent: pick,
      confidence,
      probabilities,
      danger: 0.1,
      greedy: 0.2,
      latencyMs: 3,
      usage: { ...USAGE },
      model: MODEL,
    };
  };
  decideFn.calls = calls;
  return decideFn;
}

function stubPreflight({ passed = true, calls = 12 } = {}) {
  const seen = [];
  const preflight = async ({ start }) => {
    seen.push(true);
    const result = {
      passed,
      calls,
      tokens: { ...USAGE },
      resolved_models: [MODEL],
      controls_version: "stub",
      controls_sha: "0".repeat(64),
      controls: [
        {
          id: "free-cache",
          passed,
          reason: passed ? "passed in both orders" : "P(take_cache) 0.1 < 0.5",
          runs: [],
        },
      ],
    };
    if (!passed) return { exit: 6, controls: result, started: null };
    return { exit: 0, controls: result, started: await start() };
  };
  preflight.seen = seen;
  return preflight;
}

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
}

async function fixture(t) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-watch-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const repository = path.join(temporary, "repository");
  await mkdir(path.join(repository, "src"), { recursive: true });
  git(repository, "init", "-q", "-b", "lab");
  await writeFile(path.join(repository, "src/tuning.txt"), "speed = 4\n");
  git(repository, "add", ".");
  git(repository, "commit", "-q", "-m", "fixture");
  const runs = {
    root: path.join(temporary, "runs"),
    repository,
    sources: ["src"],
  };
  const watch = (options) =>
    runWatch({
      launch: fakeGodot(),
      root: runs.root,
      runs,
      cache: path.join(temporary, "cache"),
      marks: path.join(temporary, "marks"),
      watchdogFloorMs: 10_000,
      ...options,
    });
  return { temporary, runs, watch };
}

const lines = async (file) =>
  (await readFile(file, "utf8"))
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => JSON.parse(line));

// --- the launch --------------------------------------------------------------

test("godotLaunch without watch keeps the headless arguments byte for byte", () => {
  const launch = godotLaunch({ mode: "kinematic" });
  const { args } = launch({
    io: "/tmp/run/trials/000",
    scenario: "downhill-run",
    seed: 7000,
    trial: 0,
    snapshotEvery: 90,
    holdTicks: 26,
  });
  assert.deepEqual(args.slice(0, 3), ["--headless", "--fixed-fps", "90"]);
  assert.ok(!args.some((arg) => arg.startsWith("--watch")));
  assert.match(launch.label, /^godot-headless /);
});

test("godotLaunch with watch opens a window at real time and names the side files", () => {
  const launch = godotLaunch({
    mode: "rigid",
    watch: { marks: "/tmp/marks", shots: [300, 900], markAt: 400 },
  });
  const { command, args } = launch({
    io: "/tmp/runs/r1/trials/002",
    scenario: "dummy-knock",
    seed: 1002,
    trial: 2,
    snapshotEvery: 90,
    holdTicks: 26,
  });
  assert.equal(command, GODOT_BINARY);
  const split = args.indexOf("--");
  const engine = args.slice(0, split);
  const user = args.slice(split + 1);
  assert.ok(!engine.includes("--headless"), "a visible window");
  assert.ok(
    !engine.includes("--fixed-fps"),
    "real time, not as fast as possible",
  );
  const paths = watchPaths("/tmp/runs/r1/trials/002", "/tmp/marks");
  assert.deepEqual(paths, {
    run: "/tmp/runs/r1",
    runId: "r1",
    trial: "002",
    dir: "/tmp/runs/r1/watch/002",
    marks: "/tmp/marks/r1.jsonl",
  });
  assert.ok(user.includes(`--watch=${paths.dir}`));
  assert.ok(user.includes(`--marks=${paths.marks}`));
  assert.ok(user.includes("--shots=300,900"));
  assert.ok(user.includes("--mark-at=400"));
  assert.ok(user.includes("--mode=rigid"));
  assert.match(launch.label, /^godot-watch /);
});

// --- the harness flag --------------------------------------------------------

test("a scripted watch reports every decision, forced ones included, and marks the record", async (t) => {
  const { watch } = await fixture(t);
  const { batch, sessions } = await watch({
    scenario: "pillar-weave",
    arm: "scripted",
  });
  const { record } = batch;
  assert.deepEqual(record.config.watch, {
    label: WATCH.watch.record,
    demo: false,
    session_cap: WATCH_DEFAULTS.callCap,
    preflight_calls: 0,
    arm_cap: record.config.call_cap,
  });
  assert.ok(record.limits.some((line) => line.includes("watch, not evidence")));
  const [session] = sessions;
  const decisions = await lines(path.join(session.dir, "decisions.ndjson"));
  assert.equal(decisions.length, record.config.trials[0].intents);
  for (const line of decisions) {
    assert.equal(line.arm, "scripted");
    assert.ok(["rule", "forced"].includes(line.kind), line.kind);
    assert.equal(typeof line.latency_ms, "number");
    assert.ok(Object.hasOwn(INTENT, line.intent));
    assert.ok(Array.isArray(line.offered) && line.offered.length > 0);
    assert.equal(line.state.options.length > 0, true, "the exact jev block");
    assert.equal(line.probabilities, null, "a rule ladder has no distribution");
  }
  assert.ok(decisions.some((line) => line.kind === "rule" && line.rule));
});

test("a random watch shows the uniform draw it actually makes", async (t) => {
  const { watch } = await fixture(t);
  const { sessions } = await watch({ scenario: "pillar-weave", arm: "random" });
  const decisions = await lines(path.join(sessions[0].dir, "decisions.ndjson"));
  const drawn = decisions.filter((line) => line.kind === "seeded");
  assert.ok(drawn.length > 0);
  for (const line of drawn) {
    const values = Object.values(line.probabilities);
    assert.equal(values.length, line.offered.length);
    for (const value of values) assert.equal(value, 1 / line.offered.length);
  }
});

test("session.json carries the palette, the arm and the marks file the overlay reads", async (t) => {
  const { watch, temporary } = await fixture(t);
  const { batch, sessions } = await watch({
    scenario: "pillar-weave",
    arm: "scripted",
  });
  const session = JSON.parse(
    await readFile(path.join(sessions[0].dir, "session.json"), "utf8"),
  );
  assert.equal(session.schema, "scrapkeep-watch/1");
  assert.equal(session.run_id, batch.record.id);
  assert.equal(session.arm, "scripted");
  assert.equal(session.scenario, "pillar-weave");
  assert.equal(session.demo, false);
  assert.equal(session.banner, WATCH.watch.banner);
  assert.equal(
    session.marks,
    path.join(temporary, "marks", `${batch.record.id}.jsonl`),
  );
  assert.deepEqual(session.palette.intents, JSON.parse(JSON.stringify(INTENT)));
  assert.deepEqual(session.palette.sources, JSON.parse(JSON.stringify(SOURCE)));
  assert.equal(session.palette.page.accent, PAGE.accent);
  assert.equal(session.palette.status.pass.hex, STATUS.green.hex);
  assert.equal(session.palette.status.fail.hex, STATUS.red.hex);
  assert.equal(session.hold_ticks, 26);
});

// --- Jev in watch mode: demo, preflight shown, cap --------------------------

test("a jev watch whose preflight fails still runs, as a demo, and shows the preflight", async (t) => {
  const { watch } = await fixture(t);
  const decideFn = stubDecide();
  const preflight = stubPreflight({ passed: false });
  const { batch, sessions } = await watch({
    scenario: "pillar-weave",
    arm: "jev",
    decideFn,
    preflight,
  });
  assert.equal(preflight.seen.length, 1, "preflight still runs");
  const { record } = batch;
  assert.notEqual(record, null, "a watch is not refused");
  assert.equal(record.config.watch.demo, true);
  assert.equal(record.config.watch.label, WATCH.demo.record);
  assert.equal(record.config.preflight.passed, false);
  assert.ok(record.limits.some((line) => line.includes("demo, not evidence")));
  assert.ok(decideFn.calls.length > 0);
  const session = JSON.parse(
    await readFile(path.join(sessions[0].dir, "session.json"), "utf8"),
  );
  assert.equal(session.demo, true);
  assert.equal(session.banner, WATCH.demo.banner);
  assert.equal(session.preflight.passed, false);
  assert.equal(session.preflight.calls, 12);
  assert.match(session.preflight.lines.join("\n"), /free-cache/);
  const decisions = await lines(path.join(sessions[0].dir, "decisions.ndjson"));
  const live = decisions.filter((line) => line.kind === "live");
  assert.ok(live.length > 0);
  for (const line of live) {
    assert.equal(line.confidence, 0.8);
    assert.equal(line.intent, line.offered.at(-1).id);
    assert.equal(line.probabilities[line.intent], 0.7);
    assert.equal(line.tokens.input_tokens % USAGE.input_tokens, 0);
    assert.equal(line.tokens.output_tokens % USAGE.output_tokens, 0);
    assert.ok(!Object.hasOwn(line.tokens, "total"), "never summed");
  }
});

test("without watch a failed preflight still refuses the batch", async (t) => {
  const { runs, temporary } = await fixture(t);
  const result = await runBatch({
    scenario: "pillar-weave",
    arm: "jev",
    launch: fakeGodot(),
    runs,
    verdictCache: path.join(temporary, "cache"),
    decideFn: stubDecide(),
    preflight: stubPreflight({ passed: false }),
    watchdogFloorMs: 10_000,
  });
  assert.equal(result.exit, 6);
  assert.equal(result.record, null);
});

test("the session cap counts the preflight's calls, and live calls never pass it", async (t) => {
  const { watch } = await fixture(t);
  const decideFn = stubDecide();
  const { batch } = await watch({
    scenario: "pillar-weave",
    arm: "jev",
    trials: 3,
    callCap: 14,
    decideFn,
    preflight: stubPreflight({ calls: 12 }),
  });
  const { record } = batch;
  assert.equal(record.config.watch.session_cap, 14);
  assert.equal(record.config.watch.preflight_calls, 12);
  assert.equal(record.config.watch.arm_cap, 2);
  assert.equal(record.config.call_cap, 2);
  assert.equal(decideFn.calls.length, 2);
  assert.ok(12 + record.provenance.jev.calls <= 14);
  assert.equal(record.config.capped, true);
  assert.equal(WATCH_DEFAULTS.callCap, 60);
});

test("a watch never writes to the lab's own verdict cache or runs root", async (t) => {
  assert.match(WATCH_DEFAULTS.cache, /artifacts\/local\/watch-cache$/);
  assert.match(WATCH_DEFAULTS.root, /artifacts\/local\/watch-runs$/);
  assert.match(WATCH_DEFAULTS.marks, /artifacts\/local\/watch-marks$/);
});

test("cached, fallback, forced and failed decisions are never labelled as a Jev choice", () => {
  const base = {
    trial: 0,
    seq: 3,
    tick: 270,
    offered: [{ id: "push_objective" }, { id: "ram_target" }],
    state: { jev: { state: {}, options: [] } },
    latencyMs: 1.5,
  };
  const counters = { live: 0, cached: 0, cap: 48, tokens: { ...USAGE } };
  const kinds = [
    [
      {
        ...base,
        forced: true,
        choice: { intent: "push_objective", source: "forced", meta: {} },
      },
      null,
      "forced",
    ],
    [
      {
        ...base,
        choice: {
          intent: "ram_target",
          source: "cache",
          meta: { confidence: 0.6, low_confidence: false },
        },
      },
      { probabilities: { ram_target: 0.6 } },
      "cache",
    ],
    [
      {
        ...base,
        choice: {
          intent: "push_objective",
          source: "live",
          meta: {
            confidence: 0.01,
            low_confidence: true,
            raw_intent: "ram_target",
          },
        },
      },
      { probabilities: { ram_target: 0.3 } },
      "fallback",
    ],
    [{ ...base, choice: null, error: "Jev call failed: 500" }, null, "failed"],
    [
      {
        ...base,
        choice: {
          intent: "ram_target",
          source: "live",
          meta: { confidence: 0.9, low_confidence: false },
        },
      },
      { probabilities: { ram_target: 0.9 } },
      "live",
    ],
  ];
  for (const [event, verdict, kind] of kinds) {
    const line = decisionLine({ arm: "jev", event, verdict, counters });
    assert.equal(line.kind, kind);
    assert.ok(Object.hasOwn(SOURCE, line.kind));
  }
  const fallback = decisionLine({
    arm: "jev",
    event: kinds[2][0],
    verdict: kinds[2][1],
    counters,
  });
  assert.equal(fallback.raw_intent, "ram_target");
  assert.equal(fallback.intent, "push_objective");
  assert.equal(
    decisionLine({
      arm: "jev",
      event: kinds[1][0],
      verdict: kinds[1][1],
      counters,
    }).cached,
    true,
  );
});

// --- the gate ----------------------------------------------------------------

test("the gate refuses a watch record: it cannot be pinned or gated", async (t) => {
  const { watch, runs, temporary } = await fixture(t);
  const { batch } = await watch({
    scenario: "pillar-weave",
    arm: "jev",
    decideFn: stubDecide(),
    preflight: stubPreflight({ passed: false }),
  });
  const gate = (...args) =>
    spawnSync(
      process.execPath,
      [
        gateScript,
        ...args,
        "--runs",
        runs.root,
        "--artifacts",
        path.join(temporary, "artifacts"),
        "--epochs",
        path.join(temporary, "epochs"),
      ],
      { encoding: "utf8" },
    );
  const pinned = gate("--pin", batch.record.id, "--as", "demo");
  assert.equal(pinned.status, 4, pinned.stdout + pinned.stderr);
  assert.match(pinned.stdout, /demo, not evidence/);
  assert.match(pinned.stderr, /refusing to pin/);
  assert.equal(existsSync(path.join(temporary, "artifacts")), false);
});

// --- the replay page ---------------------------------------------------------

test("the replay page is self-contained: one hashed inline script, no network, every decision on the timeline", async (t) => {
  const { watch } = await fixture(t);
  const { batch } = await watch({
    scenario: "pillar-weave",
    arm: "jev",
    decideFn: stubDecide(),
    preflight: stubPreflight(),
  });
  const { html, data } = await buildReplay(batch.directory);
  const csp = html.match(
    /<meta http-equiv="Content-Security-Policy" content="([^"]+)">/,
  );
  assert.ok(csp, "a CSP meta");
  assert.ok(csp[1].startsWith(REPLAY_CSP_BASE));
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  assert.equal(scripts.length, 1, "one executable inline script");
  const hash = createHash("sha256").update(scripts[0][1]).digest("base64");
  assert.ok(csp[1].includes(`'sha256-${hash}'`), "the CSP pins that script");
  assert.doesNotMatch(html, /https?:\/\//);
  assert.doesNotMatch(html, /\ssrc=/);
  assert.doesNotMatch(html, /<link\b/);
  assert.equal(data.decisions.length, batch.record.config.trials[0].intents);
  assert.ok(data.trace.length > 1);
  assert.ok(data.decisions.every((one) => Number.isInteger(one.tick)));
  assert.ok(data.decisions.some((one) => one.probabilities !== null));
  assert.equal(data.label, WATCH.demo.record);
  assert.equal(data.demo, true);
  for (const speed of ["0.25", "0.5", "1", "2", "4", "8"])
    assert.match(html, new RegExp(`value="${speed}"`));
  for (const hex of html.match(/#[0-9a-f]{6}\b/gi) ?? []) {
    const palette = JSON.stringify({ INTENT, SOURCE, PAGE, STATUS, WATCH });
    assert.ok(
      palette.toLowerCase().includes(hex.toLowerCase()),
      `${hex} is from the palette`,
    );
  }
});

test("a headless batch replays too, with no watch side file", async (t) => {
  const { runs, temporary } = await fixture(t);
  const batch = await runBatch({
    scenario: "pillar-weave",
    arm: "random",
    launch: fakeGodot(),
    runs,
    watchdogFloorMs: 10_000,
  });
  const trialDir = path.join(batch.directory, "trials", "000");
  const { data } = await buildReplay(trialDir);
  assert.equal(data.label, null);
  assert.equal(data.decisions.length, batch.trials[0].intents);
  assert.ok(data.decisions.every((one) => one.latency_ms === null));
  assert.equal(data.arm, "random");
  assert.ok(temporary);
});

// --- routing -----------------------------------------------------------------

test("scrapkeep lab watch routes to watch.mjs", () => {
  const routed = labRoute(["lab", "watch", "dummy-knock", "--arm", "jev"], {
    exists: () => true,
  });
  assert.deepEqual(routed, {
    script: path.join(root, "scripts", "lab", "watch.mjs"),
    args: ["dummy-knock", "--arm", "jev"],
  });
  assert.match(labRoute(["lab", "bogus"]).error, /watch/);
});

test("the palette names every intent and every arm source a decision can carry", () => {
  const sources = new Set(Object.values(ARMS).flat());
  for (const source of sources) {
    const key = source === "cache" ? "cache" : source;
    assert.ok(Object.hasOwn(SOURCE, key), source);
  }
  for (const [id, look] of Object.entries(INTENT)) {
    assert.match(look.hex, /^#[0-9a-f]{6}$/, id);
    assert.ok(look.shape.length >= 3, id);
    for (const [x, y] of look.shape)
      assert.ok(Math.abs(x) <= 1 && Math.abs(y) <= 1, id);
  }
});

// OKLab (Ottosson 2020): Euclidean distance there tracks perceived difference.
function oklab(hex) {
  const [r, g, b] = [1, 3, 5]
    .map((at) => parseInt(hex.slice(at, at + 2), 16) / 255)
    .map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}
const distance = (a, b) => {
  const [x, y] = [oklab(a), oklab(b)];
  return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]);
};

test("an intent colour means only that intent: far from every status, page and source colour and from each other", () => {
  const reserved = new Map();
  for (const [key, status] of Object.entries(STATUS)) {
    reserved.set(status.hex, `STATUS.${key}`);
    reserved.set(status.ink, `STATUS.${key}.ink`);
  }
  for (const [key, hex] of Object.entries(PAGE))
    reserved.set(hex, `PAGE.${key}`);
  for (const [key, source] of Object.entries(SOURCE))
    reserved.set(source.hex, `SOURCE.${key}`);
  const intents = Object.entries(INTENT);
  for (const [id, look] of intents) {
    for (const [hex, name] of reserved)
      assert.ok(
        distance(look.hex, hex) >= 0.12,
        `${id} ${look.hex} is ${distance(look.hex, hex).toFixed(3)} from ${name} ${hex}`,
      );
    for (const [other, peer] of intents)
      if (other !== id)
        assert.ok(
          distance(look.hex, peer.hex) >= 0.1,
          `${id} and ${other} are ${distance(look.hex, peer.hex).toFixed(3)} apart`,
        );
  }
  assert.ok(
    distance("#4fa3d9", STATUS.untiered.hex) < 0.12,
    "the rule catches the old push blue",
  );
  assert.ok(
    distance("#ffe29a", STATUS.amber.hex) < 0.12,
    "and the old evade yellow",
  );
});

function luminance(hex) {
  const [r, g, b] = [1, 3, 5]
    .map((at) => parseInt(hex.slice(at, at + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
const contrast = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].toSorted((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

test("every text colour on the replay page reads at 4.5:1 on each surface it can sit on", async (t) => {
  const { watch } = await fixture(t);
  const { batch } = await watch({ scenario: "pillar-weave", arm: "scripted" });
  const { html } = await buildReplay(batch.directory);
  const css = html.match(/<style>([\s\S]*?)<\/style>/)[1];
  const texts = new Set();
  for (const rule of css.split("}")) {
    if (rule.trim().startsWith(".label")) continue;
    for (const found of rule.matchAll(/(?:^|[\s;{])color: (#[0-9a-f]{6})/g))
      texts.add(found[1]);
  }
  for (const found of html.matchAll(/<text [^>]*fill="(#[0-9a-f]{6})"/g))
    texts.add(found[1]);
  assert.ok(texts.size >= 3, [...texts].join(" "));
  for (const hex of texts)
    for (const surface of [PAGE.background, PAGE.panel, PAGE.deep])
      assert.ok(
        contrast(hex, surface) >= 4.5,
        `${hex} on ${surface}: ${contrast(hex, surface).toFixed(2)}`,
      );
  for (const label of [WATCH.demo, WATCH.watch])
    assert.ok(
      contrast(PAGE.deep, label.hex) >= 4.5,
      `label text on ${label.hex}`,
    );
});

test("a --call-cap below the preflight's calls is refused before any call", async (t) => {
  const { watch } = await fixture(t);
  assert.equal(
    plannedPreflightCalls(),
    12,
    "c2: two threshold and two wording controls",
  );
  const decideFn = stubDecide();
  await assert.rejects(
    watch({
      scenario: "pillar-weave",
      arm: "jev",
      callCap: 11,
      decideFn,
      preflight: stubPreflight(),
    }),
    /--call-cap 11 is below the 12 live calls the preflight makes/,
  );
  assert.equal(decideFn.calls.length, 0);
  const scripted = await watch({
    scenario: "pillar-weave",
    arm: "scripted",
    callCap: 1,
  });
  assert.equal(scripted.batch.record.result, "pass", "the cap only binds Jev");
});

test("the gate refuses a pin that is a watch record, even one copied into place by hand", async (t) => {
  const { watch, runs, temporary } = await fixture(t);
  const demo = await watch({
    scenario: "pillar-weave",
    arm: "jev",
    decideFn: stubDecide(),
    preflight: stubPreflight(),
  });
  const candidate = await runBatch({
    scenario: "pillar-weave",
    arm: "jev",
    launch: fakeGodot(),
    runs,
    verdictCache: path.join(temporary, "cache-evidence"),
    decideFn: stubDecide(),
    preflight: stubPreflight(),
    watchdogFloorMs: 10_000,
  });
  const artifacts = path.join(temporary, "artifacts");
  const pin = path.join(
    artifacts,
    `jev-lab-${new Date().toISOString().slice(0, 10)}`,
    "pins",
    "copied-demo",
  );
  await mkdir(pin, { recursive: true });
  await writeFile(
    path.join(pin, "run.json"),
    await readFile(path.join(demo.batch.directory, "run.json")),
  );
  const result = spawnSync(
    process.execPath,
    [
      gateScript,
      candidate.record.id,
      "--against",
      "copied-demo",
      "--runs",
      runs.root,
      "--artifacts",
      artifacts,
      "--epochs",
      path.join(temporary, "epochs"),
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 4, result.stdout + result.stderr);
  assert.match(
    result.stdout,
    /pin copied-demo is a watch-mode record, demo, not evidence/,
  );
});

test("session.json names the marks file relative to the repository when it is inside it", () => {
  assert.equal(
    repoRelative(path.join(root, "artifacts/local/watch-marks/r.jsonl")),
    "artifacts/local/watch-marks/r.jsonl",
  );
  assert.equal(repoRelative("/elsewhere/r.jsonl"), "/elsewhere/r.jsonl");
});
