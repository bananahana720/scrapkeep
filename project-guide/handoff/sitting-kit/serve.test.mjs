import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { HOST, MAX_BODY, createKitServer, readBuild } from "./serve.mjs";

async function withServer(run) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "sitting-kit-"));
  const file = path.join(dir, "out", "verdicts.json");
  const server = createKitServer({ port: 0, verdictFile: file, buildOf: () => ({ sha: "a".repeat(40), short: "aaaaaaaa", subject: "s", dirty: false }) });
  await new Promise((resolve) => server.listen(0, HOST, resolve));
  const port = server.address().port;
  const base = `http://${HOST}:${port}`;
  try {
    await run({ base, file, port });
  } finally {
    await new Promise((resolve) => server.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  }
}

test("serves the page, the data file and the build, and refuses everything else", async () => {
  await withServer(async ({ base }) => {
    const page = await fetch(`${base}/`);
    assert.equal(page.status, 200);
    assert.match(page.headers.get("content-type"), /text\/html/);
    assert.match(await page.text(), /Sitting Kit/);
    assert.equal((await fetch(`${base}/areas.js`)).status, 200);
    assert.equal((await fetch(`${base}/serve.mjs`)).status, 404, "the server source is not served");
    assert.equal((await fetch(`${base}/..%2F..%2FDECISIONS.md`)).status, 404, "no path walks out of the folder");
    assert.equal((await fetch(`${base}/api/build`).then((r) => r.json())).short, "aaaaaaaa");
    assert.equal((await fetch(`${base}/anything`, { method: "DELETE" })).status, 405);
  });
});

test("verdicts round-trip through disk and a bad body is refused without touching the file", async () => {
  await withServer(async ({ base, file }) => {
    assert.deepEqual(await fetch(`${base}/api/verdicts`).then((r) => r.json()), {});
    const saved = { areas: { "core-feel": { verdict: "accept", note: "tight" } } };
    const post = await fetch(`${base}/api/verdicts`, { method: "POST", body: JSON.stringify(saved) });
    assert.equal(post.status, 200);
    assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), saved);
    assert.deepEqual(await fetch(`${base}/api/verdicts`).then((r) => r.json()), saved);
    for (const body of ["not json", "[1]", "null", "3"]) {
      const bad = await fetch(`${base}/api/verdicts`, { method: "POST", body });
      assert.equal(bad.status, 400, `body ${body} is refused`);
    }
    assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), saved, "refused bodies leave the last good copy");
  });
});

test("an oversized body is refused and a write from another origin is refused", async () => {
  await withServer(async ({ base, file }) => {
    const big = JSON.stringify({ note: "x".repeat(MAX_BODY + 10) });
    const response = await fetch(`${base}/api/verdicts`, { method: "POST", body: big }).catch(() => null);
    assert.ok(response === null || response.status === 413, "oversized body is cut off");
    const foreign = await fetch(`${base}/api/verdicts`, { method: "POST", headers: { origin: "http://evil.example" }, body: "{}" });
    assert.equal(foreign.status, 403);
    assert.deepEqual(await fetch(`${base}/api/verdicts`).then((r) => r.json()), {}, "nothing was written");
    assert.equal(file.includes("out"), true);
  });
});

test("readBuild names the checkout and degrades to unknown outside git", () => {
  const here = readBuild();
  assert.match(here.sha, /^[0-9a-f]{40}$/);
  const outside = readBuild(mkdtempSync(path.join(os.tmpdir(), "no-git-")));
  assert.equal(outside.short, "unknown");
});
