import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import * as smoke from "./sketch-smoke.mjs";
import {
  HEARTBEAT_MS,
  STALE_CLAIM_MS,
  MISSING_VERDICT,
  acquireSlot,
  binary,
  buildReceipt,
  countChecks,
  emitReceipt,
  gateFlagsError,
  globToRegExp,
  hasVerdictLine,
  judge,
  matchesGlob,
  machineSlotCount,
  namedRunMustWait,
  noMatchMessage,
  parseArgs,
  expiredLine,
  failingLines,
  logFileName,
  timeScale,
  expiredQuarantine,
  parseQuarantine,
  quarantineLines,
  quarantineRecords,
  quarantineNote,
  readQuarantine,
  readQuarantineEntries,
  quarantinedNames,
  quarantineVerdict,
  runPasses,
  receiptFileName,
  selectTests,
  splitFlags,
  validateRun,
  waitForMachine,
  isSolo,
  isSoloScript,
  testTimeoutMs,
} from "./sketch-smoke.mjs";

test("a bot head marker has its own timeout bounded at 1800 s", () => {
  assert.equal(testTimeoutMs("# smoke: bots timeout=1500s\nextends SceneTree\n"), 1_500_000);
  assert.equal(testTimeoutMs("# smoke: bots timeout=9999s\n"), 1_800_000);
  assert.equal(testTimeoutMs("# smoke: bots timeout=600s\n"), 600_000);
});

test("a bot head marker without a timeout gets 1200 s", () => {
  assert.equal(testTimeoutMs("# smoke: bots\nextends SceneTree\n"), 1_200_000);
  assert.equal(testTimeoutMs("# smoke: bots\r\n"), 1_200_000);
});

test("bot markers are recognized only in the first five lines", () => {
  assert.equal(smoke.isBot("#smoke:bots\r\n"), true);
  assert.equal(isSolo("# smoke: bots timeout=1500s\n"), true);
  assert.equal(smoke.isBot("# comment\n".repeat(4) + "# smoke: bots timeout=1500s\n"), true);
  const late = "# comment\n".repeat(5) + "# smoke: bots timeout=1500s\n";
  assert.equal(smoke.isBot(late), false);
  assert.equal(testTimeoutMs(late), 180_000);
  assert.equal(smoke.isBot('var s := "# smoke: bots"\n'), false);
  assert.equal(smoke.isBot("# smoke: botswain\n"), false);
});

test("parseArgs selects the bot tier with its own receipt label", () => {
  assert.equal(parseArgs(["--bots"]).bots, true);
  assert.equal(parseArgs(["--bots"]).receipt, "bots");
  assert.equal(parseArgs([]).bots, false);
  assert.equal(parseArgs(["--bots", "--receipt", "gate-bots"]).receipt, "gate-bots");
  assert.match(gateFlagsError(parseArgs(["--bots", "--receipt", "gate-bots", "--flags", "--scrap=armor"])), /refuses launch flags/);
});

// Run the real CLI with a fake Godot, so selection, serial scheduling and receipts
// are checked together without playing whole runs in the script suite.
function botTierFixture(args, check) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "smoke-bot-tier-"));
  try {
    mkdirSync(path.join(dir, "scripts"));
    writeFileSync(path.join(dir, "scripts/sketch-smoke.mjs"), readFileSync(new URL("./sketch-smoke.mjs", import.meta.url)));
    writeFileSync(path.join(dir, "scripts/import-stamp.mjs"), readFileSync(new URL("./import-stamp.mjs", import.meta.url)));
    const tests = path.join(dir, "sketches/core-loop/tests");
    mkdirSync(tests, { recursive: true });
    writeFileSync(path.join(dir, "sketches/core-loop/project.godot"), "config_version=5\n");
    writeFileSync(path.join(tests, "ordinary_test.gd"), "extends SceneTree\n");
    writeFileSync(path.join(tests, "solo_test.gd"), "# smoke: solo timeout=360s\n");
    writeFileSync(path.join(tests, "bot_a_test.gd"), "# smoke: bots timeout=1500s\n");
    writeFileSync(path.join(tests, "bot_b_test.gd"), "# smoke: bots\n");
    const fake = path.join(dir, "godot");
    writeFileSync(fake, `#!${process.execPath}
import { appendFileSync } from "node:fs";
const args = process.argv.slice(2);
if (args.includes("--version")) { console.log("fake"); process.exit(0); }
const script = args[args.indexOf("--script") + 1];
const name = args.includes("--script") ? script.split("/").pop().replace(/\\.gd$/, "") : args.includes("--import") ? "import" : "boot";
appendFileSync(process.env.FIXTURE_LOG, "start " + name + "\\n");
setTimeout(() => {
  appendFileSync(process.env.FIXTURE_LOG, "end " + name + "\\n");
  if (args.includes("--script")) console.log(name + ": PASS (1 checks)");
}, 40);
`, { mode: 0o755 });
    const log = path.join(dir, "jobs.log");
    const run = spawnSync(process.execPath, [path.join(dir, "scripts/sketch-smoke.mjs"), "--sketch", "core-loop", ...args], {
      encoding: "utf8", timeout: 20_000,
      env: { ...process.env, GODOT_BIN: fake, SMOKE_JOBS: "4", SMOKE_SLOTS: "6", SCRAPKEEP_LOCK_DIR: dir, SMOKE_FLAGS: "", FIXTURE_LOG: log },
    });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    const receipts = path.join(dir, "artifacts/local/receipts");
    const receipt = JSON.parse(readFileSync(path.join(receipts, readdirSync(receipts)[0]), "utf8"));
    check(run.stdout, receipt, readFileSync(log, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("default smoke excludes and names bot tests without failures or missing verdicts", () => {
  botTierFixture([], (output, receipt, log) => {
    assert.match(output, /bot tier: 2 not run \(npm run sketch:bots\)/);
    assert.match(output, /  bot_a_test\.gd\n  bot_b_test\.gd/);
    assert.deepEqual(receipt.bot_tier_not_run, ["bot_a_test.gd", "bot_b_test.gd"]);
    assert.equal(receipt.totals.failed, 0);
    assert.equal(receipt.totals.missing_verdict, 0);
    assert.equal(receipt.totals.runs, 4);
    assert.doesNotMatch(log, /bot_[ab]_test/);
  });
});

test("--bots runs only bot tests one at a time", () => {
  botTierFixture(["--bots"], (output, receipt, log) => {
    assert.deepEqual(log.trim().split("\n"), ["start import", "end import", "start bot_a_test", "end bot_a_test", "start bot_b_test", "end bot_b_test"]);
    assert.equal(receipt.width, 1);
    assert.equal(receipt.label, "bots");
    assert.deepEqual(receipt.bot_tier_not_run, []);
    assert.equal(receipt.results.filter((row) => row.solo).length, 2);
  });
});

test("a named glob runs matching bot tests solo and keeps their timeouts", () => {
  botTierFixture(["--test", "bot_*"], (output, receipt, log) => {
    assert.deepEqual(log.trim().split("\n"), ["start import", "end import", "start bot_a_test", "end bot_a_test", "start bot_b_test", "end bot_b_test"]);
    assert.equal(receipt.results.filter((row) => row.solo).length, 2);
    assert.deepEqual(receipt.bot_tier_not_run, []);
    assert.equal(testTimeoutMs("# smoke: bots timeout=1500s\n"), 1_500_000);
  });
});

test("old receipt callers get an empty bot-tier exclusion array", () => {
  const receipt = buildReceipt({ label: "old", argv: [], root: "/r", git: null, godot: {}, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: [] });
  assert.deepEqual(receipt.bot_tier_not_run, []);
  assert.equal(receipt.ok, true);
});

test("a head marker can raise one test's cap, bounded at 360 s", () => {
  assert.equal(testTimeoutMs("extends SceneTree\n"), 180_000);
  assert.equal(testTimeoutMs("# smoke: solo timeout=300s\nextends SceneTree\n"), 300_000);
  assert.equal(testTimeoutMs("# smoke: solo timeout=900s\nextends SceneTree\n"), 360_000);
  assert.equal(testTimeoutMs("# smoke: solo timeout=60s\nextends SceneTree\n"), 180_000);
  assert.equal(testTimeoutMs("extends SceneTree\n\n\n\n\n# smoke: solo timeout=300s\n"), 180_000);
  assert.equal(isSolo("# smoke: solo timeout=300s\nextends SceneTree\n"), true);
});

test("a first-line marker opts a file into the solo phase", () => {
  assert.equal(isSolo("# smoke: solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("#smoke:solo\nextends SceneTree\n"), true);
  assert.equal(isSolo("# smoke: solo - wall-time cap\r\nextends SceneTree\n"), true);
});

test("an unmarked file stays in the parallel batch", () => {
  assert.equal(isSolo("extends SceneTree\n# smoke: parallel\n"), false);
  assert.equal(isSolo("# smoke: soloist\nextends SceneTree\n"), false);
  assert.equal(isSolo(""), false);
});

test("the marker is read only from the first lines", () => {
  const body = "extends SceneTree\n".repeat(5);
  assert.equal(isSolo(body + "# smoke: solo\n"), false);
  assert.equal(isSolo('extends SceneTree\nvar s := "# smoke: solo"\n'), false);
  assert.equal(isSolo("extends SceneTree\n# smoke: solo\n"), true);
});

test("the runner reads the res:// script from the sketch directory", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "smoke-marker-"));
  try {
    mkdirSync(path.join(dir, "tests"));
    writeFileSync(path.join(dir, "tests", "a_test.gd"), "# smoke: solo\nextends SceneTree\n");
    writeFileSync(path.join(dir, "tests", "b_test.gd"), "extends SceneTree\n");
    assert.equal(isSoloScript(dir, "res://tests/a_test.gd"), true);
    assert.equal(isSoloScript(dir, "res://tests/b_test.gd"), false);
    assert.equal(isSoloScript(dir, "res://tests/missing.gd"), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a glob matches a base name with or without .gd and * as the only wildcard", () => {
  assert.equal(matchesGlob("tuning_*", "tuning_basic_test.gd"), true);
  assert.equal(matchesGlob("tuning_*", "enemy_tuning_test.gd"), false);
  assert.equal(matchesGlob("boss_flow_test.gd", "boss_flow_test.gd"), true);
  assert.equal(matchesGlob("boss_flow_test", "boss_flow_test.gd"), true);
  assert.equal(matchesGlob("boss_flow_test", "boss_flow_test_2.gd"), false);
  assert.equal(matchesGlob("a.b", "axb.gd"), false);
  assert.equal(globToRegExp("*").test("anything"), true);
});

test("selectTests keeps scripts that match any glob", () => {
  const scripts = ["res://tests/tuning_a.gd", "res://tests/tuning_b.gd", "res://tests/enemy_director_test.gd", "res://tests/other.gd"];
  assert.deepEqual(selectTests(scripts, ["tuning_*", "enemy_director_test"]), scripts.slice(0, 3));
  assert.deepEqual(selectTests(scripts, ["nope_*"]), []);
});

test("flags split on spaces, and --flags wins over SMOKE_FLAGS", () => {
  assert.deepEqual(splitFlags("--scrap=armor  --music=ace"), ["--scrap=armor", "--music=ace"]);
  assert.deepEqual(splitFlags(""), []);
  assert.deepEqual(splitFlags(undefined), []);
  assert.deepEqual(parseArgs(["--flags", "--scrap=armor"], { SMOKE_FLAGS: "--music=ace" }).flags, ["--scrap=armor"]);
  assert.deepEqual(parseArgs([], { SMOKE_FLAGS: "--music=ace --c" }).flags, ["--music=ace", "--c"]);
});

test("parseArgs reads tests, receipt label and the strict switch", () => {
  const named = parseArgs(["--sketch", "core-loop", "--test", "a_*", "--test", "b"]);
  assert.deepEqual(named.tests, ["a_*", "b"]);
  assert.equal(named.named, true);
  assert.equal(named.receipt, "named");
  assert.equal(parseArgs(["--sketch", "x"]).receipt, "smoke");
  assert.equal(parseArgs(["--receipt", "gate"]).receipt, "gate");
  assert.equal(parseArgs(["--strict-verdict"]).strict, true);
  assert.equal(parseArgs([]).strict, false);
});

test("a named run needs exactly one known sketch and at least one match", () => {
  const available = ["core-loop", "other"];
  assert.match(validateRun(parseArgs(["--test", "x"]), available), /exactly one --sketch/);
  assert.match(validateRun(parseArgs(["--test", "x", "--sketch", "core-loop", "--sketch", "other"]), available), /exactly one --sketch/);
  assert.match(validateRun(parseArgs(["--sketch", "nope"]), available), /no sketch named nope/);
  assert.equal(validateRun(parseArgs(["--sketch", "core-loop", "--test", "x"]), available), null);
  assert.equal(validateRun(parseArgs([]), available), null);
  assert.match(noMatchMessage("core-loop", ["zzz_*"]), /no test in core-loop matching zzz_\*/);
});

test("verdict lines and check counts are detected tolerantly", () => {
  assert.equal(hasVerdictLine("a -> PASS\nboss_flow_test: PASS\n"), true);
  assert.equal(hasVerdictLine("boss_flow_test: FAIL (2 checks)\r\n"), true);
  assert.equal(hasVerdictLine("a -> PASS\nall good\n"), false);
  assert.equal(hasVerdictLine("  indented: PASS\n"), false);
  assert.deepEqual(countChecks("a -> PASS\nb -> PASS\nc -> FAIL\nx: PASS\n"), { passes: 2, fails: 1 });
  assert.deepEqual(countChecks("x: PASS\n"), { passes: 0, fails: 0 });
});

// Rule: a child's verdict for another file cannot satisfy the parent's file stem.
test("a child's other_test PASS does not satisfy the parent", () => {
  const child = spawnSync(
    process.execPath,
    ["-e", 'console.log("other_test: PASS")'],
    { encoding: "utf8" },
  );
  assert.equal(child.status, 0);
  const parent = judge({
    test: "res://tests/parent_test.gd",
    status: child.status,
    output: child.stdout,
  });
  assert.equal(parent.ok, false);
  assert.equal(parent.verdict, false);
  assert.equal(parent.reason, MISSING_VERDICT);
  assert.equal(
    judge({
      test: "res://tests/parent_test.gd",
      status: 0,
      output: "other_test: PASS\nparent_test: PASS (2 checks)\r\n",
    }).ok,
    true,
  );
  assert.equal(
    judge({
      test: "res://tests/parent_test.gd",
      status: 0,
      output: "parent_test_extra: PASS\n",
    }).ok,
    false,
  );
  assert.equal(
    hasVerdictLine("parent.test: PASS\n", "res://tests/parent.test.gd"),
    true,
  );
  assert.equal(
    hasVerdictLine("parentXtest: PASS\n", "res://tests/parent.test.gd"),
    false,
  );
});

// Rule: all run types share N slots, with a positive integer machine-wide override.
test("the machine pool defaults to two slots and validates SMOKE_SLOTS", () => {
  assert.equal(machineSlotCount({}), 2);
  assert.equal(machineSlotCount({ SMOKE_SLOTS: "3" }), 3);
  for (const value of ["0", "-1", "1.5", "nope", "", "Infinity"]) {
    assert.throws(
      () => machineSlotCount({ SMOKE_SLOTS: value }),
      /positive integer/,
    );
  }
});

// Rule: two claims fit; a third yields until a slot is released, without a timed assertion.
test("two runs acquire two slots and a third waits", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-slots-"));
  const leases = [];
  const options = {
    directory,
    slots: 2,
    log: () => {},
    sleep: async () => assert.fail("unexpected wait"),
  };
  try {
    leases.push(await acquireSlot(options));
    assert.equal(namedRunMustWait(options), false);
    leases.push(await acquireSlot(options));
    assert.notEqual(leases[0].slot, leases[1].slot);
    assert.equal(namedRunMustWait(options), true);
    let sleeps = 0;
    leases.push(
      await acquireSlot({
        ...options,
        pollMs: 7,
        sleep: async (ms) => {
          assert.equal(ms, 7);
          assert.equal(++sleeps, 1);
          assert.equal(namedRunMustWait(options), true);
          leases[0].release();
        },
      }),
    );
    assert.equal(sleeps, 1);
    assert.equal(leases[2].slot, leases[0].slot);
    assert.equal(typeof leases[2].waitMs, "number");
    leases[0].release();
    assert.equal(
      namedRunMustWait(options),
      true,
      "an old release cannot delete the new claim",
    );
  } finally {
    for (const lease of leases) lease.release();
    rmSync(directory, { recursive: true, force: true });
  }
});

// Rule: only a dead positive pid is reclaimable; re-use the pid of an exited child.
test("a dead pid slot is reclaimed without waiting", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-dead-slot-"));
  let lease;
  try {
    const dead = spawnSync(process.execPath, ["-e", ""], { encoding: "utf8" });
    assert.equal(dead.status, 0);
    assert.throws(() => process.kill(dead.pid, 0), { code: "ESRCH" });
    const slot = path.join(directory, "slot-0");
    mkdirSync(slot);
    writeFileSync(path.join(slot, "claim-dead"), String(dead.pid));
    lease = await acquireSlot({
      directory,
      slots: 1,
      sleep: async () => assert.fail("dead pid made us wait"),
    });
    assert.equal(lease.slot, slot);
    assert.equal(existsSync(path.join(slot, "claim-dead")), false);
    assert.equal(namedRunMustWait({ directory, slots: 1 }), true);
    lease.release();
    assert.equal(namedRunMustWait({ directory, slots: 1 }), false);
    assert.deepEqual(readdirSync(directory), []);
  } finally {
    lease?.release();
    rmSync(directory, { recursive: true, force: true });
  }
});

// Rule: a sandboxed runner records a namespace pid that answers EPERM on the
// host; only the claim's heartbeat mtime decides liveness.
test("a fresh unkillable-pid claim holds its slot", async (t) => {
  const kill = process.kill.bind(process);
  t.mock.method(process, "kill", (pid, signal) => {
    if (pid === 1 && signal === 0) throw Object.assign(new Error("fixture EPERM"), { code: "EPERM" });
    return kill(pid, signal);
  });
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-foreign-young-"));
  try {
    assert.throws(() => process.kill(1, 0), { code: "EPERM" });
    const slot = path.join(directory, "slot-0");
    mkdirSync(slot);
    writeFileSync(path.join(slot, "claim-foreign"), "1");
    assert.equal(namedRunMustWait({ directory, slots: 1 }), true);
    await assert.rejects(
      acquireSlot({
        directory,
        slots: 1,
        sleep: async () => {
          throw new Error("waited");
        },
      }),
      /waited/,
    );
    assert.equal(existsSync(path.join(slot, "claim-foreign")), true);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("a stale unkillable-pid claim is reclaimed at once", async (t) => {
  const kill = process.kill.bind(process);
  t.mock.method(process, "kill", (pid, signal) => {
    if (pid === 1 && signal === 0) throw Object.assign(new Error("fixture EPERM"), { code: "EPERM" });
    return kill(pid, signal);
  });
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-foreign-slot-"));
  let lease;
  try {
    assert.throws(() => process.kill(1, 0), { code: "EPERM" });
    const slot = path.join(directory, "slot-0");
    mkdirSync(slot);
    writeFileSync(path.join(slot, "claim-foreign"), "1");
    const old = (Date.now() - STALE_CLAIM_MS - 60_000) / 1000;
    utimesSync(path.join(slot, "claim-foreign"), old, old);
    assert.equal(namedRunMustWait({ directory, slots: 1 }), false);
    lease = await acquireSlot({
      directory,
      slots: 1,
      sleep: async () => assert.fail("stale claim made us wait"),
    });
    assert.equal(lease.slot, slot);
    assert.equal(existsSync(path.join(slot, "claim-foreign")), false);
  } finally {
    lease?.release();
    rmSync(directory, { recursive: true, force: true });
  }
});

test("a lease heartbeat refreshes its claim mtime", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-heartbeat-"));
  let lease;
  try {
    assert.ok(HEARTBEAT_MS < STALE_CLAIM_MS);
    lease = await acquireSlot({ directory, slots: 1, heartbeatMs: 20 });
    const claimFile = path.join(lease.slot, readdirSync(lease.slot)[0]);
    const old = (Date.now() - 600_000) / 1000;
    utimesSync(claimFile, old, old);
    await new Promise((r) => setTimeout(r, 200));
    assert.ok(Date.now() - statSync(claimFile).mtimeMs < STALE_CLAIM_MS);
    assert.equal(namedRunMustWait({ directory, slots: 1 }), true);
  } finally {
    lease?.release();
    rmSync(directory, { recursive: true, force: true });
  }
});

test("a stale waiter directory is swept and a fresh one is kept", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-waiters-"));
  let lease;
  try {
    const waiter = (name, ageMs) => {
      const dir = path.join(directory, name);
      mkdirSync(dir);
      writeFileSync(path.join(dir, name), "99999999");
      const t = (Date.now() - ageMs) / 1000;
      utimesSync(dir, t, t);
      return dir;
    };
    const stale = waiter("claim-1-stale", STALE_CLAIM_MS + 60_000);
    const fresh = waiter("claim-2-fresh", 1000);
    lease = await acquireSlot({
      directory,
      slots: 1,
      sleep: async () => assert.fail("unexpected wait"),
    });
    assert.equal(existsSync(stale), false);
    assert.equal(existsSync(fresh), true);
  } finally {
    lease?.release();
    rmSync(directory, { recursive: true, force: true });
  }
});

// Rule: named runs acquire a slot, rather than just observing the pool.
test("waitForMachine claims a slot and records wait duration", async () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), "smoke-named-slot-"));
  const exitsBefore = new Set(process.listeners("exit"));
  try {
    const waited = await waitForMachine({
      directory,
      slots: 1,
      sleep: async () => assert.fail("unexpected wait"),
    });
    assert.equal(typeof waited, "number");
    assert.equal(namedRunMustWait({ directory, slots: 1 }), true);
  } finally {
    for (const listener of process.listeners("exit")) {
      if (!exitsBefore.has(listener)) {
        listener();
        process.removeListener("exit", listener);
      }
    }
    rmSync(directory, { recursive: true, force: true });
  }
});

// Rule: independent processes publish complete claims and release them on exit.
test(
  "independent runs share slots and reclaim a killed holder",
  { timeout: 10_000 },
  async () => {
    const directory = mkdtempSync(
      path.join(os.tmpdir(), "smoke-process-slots-"),
    );
    const children = [];
    const source = `
    import { acquireMachine } from ${JSON.stringify(new URL("./sketch-smoke.mjs", import.meta.url).href)};
    console.log = () => process.send({ kind: "waiting" });
    process.on("message", () => process.exit(0));
    const waitMs = await acquireMachine(5);
    process.send({ kind: "acquired", waitMs });
  `;
    const start = () => {
      const child = spawn(
        process.execPath,
        ["--input-type", "module", "-e", source],
        {
          env: {
            ...process.env,
            SCRAPKEEP_LOCK_DIR: directory,
            SMOKE_SLOTS: "2",
          },
          stdio: ["ignore", "pipe", "pipe", "ipc"],
        },
      );
      const closed = once(child, "close");
      children.push({ child, closed });
      return child;
    };
    try {
      const first = start();
      assert.equal((await once(first, "message"))[0].kind, "acquired");
      const second = start();
      assert.equal((await once(second, "message"))[0].kind, "acquired");
      const third = start();
      assert.equal((await once(third, "message"))[0].kind, "waiting");
      const acquired = once(third, "message");
      first.kill("SIGKILL");
      assert.equal((await acquired)[0].kind, "acquired");
      assert.equal(
        readdirSync(
          path.join(directory, "scrapkeep-sketch-smoke.slots"),
        ).filter((name) => name.startsWith("slot-")).length,
        2,
      );
      second.send("release");
      third.send("release");
      await Promise.all(children.map(({ closed }) => closed));
      assert.deepEqual(
        readdirSync(path.join(directory, "scrapkeep-sketch-smoke.slots")),
        [],
      );
    } finally {
      for (const { child } of children) {
        if (child.exitCode === null && child.signalCode === null)
          child.kill("SIGKILL");
      }
      await Promise.all(children.map(({ closed }) => closed));
      rmSync(directory, { recursive: true, force: true });
    }
  },
);

// Rule: the receipt preserves measured lock_wait_ms for its existing readers.
test("the receipt keeps a nonzero lock wait", () => {
  const receipt = buildReceipt({
    label: "gate",
    argv: [],
    root: "/r",
    git: null,
    godot: {},
    sketches: [],
    flags: [],
    width: 2,
    lockWaitMs: 17,
    startedAt: "t",
    wallMs: 0,
    stems: {},
    results: [],
  });
  assert.equal(receipt.lock_wait_ms, 17);
});

test("the receipt carries every field and its totals", () => {
  const results = [
    { label: "s import", ok: true, exit: 0, ms: 5, solo: false, passes: 0, fails: 0, verdict_line: null, skips: [] },
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 9, solo: false, passes: 3, fails: 0, verdict_line: true, skips: ["SKIP x"] },
    { label: "s res://tests/b.gd", ok: false, exit: 1, ms: 7, solo: true, passes: 1, fails: 1, verdict_line: false, skips: [] },
  ];
  const receipt = buildReceipt({
    label: "named",
    argv: ["--test", "a"],
    root: "/r",
    git: { head: "h", tree: "t".repeat(40), clean: false, dirty_paths: ["x"] },
    godot: { binary: "/g", version: "4.7.2" },
    sketches: ["sketches/s"],
    flags: ["--scrap=armor"],
    width: 2,
    lockWaitMs: 0,
    startedAt: "2026-10-01T00:00:00.000Z",
    wallMs: 21,
    stems: { "sketches/s": 4 },
    results,
  });
  assert.equal(receipt.schema, "scrapkeep-smoke-receipt/1");
  assert.deepEqual(receipt.totals, { runs: 3, failed: 1, skipped: 1, missing_verdict: 1, quarantined_red: [], quarantine_stale: [] });
  assert.equal(receipt.ok, false);
  for (const key of ["label", "argv", "root", "head", "tree", "clean", "dirty_paths", "godot", "sketches", "flags", "width", "lock_wait_ms", "started_at", "wall_ms", "stems", "results", "totals", "ok"]) {
    assert.ok(key in receipt, key);
  }
  assert.deepEqual(Object.keys(receipt.results[1]), ["label", "ok", "exit", "ms", "solo", "passes", "fails", "verdict_line", "skips"]);
  assert.equal(receiptFileName("named", receipt.tree, receipt.started_at), "named-tttttttttttt-2026-10-01T00-00-00-000Z.json");
});

test("without git the receipt's git fields are null", () => {
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: [] });
  assert.equal(receipt.head, null);
  assert.equal(receipt.tree, null);
  assert.equal(receipt.clean, null);
  assert.equal(receipt.ok, true);
  assert.equal(receiptFileName("x", null, "2026-10-01T00:00:00.000Z"), "x-nogit-2026-10-01T00-00-00-000Z.json");
});

const result = (label, ok, extra = {}) => ({ label, ok, exit: ok ? 0 : 1, ms: 1, solo: false, passes: 0, fails: 0, verdict_line: true, skips: [], ...extra });
const testLabel = (name) => `sketches/core-loop res://tests/${name}.gd`;

test("the quarantine file parses into entries and names", () => {
  const text = "test\towner\treason\tadded\tdeadline\na_test\tO1\twhy\t2026-10-01\twave 3\r\n\nb_test\tB0\tbecause\t2026-10-01\twave 3\n";
  assert.deepEqual(parseQuarantine(text)[0], { test: "a_test", owner: "O1", reason: "why", added: "2026-10-01", deadline: "wave 3" });
  assert.deepEqual([...quarantinedNames(text)], ["a_test", "b_test"]);
  assert.deepEqual(parseQuarantine(""), []);
});

test("a quarantined failure names its owner and reason, and the readers agree", () => {
  const entry = parseQuarantine("test\towner\treason\tadded\tdeadline\na_test\tO1\twhy; #1\t2026-10-01\twave 3\n")[0];
  assert.equal(quarantineNote(entry), "quarantined: a_test (O1: why; #1)");
  const dir = mkdtempSync(path.join(os.tmpdir(), "quarantine-"));
  try {
    mkdirSync(path.join(dir, "tests"));
    writeFileSync(path.join(dir, "tests", "QUARANTINE.tsv"), "test\towner\treason\tadded\tdeadline\nfixture_test\tSystems\texit abort after 12 passing checks; #241 1\t2026-10-22\t2026-10-29\n");
    const rows = readQuarantineEntries(dir);
    const fixture = rows.find((row) => row.test === "fixture_test");
    assert.equal(fixture.owner, "Systems");
    assert.match(quarantineNote(fixture), /^quarantined: fixture_test \(Systems: exit abort .*#241 1\)$/);
    assert.deepEqual([...readQuarantine(dir)], rows.map((row) => row.test));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("an expired quarantine row is reported and an unexpired or free-text one is not", () => {
  const rows = parseQuarantine("test\towner\treason\tadded\tdeadline\na_test\tO1\twhy\t2026-10-01\t2026-10-29\nb_test\tO2\twhy\t2026-10-01\twave 3\n");
  assert.deepEqual(expiredQuarantine(rows, "2026-10-29"), []);
  const late = expiredQuarantine(rows, "2026-10-30");
  assert.deepEqual(late.map((row) => row.test), ["a_test"]);
  assert.equal(expiredLine(late[0]).startsWith("quarantine expired: a_test (O1) deadline 2026-10-29"), true);
});

test("quarantine rows reach the human output and the receipt with that run's result", () => {
  const entry = { test: "a_test", owner: "Systems", reason: "why; #1", added: "2026-10-22", deadline: "2026-10-29" };
  const stale = { ...entry, test: "b_test" };
  const results = [
    result(testLabel("a_test"), false, { quarantined: true, quarantine: entry, exit: null, signal: "SIGABRT", fails: 0 }),
    result(testLabel("b_test"), true, { quarantined: true, quarantine: stale, exit: 0, fails: 0 }),
    result(testLabel("c_test"), true),
  ];
  const records = quarantineRecords(results);
  assert.deepEqual(records.map((row) => [row.test, row.result, row.signal, row.failing_checks]), [["a_test", "red", "SIGABRT", 0], ["b_test", "green", null, 0]]);
  const lines = quarantineLines(records);
  assert.ok(lines.some((line) => line.includes("a_test: 0 failing checks, signal SIGABRT (Systems: why; #1; deadline 2026-10-29)")));
  assert.ok(lines.some((line) => line.startsWith("quarantined but green")) && lines.some((line) => line.includes("b_test")));
  const receipt = buildReceipt({ label: "t", argv: [], root: "/r", git: null, godot: "g", sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "x", wallMs: 1, stems: {}, results, expired: [] });
  assert.equal(receipt.quarantined.length, 2);
  assert.deepEqual(Object.keys(receipt.quarantined[0]).sort(), ["deadline", "exit", "failing_checks", "owner", "reason", "result", "signal", "test"]);
});

test("a red quarantined test does not fail the run, a green one is stale, any other failure fails", () => {
  const red = [result("sketches/core-loop import", true), result(testLabel("a_test"), false, { quarantined: true }), result(testLabel("c_test"), true)];
  assert.equal(runPasses(red), true);
  assert.deepEqual(quarantineVerdict(red).quarantined_red, ["a_test"]);
  assert.deepEqual(quarantineVerdict(red).quarantine_stale, []);
  const green = [result(testLabel("a_test"), true, { quarantined: true })];
  assert.equal(runPasses(green), true);
  assert.deepEqual(quarantineVerdict(green).quarantine_stale, ["a_test"]);
  assert.equal(runPasses([...red, result(testLabel("d_test"), false)]), false);
});

test("the receipt lists quarantine outcomes and never counts them as failed", () => {
  const receipt = buildReceipt({
    label: "named", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {},
    results: [result(testLabel("a_test"), false, { quarantined: true }), result(testLabel("b_test"), true, { quarantined: true }), result(testLabel("c_test"), true)],
  });
  assert.equal(receipt.totals.failed, 0);
  assert.deepEqual(receipt.totals.quarantined_red, ["a_test"]);
  assert.deepEqual(receipt.totals.quarantine_stale, ["b_test"]);
  assert.equal(receipt.results[0].quarantined, true);
  assert.equal("quarantined" in receipt.results[2], false);
  assert.equal(receipt.ok, true);
});

test("a gate run refuses launch flags from --flags or the environment", () => {
  assert.match(gateFlagsError(parseArgs(["--receipt", "gate", "--flags", "--scrap=armor"])), /refuses launch flags/);
  assert.match(gateFlagsError(parseArgs(["--receipt", "gate"], { SMOKE_FLAGS: "--music=ace" })), /SMOKE_FLAGS/);
  assert.equal(gateFlagsError(parseArgs(["--receipt", "gate"], {})), null);
  assert.equal(gateFlagsError(parseArgs(["--flags", "--scrap=armor"])), null);
});

test("a receipt that cannot be written is exit 3 and one clear line", () => {
  const lines = [];
  const code = emitReceipt({ label: "x" }, () => { throw new Error("ENOSPC: no space left"); }, (line) => lines.push(line));
  assert.equal(code, 3);
  assert.equal(lines.length, 1);
  assert.match(lines[0], /could not write the receipt under .*receipts: ENOSPC/);
  const ok = [];
  assert.equal(emitReceipt({ label: "x" }, () => "/p/x.json", (line) => ok.push(line)), null);
  assert.deepEqual(ok, ["receipt /p/x.json"]);
});

test("every export the runner had before the quarantine unit still exists", async () => {
  const module = await import("./sketch-smoke.mjs");
  for (const name of ["binary", "sketchDirectories", "testScripts", "isSolo", "isSoloScript", "jobCount", "skipLines", "hasVerdictLine", "countChecks", "globToRegExp", "matchesGlob", "selectTests", "splitFlags", "parseArgs", "validateRun", "noMatchMessage", "acquireMachine", "namedRunMustWait", "waitForMachine", "receiptFileName", "buildReceipt"]) {
    assert.ok(name in module, name);
  }
});

test("a test that exits 0 with no verdict line fails and says why", () => {
  const ended = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] y -> PASS\n" });
  assert.equal(ended.ok, false);
  assert.equal(ended.missing, true);
  assert.equal(ended.reason, MISSING_VERDICT);
  assert.equal(MISSING_VERDICT, "no verdict line: the test ended early");
  const done = judge({ test: true, status: 0, output: "[a] x -> PASS\nsuite_test: PASS (1 checks)\n" });
  assert.equal(done.ok, true);
  assert.equal(done.missing, false);
  const skipped = judge({ test: true, status: 0, output: "[ace] stems missing -> SKIP\n" });
  assert.equal(skipped.ok, true);
  assert.equal(skipped.missing, false);
  assert.equal(skipped.skips.length, 1);
  assert.equal(judge({ test: false, status: 0, output: "booted\n" }).ok, true);
  assert.equal(judge({ test: true, status: 1, output: "suite_test: FAIL (1 of 2 checks)\n" }).ok, false);
  assert.equal(done.reason, null);
  assert.equal(skipped.reason, null);
});

test("a nonzero exit and a kill give their own reason, not the missing-verdict one", () => {
  const crashed = judge({ test: true, status: 1, output: "[a] x -> PASS\n" });
  assert.equal(crashed.ok, false);
  assert.equal(crashed.reason, "the test exited with code 1");
  assert.notEqual(crashed.reason, MISSING_VERDICT);
  const killed = judge({ test: true, status: null, output: "[a] x -> PASS\n" });
  assert.equal(killed.ok, false);
  assert.equal(killed.reason, "the test was killed at the time limit or by a signal");
  const failed = judge({ test: true, status: 0, output: "suite_test: FAIL (1 of 2 checks)\n" });
  assert.equal(failed.reason, "the test printed a FAIL verdict");
});

test("a skip line exempts a test only when no check ran", () => {
  const mixed = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] stems missing -> SKIP\n" });
  assert.equal(mixed.ok, false);
  assert.equal(mixed.missing, true);
  assert.equal(mixed.reason, MISSING_VERDICT);
  const withVerdict = judge({ test: true, status: 0, output: "[a] x -> PASS\n[b] stems missing -> SKIP\nsuite_test: PASS (1 checks)\n" });
  assert.equal(withVerdict.ok, true);
});

test("a FAIL verdict fails the test whatever the exit code and wherever the line sits", () => {
  const early = judge({ test: true, status: 0, output: "suite_test: FAIL (1 of 2 checks)\ntrailing line\n" });
  assert.equal(early.ok, false);
  assert.equal(early.missing, false);
  assert.equal(early.reason, "the test printed a FAIL verdict");
  const both = judge({ test: true, status: 0, output: "suite_test: PASS (2 checks)\nsuite_test: FAIL (1 of 2 checks)\n" });
  assert.equal(both.ok, false);
});

test("a skipped test is not counted as missing a verdict in the receipt", () => {
  const rows = [
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 1, passes: 0, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
    { label: "s res://tests/b.gd", ok: false, exit: 0, ms: 1, passes: 2, fails: 0, verdict_line: false, skips: [] },
  ];
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: rows });
  assert.equal(receipt.totals.missing_verdict, 1);
  assert.equal(receipt.totals.skipped, 1);
});

test("the receipt counts a skip line with checks and no verdict as missing, as judge does", () => {
  const rows = [
    { label: "s res://tests/a.gd", ok: true, exit: 0, ms: 1, passes: 0, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
    { label: "s res://tests/c.gd", ok: false, exit: 0, ms: 1, passes: 1, fails: 0, verdict_line: false, skips: ["SKIP stems"] },
  ];
  const receipt = buildReceipt({ label: "x", argv: [], root: "/r", git: null, godot: { binary: "/g", version: null }, sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "t", wallMs: 0, stems: {}, results: rows });
  assert.equal(receipt.totals.missing_verdict, 1);
  assert.equal(receipt.totals.skipped, 2);
});

test("an error line under a PASS verdict fails with its own reason", () => {
  const errored = judge({ test: true, status: 0, output: "SCRIPT ERROR: bad call\nsuite_test: PASS (2 checks)\n" });
  assert.equal(errored.ok, false);
  assert.equal(errored.reason, "the test printed an error line");
});

test("a script error inside an awaited part of a test cannot pass", { skip: !existsSync(binary) }, () => {
  const project = mkdtempSync(path.join(os.tmpdir(), "verdict-fixture-"));
  try {
    writeFileSync(path.join(project, "project.godot"), 'config_version=5\n[application]\nconfig/name="fixture"\n');
    writeFileSync(
      path.join(project, "hazard.gd"),
      [
        "extends SceneTree",
        "func _initialize() -> void:",
        "\t_run.call_deferred()",
        "func _part() -> void:",
        '\tprint("[one] first -> PASS")',
        "\tawait process_frame",
        "\tvar empty: Dictionary = {}",
        '\tvar broken = empty["absent"].call()',
        '\tprint("[two] second -> PASS")',
        "func _run() -> void:",
        "\tawait _part()",
        "\tquit(0)",
        "",
      ].join("\n"),
    );
    const run = spawnSync(binary, ["--headless", "--path", project, "--script", "hazard.gd"], {
      encoding: "utf8",
      timeout: 60_000,
      env: { ...process.env, XDG_DATA_HOME: path.join(project, "data") },
    });
    const output = (run.stdout || "") + (run.stderr || "");
    assert.equal(run.status, 0);
    assert.match(output, /^SCRIPT ERROR/m);
    assert.match(output, /\[one\] first -> PASS/);
    assert.doesNotMatch(output, /\[two\]/);
    assert.equal(hasVerdictLine(output), false);
    const judged = judge({ test: true, status: run.status, output });
    assert.equal(judged.ok, false);
    assert.equal(judged.missing, true);
    const withoutErrorLines = output.split("\n").filter((line) => !/^SCRIPT ERROR/.test(line)).join("\n");
    const quiet = judge({ test: true, status: 0, output: withoutErrorLines });
    assert.equal(quiet.ok, false);
    assert.equal(quiet.missing, true);
  } finally {
    rmSync(project, { recursive: true, force: true });
  }
});

test("the time scale stretches a limit past the ceilings and refuses a value out of range", () => {
  assert.equal(timeScale({}), 1);
  assert.equal(timeScale({ SMOKE_TIME_SCALE: "1.5" }), 1.5);
  assert.throws(() => timeScale({ SMOKE_TIME_SCALE: "0.5" }), /from 1 to 4/);
  assert.throws(() => timeScale({ SMOKE_TIME_SCALE: "9" }), /from 1 to 4/);
  assert.throws(() => timeScale({ SMOKE_TIME_SCALE: "fast" }), /from 1 to 4/);
  assert.equal(testTimeoutMs("# smoke: solo timeout=360s\n"), 360_000);
  assert.equal(testTimeoutMs("# smoke: solo timeout=360s\n", 1.5), 540_000);
  assert.equal(testTimeoutMs("# smoke: solo timeout=900s\n", 1.5), 540_000, "the marker still stops at its ceiling before the scale");
  assert.equal(testTimeoutMs("# smoke: bots timeout=1800s\n", 1.5), 2_700_000);
  assert.equal(testTimeoutMs("extends SceneTree\n", 2), 360_000);
});

test("a receipt names the time scale only when one was used", () => {
  const base = { label: "t", argv: [], root: "/r", git: null, godot: "g", sketches: [], flags: [], width: 1, lockWaitMs: 0, startedAt: "x", wallMs: 1, stems: {}, results: [] };
  assert.equal("time_scale" in buildReceipt(base), false);
  assert.equal(buildReceipt({ ...base, timeScale: 1.5 }).time_scale, 1.5);
});

test("a failure lists its failed checks, engine errors and time-outs, and caps the list", () => {
  const output = [
    "  [a check] 3 -> PASS",
    "  [small median] 119.1 s against 103.8 s -> FAIL",
    "ERROR: res://src/world/ambient_life.gd:85 - Invalid call",
    "SCRIPT ERROR: Invalid call. Nonexistent function 'run' in base 'CtxDouble'.",
    "child class 5 timed out after 100 s",
    "an ordinary line that mentions errors in passing",
  ].join("\n");
  assert.deepEqual(failingLines(output).map((line) => line.trim().slice(0, 14)), ["[small median]", "ERROR: res://s", "SCRIPT ERROR: ", "child class 5 "]);
  assert.deepEqual(failingLines("SCRIPT ERROR: no 'run'\nok\nSCRIPT ERROR: no 'run'\n"), ["SCRIPT ERROR: no 'run' (x2)"]);
  assert.deepEqual(failingLines("[child] exit 0, timed out false -> PASS\nFAIL boss_weak_crew child 3\n[child] timed out true -> FAIL\n"), ["FAIL boss_weak_crew child 3", "[child] timed out true -> FAIL"]);
  const many = Array.from({ length: 70 }, (_, index) => `[check ${index}] -> FAIL`).join("\n");
  const capped = failingLines(many, 60);
  assert.equal(capped.length, 61);
  assert.match(capped[60], /10 more failing lines/);
});

test("a test's kept log is named after the test, whatever its sketch", () => {
  assert.equal(logFileName("sketches/core-loop res://tests/kest_set_piece_test.gd"), "kest_set_piece_test.log");
  assert.equal(logFileName("sketches/core-loop import"), "sketches_core-loop_import.log");
});
