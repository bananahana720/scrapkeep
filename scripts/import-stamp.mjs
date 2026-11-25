#!/usr/bin/env node
// Which tree a sketch's .godot folder was imported at. A .godot imported at one tree and then run
// at another gives a run that is not the checked-out code (14 Nov 2026: seed 40322 played a
// different stage 1 on a worktree whose .godot came from an older tree). Every import that passes
// writes the stamp; a runner that does not import refuses a .godot whose stamp is not this tree.
//
//   node scripts/import-stamp.mjs check  [--sketch sketches/core-loop]
//   node scripts/import-stamp.mjs import [--sketch sketches/core-loop] [--double]
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { scratchHomeEnv } from "./godot-home.mjs";

export const DEFAULT_SKETCH = "sketches/core-loop";
const STAMP = "scrapkeep-import.json";
const GODOT_ASSET_FILE =
  /(?:^|\/)project\.godot$|\.(?:gd|tscn|tres|glb|png|ogg|wav|ttf|otf|gdshader|json|bin|import)$/i;

function git(root, args, { trim = true } = {}) {
  const ran = spawnSync("git", ["-C", root, ...args], { encoding: "utf8" });
  if (ran.status !== 0) return null;
  return trim ? ran.stdout.trim() : ran.stdout.replace(/\r?\n$/, "");
}

export function godotIdentity(godotBin = process.env.GODOT_BIN) {
  if (!godotBin || !existsSync(godotBin)) return null;
  try {
    return `${path.basename(godotBin)}:${statSync(godotBin).size}`;
  } catch {
    return null;
  }
}

export function isUntrackedGodotAsset(porcelainLine) {
  if (!porcelainLine.startsWith("?? ")) return false;
  let file = porcelainLine.slice(3).trim();
  if (file.startsWith('"') && file.endsWith('"')) file = file.slice(1, -1);
  return GODOT_ASSET_FILE.test(file);
}

// The git tree of the sketch folder at HEAD, so commits that leave the sketch alone keep the stamp.
// Uncommitted edits to tracked sketch files and untracked Godot project/asset files are named apart
// (untracked non-asset temp/output files such as run logs are ignored): they are not in the tree a stamp records.
export function sketchState(root, sketch = DEFAULT_SKETCH) {
  const status = git(root, ["status", "--porcelain", "--untracked-files=all", "--", sketch], {
    trim: false,
  });
  const dirty = Boolean(
    status &&
    status
      .split("\n")
      .filter(Boolean)
      .some((line) => !line.startsWith("?? ") || isUntrackedGodotAsset(line)),
  );
  return {
    tree: git(root, ["rev-parse", `HEAD:${sketch}`]),
    head: git(root, ["rev-parse", "HEAD"]),
    dirty,
  };
}

export function stampPath(root, sketch = DEFAULT_SKETCH) {
  return path.join(root, sketch, ".godot", STAMP);
}

export function writeImportStamp(root, sketch = DEFAULT_SKETCH, nowOrOptions = new Date()) {
  const isDate = nowOrOptions instanceof Date;
  const now = isDate ? nowOrOptions : (nowOrOptions?.now ?? new Date());
  const godot =
    !isDate && nowOrOptions && "godot" in nowOrOptions ? nowOrOptions.godot : godotIdentity();
  const state = sketchState(root, sketch);
  const file = stampPath(root, sketch);
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(
    file,
    JSON.stringify(
      {
        tree: state.tree,
        head: state.head,
        dirty: state.dirty,
        ...(godot ? { godot } : {}),
        at: now.toISOString(),
      },
      null,
      2,
    ) + "\n",
  );
  return state;
}

// { ok, reason }. Uncommitted sketch edits, at the import or now, are not in any tree a stamp can
// name, so either one refuses.
export function checkImportStamp(root, sketch = DEFAULT_SKETCH, options = {}) {
  const godot = "godot" in options ? options.godot : godotIdentity();
  const file = stampPath(root, sketch);
  if (!existsSync(path.join(root, sketch, ".godot")))
    return { ok: false, reason: `${sketch} has no .godot folder; it was never imported` };
  if (!existsSync(file))
    return {
      ok: false,
      reason: `${sketch}/.godot has no import stamp, so the tree it was imported at is unknown`,
    };
  let stamp;
  try {
    stamp = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return { ok: false, reason: `${sketch}/.godot/${STAMP} is not readable JSON` };
  }
  const now = sketchState(root, sketch);
  if (!now.tree) return { ok: false, reason: `git cannot name the tree of ${sketch} at HEAD` };
  if (stamp.dirty)
    return { ok: false, reason: `${sketch}/.godot was imported with uncommitted sketch edits` };
  if (now.dirty)
    return { ok: false, reason: `${sketch} has uncommitted edits that no import stamp covers` };
  if (stamp.tree !== now.tree)
    return {
      ok: false,
      reason: `${sketch}/.godot was imported at commit ${String(stamp.head).slice(0, 9)}, whose sketch differs from HEAD ${String(now.head).slice(0, 9)}`,
    };
  if (stamp.godot && godot && stamp.godot !== godot)
    return {
      ok: false,
      reason: `${sketch}/.godot was imported with Godot ${stamp.godot}, which differs from ${godot}`,
    };
  return { ok: true, reason: "" };
}

export const REIMPORT_HINT =
  "run `node scripts/import-stamp.mjs import` (imports and stamps; add --double to force two passes), or pass --stale-import-ok to run anyway";

const IMPORT_SCRIPT_ERROR = /^\s*SCRIPT ERROR\b/m;
const IMPORT_REIMPORT_WARNING =
  /^\s*(?:WARNING|ERROR):.*(?:reimport|import|uid_cache|could not (?:load|open|preload|import)|failed to (?:load|import))/im;

export function hasValidUidCache(root, sketch = DEFAULT_SKETCH) {
  const uidCache = path.join(root, sketch, ".godot", "uid_cache.bin");
  try {
    return statSync(uidCache).size > 0;
  } catch {
    return false;
  }
}

export function isCleanImportPass({ status, signal = null, output = "", uidCacheValid = false }) {
  if (status !== 0 || signal) return false;
  if (!uidCacheValid) return false;
  if (IMPORT_SCRIPT_ERROR.test(output)) return false;
  if (IMPORT_REIMPORT_WARNING.test(output)) return false;
  return true;
}

function runGodotImportPass(root, sketch) {
  const godot = process.env.GODOT_BIN;
  if (!godot || !existsSync(godot)) throw new Error("set GODOT_BIN to the Godot 4.7.2 editor");
  const scratchDir = mkdtempSync(path.join(os.tmpdir(), "import-stamp-"));
  try {
    return spawnSync(
      godot,
      ["--headless", "--path", path.join(root, sketch), "--editor", "--import"],
      {
        encoding: "utf8",
        maxBuffer: 1 << 28,
        env: {
          ...process.env,
          ...scratchHomeEnv(() => scratchDir),
        },
      },
    );
  } finally {
    rmSync(scratchDir, { recursive: true, force: true });
  }
}

export function importSketch(root, sketch = DEFAULT_SKETCH, options = {}) {
  const doublePass = Boolean(options.doublePass);
  const runPass = options.runPass ?? runGodotImportPass;
  const checkUid = options.hasUidCache ?? (() => hasValidUidCache(root, sketch));

  const first = runPass(root, sketch, 1);
  const firstOutput = `${first.stdout ?? ""}${first.stderr ?? ""}`;
  const firstClean = isCleanImportPass({
    status: first.status,
    signal: first.signal ?? null,
    output: firstOutput,
    uidCacheValid: checkUid(),
  });
  if (!doublePass && firstClean) {
    return { passes: 1, skippedSecond: true };
  }

  const second = runPass(root, sketch, 2);
  const secondOutput = `${second.stdout ?? ""}${second.stderr ?? ""}`;
  if (
    second.status !== 0 ||
    second.signal ||
    IMPORT_SCRIPT_ERROR.test(secondOutput) ||
    !checkUid()
  ) {
    throw new Error(
      `the second import was not clean (exit ${second.status ?? second.signal}); no stamp written`,
    );
  }
  return { passes: 2, skippedSecond: false };
}

function main(argv) {
  const root = git(process.cwd(), ["rev-parse", "--show-toplevel"]) ?? process.cwd();
  const at = argv.indexOf("--sketch");
  const sketch = at >= 0 ? argv[at + 1] : DEFAULT_SKETCH;
  const doublePass = argv.includes("--double");
  const verb = argv[0];
  if (verb === "check") {
    const result = checkImportStamp(root, sketch);
    console.log(
      result.ok ? `import stamp matches HEAD for ${sketch}` : `stale import: ${result.reason}`,
    );
    return result.ok ? 0 : 1;
  }
  if (verb === "import") {
    const { passes } = importSketch(root, sketch, { doublePass });
    const state = writeImportStamp(root, sketch);
    console.log(
      `imported ${sketch} in ${passes} pass${passes === 1 ? "" : "es"} and stamped tree ${state.tree?.slice(0, 9)} (HEAD ${state.head?.slice(0, 9)})`,
    );
    return 0;
  }
  console.error("usage: node scripts/import-stamp.mjs check|import [--sketch <dir>] [--double]");
  return 2;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
