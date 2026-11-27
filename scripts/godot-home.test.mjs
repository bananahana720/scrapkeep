import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  GODOT_VERSION,
  requireGodotBinary,
  resolveGodotBinary,
  scratchHomeEnv,
  userDataEnv,
} from "./godot-home.mjs";

const CLOUD_BIN = `/opt/scrapkeep-toolchain/Godot_v${GODOT_VERSION}-stable_linux.x86_64`;
const PC_HOME = "/home/andrew";
const PC_LOCAL_BIN = path.join(
  PC_HOME,
  ".local",
  "share",
  "godot",
  GODOT_VERSION,
  `Godot_v${GODOT_VERSION}-stable_linux.x86_64`,
);
const MAC_HOME = "/Users/studio";
const MAC_APP_BIN = path.join(
  MAC_HOME,
  "Applications",
  `Godot_${GODOT_VERSION}.app`,
  "Contents",
  "MacOS",
  "Godot",
);

const SCRIPTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPTS_DIR, "..");

const HOME_ANDREW_ALLOWLIST = {
  "scripts/music/lyria-tune.mjs":
    "remote SSH paths on Linux PC ahana; parked under Needs the owner",
};

const GODOT_BIN_OWNER = "scripts/godot-home.mjs";
const GODOT_BIN_ALLOWLIST = {
  "scripts/alpha-rc.mjs": "strips GODOT_BIN from a child environment",
  "scripts/gate/pc.mjs": "reads GODOT_BIN from the step environment it built",
};
const DIRECT_GODOT_BIN_READ =
  /\.GODOT_BIN\b|\[\s*["'`]GODOT_BIN["'`]\s*\]|\{[^{}]*\bGODOT_BIN\b[^{}]*\}\s*=(?![=>])/;

function nonTestScriptFiles(dir) {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...nonTestScriptFiles(full));
    } else if (entry.isFile() && entry.name.endsWith(".mjs") && !entry.name.endsWith(".test.mjs")) {
      files.push(full);
    }
  }
  return files.sort();
}

test("GODOT_VERSION exposes the pinned editor version", () => {
  assert.equal(GODOT_VERSION, "4.7.2");
});

test("GODOT_BIN wins on every platform and trims surrounding whitespace", () => {
  for (const platform of ["darwin", "linux"]) {
    assert.equal(
      resolveGodotBinary({
        env: { GODOT_BIN: "  /custom/godot  " },
        platform,
        homeDir: platform === "darwin" ? MAC_HOME : PC_HOME,
        exists: () => false,
        which: () => "/usr/bin/godot",
      }),
      "/custom/godot",
    );
    assert.equal(
      resolveGodotBinary({
        env: { GODOT_BIN: "/explicit/godot" },
        platform,
        homeDir: platform === "darwin" ? MAC_HOME : PC_HOME,
        exists: () => false,
        requireExplicit: true,
      }),
      "/explicit/godot",
    );
  }
});

test("unset GODOT_BIN on macOS resolves ~/Applications/Godot_4.7.2.app when present", () => {
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "darwin",
      homeDir: MAC_HOME,
      exists: (p) => p === MAC_APP_BIN,
    }),
    MAC_APP_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: { GODOT_BIN: "   " },
      platform: "darwin",
      homeDir: MAC_HOME,
      exists: (p) => p === MAC_APP_BIN,
    }),
    MAC_APP_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "darwin",
      homeDir: MAC_HOME,
      exists: () => false,
    }),
    null,
  );
});

test("unset GODOT_BIN on Linux PC resolves ~/.local/share/godot/4.7.2 or /usr/bin/godot", () => {
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === PC_LOCAL_BIN,
    }),
    PC_LOCAL_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === PC_LOCAL_BIN || p === "/usr/bin/godot",
    }),
    PC_LOCAL_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === "/usr/bin/godot",
    }),
    "/usr/bin/godot",
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: () => false,
    }),
    null,
  );
});

test("unset GODOT_BIN on cloud image resolves /opt/scrapkeep-toolchain before home fallback", () => {
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === CLOUD_BIN,
    }),
    CLOUD_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === CLOUD_BIN || p === PC_LOCAL_BIN || p === "/usr/bin/godot",
    }),
    CLOUD_BIN,
  );
});

test("optional which probe runs after macOS app bundle and before Linux static fallbacks", () => {
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "darwin",
      homeDir: MAC_HOME,
      exists: (p) => p === MAC_APP_BIN || p === "/opt/homebrew/bin/godot",
      which: () => "/opt/homebrew/bin/godot",
    }),
    MAC_APP_BIN,
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === "/usr/bin/godot" || p === CLOUD_BIN,
      which: () => "/usr/bin/godot",
    }),
    "/usr/bin/godot",
  );
  assert.equal(
    resolveGodotBinary({
      env: {},
      platform: "linux",
      homeDir: PC_HOME,
      exists: (p) => p === CLOUD_BIN,
      which: () => "/missing/godot",
    }),
    CLOUD_BIN,
  );
});

test("requireExplicit refuses fallback binaries on every machine when GODOT_BIN is unset", () => {
  for (const [platform, homeDir] of [
    ["darwin", MAC_HOME],
    ["linux", PC_HOME],
    ["linux", "/root"],
  ]) {
    assert.equal(
      resolveGodotBinary({
        env: {},
        platform,
        homeDir,
        exists: () => true,
        which: () => "/usr/bin/godot",
        requireExplicit: true,
      }),
      null,
    );
    assert.equal(
      resolveGodotBinary({
        env: { GODOT_BIN: "  " },
        platform,
        homeDir,
        exists: () => true,
        requireExplicit: true,
      }),
      null,
    );
  }
});

test("userDataEnv and scratchHomeEnv isolate HOME only on darwin", () => {
  assert.deepEqual(userDataEnv("/tmp/d", "darwin"), { XDG_DATA_HOME: "/tmp/d", HOME: "/tmp/d" });
  assert.deepEqual(userDataEnv("/tmp/d", "linux"), { XDG_DATA_HOME: "/tmp/d" });
  assert.deepEqual(
    scratchHomeEnv(() => "/tmp/s", "darwin"),
    { HOME: "/tmp/s" },
  );
  assert.deepEqual(
    scratchHomeEnv(() => "/tmp/s", "linux"),
    {},
  );
});

test("requireGodotBinary returns an existing binary or throws with set GODOT_BIN", () => {
  assert.equal(
    requireGodotBinary({
      env: { GODOT_BIN: "/custom/godot" },
      exists: (p) => p === "/custom/godot",
    }),
    "/custom/godot",
  );
  assert.throws(
    () =>
      requireGodotBinary({
        env: {},
        platform: "linux",
        homeDir: PC_HOME,
        exists: () => false,
      }),
    /^Error: Godot binary not found; set GODOT_BIN$/,
  );
  assert.throws(
    () =>
      requireGodotBinary({
        env: { GODOT_BIN: "/missing/godot" },
        exists: () => false,
      }),
    /^Error: Godot binary not found at \/missing\/godot; set GODOT_BIN$/,
  );
});

test("DIRECT_GODOT_BIN_READ catches env reads and ignores writes and messages", () => {
  for (const hit of [
    "process.env.GODOT_BIN",
    "env.GODOT_BIN",
    "env?.GODOT_BIN",
    'process.env["GODOT_BIN"]',
    "env['GODOT_BIN']",
    "env[`GODOT_BIN`]",
    "const { GODOT_BIN } = process.env",
    "const { GODOT_BIN: bin, ...rest } = env",
    "const { PATH, GODOT_BIN = '' } = env",
  ]) {
    assert.equal(DIRECT_GODOT_BIN_READ.test(hit), true, `expected match for: ${hit}`);
  }
  for (const miss of [
    "const env = { ...process.env, GODOT_BIN: godot };",
    "GODOT_BIN: godotBin,",
    'fail("set GODOT_BIN to the Godot editor");',
    '"$GODOT_BIN --headless"',
  ]) {
    assert.equal(DIRECT_GODOT_BIN_READ.test(miss), false, `unexpected match for: ${miss}`);
  }
});

test("non-test scripts contain no unapproved /home/andrew/ literals or direct GODOT_BIN env reads", () => {
  const files = nonTestScriptFiles(SCRIPTS_DIR);
  assert.ok(files.length > 0);
  const badHome = [];
  const badEnv = [];
  const seenHomeAllow = new Set();
  const seenEnvAllow = new Set();

  for (const file of files) {
    const rel = path.relative(REPO_ROOT, file).split(path.sep).join("/");
    const source = readFileSync(file, "utf8");
    if (source.includes("/home/andrew/")) {
      if (rel in HOME_ANDREW_ALLOWLIST) seenHomeAllow.add(rel);
      else badHome.push(rel);
    }
    if (rel !== GODOT_BIN_OWNER && DIRECT_GODOT_BIN_READ.test(source)) {
      if (rel in GODOT_BIN_ALLOWLIST) seenEnvAllow.add(rel);
      else badEnv.push(rel);
    }
  }

  assert.deepEqual(badHome, [], `unexpected /home/andrew/ literal in: ${badHome.join(", ")}`);
  assert.deepEqual(
    badEnv,
    [],
    `unexpected GODOT_BIN environment read outside ${GODOT_BIN_OWNER} in: ${badEnv.join(", ")}`,
  );
  assert.deepEqual(
    Object.keys(HOME_ANDREW_ALLOWLIST).filter((rel) => !seenHomeAllow.has(rel)),
    [],
    "stale HOME_ANDREW_ALLOWLIST entries must be removed",
  );
  assert.deepEqual(
    Object.keys(GODOT_BIN_ALLOWLIST).filter((rel) => !seenEnvAllow.has(rel)),
    [],
    "stale GODOT_BIN_ALLOWLIST entries must be removed",
  );
});
