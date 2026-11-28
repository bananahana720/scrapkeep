import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { isMain, parseCliArgs } from "./lib/cli.mjs";

export const TOOLCHAIN = JSON.parse(
  readFileSync(new URL("./toolchain.json", import.meta.url), "utf8"),
);

// Godot on macOS ignores XDG_DATA_HOME and keeps user:// under $HOME/Library/Application Support
// (platform/macos/os_macos.mm), so a scratch data home isolates a run there only when HOME moves
// with it. Linux and Windows keep the caller's HOME.
export function userDataEnv(dir, platform = process.platform) {
  return platform === "darwin" ? { XDG_DATA_HOME: dir, HOME: dir } : { XDG_DATA_HOME: dir };
}

export function scratchHomeEnv(makeDir, platform = process.platform) {
  return platform === "darwin" ? { HOME: makeDir() } : {};
}

const XDG_KEYS = {
  data: "XDG_DATA_HOME",
  config: "XDG_CONFIG_HOME",
  cache: "XDG_CACHE_HOME",
  state: "XDG_STATE_HOME",
};
const DEFAULT_XDG_DIRS = { data: "data", config: "config", cache: "cache" };

export function scratchGodotEnv(
  dir,
  {
    baseEnv = null,
    dirs = DEFAULT_XDG_DIRS,
    forceHome = false,
    homeDir = null,
    create = false,
    platform = process.platform,
  } = {},
) {
  const env = baseEnv ? { ...baseEnv } : {};
  let dataDir = dir;
  if (dirs) {
    for (const [slot, rel] of Object.entries(dirs)) {
      const key = XDG_KEYS[slot];
      if (!key) throw new Error(`unknown XDG slot: ${slot}`);
      const full = rel ? path.join(dir, rel) : dir;
      if (create) mkdirSync(full, { recursive: true });
      env[key] = full;
      if (slot === "data") dataDir = full;
    }
  } else {
    if (create) mkdirSync(dir, { recursive: true });
    env.XDG_DATA_HOME = dir;
  }
  if (forceHome || platform === "darwin") {
    env.HOME = homeDir ?? (forceHome ? dir : dataDir);
  }
  return env;
}

export async function withScratchGodotEnv(
  fn,
  {
    prefix = "scrapkeep-godot-",
    tmpRoot = os.tmpdir(),
    baseEnv = process.env,
    dirs = DEFAULT_XDG_DIRS,
    forceHome = false,
    homeOnly = false,
    platform = process.platform,
  } = {},
) {
  if (homeOnly && platform !== "darwin") {
    return await fn(baseEnv ? { ...baseEnv } : {}, null);
  }
  const dir = mkdtempSync(path.join(tmpRoot, prefix));
  try {
    const env = homeOnly
      ? { ...(baseEnv ?? {}), HOME: dir }
      : scratchGodotEnv(dir, {
          baseEnv,
          dirs,
          forceHome,
          create: dirs !== null,
          platform,
        });
    return await fn(env, dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export const GODOT_VERSION = TOOLCHAIN.godotNumericVersion;

export function whichTool(toolName, env = process.env) {
  const found = spawnSync("which", [toolName], { env, encoding: "utf8" });
  if (found.status === 0) {
    const resolved = found.stdout.trim().split(/\r?\n/)[0];
    if (resolved) return resolved;
  }
  return null;
}

export function resolveGodotBinary({
  env = process.env,
  platform = process.platform,
  homeDir = os.homedir(),
  exists = existsSync,
  which = null,
  requireExplicit = false,
} = {}) {
  const explicit = typeof env.GODOT_BIN === "string" ? env.GODOT_BIN.trim() : "";
  if (explicit) return explicit;
  if (requireExplicit) return null;
  if (platform === "darwin") {
    const macApp = path.join(
      homeDir,
      "Applications",
      `Godot_${GODOT_VERSION}.app`,
      "Contents",
      "MacOS",
      "Godot",
    );
    if (exists(macApp)) return macApp;
  }
  if (which) {
    const onPath = which("godot");
    if (onPath && exists(onPath)) return onPath;
  }
  const candidates = [
    `/opt/scrapkeep-toolchain/Godot_v${GODOT_VERSION}-stable_linux.x86_64`,
    path.join(
      homeDir,
      ".local",
      "share",
      "godot",
      GODOT_VERSION,
      `Godot_v${GODOT_VERSION}-stable_linux.x86_64`,
    ),
    "/usr/bin/godot",
  ];
  return candidates.find((candidate) => exists(candidate)) ?? null;
}

export function requireGodotBinary(options = {}) {
  const exists = options.exists ?? existsSync;
  const binary = resolveGodotBinary(options);
  if (!binary || !exists(binary)) {
    throw new Error(`Godot binary not found${binary ? ` at ${binary}` : ""}; set GODOT_BIN`);
  }
  return binary;
}

if (isMain(import.meta.url)) {
  try {
    const { bin } = parseCliArgs(process.argv.slice(2), { flags: { "--bin": "bin" } });
    if (!bin) throw new Error("usage: node scripts/godot-home.mjs --bin");
    console.log(requireGodotBinary({ which: whichTool }));
  } catch (error) {
    console.error(`godot-home: ${error.message}`);
    process.exitCode = 1;
  }
}
