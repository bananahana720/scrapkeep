import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";
import { isMain, parseCliArgs } from "./cli.mjs";
import { REPO_ROOT } from "./git.mjs";
import { walkSync } from "./walk.mjs";

const READS_ARGV1 = [
  "scripts/gate/display-run.test.mjs",
  "scripts/lib/cli.mjs",
  "scripts/lib/cli.test.mjs",
];

function scriptsReadingArgv1(root) {
  const found = [];
  let seen = 0;
  const skipped = (entry) => entry.name === "node_modules" || entry.name.startsWith(".");
  for (const entry of walkSync(path.join(root, "scripts"), { sort: true, prune: skipped })) {
    if (!/\.(mjs|cjs|js)$/.test(entry.name)) continue;
    seen += 1;
    const text = readFileSync(entry.full, "utf8");
    assert.notEqual(text, "", `${entry.rel} read as empty`);
    if (/process\s*\.\s*argv\s*\[\s*1\s*\]/.test(text)) found.push(`scripts/${entry.rel}`);
  }
  return { found, seen };
}

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

test("only the shared helper decides whether a script is the one being run", () => {
  const { found, seen } = scriptsReadingArgv1(REPO_ROOT);
  assert.ok(seen > 150, `walked only ${seen} script files under scripts/`);
  assert.deepEqual(
    found,
    READS_ARGV1,
    "a script reads process.argv[1] itself; use isMain(import.meta.url) from scripts/lib/cli.mjs",
  );
});

test("the search for scripts that read process.argv[1] sees every spelling this repository has used", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-argv1-"));
  try {
    const scripts = path.join(dir, "scripts");
    for (const folder of ["gate", "node_modules", ".cache"])
      mkdirSync(path.join(scripts, folder), { recursive: true });
    const spellings = {
      "a.mjs":
        "if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();\n",
      "b.mjs": "if (realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();\n",
      "gate/c.mjs": "if (import.meta.url === pathToFileURL(process.argv[ 1 ]).href) main();\n",
      "d.js": "if (process.argv[1]?.endsWith('d.js')) main();\n",
      "e.cjs": "if (process.argv[1] === __filename) main();\n",
      "node_modules/skipped.mjs": "process.argv[1];\n",
      ".cache/skipped.mjs": "process.argv[1];\n",
      "clean.mjs": "if (isMain(import.meta.url)) main();\n",
      "notes.md": "process.argv[1]\n",
    };
    for (const [rel, text] of Object.entries(spellings))
      writeFileSync(path.join(scripts, rel), text);
    assert.deepEqual(scriptsReadingArgv1(dir), {
      found: [
        "scripts/a.mjs",
        "scripts/b.mjs",
        "scripts/d.js",
        "scripts/e.cjs",
        "scripts/gate/c.mjs",
      ],
      seen: 6,
    });
    writeFileSync(path.join(scripts, "empty.mjs"), "");
    assert.throws(() => scriptsReadingArgv1(dir), /empty\.mjs read as empty/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
