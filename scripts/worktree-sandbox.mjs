#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  closeSync,
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { ensureNodeModules } from "./ensure-node-modules.mjs";
import {
  godotIdentity,
  hasValidUidCache,
  importSketch,
  writeImportStamp,
} from "./import-stamp.mjs";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SANDBOX_ROOT_REL = path.join("artifacts", "local", "dev-ref");
export const LOCK_FILENAME = ".sandbox-lock.json";
export const OVERLAY_MARKER = ".sandbox-overlay.json";
export const IMPORT_STAMP_FILENAME = "scrapkeep-sandbox-import.json";
const SEAM_VERSION = "2";
const MAX_AUTO_SLOTS = 32;

export function isPidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === "EPERM";
  }
}

function safeRealpath(targetPath) {
  try {
    return realpathSync(targetPath);
  } catch {
    return path.resolve(targetPath);
  }
}

export function validateSlotName(slot) {
  if (
    typeof slot !== "string" ||
    !/^[a-zA-Z0-9._-]+$/.test(slot) ||
    slot === "." ||
    slot === ".."
  ) {
    throw new Error(`Invalid sandbox slot "${slot}": use letters, digits, '.', '_', or '-'`);
  }
  return slot;
}

export function writeFileAtomic(filePath, content) {
  mkdirSync(path.dirname(filePath), { recursive: true });
  const tmpPath = path.join(
    path.dirname(filePath),
    `.${path.basename(filePath)}.${process.pid}.${Date.now()}.tmp`,
  );
  writeFileSync(tmpPath, content, "utf8");
  renameSync(tmpPath, filePath);
}

function readJsonSafe(filePath) {
  if (!existsSync(filePath)) return null;
  try {
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

export function sandboxBaseDir(repoRoot = REPO_ROOT) {
  return path.resolve(repoRoot, SANDBOX_ROOT_REL);
}

export function assertUnderSandboxRoot(targetPath, repoRoot = REPO_ROOT) {
  const base = sandboxBaseDir(repoRoot);
  const resolved = path.resolve(targetPath);
  const rel = path.relative(base, resolved);
  if (!rel || rel === "." || rel.startsWith("..") || path.isAbsolute(rel)) {
    const error = new Error(
      `Refusing sandbox path outside ${SANDBOX_ROOT_REL}/: "${resolved}" (must stay under "${base}")`,
    );
    error.code = "SANDBOX_PATH_ESCAPE";
    throw error;
  }
  return resolved;
}

export function assertNotPrimaryCheckout(targetDir, repoRoot = REPO_ROOT) {
  const resolvedTarget = safeRealpath(targetDir);
  const resolvedRepo = safeRealpath(repoRoot);
  const base = safeRealpath(sandboxBaseDir(repoRoot));
  const relToBase = path.relative(base, resolvedTarget);
  const insideSandbox =
    Boolean(relToBase) &&
    relToBase !== "." &&
    !relToBase.startsWith("..") &&
    !path.isAbsolute(relToBase);

  if (resolvedTarget === resolvedRepo) {
    const error = new Error(
      `Refusing to mutate primary checkout "${resolvedTarget}": use an isolated detached sandbox under ${SANDBOX_ROOT_REL}/`,
    );
    error.code = "PRIMARY_CHECKOUT_PROTECTED";
    throw error;
  }

  const hooksJson = path.join(resolvedTarget, ".agents", "hooks.json");
  if (!insideSandbox && existsSync(hooksJson)) {
    const error = new Error(
      `Refusing to mutate checkout owning .agents/hooks.json ("${resolvedTarget}"): use --ref with an isolated detached sandbox under ${SANDBOX_ROOT_REL}/`,
    );
    error.code = "PRIMARY_CHECKOUT_PROTECTED";
    throw error;
  }
}

export function resolveGitRef(ref, repoRoot = REPO_ROOT, { spawn = spawnSync } = {}) {
  if (typeof ref !== "string" || ref.trim() === "") {
    throw new Error("--ref requires a non-empty git ref or commit SHA");
  }
  const cleanRef = ref.trim();
  const ran = spawn("git", ["-C", repoRoot, "rev-parse", "--verify", `${cleanRef}^{commit}`], {
    encoding: "utf8",
  });
  if (ran.error || ran.status !== 0 || !ran.stdout.trim()) {
    throw new Error(
      `Could not resolve git ref "${cleanRef}": ${(ran.stderr || ran.error?.message || "unknown ref").trim()}`,
    );
  }
  const sha = ran.stdout.trim().split(/\r?\n/)[0];
  return { ref: cleanRef, sha, sha12: sha.slice(0, 12) };
}

export function acquireSlotLock(
  slotDir,
  metadata = {},
  { isAlive = isPidAlive, pid = process.pid } = {},
) {
  mkdirSync(slotDir, { recursive: true });
  const lockPath = path.join(slotDir, LOCK_FILENAME);
  const payload =
    JSON.stringify(
      {
        pid,
        ...metadata,
        acquired_at: new Date().toISOString(),
      },
      null,
      2,
    ) + "\n";

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const fd = openSync(lockPath, "wx");
      try {
        writeFileSync(fd, payload, "utf8");
      } finally {
        closeSync(fd);
      }
      return {
        acquired: true,
        lockPath,
        staleCleaned: attempt > 0,
        release() {
          const current = readJsonSafe(lockPath);
          if (!current || current.pid === pid) {
            try {
              unlinkSync(lockPath);
            } catch {}
          }
        },
        transferTo(nextPid, extra = {}) {
          writeFileAtomic(
            lockPath,
            JSON.stringify(
              {
                pid: nextPid,
                ...metadata,
                ...extra,
                acquired_at: new Date().toISOString(),
              },
              null,
              2,
            ) + "\n",
          );
        },
      };
    } catch (error) {
      if (error?.code !== "EEXIST") throw error;
      const existing = readJsonSafe(lockPath);
      const ownerPid = Number(existing?.pid);
      if (existing && isAlive(ownerPid)) {
        return { acquired: false, lockPath, busyPid: ownerPid, existing };
      }
      try {
        unlinkSync(lockPath);
      } catch {}
    }
  }
  return { acquired: false, lockPath, busyPid: null, existing: null };
}

export function releaseSlotLock(slotDir, { expectedPid = null } = {}) {
  const lockPath = path.join(slotDir, LOCK_FILENAME);
  if (!existsSync(lockPath)) return false;
  if (expectedPid !== null) {
    const existing = readJsonSafe(lockPath);
    if (
      existing &&
      Number(existing.pid) !== Number(expectedPid) &&
      isPidAlive(Number(existing.pid))
    ) {
      return false;
    }
  }
  try {
    unlinkSync(lockPath);
    return true;
  } catch {
    return false;
  }
}

export function patchGameGd(text) {
  let out = text;
  let changed = false;

  if (!out.includes("var _dev_held")) {
    const replaced = out.replace(
      /^(var keyboard\b.*)$/m,
      "$1\nvar _dev_held := false\nvar _dev_frozen := false",
    );
    if (replaced === out) {
      throw new Error("game.gd seam anchor 'var keyboard' not found");
    }
    out = replaced;
    changed = true;
  }

  if (!out.includes('load("res://src/dev/dev_console.gd").hook(self)')) {
    const replaced = out.replace(
      /^(\tauto_pause\.setup\(self\))$/m,
      '$1\n\tif dev and not test_mode:\n\t\tload("res://src/dev/dev_console.gd").hook(self)',
    );
    if (replaced === out) {
      throw new Error("game.gd seam anchor 'auto_pause.setup(self)' not found");
    }
    out = replaced;
    changed = true;
  }

  if (!out.includes("func freeze_for_dev(")) {
    const replaced = out.replace(
      /^func _apply_pause\(\) -> void:\n\tget_tree\(\)\.paused = _pause_toggled or _notes_held$/m,
      [
        "func _apply_pause() -> void:",
        "\tget_tree().paused = _pause_toggled or _notes_held or _dev_frozen",
        "",
        "",
        "func pause_wanted() -> bool:",
        '\tvar shop := get_node_or_null("Workshop")',
        "\treturn _pause_toggled or _notes_held or (shop != null and shop.pausing())",
        "",
        "",
        "func freeze_for_dev(on: bool) -> void:",
        "\t_dev_frozen = on",
        "\tget_tree().paused = on or pause_wanted()",
        "",
        "",
        "func hold_for_dev(on: bool) -> void:",
        "\t_dev_held = on",
        "\tif keyboard != null:",
        "\t\tkeyboard.held = on",
        "\tif on:",
        "\t\tcapture_mouse(false)",
        "\telse:",
        "\t\trecapture_mouse()",
      ].join("\n"),
    );
    if (replaced === out) {
      throw new Error("game.gd seam anchor 'func _apply_pause()' not found");
    }
    out = replaced;
    changed = true;
  }

  if (!out.includes("capture and not _dev_held")) {
    const replaced = out.replace(
      "Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE",
      "Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture and not _dev_held else Input.MOUSE_MODE_VISIBLE",
    );
    if (replaced === out) {
      throw new Error("game.gd seam anchor 'capture_mouse' not found");
    }
    out = replaced;
    changed = true;
  }

  if (!out.includes('return _dev_held or get_meta("menu_held", false)')) {
    const replaced = out.replace(
      'return get_meta("menu_held", false)',
      'return _dev_held or get_meta("menu_held", false)',
    );
    if (replaced === out) {
      throw new Error("game.gd seam anchor 'menu_held' not found");
    }
    out = replaced;
    changed = true;
  }

  return { text: out, changed };
}

export function patchIntentGd(text) {
  let out = text;
  let changed = false;

  if (!out.includes("\tvar held := false")) {
    const replaced = out.replace(/^(\tvar enabled := true)$/m, "$1\n\tvar held := false");
    if (replaced === out) {
      throw new Error("intent.gd seam anchor 'var enabled := true' not found");
    }
    out = replaced;
    changed = true;
  }

  if (!out.includes("if not enabled or held:")) {
    const replaced = out.replace(/^(\t\tif not enabled:)$/m, "\t\tif not enabled or held:");
    if (replaced === out) {
      throw new Error("intent.gd seam anchor 'if not enabled:' not found");
    }
    out = replaced;
    changed = true;
  }

  return { text: out, changed };
}

export function patchWorkshopGd(text) {
  if (text.includes("func pausing() -> bool:")) {
    return { text, changed: false };
  }
  const replaced = text.replace(
    /^func _apply_hold\(\) -> void:/m,
    "func pausing() -> bool:\n\treturn _paused\n\n\nfunc _apply_hold() -> void:",
  );
  if (replaced !== text) {
    return { text: replaced, changed: true };
  }
  return {
    text: `${text.trimEnd()}\n\n\nfunc pausing() -> bool:\n\treturn _paused\n`,
    changed: true,
  };
}

function collectOverlayFiles(sourceRoot) {
  const sketchSrc = path.join(sourceRoot, "sketches", "core-loop", "src");
  const devDir = path.join(sketchSrc, "dev");
  const files = [];
  if (existsSync(devDir)) {
    for (const entry of readdirSync(devDir, { withFileTypes: true }).sort((a, b) =>
      a.name.localeCompare(b.name),
    )) {
      if (!entry.isFile()) continue;
      files.push({
        rel: path.join("sketches", "core-loop", "src", "dev", entry.name),
        abs: path.join(devDir, entry.name),
      });
    }
  }
  for (const extra of [
    path.join("sketches", "core-loop", "src", "presentation", "frame_read.gd"),
    path.join("sketches", "core-loop", "src", "presentation", "frame_read.gd.uid"),
  ]) {
    const abs = path.join(sourceRoot, extra);
    if (existsSync(abs)) {
      files.push({ rel: extra, abs });
    }
  }
  return files;
}

export function computeOverlayHash(sourceRoot = REPO_ROOT) {
  const hash = createHash("sha256");
  hash.update(`seam:${SEAM_VERSION}\n`);
  for (const file of collectOverlayFiles(sourceRoot)) {
    hash.update(file.rel);
    hash.update("\0");
    hash.update(readFileSync(file.abs));
    hash.update("\0");
  }
  return hash.digest("hex").slice(0, 16);
}

export function needsDevOverlay(worktreeDir, sourceRoot = REPO_ROOT) {
  const sketchDir = path.join(worktreeDir, "sketches", "core-loop");
  const consoleGd = path.join(sketchDir, "src", "dev", "dev_console.gd");
  const inspectGd = path.join(sketchDir, "src", "dev", "dev_inspect.gd");
  const gameGd = path.join(sketchDir, "src", "game.gd");
  if (!existsSync(consoleGd) || !existsSync(inspectGd)) return true;
  if (existsSync(gameGd)) {
    const gameText = readFileSync(gameGd, "utf8");
    if (!gameText.includes("dev_console.gd")) return true;
  }
  const inspectText = readFileSync(inspectGd, "utf8");
  if (!inspectText.includes("greybox") || !inspectText.includes("sample_perf")) return true;
  const marker = readJsonSafe(path.join(worktreeDir, OVERLAY_MARKER));
  if (marker && marker.overlay_hash !== computeOverlayHash(sourceRoot)) return true;
  return false;
}

export function applyDevOverlay(worktreeDir, { sourceRoot = REPO_ROOT, sha = "" } = {}) {
  assertNotPrimaryCheckout(worktreeDir, sourceRoot);
  const overlayHash = computeOverlayHash(sourceRoot);
  const markerPath = path.join(worktreeDir, OVERLAY_MARKER);
  const existing = readJsonSafe(markerPath);
  if (
    existing &&
    existing.sha === sha &&
    existing.overlay_hash === overlayHash &&
    !needsDevOverlay(worktreeDir)
  ) {
    return { applied: false, cached: true, overlayHash, filesCopied: 0, seamsPatched: [] };
  }

  const files = collectOverlayFiles(sourceRoot);
  let filesCopied = 0;
  for (const file of files) {
    const dest = path.join(worktreeDir, file.rel);
    mkdirSync(path.dirname(dest), { recursive: true });
    copyFileSync(file.abs, dest);
    filesCopied += 1;
  }

  const seamsPatched = [];
  const seamTargets = [
    { rel: path.join("sketches", "core-loop", "src", "game.gd"), patch: patchGameGd },
    {
      rel: path.join("sketches", "core-loop", "src", "movement", "intent.gd"),
      patch: patchIntentGd,
    },
    { rel: path.join("sketches", "core-loop", "src", "ui", "workshop.gd"), patch: patchWorkshopGd },
  ];
  for (const item of seamTargets) {
    const filePath = path.join(worktreeDir, item.rel);
    if (!existsSync(filePath)) continue;
    const raw = readFileSync(filePath, "utf8");
    const res = item.patch(raw);
    if (res.changed) {
      writeFileAtomic(filePath, res.text);
      seamsPatched.push(item.rel);
    }
  }

  writeFileAtomic(
    markerPath,
    JSON.stringify(
      {
        sha,
        overlay_hash: overlayHash,
        files_copied: filesCopied,
        seams_patched: seamsPatched,
        applied_at: new Date().toISOString(),
      },
      null,
      2,
    ) + "\n",
  );

  return { applied: true, cached: false, overlayHash, filesCopied, seamsPatched };
}

function worktreeGitDir(worktreeDir) {
  const dotGit = path.join(worktreeDir, ".git");
  if (!existsSync(dotGit)) return null;
  try {
    const stat = lstatSync(dotGit);
    if (stat.isDirectory()) return dotGit;
    const content = readFileSync(dotGit, "utf8").trim();
    const match = /^gitdir:\s*(.+)$/.exec(content);
    if (!match) return null;
    return path.resolve(worktreeDir, match[1].trim());
  } catch {
    return null;
  }
}

export function reconcileDetachedWorktree({
  repoRoot = REPO_ROOT,
  worktreeDir,
  sha,
  spawn = spawnSync,
} = {}) {
  assertNotPrimaryCheckout(worktreeDir, repoRoot);
  assertUnderSandboxRoot(worktreeDir, repoRoot);

  const gitDir = worktreeGitDir(worktreeDir);
  if (gitDir && existsSync(gitDir)) {
    const indexLock = path.join(gitDir, "index.lock");
    if (existsSync(indexLock)) {
      try {
        unlinkSync(indexLock);
      } catch {}
    }
    const headCheck = spawn("git", ["-C", worktreeDir, "rev-parse", "HEAD"], { encoding: "utf8" });
    if (headCheck.status === 0 && headCheck.stdout.trim() === sha) {
      return { created: false, reconciled: false, worktreeDir, sha };
    }
  }

  if (existsSync(worktreeDir)) {
    const lockBackup = readJsonSafe(path.join(worktreeDir, LOCK_FILENAME));
    spawn("git", ["-C", repoRoot, "worktree", "remove", "--force", worktreeDir], {
      encoding: "utf8",
    });
    if (existsSync(worktreeDir)) {
      rmSync(worktreeDir, { recursive: true, force: true });
    }
    spawn("git", ["-C", repoRoot, "worktree", "prune"], { encoding: "utf8" });
    const add = spawn(
      "git",
      ["-C", repoRoot, "worktree", "add", "--detach", "--force", worktreeDir, sha],
      {
        encoding: "utf8",
      },
    );
    if (add.error || add.status !== 0) {
      throw new Error(
        `Failed to recreate sandbox worktree at ${sha}: ${(add.stderr || add.error?.message || "git error").trim()}`,
      );
    }
    if (lockBackup) {
      writeFileAtomic(
        path.join(worktreeDir, LOCK_FILENAME),
        JSON.stringify(lockBackup, null, 2) + "\n",
      );
    }
    return { created: true, reconciled: true, worktreeDir, sha };
  }

  mkdirSync(path.dirname(worktreeDir), { recursive: true });
  spawn("git", ["-C", repoRoot, "worktree", "prune"], { encoding: "utf8" });
  const add = spawn(
    "git",
    ["-C", repoRoot, "worktree", "add", "--detach", "--force", worktreeDir, sha],
    {
      encoding: "utf8",
    },
  );
  if (add.error || add.status !== 0) {
    throw new Error(
      `Failed to add sandbox worktree at ${sha}: ${(add.stderr || add.error?.message || "git error").trim()}`,
    );
  }
  return { created: true, reconciled: false, worktreeDir, sha };
}

export function linkSandboxNodeModules(worktreeDir, repoRoot = REPO_ROOT) {
  const res = ensureNodeModules(worktreeDir);
  if (res.ok) return res;
  const target = path.join(worktreeDir, "node_modules");
  try {
    lstatSync(target);
    return { ok: true, linked: false, reason: "already_exists" };
  } catch {}
  const candidates = [path.join(repoRoot, "node_modules")];
  const common = spawnSync(
    "git",
    ["-C", repoRoot, "rev-parse", "--path-format=absolute", "--git-common-dir"],
    { encoding: "utf8" },
  );
  if (common.status === 0 && common.stdout.trim()) {
    candidates.push(path.join(path.dirname(common.stdout.trim()), "node_modules"));
  }
  for (const primaryModules of candidates) {
    if (existsSync(primaryModules)) {
      symlinkSync(primaryModules, target, process.platform === "win32" ? "junction" : "dir");
      return { ok: true, linked: true, reason: "fallback_symlink", target: primaryModules };
    }
  }
  return res;
}

export function ensureSandboxImport({
  worktreeDir,
  godotBin,
  sha,
  overlayHash = "",
  homeDir,
  sketch = "sketches/core-loop",
} = {}) {
  const sketchDir = path.join(worktreeDir, sketch);
  const stampFile = path.join(sketchDir, ".godot", IMPORT_STAMP_FILENAME);
  const godotId = godotIdentity(godotBin);
  const existing = readJsonSafe(stampFile);

  if (
    existing &&
    existing.sha === sha &&
    existing.overlay_hash === overlayHash &&
    (!godotId || existing.godot === godotId) &&
    hasValidUidCache(worktreeDir, sketch)
  ) {
    return { imported: false, cached: true, passes: 0 };
  }

  if (!godotBin || !existsSync(godotBin)) {
    throw new Error(`Godot binary not found for sandbox import: ${godotBin ?? "(unset)"}`);
  }

  const importHome = path.resolve(homeDir);
  const dataDir = path.join(importHome, "data");
  const configDir = path.join(importHome, "config");
  const cacheDir = path.join(importHome, "cache");
  mkdirSync(dataDir, { recursive: true });
  mkdirSync(configDir, { recursive: true });
  mkdirSync(cacheDir, { recursive: true });

  const env = {
    ...process.env,
    GODOT_BIN: godotBin,
    HOME: importHome,
    XDG_DATA_HOME: dataDir,
    XDG_CONFIG_HOME: configDir,
    XDG_CACHE_HOME: cacheDir,
  };
  if (process.platform === "linux") {
    env.SDL_AUDIODRIVER = "dummy";
  }

  const result = importSketch(worktreeDir, sketch, {
    runPass: (rootDir, sketchRel) =>
      spawnSync(
        godotBin,
        [
          "--headless",
          "--audio-driver",
          "Dummy",
          "--path",
          path.join(rootDir, sketchRel),
          "--editor",
          "--import",
        ],
        { encoding: "utf8", maxBuffer: 1 << 28, env },
      ),
  });

  writeImportStamp(worktreeDir, sketch, { godot: godotId });
  writeFileAtomic(
    stampFile,
    JSON.stringify(
      {
        sha,
        overlay_hash: overlayHash,
        godot: godotId,
        passes: result.passes,
        stamped_at: new Date().toISOString(),
      },
      null,
      2,
    ) + "\n",
  );
  return { imported: true, cached: false, passes: result.passes };
}

export function materializeSandbox({
  ref,
  repoRoot = REPO_ROOT,
  slot = null,
  godotBin = null,
  skipImport = false,
  overlayMode = "auto",
  importHomeDir = null,
  isAlive = isPidAlive,
} = {}) {
  const resolved = resolveGitRef(ref, repoRoot);
  const baseDir = sandboxBaseDir(repoRoot);
  mkdirSync(baseDir, { recursive: true });

  let chosenSlot = null;
  let slotDir = null;
  let lock = null;

  if (slot !== null && slot !== undefined && String(slot).trim() !== "") {
    chosenSlot = validateSlotName(String(slot));
    slotDir = path.join(baseDir, `${resolved.sha12}-${chosenSlot}`);
    assertUnderSandboxRoot(slotDir, repoRoot);
    lock = acquireSlotLock(
      slotDir,
      { ref: resolved.ref, sha: resolved.sha, slot: chosenSlot },
      { isAlive },
    );
    if (!lock.acquired) {
      const error = new Error(
        `Sandbox slot "${resolved.sha12}-${chosenSlot}" is held by live PID ${lock.busyPid}. Omit --slot to auto-allocate a free slot.`,
      );
      error.code = "SANDBOX_SLOT_BUSY";
      throw error;
    }
  } else {
    for (let i = 0; i < MAX_AUTO_SLOTS; i++) {
      const candidateSlot = `s${i}`;
      const candidateDir = path.join(baseDir, `${resolved.sha12}-${candidateSlot}`);
      const attempt = acquireSlotLock(
        candidateDir,
        { ref: resolved.ref, sha: resolved.sha, slot: candidateSlot },
        { isAlive },
      );
      if (attempt.acquired) {
        chosenSlot = candidateSlot;
        slotDir = candidateDir;
        lock = attempt;
        break;
      }
    }
    if (!lock) {
      const error = new Error(`All ${MAX_AUTO_SLOTS} sandbox slots for ${resolved.sha12} are busy`);
      error.code = "SANDBOX_SLOTS_EXHAUSTED";
      throw error;
    }
  }

  try {
    const wt = reconcileDetachedWorktree({ repoRoot, worktreeDir: slotDir, sha: resolved.sha });
    const deps = linkSandboxNodeModules(slotDir, repoRoot);

    let overlay = {
      applied: false,
      cached: false,
      overlayHash: "",
      filesCopied: 0,
      seamsPatched: [],
    };
    if (
      overlayMode === "always" ||
      (overlayMode === "auto" && needsDevOverlay(slotDir, repoRoot))
    ) {
      overlay = applyDevOverlay(slotDir, { sourceRoot: repoRoot, sha: resolved.sha });
    } else if (existsSync(path.join(slotDir, OVERLAY_MARKER))) {
      const existing = readJsonSafe(path.join(slotDir, OVERLAY_MARKER));
      overlay.overlayHash = String(existing?.overlay_hash ?? "");
      overlay.cached = true;
    }

    let importInfo = { imported: false, cached: false, passes: 0, skipped: skipImport };
    if (!skipImport && godotBin) {
      const home =
        importHomeDir ??
        path.join(
          repoRoot,
          "artifacts",
          "local",
          "dev-ref-home",
          `${resolved.sha12}-${chosenSlot}`,
        );
      importInfo = {
        ...ensureSandboxImport({
          worktreeDir: slotDir,
          godotBin,
          sha: resolved.sha,
          overlayHash: overlay.overlayHash,
          homeDir: home,
        }),
        skipped: false,
      };
    }

    return {
      ref: resolved.ref,
      sha: resolved.sha,
      sha12: resolved.sha12,
      slot: chosenSlot,
      worktreeDir: slotDir,
      sketchDir: path.join(slotDir, "sketches", "core-loop"),
      created: wt.created,
      reconciled: wt.reconciled,
      staleLockCleaned: lock.staleCleaned,
      nodeModules: deps,
      overlay,
      importInfo,
      lockPath: lock.lockPath,
      release: lock.release,
      transferLockTo: lock.transferTo,
    };
  } catch (error) {
    lock.release();
    throw error;
  }
}

export function listSandboxes(repoRoot = REPO_ROOT, { isAlive = isPidAlive } = {}) {
  const baseDir = sandboxBaseDir(repoRoot);
  if (!existsSync(baseDir)) return [];
  const rows = [];
  for (const entry of readdirSync(baseDir, { withFileTypes: true }).sort((a, b) =>
    a.name.localeCompare(b.name),
  )) {
    if (!entry.isDirectory()) continue;
    const dir = path.join(baseDir, entry.name);
    const lock = readJsonSafe(path.join(dir, LOCK_FILENAME));
    const overlay = readJsonSafe(path.join(dir, OVERLAY_MARKER));
    const pid = Number(lock?.pid);
    const busy = Boolean(lock && isAlive(pid));
    rows.push({
      name: entry.name,
      dir,
      busy,
      pid: Number.isFinite(pid) && pid > 0 ? pid : null,
      stale_lock: Boolean(lock && !busy),
      sha: overlay?.sha ?? lock?.sha ?? null,
      overlay_hash: overlay?.overlay_hash ?? null,
    });
  }
  return rows;
}

function parseCliArgs(argv) {
  const cmd = argv[0] ?? "help";
  const opts = { ref: null, slot: null, json: false, skipImport: false, overlayMode: "auto" };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--ref") opts.ref = argv[++i];
    else if (a === "--slot") opts.slot = argv[++i];
    else if (a === "--json") opts.json = true;
    else if (a === "--skip-import") opts.skipImport = true;
    else if (a === "--overlay") opts.overlayMode = argv[++i];
    else throw new Error(`Unknown option: ${a}`);
  }
  return { cmd, opts };
}

function isMain() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
  }
}

if (isMain()) {
  try {
    const { cmd, opts } = parseCliArgs(process.argv.slice(2));
    if (cmd === "prepare") {
      const box = materializeSandbox({
        ref: opts.ref,
        slot: opts.slot,
        godotBin: process.env.GODOT_BIN || null,
        skipImport: opts.skipImport || !process.env.GODOT_BIN,
        overlayMode: opts.overlayMode,
      });
      box.release();
      const out = {
        ok: true,
        ref: box.ref,
        sha: box.sha,
        slot: box.slot,
        worktreeDir: box.worktreeDir,
        sketchDir: box.sketchDir,
        overlay: box.overlay,
        importInfo: box.importInfo,
      };
      if (opts.json) console.log(JSON.stringify(out, null, 2));
      else console.log(`sandbox ready: ${box.worktreeDir} (${box.sha12}, slot=${box.slot})`);
    } else if (cmd === "status") {
      const rows = listSandboxes();
      if (opts.json) console.log(JSON.stringify(rows, null, 2));
      else {
        for (const r of rows) {
          console.log(`${r.name}  busy=${r.busy}  stale=${r.stale_lock}  dir=${r.dir}`);
        }
      }
    } else {
      console.log(
        "Usage: node scripts/worktree-sandbox.mjs prepare --ref <git-ref> [--slot <name>] [--skip-import] [--json] | status [--json]",
      );
    }
  } catch (error) {
    console.error(`worktree-sandbox: ${error?.message ?? error}`);
    process.exitCode = 1;
  }
}
