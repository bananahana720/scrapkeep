import { spawnSync } from "node:child_process";
import { chmod, copyFile, mkdir, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { existsSync, readdirSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// node scripts/sketch-appimage.mjs: wraps the newest npm run sketch:export tarball
// (artifacts/local/core-loop-export/scrapkeep-core-loop-<sha>.tar.gz, pack embedded) into
// Scrapkeep-<sha>-x86_64.AppImage beside it, then installs it for the current user: the AppImage
// at ~/.local/share/scrapkeep/Scrapkeep.AppImage, the icon under ~/.local/share/icons and the
// app-menu entry at ~/.local/share/applications/scrapkeep.desktop. --tarball=<path> picks another
// export, --no-install only builds, --appimagetool=<path> (or APPIMAGETOOL) names the packer.
// The game and its music_ace folder sit side by side in usr/lib/scrapkeep/ as real files, because
// the sequencer looks for music_ace beside OS.get_executable_path(), which resolves symlinks.
// appimagetool is not on a stock Arch install and this script never downloads it: without it the
// AppDir is left built and the script prints how to get the tool.

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const exportRoot = path.join(root, "artifacts/local/core-loop-export");
const iconSource = path.join(root, "scripts/appimage/scrapkeep.svg");
export const APP_ID = "scrapkeep";
export const EXECUTABLE = "core-loop.x86_64";
const tarballName = /^scrapkeep-core-loop-([0-9a-f]{7,40}(?:-dirty)?)\.tar\.gz$/;
const toolNames = ["appimagetool", "appimagetool-x86_64.AppImage", "appimagetool.AppImage"];

export function parseArgs(argv) {
  const args = { tarball: null, install: true, appimagetool: null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--no-install") args.install = false;
    else if (arg.startsWith("--tarball=")) args.tarball = arg.slice("--tarball=".length);
    else if (arg === "--tarball" && i + 1 < argv.length) args.tarball = argv[++i];
    else if (arg.startsWith("--appimagetool=")) args.appimagetool = arg.slice("--appimagetool=".length);
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

// Newest by modification time, so a rebuilt sha wins over an older one.
export function newestTarball(directory, list = readdirSync, mtime = (file) => statSync(file).mtimeMs) {
  if (!existsSync(directory)) return null;
  const found = list(directory)
    .filter((name) => tarballName.test(name))
    .map((name) => path.join(directory, name))
    .sort((a, b) => mtime(b) - mtime(a));
  return found[0] ?? null;
}

// Exec names the AppImage when installed, or the command on PATH inside the AppDir.
export function desktopEntry({ exec, icon = APP_ID, tryExec = null }) {
  return (
    [
      "[Desktop Entry]",
      "Type=Application",
      "Name=Scrapkeep",
      "GenericName=Roguelite",
      "Comment=Roll a scrap-mech ball through three worlds with a harpoon",
      "Exec=" + exec,
      ...(tryExec ? ["TryExec=" + tryExec] : []),
      "Icon=" + icon,
      "Terminal=false",
      "Categories=Game;ActionGame;",
      "Keywords=scrap;mech;harpoon;roguelite;",
    ].join("\n") + "\n"
  );
}

// The AppImage runtime mounts the image and runs AppRun with APPDIR set; arguments pass through,
// so "Scrapkeep.AppImage -- --profile=sitting" still reaches the game.
export function appRun() {
  return [
    "#!/bin/sh",
    'HERE="${APPDIR:-$(dirname "$(readlink -f "$0")")}"',
    `exec "$HERE/usr/lib/${APP_ID}/${EXECUTABLE}" "$@"`,
    "",
  ].join("\n");
}

export function findAppimagetool({ flag = null, env = process.env, home = os.homedir(), exists = existsSync }) {
  const named = flag ?? env.APPIMAGETOOL;
  if (named) return exists(named) ? path.resolve(named) : null;
  const dirs = [...(env.PATH ?? "").split(":").filter(Boolean), path.join(home, "Applications"), path.join(home, ".local/bin")];
  for (const dir of dirs)
    for (const name of toolNames) if (exists(path.join(dir, name))) return path.join(dir, name);
  return null;
}

export function missingToolMessage(appDir, named = null) {
  return [
    named ? `appimagetool not found at ${named}.` : "appimagetool not found on PATH, in ~/Applications or in ~/.local/bin.",
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

// The desktop spec splits Exec on spaces, so a path with a space or quote is quoted.
export function execPath(file) {
  return /[\s"'\\$`]/.test(file) ? '"' + file.replace(/(["\\$`])/g, "\\$1") + '"' : file;
}

export function appImageToolArgs(appDir, output) {
  return ["--no-appstream", appDir, output];
}

function run(command, args, options = {}) {
  return spawnSync(command, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, timeout: 600_000, ...options });
}

export class AppImageError extends Error {}

// Builds <tarball dir>/<name>.AppDir, packs it beside the tarball and, unless install is false,
// installs it under dataHome. Returns what it made; throws AppImageError on any failure.
export async function buildAppImage({ tarball, install = true, appimagetool = null, env = process.env, home = os.homedir(), log = console.log }) {
  const version = versionOf(tarball);
  if (!version) throw new AppImageError(`not a sketch:export tarball: ${tarball} (want scrapkeep-core-loop-<sha>.tar.gz)`);
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
  if (top.length !== 1) throw new AppImageError(`expected one folder in the tarball, found ${top.length}`);
  await rename(path.join(unpack, top[0]), lib);
  await rm(unpack, { recursive: true });
  const exe = path.join(lib, EXECUTABLE);
  if (!existsSync(exe)) throw new AppImageError(`no ${EXECUTABLE} in the tarball`);
  if (!existsSync(path.join(lib, "music_ace")))
    log("warning: no music_ace folder in the tarball; the game will play its built-in synth music");
  await chmod(exe, 0o755);

  await writeFile(path.join(appDir, "AppRun"), appRun(), { mode: 0o755 });
  await writeFile(path.join(appDir, APP_ID + ".desktop"), desktopEntry({ exec: APP_ID }));
  await copyFile(iconSource, path.join(appDir, APP_ID + ".svg"));
  await copyFile(iconSource, path.join(appDir, ".DirIcon"));
  log("appdir: " + appDir);

  const tool = findAppimagetool({ flag: appimagetool, env, home });
  if (!tool) throw new AppImageError(missingToolMessage(appDir, appimagetool ?? env.APPIMAGETOOL ?? null));
  await rm(output, { force: true });
  const packed = run(tool, appImageToolArgs(appDir, output), { env: { ...env, ARCH: "x86_64" } });
  if (packed.status !== 0 || !existsSync(output))
    throw new AppImageError(`appimagetool exited ${packed.status}\n` + (packed.stdout + packed.stderr).slice(-2000));
  await chmod(output, 0o755);
  log(`appimage: ${output} (${((await stat(output)).size / 1048576).toFixed(1)} MiB)`);
  if (!install) return { version, appDir, output, installed: null };

  const dataHome = env.XDG_DATA_HOME || path.join(home, ".local/share");
  const installed = installPaths({ dataHome });
  for (const file of Object.values(installed)) await mkdir(path.dirname(file), { recursive: true });
  await copyFile(output, installed.appImage + ".part");
  await chmod(installed.appImage + ".part", 0o755);
  await rename(installed.appImage + ".part", installed.appImage);
  await copyFile(iconSource, installed.icon);
  await writeFile(installed.desktop, desktopEntry({ exec: execPath(installed.appImage), tryExec: installed.appImage }));
  // Optional refreshes; launchers that watch the folder pick the entry up without them.
  run("update-desktop-database", [path.dirname(installed.desktop)]);
  run("gtk-update-icon-cache", ["-q", "-t", path.join(dataHome, "icons/hicolor")]);
  log("installed: " + installed.appImage);
  log("app menu: " + installed.desktop);
  return { version, appDir, output, installed };
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    fail(error.message);
  }
  const tarball = args.tarball ? path.resolve(args.tarball) : newestTarball(exportRoot);
  if (!tarball) fail(`no scrapkeep-core-loop-*.tar.gz in ${exportRoot}; run npm run sketch:export first`);
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

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
