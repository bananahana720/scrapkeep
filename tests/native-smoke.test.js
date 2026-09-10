import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  executionFailures,
  exportFailures,
  forbiddenNetworkingClasses,
  godotEnvironment,
  networkingGrep,
  networkingScan,
  repositoryFiles,
  run,
  templateCheck,
} from "../scripts/native-smoke.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const plantedDirectory = "tests/fixtures/native-smoke/planted";
// The five families the earlier forbidden list missed, each planted on line 2
// of a file the previous `.gd`/`project.godot` filter never opened.
const plantedSymbols = [
  ["DTLSServer", "planted_dtls_server.txt"],
  ["MultiplayerPeer", "planted_multiplayer_peer.txt"],
  ["SceneMultiplayer", "planted_scene_multiplayer.txt"],
  ["UPNP", "planted_upnp.txt"],
  ["WebRTC", "planted_web_rtc.txt"],
];
const plantedHits = [
  plantedDirectory + "/planted_dtls_server.txt:2:DTLSServer",
  plantedDirectory + "/planted_multiplayer_peer.txt:2:MultiplayerPeer",
  plantedDirectory + "/planted_prose_note.md:3:ENet",
  plantedDirectory + "/planted_scene_multiplayer.txt:2:SceneMultiplayer",
  plantedDirectory + "/planted_upnp.txt:2:UPNP",
  plantedDirectory + "/planted_web_rtc.txt:2:WebRTC",
];
const passMarker = /^SCRAPKEEP_INTEGRATION STAGE PASS$/m;
const execute = (source, options) =>
  run(process.execPath, ["-e", source], options);

test("accepts an actual process with the required marker and expected exit", () => {
  const result = execute('console.log("SCRAPKEEP_INTEGRATION STAGE PASS")');
  assert.deepEqual(
    executionFailures(result, { requiredMarker: passMarker }),
    [],
  );
});

test("rejects a successful process without its success marker", () => {
  const result = execute('console.log("booted")');
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /required marker absent/,
  );
});

test("rejects timeout even when the child printed success first", () => {
  const result = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE PASS"); setInterval(() => {}, 1000)',
    { timeout: 200 },
  );
  assert.equal(result.error.code, "ETIMEDOUT");
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /ETIMEDOUT/,
  );
});

test("rejects script errors despite a success marker and zero exit", () => {
  const result = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE PASS"); console.error("SCRIPT ERROR: bad type")',
  );
  assert.match(
    executionFailures(result, { requiredMarker: passMarker }).join(" "),
    /engine script error/,
  );
});

test("requires the injected fault exit code and marker together", () => {
  const requiredMarker = /^SCRAPKEEP_INTEGRATION STAGE FAIL$/m;
  const caught = execute(
    'console.log("SCRAPKEEP_INTEGRATION STAGE FAIL"); process.exitCode = 1',
  );
  assert.deepEqual(
    executionFailures(caught, { expectedCode: 1, requiredMarker }),
    [],
  );
  const ignored = execute('console.log("SCRAPKEEP_INTEGRATION STAGE FAIL")');
  assert.match(
    executionFailures(ignored, { expectedCode: 1, requiredMarker }).join(" "),
    /expected exit 1/,
  );
});

test("failed export cannot pass because an output file exists", () => {
  const result = execute("process.exitCode = 1");
  assert.match(
    exportFailures(result, { size: 100, sha256: "a".repeat(64) }).join(" "),
    /expected exit 0/,
  );
});

test("export refuses missing, empty and unhashed files", () => {
  const result = execute("");
  for (const artifact of [
    null,
    { size: 0, sha256: "a".repeat(64) },
    { size: 100, sha256: "" },
  ]) {
    assert.match(
      exportFailures(result, artifact).join(" "),
      /missing, empty or unhashed/,
    );
  }
});

test("export error text cannot pass on zero exit", () => {
  const result = execute('console.error("ERROR: export failed")');
  assert.match(
    exportFailures(result, { size: 100, sha256: "a".repeat(64) }).join(" "),
    /engine export\/import error/,
  );
});

test("missing executable is a failed execution with a retained command", () => {
  const result = run("/nonexistent/scrapkeep-smoke-binary", []);
  assert.equal(result.error.code, "ENOENT");
  assert.deepEqual(result.command, ["/nonexistent/scrapkeep-smoke-binary"]);
  assert.match(executionFailures(result).join(" "), /ENOENT/);
});

test("rejects a replaced consumed template even when the file remains nonempty", async (t) => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-template-test-"),
  );
  t.after(() => rm(directory, { recursive: true, force: true }));
  const file = path.join(directory, "version.txt");
  const inspect = async () => {
    const bytes = await readFile(file);
    return templateCheck("version.txt", {
      size: bytes.length,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    });
  };
  await writeFile(file, "4.7.2.stable\n");
  assert.equal((await inspect()).status, "pass");
  await writeFile(file, "4.7.2.stable\nappended replacement marker\n");
  const replacement = await inspect();
  assert.equal(replacement.status, "fail");
  assert.notEqual(replacement.actualSha256, replacement.expectedSha256);
});

test("child process writes settings into its run instead of inherited user config", async (t) => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "scrapkeep-config-test-"),
  );
  t.after(() => rm(directory, { recursive: true, force: true }));
  const inheritedConfig = path.join(directory, "owner-config");
  const inherited = {
    ...process.env,
    XDG_CONFIG_HOME: inheritedConfig,
    XDG_DATA_HOME: "/owner-data",
    XDG_CACHE_HOME: "/owner-cache",
  };
  const runDirectory = path.join(directory, "run");
  const env = godotEnvironment(runDirectory, inherited);
  const child = execute(
    'const fs = require("node:fs"); fs.mkdirSync(process.env.XDG_CONFIG_HOME, {recursive:true}); fs.writeFileSync(process.env.XDG_CONFIG_HOME + "/settings", "isolated");',
    { env },
  );
  assert.deepEqual(executionFailures(child), []);
  assert.equal(
    await readFile(path.join(runDirectory, "config/settings"), "utf8"),
    "isolated",
  );
  await assert.rejects(readFile(path.join(inheritedConfig, "settings")), {
    code: "ENOENT",
  });
  assert.equal(env.XDG_DATA_HOME, path.join(runDirectory, "user-data"));
  assert.equal(env.XDG_CACHE_HOME, path.join(runDirectory, "cache"));
  assert.equal(inherited.XDG_CONFIG_HOME, inheritedConfig);
});

test("forbidden list names the whole networking family", () => {
  const families = [
    "HTTPRequest",
    "ENet",
    "WebSocket",
    "MultiplayerAPI",
    "PacketPeer",
    "StreamPeer",
    "HTTPClient",
    "UDPServer",
    "TCPServer",
    ...plantedSymbols.map(([symbol]) => symbol),
  ];
  for (const family of families)
    assert.match(
      family,
      forbiddenNetworkingClasses,
      family + " must stay listed",
    );
});

test("planted fixture fails the widened scan with its exact message", async () => {
  const check = await networkingScan(plantedDirectory);
  assert.equal(check.status, "fail");
  assert.equal(
    check.derivation,
    "git ls-files -z --cached --others --exclude-standard -- " +
      plantedDirectory,
  );
  assert.equal(check.scannedFiles.length, plantedHits.length);
  assert.equal(check.stdoutExcerpt, plantedHits.join("\n"));
  assert.equal(
    check.detail,
    "networking class named at " + plantedHits.join(", "),
  );
});

for (const [symbol, file] of plantedSymbols) {
  test(
    "the widened list detects " + symbol + " in a non-script file",
    async () => {
      const check = await networkingGrep([
        path.join(root, plantedDirectory, file),
      ]);
      assert.equal(check.status, "fail");
      assert.equal(
        check.detail,
        "networking class named at " +
          plantedDirectory +
          "/" +
          file +
          ":2:" +
          symbol,
      );
    },
  );
}

test("the real native tree passes with every tracked file scanned", async () => {
  const tracked = run("git", ["ls-files", "-z", "--", "native"])
    .stdout.split("\0")
    .filter(Boolean)
    .sort();
  const scanned = repositoryFiles("native").map((file) =>
    path.relative(root, file).split(path.sep).join("/"),
  );
  assert.deepEqual(
    scanned.filter((file) => tracked.includes(file)),
    tracked,
  );
  for (const file of [
    "native/README.md",
    "native/export_presets.cfg",
    "native/integration/smoke.gd.uid",
    "native/proofs/tadr-003/fixtures/placeholder_tree.tres",
    "native/proofs/tadr-004/fixtures/lifecycle/save.json",
  ])
    assert.ok(
      scanned.includes(file),
      file + " must be scanned instead of skipped by an extension filter",
    );
  const check = await networkingScan("native");
  assert.equal(check.status, "pass");
  assert.deepEqual(check.scannedFiles, scanned);
  assert.equal(
    check.derivation,
    "git ls-files -z --cached --others --exclude-standard -- native",
  );
  assert.equal(
    check.detail,
    "no networking class named in " + scanned.length + " scanned files",
  );
});

test("a file added after the last commit cannot escape the scan", async (t) => {
  const directory = "tests/fixtures/native-smoke/derived";
  const added = directory + "/added_after_commit.txt";
  await mkdir(path.join(root, directory), { recursive: true });
  t.after(() =>
    rm(path.join(root, directory), { recursive: true, force: true }),
  );
  await writeFile(path.join(root, added), "transport = WebRTC\n");
  assert.equal(
    run("git", [
      "ls-files",
      "--others",
      "--exclude-standard",
      "--",
      directory,
    ]).stdout.trim(),
    added,
    "the fixture must be an untracked, newly added file",
  );
  const check = await networkingScan(directory);
  assert.equal(check.status, "fail");
  assert.equal(
    check.detail,
    "networking class named at " + added + ":1:WebRTC",
  );
});

test("an empty scan list cannot pass", async () => {
  const check = await networkingGrep([]);
  assert.equal(check.status, "fail");
  assert.equal(check.scannedFiles.length, 0);
  assert.match(check.detail, /unread tree cannot pass/);
});
