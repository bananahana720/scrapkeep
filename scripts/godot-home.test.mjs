import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import {
  GODOT_VERSION,
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
  assert.deepEqual(scratchHomeEnv(() => "/tmp/s", "darwin"), { HOME: "/tmp/s" });
  assert.deepEqual(scratchHomeEnv(() => "/tmp/s", "linux"), {});
});
