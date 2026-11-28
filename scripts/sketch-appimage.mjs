import { spawnSync } from "node:child_process";
import { chmod, copyFile, mkdir, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { existsSync, readdirSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { isMain } from "./lib/cli.mjs";

// the sequencer looks for music_ace beside OS.get_executable_path(), which resolves symlinks.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const exportRoot = path.join(root, "artifacts/local/core-loop-export");
const iconSource = path.join(root, "scripts/appimage/scrapkeep.svg");
const installScript = path.join(root, "scripts/appimage/install.sh");
export const APP_ID = "scrapkeep";
// Godot 4.7.2 sets the X11 WM_CLASS class from application/config/name in
// measured, to follow it. StartupWMClass must equal it so a launcher groups the window with its
export const WM_CLASS = "Scrapkeep";
export const EXECUTABLE = "core-loop.x86_64";
const tarballName = /^scrapkeep-core-loop-([0-9a-f]{7,40}(?:-dirty)?)\.tar\.gz$/;
const toolNames = ["appimagetool", "appimagetool-x86_64.AppImage", "appimagetool.AppImage"];

export function parseArgs(argv) {
  const args = { tarball: null, install: true, appimagetool: null, uninstall: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--no-install") args.install = false;
    else if (arg === "--uninstall") args.uninstall = true;
    else if (arg.startsWith("--tarball=")) args.tarball = arg.slice("--tarball=".length);
    else if (arg === "--tarball" && i + 1 < argv.length) args.tarball = argv[++i];
    else if (arg.startsWith("--appimagetool="))
      args.appimagetool = arg.slice("--appimagetool=".length);
    else if (arg === "--appimagetool" && i + 1 < argv.length) args.appimagetool = argv[++i];
    else throw new Error("unknown argument: " + arg);
  }
  return args;
}

export function versionOf(tarball) {
  return tarballName.exec(path.basename(tarball))?.[1] ?? null;
}

export function appImageName(version) {
  return `Scrapkeep-${version}-x86_64.AppImage`;
}

export function newestTarball(
  directory,
  list = readdirSync,
  mtime = (file) => statSync(file).mtimeMs,
) {
  if (!existsSync(directory)) return null;
  const found = list(directory)
    .filter((name) => tarballName.test(name))
    .map((name) => path.join(directory, name))
    .sort((a, b) => mtime(b) - mtime(a));
  return found[0] ?? null;
}

export function desktopEntry({ exec, icon = APP_ID }) {
  return (
    [
      "[Desktop Entry]",
      "Type=Application",
      "Name=Scrapkeep",
      "GenericName=Roguelite",
      "Comment=Roll a scrap-mech ball through three worlds with a harpoon",
      "Exec=" + exec,
      "Icon=" + icon,
      "Terminal=false",
      "StartupNotify=true",
      "StartupWMClass=" + WM_CLASS,
      "Categories=Game;ActionGame;",
      "Keywords=scrap;mech;harpoon;roguelite;",
      "Actions=sitting-earned;sitting;sitting-alpha-earned;sitting-alpha;",
      "",
      "[Desktop Action sitting-earned]",
      "Name=Scrapkeep sitting (fresh profile, unlocks earned)",
      "Exec=" + exec + " -- --profile=sitting-earned",
      "",
      "[Desktop Action sitting]",
      "Name=Scrapkeep sitting (all pilots, save untouched)",
      "Exec=" + exec + " -- --profile=sitting",
      "",
      "[Desktop Action sitting-alpha-earned]",
      "Name=Scrapkeep full-alpha sitting (fresh profile, unlocks earned)",
      "Exec=" + exec + " -- --profile=sitting-earned --final-world=last",
      "",
      "[Desktop Action sitting-alpha]",
      "Name=Scrapkeep full-alpha sitting (all pilots, save untouched)",
      "Exec=" + exec + " -- --profile=sitting --final-world=last",
    ].join("\n") + "\n"
  );
}

export function appRun() {
  return [
    "#!/bin/sh",
    'HERE="${APPDIR:-$(dirname "$(readlink -f "$0")")}"',
    'case "${1:-}" in',
    `--install | --uninstall) exec sh "$HERE/usr/bin/${APP_ID}-install" "\${1#--}" "\${APPIMAGE:-}" "$HERE" ;;`,
    "esac",
    `exec "$HERE/usr/lib/${APP_ID}/${EXECUTABLE}" "$@"`,
    "",
  ].join("\n");
}

export function findAppimagetool({
  flag = null,
  env = process.env,
  home = os.homedir(),
  exists = existsSync,
}) {
  const named = flag ?? env.APPIMAGETOOL;
  if (named) return exists(named) ? path.resolve(named) : null;
  const dirs = [
    ...(env.PATH ?? "").split(":").filter(Boolean),
    path.join(home, "Applications"),
    path.join(home, ".local/bin"),
  ];
  for (const dir of dirs)
    for (const name of toolNames) if (exists(path.join(dir, name))) return path.join(dir, name);
  return null;
}

export function missingToolMessage(appDir, named = null) {
  return [
    named
      ? `appimagetool not found at ${named}.`
      : "appimagetool not found on PATH, in ~/Applications or in ~/.local/bin.",
    `The AppDir is built at ${appDir}. Get the packer one of these ways, then run this again:`,
    "  yay -S appimagetool-bin        (AUR package; Omarchy ships yay)",
    "  or download appimagetool-x86_64.AppImage from https://github.com/AppImage/appimagetool/releases,",
    "  chmod +x it and put it in ~/.local/bin or pass --appimagetool=<path>.",
    "AppImages need FUSE to mount themselves; if one will not start, install it with: sudo pacman -S fuse2",
  ].join("\n");
}

export function installPaths({ dataHome }) {
  return {
    appImage: path.join(dataHome, APP_ID, "Scrapkeep.AppImage"),
    icon: path.join(dataHome, "icons/hicolor/scalable/apps", APP_ID + ".svg"),
    desktop: path.join(dataHome, "applications", APP_ID + ".desktop"),
  };
}

export function appImageToolArgs(appDir, output) {
  return ["--no-appstream", appDir, output];
}

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 600_000,
    ...options,
  });
}

export class AppImageError extends Error {}

export async function buildAppImage({
  tarball,
  install = true,
  appimagetool = null,
  env = process.env,
  home = os.homedir(),
  log = console.log,
}) {
  const version = versionOf(tarball);
  if (!version)
    throw new AppImageError(
      `not a sketch:export tarball: ${tarball} (want scrapkeep-core-loop-<sha>.tar.gz)`,
    );
  if (!existsSync(tarball)) throw new AppImageError("tarball missing: " + tarball);
  const outDir = path.dirname(tarball);
  const output = path.join(outDir, appImageName(version));
  const appDir = path.join(outDir, appImageName(version).replace(/\.AppImage$/, ".AppDir"));
  await rm(appDir, { recursive: true, force: true });
  const lib = path.join(appDir, "usr/lib", APP_ID);
  await mkdir(path.dirname(lib), { recursive: true });
  const unpack = appDir + ".unpack";
  await rm(unpack, { recursive: true, force: true });
  await mkdir(unpack);
  const untar = run("tar", ["-xzf", tarball, "-C", unpack]);
  if (untar.status !== 0) throw new AppImageError("tar failed\n" + untar.stderr);
  const top = await readdir(unpack);
  if (top.length !== 1)
    throw new AppImageError(`expected one folder in the tarball, found ${top.length}`);
  await rename(path.join(unpack, top[0]), lib);
  await rm(unpack, { recursive: true });
  const exe = path.join(lib, EXECUTABLE);
  if (!existsSync(exe)) throw new AppImageError(`no ${EXECUTABLE} in the tarball`);
  if (!existsSync(path.join(lib, "music_ace")))
    log("warning: no music_ace folder in the tarball; the game will play its built-in synth music");
  await chmod(exe, 0o755);

  await writeFile(path.join(appDir, "AppRun"), appRun(), { mode: 0o755 });
  await mkdir(path.join(appDir, "usr/bin"), { recursive: true });
  await copyFile(installScript, path.join(appDir, "usr/bin", APP_ID + "-install"));
  await chmod(path.join(appDir, "usr/bin", APP_ID + "-install"), 0o755);
  await writeFile(path.join(appDir, APP_ID + ".desktop"), desktopEntry({ exec: APP_ID }));
  await copyFile(iconSource, path.join(appDir, APP_ID + ".svg"));
  await copyFile(iconSource, path.join(appDir, ".DirIcon"));
  log("appdir: " + appDir);

  const tool = findAppimagetool({ flag: appimagetool, env, home });
  if (!tool)
    throw new AppImageError(missingToolMessage(appDir, appimagetool ?? env.APPIMAGETOOL ?? null));
  await rm(output, { force: true });
  const packed = run(tool, appImageToolArgs(appDir, output), { env: { ...env, ARCH: "x86_64" } });
  if (packed.status !== 0 || !existsSync(output))
    throw new AppImageError(
      `appimagetool exited ${packed.status}\n` + (packed.stdout + packed.stderr).slice(-2000),
    );
  await chmod(output, 0o755);
  log(`appimage: ${output} (${((await stat(output)).size / 1048576).toFixed(1)} MiB)`);
  if (!install) return { version, appDir, output, installed: null };

  const installed = await runInstallScript(["install", output, appDir], { env, home, log });
  return { version, appDir, output, installed };
}

export function dataHomeOf(env, home) {
  return env.XDG_DATA_HOME || path.join(home, ".local/share");
}

export async function runInstallScript(
  args,
  { env = process.env, home = os.homedir(), log = console.log } = {},
) {
  const dataHome = dataHomeOf(env, home);
  const result = run("sh", [installScript, ...args], {
    env: { ...env, HOME: home, XDG_DATA_HOME: dataHome },
  });
  if (result.status !== 0)
    throw new AppImageError(
      `install.sh ${args[0]} exited ${result.status}\n` + result.stdout + result.stderr,
    );
  for (const line of result.stdout.trim().split("\n")) if (line) log(line);
  return installPaths({ dataHome });
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    fail(error.message);
  }
  if (args.uninstall) {
    try {
      await runInstallScript(["uninstall"]);
    } catch (error) {
      if (error instanceof AppImageError) fail(error.message);
      throw error;
    }
    return;
  }
  const tarball = args.tarball ? path.resolve(args.tarball) : newestTarball(exportRoot);
  if (!tarball)
    fail(`no scrapkeep-core-loop-*.tar.gz in ${exportRoot}; run npm run sketch:export first`);
  try {
    await buildAppImage({ tarball, install: args.install, appimagetool: args.appimagetool });
  } catch (error) {
    if (error instanceof AppImageError) fail(error.message);
    throw error;
  }
}

function fail(message) {
  console.error("sketch:appimage FAIL: " + message);
  process.exit(1);
}

if (isMain(import.meta.url)) await main();
