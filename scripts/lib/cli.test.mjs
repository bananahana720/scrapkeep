import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";
import { isMain, parseCliArgs } from "./cli.mjs";
import { REPO_ROOT } from "./git.mjs";
import { walkSync } from "./walk.mjs";

const EXCLUDED_S6 = new Set([
  "scripts/alpha-rc.mjs",
  "scripts/challenge/proc.mjs",
  "scripts/checkpoint.mjs",
  "scripts/ci/shard-plan.mjs",
  "scripts/dev-console.mjs",
  "scripts/frametime-check.mjs",
  "scripts/gate/band-receipts.mjs",
  "scripts/gate/contact-orders-receipt.mjs",
  "scripts/gate/core-feel-receipt.mjs",
  "scripts/gate/display-run.mjs",
  "scripts/gate/installed-build-receipt.mjs",
  "scripts/gate/map-standard-receipt.mjs",
  "scripts/gate/model-receipts.mjs",
  "scripts/gate/model-render-receipt.mjs",
  "scripts/gate/receipt-cli.mjs",
  "scripts/gate/release-gate-receipt.mjs",
  "scripts/gate/shard.mjs",
  "scripts/gate/sitting-played-receipt.mjs",
  "scripts/gate/six-pilots-receipt.mjs",
  "scripts/gate/snag-sweep-receipt.mjs",
  "scripts/gate/sound-levels-receipt.mjs",
  "scripts/gate/sound-recipes-receipt.mjs",
  "scripts/gate/stand-ins-receipt.mjs",
  "scripts/gate/words-on-screen-receipt.mjs",
  "scripts/known-failing.mjs",
  "scripts/lib/fast-diff-checks.mjs",
  "scripts/lib/godot-test-runner.mjs",
  "scripts/lib/machine-lock.mjs",
  "scripts/lib/proc.mjs",
  "scripts/lib/proc.test.mjs",
  "scripts/lib/receipt.mjs",
  "scripts/lib/receipt.test.mjs",
  "scripts/pacing-check.mjs",
  "scripts/play.mjs",
  "scripts/redteam/run.mjs",
  "scripts/sketch-fast.mjs",
  "scripts/sketch-fast.test.mjs",
  "scripts/sketch-nightly.mjs",
  "scripts/sketch-smoke.mjs",
  "scripts/sketch-smoke.test.mjs",
]);

test("isMain resolves direct paths, symlinks, missing argv1, and non-existent fallback", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-cli-"));
  try {
    const cliModuleUrl = new URL("./cli.mjs", import.meta.url).href;
    const entry = path.join(dir, "entry.mjs");
    const link = path.join(dir, "entry-link.mjs");
    writeFileSync(
      entry,
      `import { isMain } from ${JSON.stringify(cliModuleUrl)};\nconsole.log(isMain(import.meta.url) ? "MAIN" : "IMPORTED");\n`,
    );
    symlinkSync(entry, link);

    const direct = spawnSync(process.execPath, [entry], { encoding: "utf8" });
    assert.equal(direct.status, 0, direct.stderr);
    assert.equal(direct.stdout.trim(), "MAIN");

    const viaLink = spawnSync(process.execPath, [link], { encoding: "utf8" });
    assert.equal(viaLink.status, 0, viaLink.stderr);
    assert.equal(viaLink.stdout.trim(), "MAIN");

    assert.equal(isMain(import.meta.url, ""), false);
    assert.equal(isMain(import.meta.url, null), false);
    assert.equal(isMain(pathToFileURL(entry).href, link), true);
    const missing = path.join(dir, "missing.mjs");
    assert.equal(isMain(pathToFileURL(missing).href, missing), true);
    assert.equal(isMain(pathToFileURL(missing).href, entry), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("parseCliArgs parses flags, values, multi values, inline = syntax, positionals, and errors", () => {
  const spec = {
    flags: { "--json": "json", "--check": "check" },
    values: { "--base": "base", "--out": "out" },
    multi: { "--tag": "tags" },
    allowPositionals: true,
    defaults: { out: "default.json" },
  };
  const parsed = parseCliArgs(
    [
      "--json",
      "--base",
      "main",
      "--out=custom.json",
      "--tag",
      "a",
      "--tag=b",
      "pos1",
      "--",
      "--raw",
    ],
    spec,
  );
  assert.deepEqual(parsed, {
    json: true,
    check: false,
    base: "main",
    out: "custom.json",
    tags: ["a", "b"],
    positionals: ["pos1", "--raw"],
  });

  assert.throws(() => parseCliArgs(["--base"], spec), /--base requires a value/);
  assert.throws(() => parseCliArgs(["--base="], spec), /--base requires a value/);
  assert.throws(() => parseCliArgs(["--tag"], spec), /--tag requires a value/);
  assert.throws(() => parseCliArgs(["--bogus"], spec), /unknown argument: --bogus/);
  assert.throws(
    () => parseCliArgs(["extra"], { flags: { "--json": "json" } }),
    /unknown argument: extra/,
  );
});

test("zero non-excluded scripts in scripts/ keep bare path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)", () => {
  const barePattern =
    /path\.resolve\(\s*process\.argv\[1\]\s*\)\s*===\s*fileURLToPath\(\s*import\.meta\.url\s*\)|fileURLToPath\(\s*import\.meta\.url\s*\)\s*===\s*path\.resolve\(\s*process\.argv\[1\]\s*\)/;
  const offenders = [];
  const selfRel = path
    .relative(REPO_ROOT, fileURLToPath(import.meta.url))
    .split(path.sep)
    .join("/");
  for (const entry of walkSync(path.join(REPO_ROOT, "scripts"), { sort: true })) {
    if (!entry.name.endsWith(".mjs") && !entry.name.endsWith(".js")) continue;
    const rel = `scripts/${entry.rel}`;
    if (rel === selfRel || EXCLUDED_S6.has(rel)) continue;
    const text = readFileSync(entry.full, "utf8");
    if (barePattern.test(text)) offenders.push(rel);
  }
  assert.deepEqual(offenders, []);
});
