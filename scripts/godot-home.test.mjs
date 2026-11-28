import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
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
import { git } from "./lib/git.mjs";
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

const GODOT_PATH_SPELLING = String.raw`Godot_v?([0-9]+\.[0-9]|\$?\{|\$[A-Za-z_])`;
const SPELLS_GODOT_PATH = {
  "scripts/godot-home.mjs": "the owner: resolveGodotBinary lists every place Godot is looked for",
  "scripts/godot-home.test.mjs": "tests the owner with made-up homes",
  "scripts/dev-console.test.mjs": "a made-up macOS home in a resolver test",
  "scripts/gate/gate.test.mjs": "made-up Godot names and a made-up binary in gate tests",
  "scripts/import-stamp.test.mjs": "made-up Godot identity strings",
  "tests/fixtures/crash-harvest/jobs/speedrunner-tally-35010/log.txt":
    "a crash log kept verbatim as a fixture",
  "tools/cloud/setup.sh": "the cloud installer puts Godot at this path",
  ".claude/hooks/session-start.sh": "runs the cloud installer and exports its path as GODOT_BIN",
  ".github/actions/setup-godot/action.yml": "the CI installer downloads Godot to this path",
  ".agents/skills/scrapkeep-verify-build/scripts/build.sh":
    "a message that says where the cloud installs Godot",
  ".agents/skills/scrapkeep-verify-game/scripts/doctor.sh":
    "a message that says where to install Godot",
  "sketches/core-loop/tests/run_tier_test.gd": "a dated re-pin note records the command it ran",
  "project-guide/handoff/shared/structure-sweep/pool.tsv":
    "the sweep's task pool quotes the search that found the copies",
};

function filesSpellingGodotPath(root, pattern = GODOT_PATH_SPELLING) {
  const tracked = git(["ls-files"], { cwd: root });
  assert.notEqual(tracked, "", `git ls-files listed no tracked file in ${root}`);
  let listed = "";
  try {
    listed = git(["grep", "-l", "-E", pattern, "--", ".", ":!*.md"], { cwd: root });
  } catch (error) {
    if (error.status !== 1) throw error;
  }
  return listed ? listed.split("\n").sort() : [];
}

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

test("node scripts/godot-home.mjs --bin prints the resolved binary or fails with the owner's message", () => {
  const owner = path.join(SCRIPTS_DIR, "godot-home.mjs");
  const run = (args, env) =>
    spawnSync(process.execPath, [owner, ...args], {
      encoding: "utf8",
      env: { ...process.env, ...env },
    });
  const found = run(["--bin"], { GODOT_BIN: process.execPath });
  assert.equal(found.status, 0, found.stderr);
  assert.equal(found.stdout, `${process.execPath}\n`);
  const missing = run(["--bin"], { GODOT_BIN: "/missing/godot" });
  assert.equal(missing.status, 1);
  assert.equal(missing.stdout, "");
  assert.equal(
    missing.stderr,
    "godot-home: Godot binary not found at /missing/godot; set GODOT_BIN\n",
  );
  for (const args of [[], ["--bogus"], ["--bin", "extra"]]) {
    const refused = run(args, { GODOT_BIN: process.execPath });
    assert.equal(refused.status, 1, `expected a refusal for ${JSON.stringify(args)}`);
    assert.equal(refused.stdout, "");
    assert.match(refused.stderr, /^godot-home: (usage|unknown argument)/);
  }
});

test("only the owner and the files listed with a reason spell a Godot binary path", () => {
  const found = filesSpellingGodotPath(REPO_ROOT);
  assert.ok(found.length > 0, "the search for Godot binary paths listed no file");
  assert.deepEqual(
    found,
    Object.keys(SPELLS_GODOT_PATH).sort(),
    "a file spells a Godot binary path the owner already knows; ask `node scripts/godot-home.mjs --bin` (an explicit GODOT_BIN still wins), or list the file here with its reason",
  );
});

test("the search for Godot binary paths sees every spelling and fails when it reads nothing", () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-godot-spelling-"));
  try {
    assert.throws(() => filesSpellingGodotPath(dir), /git ls-files failed/);
    git(["init", "-q"], { cwd: dir });
    assert.throws(() => filesSpellingGodotPath(dir), /listed no tracked file/);
    const spellings = {
      "linux.sh": 'godot="$HOME/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64"\n',
      "mac.sh": 'godot="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"\n',
      "template.mjs": "const bin = `Godot_v${GODOT_VERSION}-stable_linux.x86_64`;\n",
      "format.py": 'GODOT = f"Godot_v{VERSION}-stable_linux.x86_64"\n',
      "shell-var.sh": "godot=/opt/Godot_v$GODOT_VERSION\n",
      "clean.sh": 'godot="$(node scripts/godot-home.mjs --bin)"\n',
      "notes.md": "Godot_v4.7.2-stable_linux.x86_64\n",
      "untracked.sh": "Godot_v4.7.2-stable_linux.x86_64\n",
    };
    for (const [rel, text] of Object.entries(spellings)) writeFileSync(path.join(dir, rel), text);
    git(["add", "--", ...Object.keys(spellings).filter((rel) => rel !== "untracked.sh")], {
      cwd: dir,
    });
    assert.deepEqual(filesSpellingGodotPath(dir), [
      "format.py",
      "linux.sh",
      "mac.sh",
      "shell-var.sh",
      "template.mjs",
    ]);
    assert.throws(() => filesSpellingGodotPath(dir, "Godot_v("), /git grep .* failed/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
