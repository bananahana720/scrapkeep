import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  carryList,
  collect,
  harvest,
  main,
  normalize,
  parseLog,
  runOf,
  signature,
} from "./crash-harvest.mjs";

const fixtures = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../tests/fixtures/crash-harvest",
);
const readAll = () =>
  collect([fixtures]).files.map((file) => ({
    file,
    text: readFileSync(file, "utf8"),
  }));
const byKind = (findings, kind) => findings.filter((f) => f.signature.kind === kind);

test("normalize drops the numbers that change between runs", () => {
  assert.equal(
    normalize("index '12' at 0x7f43d2a4 slot 3.5"),
    normalize("index '7' at 0x1 slot 9"),
  );
});

test("parseLog reads a Godot 4.7 script error with its first game frame", () => {
  const [event] = parseLog(
    readFileSync(path.join(fixtures, "jobs/speedrunner-tally-35010/log.txt"), "utf8").split(
      "bot_run",
    )[0],
  );
  assert.equal(event.kind, "script");
  assert.equal(signature(event).where, "res://src/enemies/brindle.gd:418");
});

test("warnings are not findings, and only log files are read", () => {
  const { files } = collect([fixtures]);
  assert.ok(files.every((f) => !f.endsWith(".ndjson")));
  const findings = harvest(readAll(), { base: fixtures });
  assert.ok(findings.every((f) => !/ACE stem/.test(f.title)));
});

test("one script error across runs and colour codes is one major with every run", () => {
  const findings = harvest(readAll(), { base: fixtures });
  const brindle = findings.filter((f) => f.signature.where === "res://src/enemies/brindle.gd:418");
  assert.equal(brindle.length, 1);
  assert.equal(brindle[0].severity, "major");
  assert.equal(brindle[0].count, 3);
  assert.deepEqual(brindle[0].runs.map((r) => r.id).sort(), [
    "first-timer-tarn-35221",
    "speedrunner-tally-35010",
  ]);
});

test("a crash is a blocker, keyed by its script frame or else its native frames", () => {
  const crashes = byKind(harvest(readAll(), { base: fixtures }), "crash");
  assert.equal(crashes.length, 2);
  assert.ok(crashes.every((f) => f.severity === "blocker" && f.area === "stability"));
  const scripted = crashes.find((f) => f.signature.where === "res://src/player/harpoon_pool.gd:41");
  assert.match(scripted.signature.message, /^Program crashed with signal 11$/);
  const native = crashes.find((f) => f.runs[0].id === "native-crash");
  assert.equal(native.signature.where, "main+1a2b3c < main+2b3c4d < main+3c4d5e");
});

test("parse errors and scripts that fail to load are majors; engine errors are minors", () => {
  const findings = harvest(readAll(), { base: fixtures });
  const shop = findings.filter((f) => /shop\.gd/.test(f.title));
  assert.equal(shop.length, 2);
  assert.ok(shop.every((f) => f.severity === "major"));
  const gate = findings.find(
    (f) => f.signature.where === "res://src/stages/map_highdraft_crown.gd:62",
  );
  assert.equal(gate.severity, "minor");
});

test("findings rank blocker first and carry seeded runs in the red team's shape", () => {
  const findings = harvest(readAll(), { base: fixtures });
  assert.deepEqual([...new Set(findings.map((f) => f.severity))], ["blocker", "major", "minor"]);
  for (const f of findings)
    for (const key of ["severity", "area", "key", "title", "feel", "runs"])
      assert.ok(key in f, key);
  const carry = carryList(findings);
  assert.ok(
    carry.some((c) => c.pilot === "tally" && c.seed === 35010 && c.persona === "speedrunner"),
  );
});

test("runOf names red team jobs and plain logs", () => {
  assert.deepEqual(runOf("/x/jobs/line-rider-pylon_engineer-2604/log.txt", "/x"), {
    id: "line-rider-pylon_engineer-2604",
    persona: "line-rider",
    pilot: "pylon_engineer",
    seed: 2604,
    log: "jobs/line-rider-pylon_engineer-2604/log.txt",
  });
  assert.equal(runOf("/x/export.txt", "/x").id, "export");
  assert.equal(runOf("/x/export.txt", "/x").seed, null);
});

test("--ignore drops matching signatures and --fail-on sets the exit", () => {
  const out = mkdtempSync(path.join(os.tmpdir(), "crash-harvest-"));
  try {
    const quiet = () => {};
    assert.equal(main([`--out=${out}`, fixtures], quiet), 0);
    const written = JSON.parse(readFileSync(path.join(out, "findings.json"), "utf8"));
    assert.equal(written.findings.filter((f) => f.severity === "blocker").length, 2);
    assert.deepEqual(written.runs, []);
    assert.equal(main(["--fail-on=blocker", fixtures], quiet), 1);
    assert.equal(main(["--fail-on=blocker", "--ignore=^crash:", fixtures], quiet), 0);
    assert.equal(main([path.join(out, "missing")], quiet), 2);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("a stdout line between a header and its at: line does not split the signature", () => {
  const clean =
    "SCRIPT ERROR: Invalid call. Nonexistent function 'x' in base 'Nil'.\n          at: boom (res://src/a.gd:5)\n";
  const split =
    "SCRIPT ERROR: Invalid call. Nonexistent function 'x' in base 'Nil'.\nbot_run: tick 90\n          at: boom (res://src/a.gd:5)\n";
  const findings = harvest(
    [
      { file: "/x/a.txt", text: clean },
      { file: "/x/b.txt", text: split },
    ],
    { base: "/x" },
  );
  assert.equal(findings.length, 1);
  assert.equal(findings[0].signature.where, "res://src/a.gd:5");
  assert.equal(findings[0].runs.length, 2);
});

test("a crash keys on its frame, not on the error printed near it", () => {
  const dump = (before) =>
    `${before}handle_crash: Program crashed with signal 11\nGDScript backtrace (most recent call first):\n    [0] _claim (res://src/p.gd:41)\n`;
  const findings = harvest(
    [
      {
        file: "/x/a.txt",
        text: dump("ERROR: pool exhausted at slot 3\n   at: push_error (core/v.cpp:1)\n"),
      },
      {
        file: "/x/b.txt",
        text: dump("ERROR: other thing\n   at: f (core/w.cpp:2)\n"),
      },
      { file: "/x/c.txt", text: dump("") },
    ],
    { base: "/x" },
  );
  const crashes = byKind(findings, "crash");
  assert.equal(crashes.length, 1);
  assert.equal(crashes[0].runs.length, 3);
});

test("digits in res:// paths stay, so different assets stay different findings", () => {
  assert.notEqual(
    normalize("Cannot open file 'res://a/crate_09.tres'."),
    normalize("Cannot open file 'res://a/crate_10.tres'."),
  );
});

test("findings.json carries what scripts/redteam/merge.mjs reads, and runs keep the red team's fields", () => {
  const out = mkdtempSync(path.join(os.tmpdir(), "crash-harvest-"));
  try {
    assert.equal(
      main([`--out=${out}`, "--wave=16", "--commit=cf63e622b0", fixtures], () => {}),
      0,
    );
    const written = JSON.parse(readFileSync(path.join(out, "findings.json"), "utf8"));
    assert.equal(written.wave, 16);
    assert.equal(typeof written.commit, "string");
    assert.equal(typeof written.started, "string");
    assert.equal(written.minutes, 0);
    assert.deepEqual(written.extras, {});
    for (const f of written.findings)
      for (const r of f.runs)
        for (const key of ["id", "persona", "pilot", "seed", "note", "replay", "carry"])
          assert.ok(key in r, key);
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});

test("collect sorts by code unit (B < _ < a) and follows symlinked directories without EISDIR", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "crash-harvest-walk-"));
  const target = mkdtempSync(path.join(os.tmpdir(), "crash-harvest-link-"));
  try {
    writeFileSync(path.join(dir, "a.log"), "ok\n");
    writeFileSync(path.join(dir, "B.log"), "ok\n");
    writeFileSync(path.join(dir, "_.log"), "ok\n");
    writeFileSync(path.join(target, "inner.log"), "ok\n");
    symlinkSync(target, path.join(dir, "log"));

    const { files, skipped } = collect([dir]);
    assert.deepEqual(
      files.map((f) => path.relative(dir, f).split(path.sep).join("/")),
      ["B.log", "_.log", "a.log", "log/inner.log"],
    );
    assert.deepEqual(skipped, []);
    assert.equal(
      main([dir], () => {}),
      0,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(target, { recursive: true, force: true });
  }
});
