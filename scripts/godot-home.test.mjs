import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  GODOT_VERSION,
  requireGodotBinary,
  resolveGodotBinary,
  scratchGodotEnv,
  scratchHomeEnv,
  userDataEnv,
  withScratchGodotEnv,
} from "./godot-home.mjs";
import { freshProfile } from "./alpha-rc.mjs";
import { stateEnv } from "./challenge/proc.mjs";
import { REPO_ROOT as DEV_REPO_ROOT, scratchEnv as devScratchEnv } from "./dev-console.mjs";
import { selfPlayXdg } from "./frametime-check.mjs";
import { scratchEnv as displayScratchEnv } from "./gate/display-run.mjs";
import { stepEnv as pcStepEnv } from "./gate/pc.mjs";
import { isolatedXdgEnv, winProofEnv } from "./sketch-export.mjs";

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

const XDG_WRITE_ALLOWLIST = {
  "scripts/sketch-appimage.mjs": "passes real Linux desktop install target to install.sh",
  "scripts/sketch-export.mjs": "overrides XDG_DATA_HOME to templateDataHome for --export-release",
};
const DIRECT_XDG_WRITE =
  /\bXDG_(?:DATA|CONFIG|CACHE)_HOME\s*:|(?:\.XDG_(?:DATA|CONFIG|CACHE)_HOME|\[\s*["'`]XDG_(?:DATA|CONFIG|CACHE)_HOME["'`]\s*\]|\[\s*`XDG_\$\{[^}]+\}_HOME`\s*\])\s*=(?!=)/;

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

test("scratchGodotEnv matches every migrated script key-for-key on Linux and isolates HOME on macOS", () => {
  const base = { PATH: "/bin", HOME: "/real/home", XDG_DATA_HOME: "/real/data" };
  const tmp = mkdtempSync(path.join(os.tmpdir(), "godot-home-eq-"));
  const devBase = path.join(DEV_REPO_ROOT, "artifacts", "local", "godot-home-test");
  mkdirSync(devBase, { recursive: true });
  const devTmp = mkdtempSync(path.join(devBase, "run-"));
  try {
    assert.deepEqual(isolatedXdgEnv(base, "/tmp/iso", "linux"), {
      ...base,
      XDG_DATA_HOME: "/tmp/iso/data",
      XDG_CONFIG_HOME: "/tmp/iso/config",
      XDG_CACHE_HOME: "/tmp/iso/cache",
    });
    assert.deepEqual(isolatedXdgEnv(base, "/tmp/iso", "darwin"), {
      ...base,
      HOME: "/tmp/iso/data",
      XDG_DATA_HOME: "/tmp/iso/data",
      XDG_CONFIG_HOME: "/tmp/iso/config",
      XDG_CACHE_HOME: "/tmp/iso/cache",
    });

    assert.deepEqual(winProofEnv("/tmp/proof", "/repo", base, "linux"), {
      ...base,
      XDG_DATA_HOME: "/tmp/proof/data",
      XDG_CONFIG_HOME: "/tmp/proof/config",
      XDG_CACHE_HOME: "/tmp/proof/cache",
      SCRAPKEEP_REPO_ROOT: "/repo",
    });
    assert.deepEqual(winProofEnv("/tmp/proof", "/repo", base, "darwin"), {
      ...base,
      HOME: "/tmp/proof/data",
      XDG_DATA_HOME: "/tmp/proof/data",
      XDG_CONFIG_HOME: "/tmp/proof/config",
      XDG_CACHE_HOME: "/tmp/proof/cache",
      SCRAPKEEP_REPO_ROOT: "/repo",
    });

    const ftDir = path.join(tmp, "ft");
    assert.deepEqual(selfPlayXdg(ftDir, "linux"), {
      XDG_DATA_HOME: path.join(ftDir, "xdg-data"),
      XDG_CONFIG_HOME: path.join(ftDir, "xdg-config"),
    });
    assert.deepEqual(selfPlayXdg(ftDir, "darwin"), {
      HOME: path.join(ftDir, "xdg-data"),
      XDG_DATA_HOME: path.join(ftDir, "xdg-data"),
      XDG_CONFIG_HOME: path.join(ftDir, "xdg-config"),
    });
    assert.ok(existsSync(path.join(ftDir, "xdg-data")));
    assert.ok(existsSync(path.join(ftDir, "xdg-config")));

    const devHome = path.join(devTmp, "home");
    assert.deepEqual(
      devScratchEnv(devHome, { repoRoot: DEV_REPO_ROOT, baseEnv: base, platform: "linux" }).env,
      {
        ...base,
        HOME: devHome,
        XDG_DATA_HOME: path.join(devHome, "data"),
        XDG_CONFIG_HOME: path.join(devHome, "config"),
        XDG_CACHE_HOME: path.join(devHome, "cache"),
        SDL_AUDIODRIVER: "dummy",
      },
    );
    assert.deepEqual(
      devScratchEnv(devHome, { repoRoot: DEV_REPO_ROOT, baseEnv: base, platform: "darwin" }).env,
      {
        ...base,
        HOME: devHome,
        XDG_DATA_HOME: path.join(devHome, "data"),
        XDG_CONFIG_HOME: path.join(devHome, "config"),
        XDG_CACHE_HOME: path.join(devHome, "cache"),
      },
    );

    const displayScratch = displayScratchEnv(tmp);
    assert.deepEqual(displayScratch.env, {
      HOME: displayScratch.home,
      XDG_DATA_HOME: path.join(displayScratch.home, "data"),
      XDG_CONFIG_HOME: path.join(displayScratch.home, "config"),
      XDG_CACHE_HOME: path.join(displayScratch.home, "cache"),
    });

    const rcProfile = freshProfile();
    try {
      assert.deepEqual(rcProfile.env, {
        HOME: rcProfile.home,
        XDG_CONFIG_HOME: path.join(rcProfile.home, ".config"),
        XDG_DATA_HOME: path.join(rcProfile.home, ".local/share"),
        XDG_CACHE_HOME: path.join(rcProfile.home, ".cache"),
        XDG_STATE_HOME: path.join(rcProfile.home, ".local/state"),
      });
    } finally {
      rmSync(rcProfile.home, { recursive: true, force: true });
    }

    assert.deepEqual(
      pcStepEnv({ root: "/g", id: "s1", godot: "/bin/godot", base, platform: "linux" }),
      {
        ...base,
        GODOT_BIN: "/bin/godot",
        XDG_DATA_HOME: "/g/xdg/s1/data",
        XDG_CONFIG_HOME: "/g/xdg/s1/config",
        XDG_CACHE_HOME: "/g/xdg/s1/cache",
        SCRAPKEEP_LOCK_DIR: "/g/locks/s1",
        SMOKE_SLOTS: "4",
        SMOKE_FULL: "1",
      },
    );
    assert.deepEqual(
      pcStepEnv({ root: "/g", id: "s1", godot: "/bin/godot", base, platform: "darwin" }),
      {
        ...base,
        GODOT_BIN: "/bin/godot",
        HOME: "/g/xdg/s1/data",
        XDG_DATA_HOME: "/g/xdg/s1/data",
        XDG_CONFIG_HOME: "/g/xdg/s1/config",
        XDG_CACHE_HOME: "/g/xdg/s1/cache",
        SCRAPKEEP_LOCK_DIR: "/g/locks/s1",
        SMOKE_SLOTS: "4",
        SMOKE_FULL: "1",
      },
    );

    const chDir = path.join(tmp, "challenge");
    assert.deepEqual(stateEnv(chDir, "linux"), {
      XDG_DATA_HOME: path.join(chDir, "data"),
      XDG_CONFIG_HOME: path.join(chDir, "config"),
      XDG_CACHE_HOME: path.join(chDir, "cache"),
    });
    assert.deepEqual(stateEnv(chDir, "darwin"), {
      HOME: path.join(chDir, "data"),
      XDG_DATA_HOME: path.join(chDir, "data"),
      XDG_CONFIG_HOME: path.join(chDir, "config"),
      XDG_CACHE_HOME: path.join(chDir, "cache"),
    });

    assert.deepEqual(
      scratchGodotEnv("/mac/h", { baseEnv: base, dirs: null, forceHome: true, platform: "darwin" }),
      { ...base, HOME: "/mac/h", XDG_DATA_HOME: "/mac/h" },
    );
    assert.throws(() => scratchGodotEnv("/x", { dirs: { nope: "nope" } }), /unknown XDG slot/);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
    rmSync(devTmp, { recursive: true, force: true });
  }
});

test("withScratchGodotEnv cleans up temp folders and skips temp creation for homeOnly on Linux", async () => {
  const tmpRoot = mkdtempSync(path.join(os.tmpdir(), "godot-home-with-"));
  try {
    const linuxHomeOnly = await withScratchGodotEnv((env, dir) => ({ env, dir }), {
      prefix: "ho-",
      tmpRoot,
      baseEnv: { PATH: "/bin", HOME: "/real" },
      homeOnly: true,
      platform: "linux",
    });
    assert.equal(linuxHomeOnly.dir, null);
    assert.deepEqual(linuxHomeOnly.env, { PATH: "/bin", HOME: "/real" });
    assert.deepEqual(readdirSync(tmpRoot), []);

    let macDir = null;
    await withScratchGodotEnv(
      (env, dir) => {
        macDir = dir;
        assert.ok(dir && existsSync(dir));
        assert.equal(env.HOME, dir);
      },
      { prefix: "ho-", tmpRoot, baseEnv: { PATH: "/bin" }, homeOnly: true, platform: "darwin" },
    );
    assert.ok(macDir && !existsSync(macDir));

    let failedDir = null;
    await assert.rejects(
      withScratchGodotEnv(
        (_env, dir) => {
          failedDir = dir;
          assert.ok(existsSync(path.join(dir, "data")));
          throw new Error("boom");
        },
        { prefix: "full-", tmpRoot, baseEnv: {}, platform: "linux" },
      ),
      /boom/,
    );
    assert.ok(failedDir && !existsSync(failedDir));

    let dataOnlyDir = null;
    await withScratchGodotEnv(
      (env, dir) => {
        dataOnlyDir = dir;
        assert.equal(env.XDG_DATA_HOME, dir);
        assert.equal(env.HOME, dir);
      },
      { prefix: "data-", tmpRoot, baseEnv: {}, dirs: null, platform: "darwin" },
    );
    assert.ok(dataOnlyDir && !existsSync(dataOnlyDir));
  } finally {
    rmSync(tmpRoot, { recursive: true, force: true });
  }
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

test("non-test scripts contain no unapproved /home/andrew/ literals, direct GODOT_BIN env reads, or manual XDG writes", () => {
  const files = nonTestScriptFiles(SCRIPTS_DIR);
  assert.ok(files.length > 0);
  const badHome = [];
  const badEnv = [];
  const badXdg = [];
  const seenHomeAllow = new Set();
  const seenEnvAllow = new Set();
  const seenXdgAllow = new Set();

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
    if (rel !== GODOT_BIN_OWNER && DIRECT_XDG_WRITE.test(source)) {
      if (rel in XDG_WRITE_ALLOWLIST) {
        seenXdgAllow.add(rel);
        if (rel === "scripts/sketch-export.mjs") {
          const matches = [...source.matchAll(new RegExp(DIRECT_XDG_WRITE.source, "g"))].map(
            (m) => m[0],
          );
          assert.deepEqual(matches, ["XDG_DATA_HOME:"]);
        }
      } else {
        badXdg.push(rel);
      }
    }
  }

  assert.deepEqual(badHome, [], `unexpected /home/andrew/ literal in: ${badHome.join(", ")}`);
  assert.deepEqual(
    badEnv,
    [],
    `unexpected GODOT_BIN environment read outside ${GODOT_BIN_OWNER} in: ${badEnv.join(", ")}`,
  );
  assert.deepEqual(
    badXdg,
    [],
    `unexpected manual XDG_*_HOME write outside ${GODOT_BIN_OWNER} in: ${badXdg.join(", ")}`,
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
  assert.deepEqual(
    Object.keys(XDG_WRITE_ALLOWLIST).filter((rel) => !seenXdgAllow.has(rel)),
    [],
    "stale XDG_WRITE_ALLOWLIST entries must be removed",
  );
});
