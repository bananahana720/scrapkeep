import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, statSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  APP_ID,
  AppImageError,
  EXECUTABLE,
  appImageName,
  appImageToolArgs,
  appRun,
  buildAppImage,
  desktopEntry,
  WM_CLASS,
  findAppimagetool,
  installPaths,
  missingToolMessage,
  newestTarball,
  parseArgs,
  versionOf,
} from "./sketch-appimage.mjs";

test("parseArgs defaults to the newest tarball, installing, with no named packer", () => {
  assert.deepEqual(parseArgs([]), {
    tarball: null,
    install: true,
    appimagetool: null,
    uninstall: false,
  });
  assert.equal(parseArgs(["--uninstall"]).uninstall, true);
  assert.deepEqual(parseArgs(["--tarball=/a.tar.gz", "--no-install", "--appimagetool", "/t"]), {
    tarball: "/a.tar.gz",
    install: false,
    appimagetool: "/t",
    uninstall: false,
  });
  assert.throws(() => parseArgs(["--nope"]), /unknown argument: --nope/);
});

test("versionOf reads the sha and dirty mark from a sketch:export tarball name only", () => {
  assert.equal(versionOf("/x/scrapkeep-core-loop-77b99de.tar.gz"), "77b99de");
  assert.equal(versionOf("scrapkeep-core-loop-77b99de-dirty.tar.gz"), "77b99de-dirty");
  assert.equal(versionOf("scrapkeep-core-loop-77b99de.zip"), null);
  assert.equal(appImageName("77b99de"), "Scrapkeep-77b99de-x86_64.AppImage");
});

test("newestTarball picks the most recently written export and ignores other files", () => {
  const times = {
    "/e/scrapkeep-core-loop-aaaaaaa.tar.gz": 1,
    "/e/scrapkeep-core-loop-bbbbbbb.tar.gz": 2,
  };
  const list = () => [
    "scrapkeep-core-loop-aaaaaaa.tar.gz",
    "scrapkeep-core-loop-bbbbbbb.tar.gz",
    "20261016T000000",
    "notes.txt",
  ];
  const dir = mkdtempSync(path.join(os.tmpdir(), "appimage-newest-"));
  assert.equal(newestTarball(dir), null);
  assert.equal(newestTarball(path.join(dir, "missing")), null);
  assert.equal(
    newestTarball(dir, list, (file) => times["/e/" + path.basename(file)] ?? 0),
    path.join(dir, "scrapkeep-core-loop-bbbbbbb.tar.gz"),
  );
});

test("the desktop entry names the game, its icon and the Game category", () => {
  const entry = desktopEntry({ exec: APP_ID });
  assert.ok(entry.startsWith("[Desktop Entry]\nType=Application\nName=Scrapkeep\n"));
  assert.match(entry, /^Exec=scrapkeep$/m);
  assert.match(entry, new RegExp(`^Icon=${APP_ID}$`, "m"));
  assert.match(entry, /^Categories=Game;ActionGame;$/m);
  assert.match(entry, /^Terminal=false$/m);
  assert.doesNotMatch(entry, /TryExec/);
  assert.match(entry, /^Actions=sitting-earned;sitting;sitting-alpha-earned;sitting-alpha;$/m);
  assert.ok(
    entry.includes(
      "\n[Desktop Action sitting-earned]\nName=Scrapkeep sitting (fresh profile, unlocks earned)\nExec=scrapkeep -- --profile=sitting-earned\n",
    ),
    entry,
  );
  assert.ok(
    entry.includes(
      "\n[Desktop Action sitting]\nName=Scrapkeep sitting (all pilots, save untouched)\nExec=scrapkeep -- --profile=sitting\n",
    ),
    entry,
  );
  assert.ok(
    entry.includes(
      "\n[Desktop Action sitting-alpha-earned]\nName=Scrapkeep full-alpha sitting (fresh profile, unlocks earned)\nExec=scrapkeep -- --profile=sitting-earned --final-world=last\n",
    ),
    entry,
  );
  assert.ok(
    entry.endsWith(
      "[Desktop Action sitting-alpha]\nName=Scrapkeep full-alpha sitting (all pilots, save untouched)\nExec=scrapkeep -- --profile=sitting --final-world=last\n",
    ),
    entry,
  );
});

test("the desktop entry groups the window: StartupWMClass is the project name Godot uses as WM_CLASS", () => {
  const entry = desktopEntry({ exec: APP_ID });
  assert.match(entry, /^StartupNotify=true$/m);
  assert.match(entry, new RegExp(`^StartupWMClass=${WM_CLASS}$`, "m"));
  const project = readFileSync(
    new URL("../sketches/core-loop/project.godot", import.meta.url),
    "utf8",
  );
  assert.match(project, new RegExp(`^config/name="${WM_CLASS}"$`, "m"));
  assert.match(project, /^config\/use_custom_user_dir=true$/m);
  assert.match(project, /^config\/custom_user_dir_name="godot\/app_userdata\/core-loop"$/m);
});

test("the release build flushes each printed line, so the cold launch check sees the menu lines", () => {
  const project = readFileSync(
    new URL("../sketches/core-loop/project.godot", import.meta.url),
    "utf8",
  );
  assert.match(project, /^run\/flush_stdout_on_print=true$/m);
});

test("the project icon is the AppImage icon, byte for byte", () => {
  const a = readFileSync(
    new URL("../sketches/core-loop/assets/app/scrapkeep_icon.svg", import.meta.url),
  );
  const b = readFileSync(new URL("./appimage/scrapkeep.svg", import.meta.url));
  assert.ok(a.equals(b));
});

test("AppRun runs the game from usr/lib and passes every argument through, except --install and --uninstall", () => {
  const text = appRun();
  assert.ok(text.startsWith("#!/bin/sh\n"));
  assert.ok(text.includes(`exec "$HERE/usr/lib/${APP_ID}/${EXECUTABLE}" "$@"`));
  assert.ok(text.includes(`--install | --uninstall) exec sh "$HERE/usr/bin/${APP_ID}-install"`));
});

test("findAppimagetool honours the flag, then APPIMAGETOOL, then PATH and the usual folders", () => {
  const has = (set) => (file) => set.has(file);
  assert.equal(
    findAppimagetool({ flag: "/t/tool", env: {}, home: "/h", exists: has(new Set(["/t/tool"])) }),
    "/t/tool",
  );
  assert.equal(
    findAppimagetool({ flag: "/t/tool", env: {}, home: "/h", exists: has(new Set()) }),
    null,
  );
  assert.equal(
    findAppimagetool({
      env: { APPIMAGETOOL: "/e/tool" },
      home: "/h",
      exists: has(new Set(["/e/tool"])),
    }),
    "/e/tool",
  );
  assert.equal(
    findAppimagetool({
      env: { PATH: "/usr/bin:/opt/bin" },
      home: "/h",
      exists: has(new Set(["/opt/bin/appimagetool"])),
    }),
    "/opt/bin/appimagetool",
  );
  assert.equal(
    findAppimagetool({
      env: { PATH: "/usr/bin" },
      home: "/h",
      exists: has(new Set(["/h/Applications/appimagetool-x86_64.AppImage"])),
    }),
    "/h/Applications/appimagetool-x86_64.AppImage",
  );
  assert.equal(
    findAppimagetool({ env: { PATH: "/usr/bin" }, home: "/h", exists: has(new Set()) }),
    null,
  );
});

test("the missing-tool message says where the AppDir is and how to get the packer, never fetching it", () => {
  const message = missingToolMessage("/x/S.AppDir");
  assert.ok(message.includes("/x/S.AppDir"));
  assert.ok(message.includes("yay -S appimagetool-bin"));
  assert.ok(message.includes("https://github.com/AppImage/appimagetool/releases"));
  assert.ok(message.includes("--appimagetool=<path>"));
  assert.ok(missingToolMessage("/x", "/t/tool").startsWith("appimagetool not found at /t/tool."));
});

test("installPaths puts the AppImage, icon and app-menu entry under the data home", () => {
  assert.deepEqual(installPaths({ dataHome: "/h/.local/share" }), {
    appImage: "/h/.local/share/scrapkeep/Scrapkeep.AppImage",
    icon: "/h/.local/share/icons/hicolor/scalable/apps/scrapkeep.svg",
    desktop: "/h/.local/share/applications/scrapkeep.desktop",
  });
  assert.deepEqual(appImageToolArgs("/a.AppDir", "/a.AppImage"), [
    "--no-appstream",
    "/a.AppDir",
    "/a.AppImage",
  ]);
});

function fakeExport() {
  const dir = mkdtempSync(path.join(os.tmpdir(), "appimage-build-"));
  const stage = path.join(dir, "stage", "scrapkeep-core-loop-abcdef1");
  mkdirSync(path.join(stage, "music_ace/spillway"), { recursive: true });
  writeFileSync(path.join(stage, EXECUTABLE), '#!/bin/sh\necho game "$@"\n');
  writeFileSync(path.join(stage, "music_ace/spillway/manifest.json"), "{}\n");
  writeFileSync(path.join(stage, "BUILD.txt"), "commit: abc\n");
  const tarball = path.join(dir, "scrapkeep-core-loop-abcdef1.tar.gz");
  const tar = spawnSync("tar", ["-czf", tarball, "-C", path.dirname(stage), path.basename(stage)]);
  assert.equal(tar.status, 0, String(tar.stderr));
  const tool = path.join(dir, "fake-appimagetool");
  writeFileSync(
    tool,
    '#!/bin/sh\necho "$@" > "$(dirname "$0")/tool-args"\necho "$ARCH" > "$(dirname "$0")/tool-arch"\nprintf image > "$3"\n',
    { mode: 0o755 },
  );
  return { dir, tarball, tool };
}

test("buildAppImage lays out the AppDir, packs it and installs the app-menu entry", async () => {
  const { dir, tarball, tool } = fakeExport();
  const home = path.join(dir, "home");
  const result = await buildAppImage({
    tarball,
    appimagetool: tool,
    env: { PATH: process.env.PATH },
    home,
    log: () => {},
  });
  const appDir = path.join(dir, "Scrapkeep-abcdef1-x86_64.AppDir");
  assert.equal(result.appDir, appDir);
  assert.equal(result.output, path.join(dir, "Scrapkeep-abcdef1-x86_64.AppImage"));
  assert.ok(statSync(path.join(appDir, "usr/lib/scrapkeep", EXECUTABLE)).mode & 0o100);
  assert.ok(existsSync(path.join(appDir, "usr/lib/scrapkeep/music_ace/spillway/manifest.json")));
  assert.ok(statSync(path.join(appDir, "AppRun")).mode & 0o100);
  assert.match(readFileSync(path.join(appDir, "scrapkeep.desktop"), "utf8"), /^Exec=scrapkeep$/m);
  assert.ok(existsSync(path.join(appDir, "scrapkeep.svg")));
  assert.ok(existsSync(path.join(appDir, ".DirIcon")));
  assert.equal(
    readFileSync(path.join(dir, "tool-args"), "utf8").trim(),
    `--no-appstream ${appDir} ${result.output}`,
  );
  assert.equal(readFileSync(path.join(dir, "tool-arch"), "utf8").trim(), "x86_64");

  const run = spawnSync(path.join(appDir, "AppRun"), ["--", "--profile=sitting"], {
    encoding: "utf8",
    env: { APPDIR: appDir },
  });
  assert.equal(run.stdout.trim(), "game -- --profile=sitting");

  const share = path.join(home, ".local/share");
  assert.equal(readFileSync(path.join(share, "scrapkeep/Scrapkeep.AppImage"), "utf8"), "image");
  assert.ok(statSync(path.join(share, "scrapkeep/Scrapkeep.AppImage")).mode & 0o100);
  assert.ok(existsSync(path.join(share, "icons/hicolor/scalable/apps/scrapkeep.svg")));
  const entry = readFileSync(path.join(share, "applications/scrapkeep.desktop"), "utf8");
  assert.match(
    entry,
    new RegExp(`^Exec=${share.replace(/[.]/g, "\\.")}/scrapkeep/Scrapkeep\\.AppImage$`, "m"),
  );
  assert.match(
    entry,
    new RegExp(`^TryExec=${share.replace(/[.]/g, "\\.")}/scrapkeep/Scrapkeep\\.AppImage$`, "m"),
  );
  assert.match(entry, /^Categories=Game;ActionGame;$/m);
  assert.ok(statSync(path.join(appDir, "usr/bin/scrapkeep-install")).mode & 0o100);
});

function runImage(appDir, image, dataHome, args) {
  return spawnSync(path.join(appDir, "AppRun"), args, {
    encoding: "utf8",
    env: {
      PATH: process.env.PATH,
      HOME: path.join(dataHome, "home"),
      APPDIR: appDir,
      APPIMAGE: image,
      XDG_DATA_HOME: dataHome,
    },
  });
}

test("the AppImage installs and uninstalls itself with --install and --uninstall, keeping saves", async () => {
  const { dir, tarball, tool } = fakeExport();
  const { appDir, output } = await buildAppImage({
    tarball,
    install: false,
    appimagetool: tool,
    env: { PATH: process.env.PATH },
    log: () => {},
  });
  const dataHome = path.join(dir, "a b", "share");
  const install = runImage(appDir, output, dataHome, ["--install"]);
  assert.equal(install.status, 0, install.stderr);
  assert.doesNotMatch(install.stdout, /^game/m);
  const app = path.join(dataHome, "scrapkeep/Scrapkeep.AppImage");
  assert.equal(readFileSync(app, "utf8"), "image");
  const entry = readFileSync(path.join(dataHome, "applications/scrapkeep.desktop"), "utf8");
  assert.ok(entry.includes(`\nExec="${app}"\nTryExec=${app}\n`), entry);
  assert.match(entry, /^Actions=sitting-earned;sitting;sitting-alpha-earned;sitting-alpha;$/m);
  assert.ok(
    entry.includes(`\nExec="${app}" -- --profile=sitting-earned --final-world=last\n`),
    entry,
  );
  assert.ok(entry.endsWith(`\nExec="${app}" -- --profile=sitting --final-world=last\n`), entry);
  assert.equal(entry.match(/^TryExec=/gm).length, 1);
  assert.match(entry, /^Name=Scrapkeep$/m);
  assert.match(entry, new RegExp(`^StartupWMClass=${WM_CLASS}$`, "m"));
  assert.match(entry, /^StartupNotify=true$/m);
  assert.ok(existsSync(path.join(dataHome, "icons/hicolor/scalable/apps/scrapkeep.svg")));

  const again = runImage(appDir, app, dataHome, ["--install"]);
  assert.equal(again.status, 0, again.stderr);
  assert.equal(readFileSync(app, "utf8"), "image");

  const saves = path.join(dataHome, "godot/app_userdata/core-loop");
  mkdirSync(saves, { recursive: true });
  writeFileSync(path.join(saves, "profile.json"), "{}");
  const remove = runImage(appDir, output, dataHome, ["--uninstall"]);
  assert.equal(remove.status, 0, remove.stderr);
  assert.match(remove.stdout, /saves and settings are kept/);
  for (const gone of [
    "scrapkeep",
    "applications/scrapkeep.desktop",
    "icons/hicolor/scalable/apps/scrapkeep.svg",
  ])
    assert.ok(!existsSync(path.join(dataHome, gone)), gone);
  assert.ok(existsSync(path.join(saves, "profile.json")));
});

test("--install without an AppImage to copy fails and writes nothing", async () => {
  const { dir, tarball, tool } = fakeExport();
  const { appDir } = await buildAppImage({
    tarball,
    install: false,
    appimagetool: tool,
    env: { PATH: process.env.PATH },
    log: () => {},
  });
  const dataHome = path.join(dir, "share");
  const run = runImage(appDir, "", dataHome, ["--install"]);
  assert.equal(run.status, 1);
  assert.match(run.stderr, /no AppImage to install/);
  assert.ok(!existsSync(dataHome));
});

test("buildAppImage honours XDG_DATA_HOME and --no-install", async () => {
  const { dir, tarball, tool } = fakeExport();
  const dataHome = path.join(dir, "xdg");
  await buildAppImage({
    tarball,
    appimagetool: tool,
    env: { PATH: process.env.PATH, XDG_DATA_HOME: dataHome },
    home: "/nonexistent",
    log: () => {},
  });
  assert.ok(existsSync(path.join(dataHome, "applications/scrapkeep.desktop")));
  const skipped = await buildAppImage({
    tarball,
    install: false,
    appimagetool: tool,
    env: { PATH: process.env.PATH, XDG_DATA_HOME: path.join(dir, "none") },
    log: () => {},
  });
  assert.equal(skipped.installed, null);
  assert.ok(!existsSync(path.join(dir, "none")));
});

test("buildAppImage without appimagetool leaves the AppDir and says how to get the tool", async () => {
  const { dir, tarball } = fakeExport();
  await assert.rejects(
    buildAppImage({ tarball, env: { PATH: "" }, home: path.join(dir, "home"), log: () => {} }),
    (error) =>
      error instanceof AppImageError &&
      /appimagetool not found/.test(error.message) &&
      /yay -S/.test(error.message),
  );
  assert.ok(existsSync(path.join(dir, "Scrapkeep-abcdef1-x86_64.AppDir/AppRun")));
  assert.ok(!existsSync(path.join(dir, "home/.local/share/applications")));
});

test("buildAppImage refuses a file that is not a sketch:export tarball", async () => {
  await assert.rejects(
    buildAppImage({ tarball: "/x/game.tar.gz", log: () => {} }),
    /not a sketch:export tarball/,
  );
  await assert.rejects(
    buildAppImage({ tarball: "/x/scrapkeep-core-loop-abcdef1.tar.gz", log: () => {} }),
    /tarball missing/,
  );
});
