import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";

// Godot on macOS ignores XDG_DATA_HOME and keeps user:// under $HOME/Library/Application Support
// (platform/macos/os_macos.mm), so a scratch data home isolates a run there only when HOME moves
// with it. Linux and Windows keep the caller's HOME.
export function userDataEnv(dir, platform = process.platform) {
  return platform === "darwin" ? { XDG_DATA_HOME: dir, HOME: dir } : { XDG_DATA_HOME: dir };
}

export function scratchHomeEnv(makeDir, platform = process.platform) {
  return platform === "darwin" ? { HOME: makeDir() } : {};
}

export const GODOT_VERSION = "4.7.2";

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
