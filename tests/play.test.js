import test from "node:test";
import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

import {
  aggregateOutcomes,
  buildTestMeasures,
  findOnPath,
  flakeRate,
  jobLimit,
  repeatCount,
  resolve,
  shotOutputPath,
  slugLabel,
} from "../scripts/play.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("jobLimit reads --jobs= and falls back to a core-based default", () => {
  assert.equal(jobLimit(["test", "--jobs=3"]), 3);
  assert.equal(jobLimit(["test", "--jobs=0"]), 1);
  assert.equal(jobLimit(["test", "--jobs=not-a-number"]), 1);
  const fallback = jobLimit(["test"]);
  assert.ok(fallback >= 2 && fallback <= 8);
});

test("repeatCount reads --repeat= and defaults to a single run", () => {
  assert.equal(repeatCount(["test"]), 1);
  assert.equal(repeatCount(["test", "--repeat=20"]), 20);
  assert.equal(repeatCount(["test", "--repeat=0"]), 1);
  assert.equal(repeatCount(["test", "--repeat=nope"]), 1);
});

test("slugLabel makes a record.mjs-safe slug from arbitrary text", () => {
  assert.equal(slugLabel("ball-lab"), "ball-lab");
  assert.equal(slugLabel("Cable Bench!!"), "cable-bench");
  assert.equal(slugLabel("spillway-drop/spillway-drop"), "spillway-drop-spillway-drop");
  assert.equal(slugLabel(""), "run");
  assert.equal(slugLabel("---"), "run");
});

test("aggregateOutcomes rows one check by label, tolerating a shorter repeat", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true },
      { label: "a boot", ok: true },
    ],
    [{ label: "a import", ok: false }],
    [
      { label: "a import", ok: true },
      { label: "a boot", ok: false },
    ],
  ];
  const byLabel = aggregateOutcomes(repeatResults);
  assert.deepEqual(byLabel.get("a import"), ["pass", "fail", "pass"]);
  assert.deepEqual(byLabel.get("a boot"), ["pass", "fail"]);
});

test("flakeRate counts a check disagreeing with itself, not just fail-then-pass order", () => {
  const agree = new Map([
    ["a", ["pass", "pass", "pass"]],
    ["b", ["fail", "fail"]],
  ]);
  assert.deepEqual(flakeRate(agree), { value: 0, n: 2, ci: null });

  const disagree = new Map([
    ["a", ["pass", "pass"]],
    ["b", ["pass", "fail"]],
    ["c", ["fail", "pass", "pass"]],
  ]);
  assert.deepEqual(flakeRate(disagree), { value: 2 / 3, n: 3, ci: null });

  assert.deepEqual(flakeRate(new Map()), { value: null, n: 0, ci: null });
});

test("buildTestMeasures reports suite_wall_s, suite_pass, engine_crash and skips flake_rate for a single run", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: true, crashed: false },
    ],
  ];
  const { measures, checks, flake, totalSeconds } = buildTestMeasures({
    repeatResults,
    repeatSeconds: [12.5],
    repeatOks: [true],
  });
  assert.equal(totalSeconds, 12.5);
  assert.deepEqual(measures.suite_wall_s, { value: 12.5, n: 1, ci: null });
  assert.deepEqual(measures.suite_pass, { value: 0, n: 1, ci: null });
  assert.deepEqual(measures.engine_crash, { value: 0, n: 2, ci: null });
  assert.equal(flake, null);
  assert.deepEqual(checks, [
    { label: "a import", outcomes: ["pass"] },
    { label: "a boot", outcomes: ["pass"] },
  ]);
});

test("buildTestMeasures reports flake_rate and counts crashes across repeats", () => {
  const repeatResults = [
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: true, crashed: true },
    ],
    [
      { label: "a import", ok: true, crashed: false },
      { label: "a boot", ok: false, crashed: false },
    ],
  ];
  const { measures, flake } = buildTestMeasures({
    repeatResults,
    repeatSeconds: [10, 14],
    repeatOks: [true, false],
  });
  assert.deepEqual(measures.suite_wall_s, { value: 12, n: 2, ci: null });
  assert.deepEqual(measures.suite_pass, { value: 1, n: 2, ci: null });
  assert.deepEqual(measures.engine_crash, { value: 1, n: 4, ci: null });
  assert.deepEqual(flake, { value: 0.5, n: 2, ci: null });
});

test("findOnPath resolves an executable from an injected PATH and returns null when absent", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "scrapkeep-path-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const executable = path.join(temporary, "claude-open");
  await writeFile(executable, "#!/bin/sh\nexit 0\n");
  await chmod(executable, 0o755);

  assert.equal(
    findOnPath("claude-open", { PATH: temporary }),
    executable,
  );
  assert.equal(findOnPath("claude-open", { PATH: "/does/not/exist" }), null);
  assert.equal(findOnPath("claude-open", {}), null);

  // A later PATH entry still resolves after an earlier one comes up empty.
  const empty = path.join(temporary, "empty-dir");
  await mkdir(empty);
  assert.equal(
    findOnPath("claude-open", {
      PATH: `${empty}${path.delimiter}${temporary}`,
    }),
    executable,
  );

  // A file that exists but is not executable does not count as found.
  const inert = path.join(temporary, "not-executable");
  await writeFile(inert, "not a script\n");
  assert.equal(findOnPath("not-executable", { PATH: temporary }), null);
});

test("shotOutputPath defaults under artifacts/local/shots/, never /tmp (audit A8)", () => {
  const entry = { sketch: "ball-lab" };
  const noArg = shotOutputPath(root, entry, undefined);
  assert.equal(
    noArg.shotsDir,
    path.join(root, "artifacts", "local", "shots"),
  );
  assert.equal(noArg.out, path.join(noArg.shotsDir, "ball-lab-spawn.png"));
  assert.ok(!noArg.out.startsWith("/tmp"));

  const named = shotOutputPath(root, entry, "custom.png");
  assert.equal(named.out, path.join(named.shotsDir, "custom.png"));

  const absolute = shotOutputPath(root, entry, "/tmp/explicit.png");
  assert.equal(absolute.out, "/tmp/explicit.png");
});

test("resolve still prefers an exact id, then a primary among prefix or substring hits", () => {
  const entries = [
    { id: "ball-lab", sketch: "ball-lab", primary: true },
    { id: "mobility-kit/ball-lab", sketch: "ball-lab", primary: false },
    { id: "spillway-drop", sketch: "spillway-drop", primary: true },
  ];
  assert.equal(resolve(entries, "ball-lab").entry.id, "ball-lab");
  assert.equal(resolve(entries, "spill").entry.id, "spillway-drop");
  assert.deepEqual(resolve(entries, "nope"), { ambiguous: [] });
});
