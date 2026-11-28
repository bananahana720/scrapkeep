import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { pool, runProcess, stopGroup, waitGroupDead } from "./proc.mjs";

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
