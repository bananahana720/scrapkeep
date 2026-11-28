import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { groupLive, pool, runProcess, stopGroup, waitGroupDead } from "./proc.mjs";

function pidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code !== "ESRCH";
  }
}

test("proc: runProcess collects stdout, stderr, interleaved output, and writes logFile", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "proc-test-basic-"));
  try {
    const logFile = path.join(dir, "out.log");
    const res = await runProcess(
      process.execPath,
      ["-e", 'process.stdout.write("hello\\n"); process.stderr.write("warn\\n");'],
      { logFile },
    );
    assert.equal(res.exit, 0);
    assert.equal(res.signal, null);
    assert.equal(res.timedOut, false);
    assert.equal(res.aborted, false);
    assert.equal(res.stdout, "hello\n");
    assert.equal(res.stderr, "warn\n");
    assert.ok(res.output.includes("hello\n"));
    assert.ok(res.output.includes("warn\n"));
    assert.equal(readFileSync(logFile, "utf8"), res.output);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("proc: runProcess reaps grandchild process group on timeout", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "proc-test-timeout-"));
  try {
    const pidFile = path.join(dir, "child.pid");
    const res = await runProcess("/bin/sh", ["-c", `sleep 30 & echo $! > "${pidFile}"; wait`], {
      timeoutMs: 250,
    });
    assert.equal(res.timedOut, true);
    assert.equal(res.aborted, false);
    assert.ok(existsSync(pidFile));
    const grandchild = Number(readFileSync(pidFile, "utf8").trim());
    assert.ok(Number.isInteger(grandchild) && grandchild > 0);
    await waitGroupDead(res.pid, 1500);
    assert.equal(pidAlive(grandchild), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("proc: runProcess reaps stubborn grandchild group with SIGTERM grace and reapOnClose", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "proc-test-grace-"));
  try {
    const pidFile = path.join(dir, "child.pid");
    const res = await runProcess(
      "/bin/sh",
      ["-c", `trap '' TERM; sleep 30 & echo $! > "${pidFile}"; wait`],
      { timeoutMs: 200, killGraceMs: 200, reapOnClose: true, exitDrainMs: 300 },
    );
    assert.equal(res.timedOut, true);
    assert.equal(res.signal, "SIGKILL");
    const grandchild = Number(readFileSync(pidFile, "utf8").trim());
    assert.equal(pidAlive(grandchild), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("proc: runProcess aborts and reaps grandchild process group via AbortSignal", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "proc-test-abort-"));
  try {
    const pidFile = path.join(dir, "child.pid");
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 250);
    let res;
    try {
      res = await runProcess("/bin/sh", ["-c", `sleep 30 & echo $! > "${pidFile}"; wait`], {
        timeoutMs: 10_000,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
    assert.equal(res.aborted, true);
    assert.equal(res.timedOut, false);
    assert.equal(res.signal, "SIGKILL");
    const grandchild = Number(readFileSync(pidFile, "utf8").trim());
    await waitGroupDead(res.pid, 1500);
    assert.equal(pidAlive(grandchild), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("proc: a signal that lands the moment the child starts still reaps its group", async () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "proc-test-signal-"));
  let pgid = 0;
  try {
    const pidFile = path.join(dir, "child.pid");
    const runner = path.join(dir, "runner.mjs");
    writeFileSync(
      runner,
      `import { writeFileSync } from "node:fs";
import { runProcess } from ${JSON.stringify(fileURLToPath(new URL("./proc.mjs", import.meta.url)))};
const res = await runProcess("/bin/sh", ["-c", "sleep 30 & wait"], {
  timeoutMs: 20000,
  forwardSignals: true,
  onChild: (child) => {
    writeFileSync(${JSON.stringify(pidFile)}, String(child.pid));
    process.kill(process.pid, "SIGTERM");
  },
});
process.exit(res.interrupted ?? 1);
`,
    );
    const node = spawn(process.execPath, [runner], { stdio: "ignore" });
    const [code, signal] = await new Promise((resolve) =>
      node.on("exit", (...ended) => resolve(ended)),
    );
    pgid = Number(readFileSync(pidFile, "utf8"));
    assert.deepEqual([code, signal], [143, null]);
    await waitGroupDead(pgid, 1500);
    assert.equal(groupLive(pgid), false);
  } finally {
    if (pgid > 0) {
      try {
        process.kill(-pgid, "SIGKILL");
      } catch {}
    }
    rmSync(dir, { recursive: true, force: true });
  }
});

test("proc: an onChild that throws on a child that failed to start rejects with the callback's error only", async () => {
  const uncaught = [];
  const onUncaught = (error) => uncaught.push(error);
  process.on("uncaughtException", onUncaught);
  try {
    await assert.rejects(
      runProcess(path.join(os.tmpdir(), "no-such-binary-proc-test"), [], {
        timeoutMs: 20000,
        onChild: () => {
          throw new Error("onChild failed");
        },
      }),
      /onChild failed/,
    );
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.deepEqual(uncaught, []);
  } finally {
    process.off("uncaughtException", onUncaught);
  }
});

test("proc: an onChild that throws stops the child and leaves no signal listener", async () => {
  const before = { int: process.listenerCount("SIGINT"), term: process.listenerCount("SIGTERM") };
  let pgid = 0;
  try {
    await assert.rejects(
      runProcess("/bin/sh", ["-c", "sleep 30 & wait"], {
        timeoutMs: 20000,
        forwardSignals: true,
        onChild: (child) => {
          pgid = child.pid;
          throw new Error("onChild failed");
        },
      }),
      /onChild failed/,
    );
    assert.deepEqual(
      { int: process.listenerCount("SIGINT"), term: process.listenerCount("SIGTERM") },
      before,
    );
    assert.ok(pgid > 0);
    await waitGroupDead(pgid, 1500);
    assert.equal(groupLive(pgid), false);
  } finally {
    if (pgid > 0) {
      try {
        process.kill(-pgid, "SIGKILL");
      } catch {}
    }
  }
});

test("proc: pool preserves order, respects width, and invokes onDone", async () => {
  assert.deepEqual(await pool([], 4), []);
  let active = 0;
  let peak = 0;
  const done = [];
  const tasks = [30, 10, 20, 5, 15].map((delay, i) => async () => {
    active++;
    peak = Math.max(peak, active);
    await new Promise((resolve) => setTimeout(resolve, delay));
    active--;
    return i * 10;
  });
  const results = await pool(tasks, 2, { onDone: (value, index) => done.push([index, value]) });
  assert.deepEqual(results, [0, 10, 20, 30, 40]);
  assert.equal(peak, 2);
  assert.equal(done.length, 5);
  assert.equal(typeof stopGroup, "function");
});
