import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";

const scripts = path.dirname(fileURLToPath(import.meta.url));
const scratch = mkdtempSync(path.join(tmpdir(), "play-args-"));
const fixture = path.join(scratch, "repo");
mkdirSync(path.join(fixture, "sketches", "demo"), { recursive: true });
writeFileSync(path.join(fixture, "sketches", "demo", "project.godot"), "");
cpSync(scripts, path.join(fixture, "scripts"), { recursive: true });
const play = path.join(fixture, "scripts", "play.mjs");
const log = path.join(scratch, "args.txt");
const stub = path.join(scratch, "godot-stub");
writeFileSync(stub, `#!/bin/sh\nprintf '%s\\n' "$@" > "${log}"\nexit 0\n`);
chmodSync(stub, 0o755);

after(() => rmSync(scratch, { recursive: true, force: true }));

function launch(args) {
  rmSync(log, { force: true });
  const result = spawnSync(process.execPath, [play, ...args], {
    encoding: "utf8",
    env: { ...process.env, GODOT_BIN: stub },
  });
  let forwarded = null;
  try {
    forwarded = readFileSync(log, "utf8").split("\n").filter((line) => line !== "");
  } catch {
    forwarded = null;
  }
  return { result, forwarded };
}

function flagsOf(forwarded) {
  assert.notEqual(forwarded, null, "Godot stub was never launched");
  assert.equal(forwarded[0], "--path");
  return forwarded.slice(2);
}

test("a bare name forwards flags that follow it without --", () => {
  const { result, forwarded } = launch(["demo", "--loop=drop", "--gun=hold"]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(flagsOf(forwarded), ["--loop=drop", "--gun=hold"]);
});

test("the -- form still forwards flags", () => {
  const { result, forwarded } = launch(["demo", "--", "--loop=drop"]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(flagsOf(forwarded), ["--loop=drop"]);
});

test("the play verb forwards flags that follow the name", () => {
  const { result, forwarded } = launch(["play", "demo", "--loop=drop"]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(flagsOf(forwarded), ["--loop=drop"]);
});

test("flags before and after -- both reach Godot", () => {
  const { result, forwarded } = launch(["demo", "--gun=hold", "--", "--loop=drop"]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(flagsOf(forwarded), ["--gun=hold", "--loop=drop"]);
});

test("a bare name with no flags forwards none", () => {
  const { result, forwarded } = launch(["demo"]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(flagsOf(forwarded), []);
});
