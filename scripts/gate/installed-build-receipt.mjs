#!/usr/bin/env node
// The receipt for the world 1 done read's row "installed-build" (scripts/world1-bands.rows.json):
//   { head, pass, measured, plant_caught }
// Extracts usr/lib/scrapkeep/BUILD.txt from the installed AppImage (or reads --build-txt directly)
// and verifies that its `commit: <sha>` stamp matches --head (7..40 hex prefix or full match,
// clean, never -dirty). Also runs the exact same grader against a synthetic mismatched commit
// and requires it to read as a miss (plant_caught).
//
//   node scripts/gate/installed-build-receipt.mjs --head <sha> [--appimage <path>] [--build-txt <path>] [--out <file>]
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const COMMIT = /^[0-9a-f]{7,40}$/;
export const BUILD_TXT_REL = "usr/lib/scrapkeep/BUILD.txt";

export function defaultAppImage(env = process.env, home = os.homedir()) {
  const dataHome = env.XDG_DATA_HOME || path.join(home, ".local/share");
  return path.join(dataHome, "scrapkeep", "Scrapkeep.AppImage");
}

export function commitsMatch(a, b) {
  return (
    typeof a === "string" &&
    typeof b === "string" &&
    COMMIT.test(a) &&
    COMMIT.test(b) &&
    (a.startsWith(b) || b.startsWith(a))
  );
}

// Synthetic 40-char hex commit guaranteed to differ from head on the first nibble.
export function mismatchedCommit(head) {
  const first = typeof head === "string" && head[0] === "0" ? "1" : "0";
  return first + "0".repeat(39);
}

export function parseBuildTxt(text) {
  if (typeof text !== "string") return { commitRaw: null, dirtyRaw: null };
  const commitMatch = /^commit:\s*(.+)$/m.exec(text);
  const dirtyMatch = /^dirty:\s*(.+)$/m.exec(text);
  return {
    commitRaw: commitMatch ? commitMatch[1].trim() : null,
    dirtyRaw: dirtyMatch ? dirtyMatch[1].trim() : null,
  };
}

// Grades the text of a BUILD.txt file against the judged head.
export function gradeBuildTxt(text, head) {
  if (typeof head !== "string" || !COMMIT.test(head)) {
    return { ok: false, commit: null, dirty: false, reason: `invalid judged head "${head}"` };
  }
  const { commitRaw, dirtyRaw } = parseBuildTxt(text);
  if (!commitRaw) {
    return { ok: false, commit: null, dirty: false, reason: "BUILD.txt has no commit: line" };
  }
  const dirtyFlag = dirtyRaw !== null && dirtyRaw.toLowerCase() !== "false";
  if (commitRaw.includes("-dirty") || dirtyFlag) {
    return {
      ok: false,
      commit: commitRaw,
      dirty: true,
      reason: `installed build is dirty (commit: ${commitRaw}${dirtyRaw !== null ? `, dirty: ${dirtyRaw}` : ""})`,
    };
  }
  if (!COMMIT.test(commitRaw)) {
    return {
      ok: false,
      commit: commitRaw,
      dirty: false,
      reason: `BUILD.txt commit "${commitRaw}" is not a valid 7..40 hex commit`,
    };
  }
  if (!commitsMatch(commitRaw, head)) {
    return {
      ok: false,
      commit: commitRaw,
      dirty: false,
      reason: `installed build is ${commitRaw.slice(0, 12)}, expected ${head.slice(0, 12)}`,
    };
  }
  return { ok: true, commit: commitRaw, dirty: false, reason: null };
}

// Extracts usr/lib/scrapkeep/BUILD.txt from an AppImage into a temp directory cleaned up in finally.
export function extractBuildTxt(appImagePath, { run = spawnSync } = {}) {
  if (!existsSync(appImagePath)) {
    return { ok: false, text: null, error: `AppImage not found: ${appImagePath}` };
  }
  const tmp = mkdtempSync(path.join(os.tmpdir(), "installed-build-"));
  try {
    const resolved = path.resolve(appImagePath);
    const res = run(resolved, ["--appimage-extract", BUILD_TXT_REL], {
      cwd: tmp,
      encoding: "utf8",
      maxBuffer: 1 << 24,
      timeout: 60_000,
    });
    if (res.error) {
      return {
        ok: false,
        text: null,
        error: `AppImage extraction failed: ${res.error.message ?? res.error}`,
      };
    }
    if (res.status !== 0) {
      const detail = `${res.stderr ?? ""}${res.stdout ?? ""}`.trim().slice(0, 160);
      return {
        ok: false,
        text: null,
        error: `AppImage --appimage-extract exited ${res.status}${detail ? `: ${detail}` : ""}`,
      };
    }
    const extracted = path.join(tmp, "squashfs-root", BUILD_TXT_REL);
    if (!existsSync(extracted)) {
      return {
        ok: false,
        text: null,
        error: `extracted AppImage has no ${BUILD_TXT_REL}`,
      };
    }
    return { ok: true, text: readFileSync(extracted, "utf8"), error: null };
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

export function buildReceipt(text, head, { source = "BUILD.txt", readError = null } = {}) {
  const plantedSha = mismatchedCommit(head);
  const plantText = `commit: ${plantedSha}\ndirty: false\n`;
  const plant = gradeBuildTxt(plantText, head);
  const plantCaught = !plant.ok;
  const plantNote = plantCaught
    ? `plant: mismatched commit ${plantedSha.slice(0, 12)} rejected`
    : `plant: mismatched commit ${plantedSha.slice(0, 12)} was not rejected`;
  if (readError) {
    return {
      head,
      pass: false,
      measured: `${readError}; ${plantNote}`,
      plant_caught: plantCaught,
    };
  }
  const main = gradeBuildTxt(text, head);
  const pass = Boolean(main.ok && plantCaught);
  const measured = main.ok
    ? `installed build (${source}) matches ${head.slice(0, 12)} (commit ${main.commit.slice(0, 12)}, clean); ${plantNote}`
    : `${main.reason} (${source}); ${plantNote}`;
  return { head, pass, measured, plant_caught: plantCaught };
}

export function produce({
  head,
  appImage = null,
  buildTxt = null,
  env = process.env,
  home = os.homedir(),
  run = spawnSync,
} = {}) {
  if (typeof head !== "string" || !COMMIT.test(head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${head ?? ""}"`);
  }
  if (buildTxt) {
    if (!existsSync(buildTxt)) {
      return buildReceipt(null, head, {
        source: buildTxt,
        readError: `BUILD.txt not found: ${buildTxt}`,
      });
    }
    return buildReceipt(readFileSync(buildTxt, "utf8"), head, { source: buildTxt });
  }
  const target = appImage ?? defaultAppImage(env, home);
  const extracted = extractBuildTxt(target, { run });
  return buildReceipt(extracted.text, head, {
    source: target,
    readError: extracted.ok ? null : extracted.error,
  });
}

export function parseArgs(argv) {
  const args = { head: null, appImage: null, buildTxt: null, out: null };
  const take = (i, flag) => {
    const val = argv[i + 1];
    if (val === undefined || val === "" || val.startsWith("--")) {
      throw new Error(`${flag} requires a value`);
    }
    return val;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--head") args.head = take(i++, a);
    else if (a.startsWith("--head=")) args.head = a.slice("--head=".length);
    else if (a === "--appimage") args.appImage = take(i++, a);
    else if (a.startsWith("--appimage=")) args.appImage = a.slice("--appimage=".length);
    else if (a === "--build-txt") args.buildTxt = take(i++, a);
    else if (a.startsWith("--build-txt=")) args.buildTxt = a.slice("--build-txt=".length);
    else if (a === "--out") args.out = take(i++, a);
    else if (a.startsWith("--out=")) args.out = a.slice("--out=".length);
    else throw new Error(`unknown argument: ${a}`);
  }
  if (!args.head) {
    throw new Error(
      "usage: installed-build-receipt.mjs --head <sha> [--appimage <path>] [--build-txt <path>] [--out <file>]",
    );
  }
  if (!COMMIT.test(args.head)) {
    throw new Error(`--head requires 7 to 40 lowercase hex characters; got "${args.head}"`);
  }
  return args;
}

function main(argv) {
  let args;
  let receipt;
  try {
    args = parseArgs(argv);
    receipt = produce(args);
  } catch (e) {
    console.error(String(e?.message ?? e));
    return 2;
  }
  const text = JSON.stringify(receipt, null, 2) + "\n";
  if (args.out) {
    mkdirSync(path.dirname(path.resolve(args.out)), { recursive: true });
    writeFileSync(args.out, text);
  } else {
    process.stdout.write(text);
  }
  return receipt.pass ? 0 : 1;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
