import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";
import { flagValue, isMain, parseCliArgs } from "./cli.mjs";
import { git, nulSeparated, REPO_ROOT } from "./git.mjs";

const READS_ARGV1 = [
  "scripts/gate/display-run.test.mjs",
  "scripts/lib/cli.mjs",
  "scripts/lib/cli.test.mjs",
  "server/index.js",
  "tests/expedition-balance.mjs",
];

function filesReadingArgv1(root) {
  const listed = nulSeparated(
    git(["ls-files", "-z", "--", "*.mjs", "*.cjs", "*.js"], { cwd: root, trim: false }),
  ).sort();
  assert.ok(listed.length > 0, `git ls-files listed no .mjs, .cjs or .js file in ${root}`);
  const found = [];
  for (const rel of listed) {
    const text = readFileSync(path.join(root, rel), "utf8");
    assert.notEqual(text, "", `${rel} read as empty`);
    if (/process\s*\.\s*argv\s*\[\s*1\s*\]/.test(text)) found.push(rel);
  }
  return { found, seen: listed.length };
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

test("flagValue returns the value after a flag and refuses a missing, empty or flag-shaped one", () => {
  assert.equal(flagValue(["--sketch", "core-loop"], 1, "a name"), "core-loop");
  for (const argv of [["--sketch"], ["--sketch", ""], ["--sketch", "--bots"], ["--sketch", "-x"]])
    assert.throws(
      () => flagValue(argv, 1, "a name"),
      /^Error: --sketch requires a name$/,
      argv.join(" "),
    );
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
  const { found, seen } = filesReadingArgv1(REPO_ROOT);
  assert.ok(seen > 200, `walked only ${seen} tracked .mjs, .cjs and .js files`);
  assert.deepEqual(
    found,
    READS_ARGV1,
    "a script reads process.argv[1] itself; use isMain(import.meta.url) from scripts/lib/cli.mjs",
  );
});

test("the search for files that read process.argv[1] sees every spelling this repository has used", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-argv1-"));
  try {
    assert.throws(() => filesReadingArgv1(dir), /git ls-files .* failed/);
    git(["init", "-q"], { cwd: dir });
    assert.throws(() => filesReadingArgv1(dir), /listed no \.mjs, \.cjs or \.js file/);
    for (const folder of ["scripts/gate", "node_modules", ".agents/hooks", "tools"])
      mkdirSync(path.join(dir, folder), { recursive: true });
    const spellings = {
      "scripts/a.mjs":
        "if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();\n",
      "scripts/b.mjs":
        "if (realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main();\n",
      "scripts/gate/c.mjs":
        "if (import.meta.url === pathToFileURL(process.argv[ 1 ]).href) main();\n",
      "scripts/d.js": "if (process.argv[1]?.endsWith('d.js')) main();\n",
      "scripts/e.cjs": "if (process.argv[1] === __filename) main();\n",
      ".agents/hooks/f.mjs": "if (process.argv[1] === fileURLToPath(import.meta.url)) main();\n",
      "tools/g.mjs": "if (process.argv[1]) main();\n",
      "scripts/clean.mjs": "if (isMain(import.meta.url)) main();\n",
      "scripts/notes.md": "process.argv[1]\n",
    };
    for (const [rel, text] of Object.entries(spellings)) writeFileSync(path.join(dir, rel), text);
    writeFileSync(path.join(dir, "node_modules/untracked.mjs"), "process.argv[1];\n");
    writeFileSync(path.join(dir, "tools/untracked.mjs"), "process.argv[1];\n");
    git(["add", "--", ...Object.keys(spellings)], { cwd: dir });
    assert.deepEqual(filesReadingArgv1(dir), {
      found: [
        ".agents/hooks/f.mjs",
        "scripts/a.mjs",
        "scripts/b.mjs",
        "scripts/d.js",
        "scripts/e.cjs",
        "scripts/gate/c.mjs",
        "tools/g.mjs",
      ],
      seen: 8,
    });
    writeFileSync(path.join(dir, "scripts/empty.mjs"), "");
    git(["add", "--", "scripts/empty.mjs"], { cwd: dir });
    assert.throws(() => filesReadingArgv1(dir), /scripts\/empty\.mjs read as empty/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
