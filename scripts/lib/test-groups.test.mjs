import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { groupId, testGroups } from "./test-groups.mjs";

function fakeTest() {
  const hooks = [];
  const notes = [];
  return {
    hooks,
    notes,
    after: (fn) => hooks.push(fn),
    diagnostic: (message) => notes.push(message),
  };
}

function recording(error = null) {
  const calls = [];
  const kill = (pid, sig) => {
    calls.push([pid, sig]);
    if (error) throw error(pid);
  };
  return { calls, kill };
}

const TOO_LARGE = [2147483648, 4294967296, 4294967297, Number.MAX_SAFE_INTEGER];

test("groupId takes only an integer from 2 to 2147483647", () => {
  for (const bad of [
    "",
    "0",
    "1",
    "-5",
    -5,
    0,
    1,
    1.5,
    "12ab",
    " 12",
    "12\n",
    NaN,
    null,
    undefined,
    -0,
    Infinity,
    "1e5",
    "0x10",
    "+42",
    1e21,
    ...TOO_LARGE,
    ...TOO_LARGE.map(String),
  ])
    assert.equal(groupId(bad), null, JSON.stringify(bad));
  assert.equal(groupId("4321"), 4321);
  assert.equal(groupId(4321), 4321);
  assert.equal(groupId(2147483647), 2147483647);
  assert.equal(groupId("2147483647"), 2147483647);
});

test("cleanup signals no group for an empty, 0, 1, negative or text id, nor one marked gone", () => {
  const t = fakeTest();
  const { calls, kill } = recording();
  const groups = testGroups(t, { kill });
  for (const bad of ["", "0", "1", "-7", -7, "seven", ...TOO_LARGE, ...TOO_LARGE.map(String)])
    assert.equal(groups.add(bad), null);
  groups.add(4001);
  groups.add("4002");
  groups.gone(4002);
  groups.add(4002);
  assert.equal(t.hooks.length, 1);
  t.hooks[0]();
  assert.deepEqual(calls, [[-4001, "SIGKILL"]]);
  t.hooks[0]();
  assert.deepEqual(calls, [[-4001, "SIGKILL"]], "a reaped group is not signalled twice");
});

test("cleanup reads only complete lines from the id file, and a missing file adds nothing", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "test-groups-"));
  try {
    const file = path.join(dir, "groups");
    const t = fakeTest();
    const { calls, kill } = recording();
    const groups = testGroups(t, { from: file, kill });
    groups.reap();
    assert.deepEqual(calls, []);
    writeFileSync(file, "\n0\n1\n5001\nx\n5002\n50");
    groups.reap();
    assert.deepEqual(calls, [
      [-5001, "SIGKILL"],
      [-5002, "SIGKILL"],
    ]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("cleanup never throws: it signals every group, ignores ESRCH and EPERM, and notes the rest", () => {
  const t = fakeTest();
  const codes = { [-6001]: "ESRCH", [-6002]: "EPERM", [-6003]: "EINVAL" };
  const { calls, kill } = recording((pid) =>
    Object.assign(new Error(`kill ${codes[pid]}`), { code: codes[pid] }),
  );
  const groups = testGroups(t, { kill });
  for (const id of [6001, 6002, 6003]) groups.add(id);
  assert.doesNotThrow(() => t.hooks[0]());
  assert.deepEqual(
    calls.map(([pid]) => pid),
    [-6001, -6002, -6003],
  );
  assert.equal(t.notes.length, 1);
  assert.match(t.notes[0], /could not signal group 6003: kill EINVAL/);
});

test("sweep marks a group gone once no such group exists, so cleanup leaves it alone", () => {
  const t = fakeTest();
  const alive = new Set([-7001]);
  const calls = [];
  const kill = (pid, sig) => {
    calls.push([pid, sig]);
    if (!alive.has(pid)) throw Object.assign(new Error("no such group"), { code: "ESRCH" });
  };
  const groups = testGroups(t, { kill });
  groups.add(7001);
  groups.add(7002);
  groups.sweep();
  calls.length = 0;
  t.hooks[0]();
  assert.deepEqual(calls, [[-7001, "SIGKILL"]]);
});

test("cleanup kills a live group the test started", { timeout: 30_000 }, async (t) => {
  const child = spawn("sleep", ["45"], { detached: true, stdio: "ignore" });
  t.after(() => {
    if (child.exitCode === null && child.signalCode === null) child.kill("SIGKILL");
  });
  const exited = new Promise((resolve) => child.once("exit", (code, signal) => resolve(signal)));
  const groups = testGroups(t);
  assert.equal(groups.add(child.pid), child.pid);
  groups.reap();
  assert.equal(await exited, "SIGKILL");
});
