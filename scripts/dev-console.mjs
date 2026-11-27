#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import {
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  unlinkSync,
  watch as watchFs,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { inflateSync } from "node:zlib";

import {
  GODOT_VERSION,
  resolveGodotBinary as resolveSharedGodotBinary,
  scratchGodotEnv,
} from "./godot-home.mjs";
import { formatLedgerAudit, runLedgerAudit } from "./ledger-audit.mjs";
import { buildVisualQaPack } from "./visual-qa-pack.mjs";
import { materializeSandbox, releaseSlotLock, validateSlotName } from "./worktree-sandbox.mjs";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const SKETCH_DIR = path.join(REPO_ROOT, "sketches", "core-loop");

export const DEV_FLAGS = [
  "dev-run",
  "dev-file",
  "dev-out",
  "dev-inbox",
  "dev-idle",
  "route-seed",
  "table",
  "no-intro",
];

export const VALID_TABLES = new Set(["park", "alpha", "slice", "default"]);

export const RECIPES = {
  smoke: {
    name: "smoke",
    mode: "headless",
    description: "Boot into World 1 stage 1, inspect core state/player/perf, and verify finiteness",
    script:
      "calm on; run 1; wait 60; pick 1; tick 15; inspect state; inspect player; inspect perf; assert state stage; assert finite; quit",
  },
  "combat-probe": {
    name: "combat-probe",
    mode: "headless",
    description:
      "Spawn mixed enemies, tick combat/telegraphs, inspect events, and verify hard clear",
    script:
      "calm on; events on; run 1; wait 60; pick 1; tick 15; spawn chaser 2; spawn lobber 1; spawn jolt_layer 1; tick 90; inspect enemies; inspect telegraphs; inspect events; assert finite; clear hard; tick 5; assert enemies 0; quit",
  },
  "boss-retry-probe": {
    name: "boss-retry-probe",
    mode: "headless",
    description:
      "Enter boss arena, advance phase, retry arena cleanly, then verify lethal death to summary",
    script:
      "calm on; events on; run 1; wait 60; pick 1; tick 15; stage 2; tick 30; boss; tick 60; boss 2; tick 60; inspect boss; assert state boss; retry; tick 60; inspect boss; assert state boss; assert no_anomalies; damage 99999; tick 10; assert state summary; assert event player_died 1; assert no_anomalies; quit",
  },
  "look-sheet": {
    name: "look-sheet",
    mode: "drawn",
    description: "Capture labeled look-preset contact sheet offscreen",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; freeze; sheet presets look_sheet; assert finite; quit",
  },
  "cam-sheet": {
    name: "cam-sheet",
    mode: "drawn",
    description: "Capture labeled camera-angle contact sheet offscreen",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; freeze; sheet cams cam_sheet; assert finite; quit",
  },
  "quality-pair": {
    name: "quality-pair",
    mode: "drawn",
    description: "Capture side-by-side quality comparison sheet offscreen",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; freeze; sheet quality quality_pair; assert finite; quit",
  },
  "overlay-check": {
    name: "overlay-check",
    mode: "drawn",
    description: "Render debug overlays over an active fight from high camera offscreen",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; spawn chaser 2; spawn jolt_layer 1; tick 90; overlay all; overlay perf on; freeze; cam high; shot overlay_check; assert finite; quit",
  },
  "perf-budget": {
    name: "perf-budget",
    mode: "drawn",
    description:
      "Warp to landmark offscreen and sample multi-tick render perf spread, limiters, and greybox census",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; warp landmark; wait 30; inspect perf 30; inspect prims greybox; assert finite; quit",
  },
  "world1-prim-census": {
    name: "world1-prim-census",
    mode: "headless",
    description:
      "Uncapped greybox PrimitiveMesh, flat StandardMaterial3D, and Skeleton3D census across park_dam, park_flume, and park_slag_bowl",
    script:
      "calm on; run 1; wait 60; pick 1; tick 15; inspect prims greybox; stage flume; wait 60; tick 15; inspect prims greybox; boss; wait 60; tick 15; inspect prims greybox; assert finite; quit",
  },
  "full-alpha-prim-census": {
    name: "full-alpha-prim-census",
    mode: "headless",
    description:
      "Sweep Worlds 1-3 stages and bosses (park_dam, park_flume, park_slag_bowl, park_pit, park_sinkhole, waking_arena, park_islands, park_crown, mind_arena) for PrimitiveMesh and flat StandardMaterial3D hotspots by owner",
    script:
      "calm on; run 1; wait 60; pick 1; tick 15; inspect prims greybox; stage flume; wait 60; tick 15; inspect prims greybox; boss; wait 60; tick 15; inspect prims greybox; stage pit; wait 60; tick 15; inspect prims greybox; stage sinkhole; wait 60; tick 15; inspect prims greybox; boss; wait 60; tick 15; inspect prims greybox; stage islands; wait 60; tick 15; inspect prims greybox; stage crown; wait 60; tick 15; inspect prims greybox; boss; wait 60; tick 15; inspect prims greybox; assert finite; quit",
  },
  "visual-qa-pack": {
    name: "visual-qa-pack",
    mode: "drawn",
    defaultSize: "1920x1080",
    description:
      "Capture an offscreen 1080p frame and emit the 4-oracle QA pack (1080p RGB, 720p, Rec.709 greyscale, Machado deuteranopia)",
    script:
      "calm on; hud off; run 1; wait 90; pick 1; wait 60; freeze; qa_pack visual_qa_pack; assert finite; quit",
  },
};

const TEARDOWN_NOISE =
  /^ERROR: \d+ (?:RID allocations of type '\w*RendererDummy\w*' were leaked|resources still in use) at exit\b.*\r?\n?/gm;

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

export function makeRunId(prefix = "run") {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  return `${prefix}-${stamp}-${randomBytes(3).toString("hex")}`;
}

export function validateSessionName(name) {
  if (
    typeof name !== "string" ||
    !/^[a-zA-Z0-9._-]+$/.test(name) ||
    name === "." ||
    name === ".."
  ) {
    throw new Error(`Invalid session name "${name}": use letters, digits, '.', '_', or '-'`);
  }
  return name;
}

export function parseSize(sizeText = "1280x720") {
  const match = /^(\d+)x(\d+)$/i.exec(String(sizeText).trim());
  if (!match) {
    throw new Error(`Invalid --size "${sizeText}": expected <width>x<height> (e.g. 1280x720)`);
  }
  const width = Number(match[1]);
  const height = Number(match[2]);
  if (width < 64 || height < 64 || width > 7680 || height > 4320) {
    throw new Error(`--size ${width}x${height} is out of allowed range (64x64..7680x4320)`);
  }
  return { width, height, text: `${width}x${height}` };
}

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
  existsFn = existsSync,
  whichFn = (name) => whichTool(name, env),
} = {}) {
  const found = resolveSharedGodotBinary({
    env,
    platform,
    homeDir,
    exists: existsFn,
    which: whichFn,
  });
  if (!found) {
    throw new Error(
      `Could not locate Godot binary. Set GODOT_BIN or install Godot ${GODOT_VERSION} before running dev-console.`,
    );
  }
  return found;
}

export function assertUnderArtifactsLocal(targetPath, repoRoot = REPO_ROOT) {
  const localRoot = path.resolve(repoRoot, "artifacts", "local");
  const resolved = path.isAbsolute(targetPath)
    ? path.resolve(targetPath)
    : path.resolve(repoRoot, targetPath);
  const rel = path.relative(localRoot, resolved);
  if (!rel || rel === "." || rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error(
      `Refusing scratch path outside artifacts/local/: "${resolved}" (must stay under "${localRoot}")`,
    );
  }
  return { localRoot, resolved };
}

export function scratchEnv(
  targetPath,
  { repoRoot = REPO_ROOT, baseEnv = process.env, platform = process.platform, create = true } = {},
) {
  const requested =
    targetPath ?? path.join(repoRoot, "artifacts", "local", "dev-console", makeRunId(), "home");
  const { resolved: home } = assertUnderArtifactsLocal(requested, repoRoot);
  const env = scratchGodotEnv(home, { baseEnv, forceHome: true, create, platform });
  if (platform === "linux") {
    env.SDL_AUDIODRIVER = "dummy";
  }
  return { home, env };
}

export function buildUserArgs({
  table = null,
  seed = null,
  devRun = null,
  devFile = null,
  devOut = null,
  devInbox = null,
  devIdle = null,
  extra = [],
} = {}) {
  const args = ["--dev", "--no-intro"];
  if (table) {
    if (!VALID_TABLES.has(table)) {
      throw new Error(
        `Invalid --table "${table}": expected one of ${[...VALID_TABLES].join(", ")}`,
      );
    }
    args.push(`--table=${table}`);
  }
  if (seed !== null && seed !== undefined) {
    args.push(`--route-seed=${seed}`);
  }
  if (devOut) args.push(`--dev-out=${devOut}`);
  if (devFile) args.push(`--dev-file=${devFile}`);
  if (devRun) args.push(`--dev-run=${devRun}`);
  if (devInbox) args.push(`--dev-inbox=${devInbox}`);
  if (devIdle !== null && devIdle !== undefined) args.push(`--dev-idle=${devIdle}`);
  args.push(...extra);
  return args;
}

export function buildGodotLaunchSpec({
  godotBin,
  sketchDir = SKETCH_DIR,
  mode = "headless",
  platform = process.platform,
  size = "1280x720",
  userArgs = [],
  findTool = whichTool,
} = {}) {
  if (!godotBin) {
    throw new Error("buildGodotLaunchSpec requires godotBin");
  }
  if (mode !== "headless" && mode !== "drawn" && mode !== "windowed") {
    throw new Error(`Invalid launch mode "${mode}": expected headless, drawn, or windowed`);
  }
  const parsedSize = parseSize(size);

  if (mode === "headless") {
    return {
      command: godotBin,
      args: ["--headless", "--audio-driver", "Dummy", "--path", sketchDir, "--", ...userArgs],
      mode,
      platform,
      size: parsedSize,
      wrapper: "none",
    };
  }

  if (mode === "windowed") {
    return {
      command: godotBin,
      args: [
        "--windowed",
        "--audio-driver",
        "Dummy",
        "--resolution",
        parsedSize.text,
        "--path",
        sketchDir,
        "--",
        ...userArgs,
      ],
      mode,
      platform,
      size: parsedSize,
      wrapper: "none",
    };
  }

  // Silent offscreen-only visual mode (--drawn)
  if (platform === "darwin") {
    return {
      command: godotBin,
      args: [
        "--embedded",
        "--rendering-driver",
        "metal",
        "--debug",
        "--skip-breakpoints",
        "--ignore-error-breaks",
        "--audio-driver",
        "Dummy",
        "--resolution",
        parsedSize.text,
        "--path",
        sketchDir,
        "--",
        ...userArgs,
      ],
      mode,
      platform,
      size: parsedSize,
      wrapper: "none",
    };
  }

  if (platform === "linux") {
    const gamescope = findTool("gamescope");
    if (gamescope) {
      return {
        command: gamescope,
        args: [
          "--backend",
          "headless",
          "-W",
          String(parsedSize.width),
          "-H",
          String(parsedSize.height),
          "--",
          godotBin,
          "--audio-driver",
          "Dummy",
          "--resolution",
          parsedSize.text,
          "--path",
          sketchDir,
          "--",
          ...userArgs,
        ],
        mode,
        platform,
        size: parsedSize,
        wrapper: "gamescope",
      };
    }
    const xvfb = findTool("xvfb-run");
    if (xvfb) {
      return {
        command: xvfb,
        args: [
          "-a",
          "-s",
          `-screen 0 ${parsedSize.width}x${parsedSize.height}x24`,
          godotBin,
          "--audio-driver",
          "Dummy",
          "--resolution",
          parsedSize.text,
          "--path",
          sketchDir,
          "--",
          ...userArgs,
        ],
        mode,
        platform,
        size: parsedSize,
        wrapper: "xvfb-run",
      };
    }
    const error = new Error(
      "Refusing bare --drawn launch on Linux: neither 'gamescope' nor 'xvfb-run' was found on PATH. Install a headless compositor or pass --windowed explicitly.",
    );
    error.exitCode = 2;
    throw error;
  }

  const error = new Error(
    `Offscreen --drawn mode is not supported on platform "${platform}". Pass --headless or --windowed explicitly.`,
  );
  error.exitCode = 2;
  throw error;
}

export function analyzeOutput({
  exitCode = 0,
  stdout = "",
  stderr = "",
  receipt = null,
  platform = process.platform,
  requireReceipt = true,
} = {}) {
  const rawCombined = `${stdout}\n${stderr}`;
  const combined = platform === "darwin" ? rawCombined.replace(TEARDOWN_NOISE, "") : rawCombined;

  const lines = combined.split(/\r?\n/);
  const scriptErrors = lines.filter((line) => /\bSCRIPT ERROR\b/.test(line));
  const parseErrors = lines.filter((line) => /\bParse Error\b/.test(line));
  const nonFiniteErrors = lines.filter((line) => line.includes("!v.is_finite()"));

  const issues = [];
  if (exitCode !== 0) {
    issues.push(`godot exited with code ${exitCode}`);
  }
  if (scriptErrors.length > 0) {
    issues.push(`detected ${scriptErrors.length} SCRIPT ERROR line(s)`);
  }
  if (parseErrors.length > 0) {
    issues.push(`detected ${parseErrors.length} Parse Error line(s)`);
  }
  if (nonFiniteErrors.length > 0) {
    issues.push(`detected ${nonFiniteErrors.length} !v.is_finite() line(s)`);
  }

  const deadFrames = [];
  const failedAssertions = [];
  if (receipt === null || receipt === undefined) {
    if (requireReceipt) issues.push("missing receipt.json");
  } else {
    if (receipt.ok !== true) {
      issues.push("receipt.ok is not true");
    }
    if (receipt.assertions && Number(receipt.assertions.failed) > 0) {
      const rows = Array.isArray(receipt.assertions.rows)
        ? receipt.assertions.rows.filter((row) => row && row.ok === false)
        : [];
      failedAssertions.push(...rows);
      issues.push(`failed assertions: ${receipt.assertions.failed}`);
    }
    if (Array.isArray(receipt.shots)) {
      for (const shot of receipt.shots) {
        if (shot && shot.dead_frame === true) {
          deadFrames.push(shot);
          issues.push(`dead_frame detected in shot ${shot.path ?? shot.name ?? "unknown"}`);
        }
      }
    }
  }

  return {
    ok: issues.length === 0,
    issues,
    scriptErrors,
    parseErrors,
    nonFiniteErrors,
    deadFrames,
    failedAssertions,
  };
}

function paethPredictor(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

export function decodePngBuffer(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 33) {
    throw new Error("Invalid PNG: buffer too short");
  }
  if (!buffer.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("Invalid PNG: bad signature");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let compression = 0;
  let filterMethod = 0;
  let interlace = 0;
  let sawIhdr = false;
  let sawIend = false;
  const idatChunks = [];

  while (offset + 12 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (dataEnd + 4 > buffer.length) {
      throw new Error(`Invalid PNG: truncated chunk "${type}"`);
    }
    const chunkData = buffer.subarray(dataStart, dataEnd);
    offset = dataEnd + 4;

    if (type === "IHDR") {
      if (length !== 13) throw new Error("Invalid PNG: IHDR length must be 13");
      width = chunkData.readUInt32BE(0);
      height = chunkData.readUInt32BE(4);
      bitDepth = chunkData[8];
      colorType = chunkData[9];
      compression = chunkData[10];
      filterMethod = chunkData[11];
      interlace = chunkData[12];
      sawIhdr = true;
    } else if (type === "IDAT") {
      idatChunks.push(chunkData);
    } else if (type === "IEND") {
      sawIend = true;
      break;
    }
  }

  if (!sawIhdr || !sawIend) {
    throw new Error("Invalid PNG: missing IHDR or IEND chunk");
  }
  if (width === 0 || height === 0) {
    throw new Error("Invalid PNG: zero dimension");
  }
  if (bitDepth !== 8) {
    throw new Error(`Unsupported PNG bit depth ${bitDepth}: only 8-bit PNGs are supported`);
  }
  if (compression !== 0 || filterMethod !== 0 || interlace !== 0) {
    throw new Error(
      `Unsupported PNG encoding (compression=${compression}, filter=${filterMethod}, interlace=${interlace})`,
    );
  }

  let bpp;
  if (colorType === 2) bpp = 3;
  else if (colorType === 6) bpp = 4;
  else if (colorType === 0) bpp = 1;
  else if (colorType === 4) bpp = 2;
  else {
    throw new Error(
      `Unsupported PNG color type ${colorType}: only 8-bit RGB (2), RGBA (6), Gray (0), and GrayA (4) are supported`,
    );
  }

  const raw = inflateSync(Buffer.concat(idatChunks));
  const stride = width * bpp;
  const expectedLength = height * (stride + 1);
  if (raw.length < expectedLength) {
    throw new Error(`Invalid PNG: decompressed data too short (${raw.length} < ${expectedLength})`);
  }

  const pixels = new Uint8Array(height * stride);
  for (let y = 0; y < height; y++) {
    const rowIn = y * (stride + 1);
    const filterType = raw[rowIn];
    const rowOut = y * stride;
    const prevOut = (y - 1) * stride;

    for (let x = 0; x < stride; x++) {
      const value = raw[rowIn + 1 + x];
      const left = x >= bpp ? pixels[rowOut + x - bpp] : 0;
      const up = y > 0 ? pixels[prevOut + x] : 0;
      const upLeft = y > 0 && x >= bpp ? pixels[prevOut + x - bpp] : 0;
      let recon;
      if (filterType === 0) recon = value;
      else if (filterType === 1) recon = (value + left) & 0xff;
      else if (filterType === 2) recon = (value + up) & 0xff;
      else if (filterType === 3) recon = (value + ((left + up) >> 1)) & 0xff;
      else if (filterType === 4) recon = (value + paethPredictor(left, up, upLeft)) & 0xff;
      else throw new Error(`Invalid PNG: unknown filter type ${filterType} at row ${y}`);
      pixels[rowOut + x] = recon;
    }
  }

  const rgba = new Uint8Array(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const dst = i * 4;
    if (colorType === 6) {
      const src = i * 4;
      rgba[dst] = pixels[src];
      rgba[dst + 1] = pixels[src + 1];
      rgba[dst + 2] = pixels[src + 2];
      rgba[dst + 3] = pixels[src + 3];
    } else if (colorType === 2) {
      const src = i * 3;
      rgba[dst] = pixels[src];
      rgba[dst + 1] = pixels[src + 1];
      rgba[dst + 2] = pixels[src + 2];
      rgba[dst + 3] = 255;
    } else if (colorType === 0) {
      const v = pixels[i];
      rgba[dst] = v;
      rgba[dst + 1] = v;
      rgba[dst + 2] = v;
      rgba[dst + 3] = 255;
    } else {
      const src = i * 2;
      const v = pixels[src];
      rgba[dst] = v;
      rgba[dst + 1] = v;
      rgba[dst + 2] = v;
      rgba[dst + 3] = pixels[src + 1];
    }
  }

  return { width, height, colorType, channels: bpp, rgba };
}

export function diffPngBuffers(bufA, bufB) {
  const imgA = decodePngBuffer(bufA);
  const imgB = decodePngBuffer(bufB);
  if (imgA.width !== imgB.width || imgA.height !== imgB.height) {
    throw new Error(
      `PNG dimension mismatch: ${imgA.width}x${imgA.height} vs ${imgB.width}x${imgB.height}`,
    );
  }
  const totalPixels = imgA.width * imgA.height;
  const compareAlpha =
    imgA.colorType === 6 || imgB.colorType === 6 || imgA.colorType === 4 || imgB.colorType === 4;
  const channels = compareAlpha ? 4 : 3;

  let changedPixels = 0;
  let sumAbsDelta = 0;
  let maxDelta = 0;

  for (let i = 0; i < totalPixels; i++) {
    const base = i * 4;
    let pixelChanged = false;
    for (let c = 0; c < channels; c++) {
      const delta = Math.abs(imgA.rgba[base + c] - imgB.rgba[base + c]);
      if (delta > 0) pixelChanged = true;
      if (delta > maxDelta) maxDelta = delta;
      sumAbsDelta += delta;
    }
    if (pixelChanged) changedPixels++;
  }

  return {
    width: imgA.width,
    height: imgA.height,
    total_pixels: totalPixels,
    changed_pixels: changedPixels,
    changed_pct: Number(((changedPixels / totalPixels) * 100).toFixed(4)),
    mean_abs_delta: Number((sumAbsDelta / (totalPixels * channels)).toFixed(4)),
    max_delta: maxDelta,
    identical: changedPixels === 0,
  };
}

export function isPidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === "EPERM";
  }
}

export function sessionPaths(sessionName = "default", repoRoot = REPO_ROOT) {
  const safe = validateSessionName(sessionName);
  const dir = path.join(repoRoot, "artifacts", "local", "dev-console", "sessions", safe);
  assertUnderArtifactsLocal(dir, repoRoot);
  const inbox = path.join(dir, "inbox");
  return {
    name: safe,
    dir,
    home: path.join(dir, "home"),
    inbox,
    inDir: path.join(inbox, "in"),
    outDir: path.join(inbox, "out"),
    readyFile: path.join(inbox, "ready.json"),
    artifactsDir: path.join(dir, "out-artifacts"),
    metaFile: path.join(dir, "session.json"),
    logFile: path.join(dir, "godot.log"),
  };
}

export function readJsonSafe(filePath) {
  if (!existsSync(filePath)) return null;
  try {
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

export function cleanStaleReady(inboxDir, { isAlive = isPidAlive } = {}) {
  const readyFile = path.join(inboxDir, "ready.json");
  if (!existsSync(readyFile)) {
    return { cleaned: false, alive: false, ready: null, stalePid: null };
  }
  const ready = readJsonSafe(readyFile);
  const pid = Number(ready?.pid);
  if (ready && ready.ready === true && isAlive(pid)) {
    return { cleaned: false, alive: true, ready, stalePid: null };
  }
  try {
    unlinkSync(readyFile);
  } catch {}
  return { cleaned: true, alive: false, ready: null, stalePid: Number.isFinite(pid) ? pid : null };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function waitForReady(
  inboxDir,
  { timeoutMs = 30_000, pid = null, isAlive = isPidAlive, pollMs = 25 } = {},
) {
  const readyFile = path.join(inboxDir, "ready.json");
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    const ready = readJsonSafe(readyFile);
    if (ready && ready.ready === true && isAlive(Number(ready.pid))) {
      return ready;
    }
    if (pid !== null && !isAlive(pid)) {
      throw new Error(`Godot session process (pid ${pid}) exited before writing ready.json`);
    }
    await sleep(pollMs);
  }
  throw new Error(`Timed out after ${timeoutMs}ms waiting for ${readyFile}`);
}

let requestSeq = 0;

export async function sendMailboxRequest(
  inboxDir,
  cmd,
  { timeoutMs = 30_000, isAlive = isPidAlive, removeResponse = true, pollMs = 15 } = {},
) {
  const ready = readJsonSafe(path.join(inboxDir, "ready.json"));
  if (!ready || ready.ready !== true) {
    throw new Error(`Session not ready: missing or invalid ${path.join(inboxDir, "ready.json")}`);
  }
  const pid = Number(ready.pid);
  if (!isAlive(pid)) {
    cleanStaleReady(inboxDir, { isAlive });
    throw new Error(`Session PID ${pid} is no longer running (cleaned stale ready.json)`);
  }

  const inDir = path.join(inboxDir, "in");
  const outDir = path.join(inboxDir, "out");
  mkdirSync(inDir, { recursive: true });
  mkdirSync(outDir, { recursive: true });

  requestSeq += 1;
  const seqStr = String(requestSeq).padStart(6, "0");
  const id = `${Date.now()}-${seqStr}-${randomBytes(3).toString("hex")}`;
  const reqFile = path.join(inDir, `${seqStr}-${id}.req.json`);
  const tmpFile = path.join(inDir, `.${seqStr}-${id}.tmp`);
  const resFile = path.join(outDir, `${id}.res.json`);

  writeFileSync(tmpFile, JSON.stringify({ id, cmd }) + "\n", "utf8");
  renameSync(tmpFile, reqFile);

  const started = Date.now();
  const deadline = started + timeoutMs;

  return new Promise((resolve, reject) => {
    let settled = false;
    let watcher = null;
    let timer = null;

    const cleanup = () => {
      if (watcher) {
        try {
          watcher.close();
        } catch {}
        watcher = null;
      }
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    };

    const finish = (err, data) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (err) reject(err);
      else resolve(data);
    };

    const tryRead = () => {
      if (settled) return;
      if (existsSync(resFile)) {
        const parsed = readJsonSafe(resFile);
        if (parsed !== null) {
          if (removeResponse) {
            try {
              unlinkSync(resFile);
            } catch {}
          }
          finish(null, { ...parsed, rtt_ms: Date.now() - started });
          return;
        }
      }
      if (Date.now() > deadline) {
        finish(new Error(`Timed out after ${timeoutMs}ms waiting for mailbox response ${id}`));
        return;
      }
      if (!isAlive(pid)) {
        // One final check in case response landed right before exit (e.g. quit)
        const parsed = readJsonSafe(resFile);
        if (parsed !== null) {
          if (removeResponse) {
            try {
              unlinkSync(resFile);
            } catch {}
          }
          finish(null, { ...parsed, rtt_ms: Date.now() - started });
          return;
        }
        finish(new Error(`Session PID ${pid} exited before responding to request ${id}`));
      }
    };

    try {
      watcher = watchFs(outDir, () => tryRead());
      watcher.on("error", () => {});
    } catch {}
    timer = setInterval(tryRead, pollMs);
    tryRead();
  });
}

function runProcess(command, args, { env, cwd, timeoutMs }) {
  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let child;
    const started = Date.now();
    try {
      child = spawn(command, args, { env, cwd, stdio: ["ignore", "pipe", "pipe"] });
    } catch (error) {
      resolve({
        exitCode: 1,
        signal: null,
        stdout: "",
        stderr: String(error?.message ?? error),
        timedOut: false,
        ms: Date.now() - started,
      });
      return;
    }

    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });

    const timer = setTimeout(() => {
      timedOut = true;
      try {
        child.kill("SIGTERM");
      } catch {}
      setTimeout(() => {
        try {
          child.kill("SIGKILL");
        } catch {}
      }, 2000).unref();
    }, timeoutMs);

    child.on("error", (error) => {
      clearTimeout(timer);
      stderr += String(error?.message ?? error);
      resolve({
        exitCode: 1,
        signal: null,
        stdout,
        stderr,
        timedOut,
        ms: Date.now() - started,
      });
    });

    child.on("close", (code, signal) => {
      clearTimeout(timer);
      resolve({
        exitCode: timedOut ? 124 : (code ?? 1),
        signal,
        stdout,
        stderr,
        timedOut,
        ms: Date.now() - started,
      });
    });
  });
}

export function parseArgs(argv) {
  if (!Array.isArray(argv) || argv.length === 0) {
    return { command: "help", positionals: [], flags: {} };
  }

  const validCommands = new Set([
    "run",
    "serve",
    "send",
    "status",
    "stop",
    "recipe",
    "diff",
    "bench",
    "visual-qa-pack",
    "ledger-audit",
    "help",
  ]);

  const flags = {
    mode: null,
    out: null,
    table: null,
    seed: null,
    size: "1280x720",
    sizeExplicit: false,
    timeout: null,
    json: false,
    strict: false,
    session: "default",
    idle: 180,
    turns: 10,
    ref: null,
    slot: null,
    capture: false,
  };
  const tokens = [];

  const setMode = (next) => {
    if (flags.mode !== null && flags.mode !== next) {
      throw new Error(`Conflicting mode flags: --${flags.mode} and --${next}`);
    }
    flags.mode = next;
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      return { command: "help", positionals: [], flags };
    }
    if (arg === "--headless") setMode("headless");
    else if (arg === "--drawn") setMode("drawn");
    else if (arg === "--windowed") setMode("windowed");
    else if (arg === "--json") flags.json = true;
    else if (arg === "--strict") flags.strict = true;
    else if (arg === "--capture") flags.capture = true;
    else if (arg === "--out") {
      if (i + 1 >= argv.length) throw new Error("--out requires a directory");
      flags.out = argv[++i];
    } else if (arg === "--table") {
      if (i + 1 >= argv.length) throw new Error("--table requires a value");
      flags.table = argv[++i];
    } else if (arg === "--seed") {
      if (i + 1 >= argv.length) throw new Error("--seed requires an integer");
      const n = Number(argv[++i]);
      if (!Number.isInteger(n)) throw new Error(`--seed must be an integer; got "${argv[i]}"`);
      flags.seed = n;
    } else if (arg === "--size") {
      if (i + 1 >= argv.length) throw new Error("--size requires <width>x<height>");
      flags.size = parseSize(argv[++i]).text;
      flags.sizeExplicit = true;
    } else if (arg === "--timeout") {
      if (i + 1 >= argv.length) throw new Error("--timeout requires milliseconds");
      const n = Number(argv[++i]);
      if (!Number.isFinite(n) || n <= 0)
        throw new Error(`--timeout must be positive ms; got "${argv[i]}"`);
      flags.timeout = Math.trunc(n);
    } else if (arg === "--session") {
      if (i + 1 >= argv.length) throw new Error("--session requires a session name");
      flags.session = validateSessionName(argv[++i]);
    } else if (arg === "--idle") {
      if (i + 1 >= argv.length) throw new Error("--idle requires seconds");
      const n = Number(argv[++i]);
      if (!Number.isFinite(n) || n < 0)
        throw new Error(`--idle must be >= 0 seconds; got "${argv[i]}"`);
      flags.idle = Math.trunc(n);
    } else if (arg === "--turns") {
      if (i + 1 >= argv.length) throw new Error("--turns requires a positive integer");
      const n = Number(argv[++i]);
      if (!Number.isInteger(n) || n < 1) throw new Error(`--turns must be >= 1; got "${argv[i]}"`);
      flags.turns = n;
    } else if (arg === "--ref") {
      if (i + 1 >= argv.length || !argv[i + 1].trim()) {
        throw new Error("--ref requires a git ref or commit SHA");
      }
      flags.ref = argv[++i].trim();
    } else if (arg === "--slot") {
      if (i + 1 >= argv.length) throw new Error("--slot requires a slot name");
      flags.slot = validateSlotName(argv[++i]);
    } else if (arg.startsWith("--")) {
      throw new Error(`Unknown flag "${arg}"`);
    } else {
      tokens.push(arg);
    }
  }

  if (tokens.length === 0) {
    return { command: "help", positionals: [], flags };
  }

  const head = tokens[0];
  if (head === "help") {
    return { command: "help", positionals: tokens.slice(1), flags };
  }
  if (validCommands.has(head)) {
    return { command: head, positionals: tokens.slice(1), flags };
  }
  if (Object.hasOwn(RECIPES, head)) {
    return { command: "recipe", positionals: tokens, flags };
  }
  throw new Error(
    `Unknown command "${head}". Expected one of: ${[...validCommands].join(", ")} (or a recipe: ${Object.keys(RECIPES).join(", ")})`,
  );
}

export function formatPerfSummaryLine(perf) {
  if (!perf || typeof perf !== "object") return null;
  const n = Number(perf.n ?? 1);
  const fps = perf.spread?.fps ?? {};
  const frame = perf.spread?.frame_ms ?? {};
  const preset = perf.quality_preset ?? "unknown";
  const driver = perf.rendering_driver ?? perf.rendering_method ?? "unknown";
  const limiter = perf.limiter?.note ?? "none";
  return `perf(n=${n}, preset=${preset}, driver=${driver}): fps min=${fps.min ?? perf.fps} med=${fps.median ?? perf.fps} p95=${fps.p95 ?? perf.fps} | frame_ms med=${frame.median ?? perf.frame_ms ?? 0} p95=${frame.p95 ?? perf.frame_ms ?? 0} | limiter=${limiter}`;
}

export function summarizeOwnerHotspots(rankedRows, limit = 3) {
  if (!Array.isArray(rankedRows) || rankedRows.length === 0) return [];
  const byOwner = new Map();
  for (const row of rankedRows) {
    if (!row || typeof row !== "object") continue;
    const owner =
      String(row.owner_script || row.owner_scene || "<unowned>").replace(/^res:\/\//, "") ||
      "<unowned>";
    const prev = byOwner.get(owner) ?? { owner, count: 0, footprint_m2: 0 };
    prev.count += Number(row.count ?? 0);
    prev.footprint_m2 += Number(row.total_footprint_m2 ?? 0);
    byOwner.set(owner, prev);
  }
  return [...byOwner.values()]
    .sort((a, b) => b.count - a.count || b.footprint_m2 - a.footprint_m2)
    .slice(0, limit);
}

export function formatCensusSummaryLine(census) {
  if (!census || typeof census !== "object") return null;
  const tag = census.map || census.flow || "unknown";
  const prims = Number(census.count ?? 0);
  const flats = Number(census.flat_materials?.count ?? 0);
  const skels = Number(census.skeletons?.count ?? 0);
  const primTop = summarizeOwnerHotspots(census.ranked, 3)
    .map((h) => `${h.owner}(${h.count})`)
    .join(", ");
  const flatTop = summarizeOwnerHotspots(census.flat_materials?.ranked, 3)
    .map((h) => `${h.owner}(${h.count})`)
    .join(", ");
  const parts = [`census[${tag}]: prims=${prims} flat_mats=${flats} skeletons=${skels}`];
  if (primTop) parts.push(`top_prim=[${primTop}]`);
  if (flatTop) parts.push(`top_flat=[${flatTop}]`);
  return parts.join(" | ");
}

function resolveOutDir(outFlag, prefix) {
  if (outFlag) {
    return path.resolve(outFlag);
  }
  return path.join(REPO_ROOT, "artifacts", "local", "dev-console", makeRunId(prefix));
}

async function cmdRun({ scriptInput, flags, prefix = "run" }) {
  if (!scriptInput) {
    throw new Error("run requires <commands-or-@file>");
  }
  const mode = flags.mode ?? "headless";
  const timeoutMs = flags.timeout ?? (mode === "drawn" ? 180_000 : 120_000);
  const outDir = resolveOutDir(flags.out, prefix);
  mkdirSync(outDir, { recursive: true });

  let scriptFile;
  if (scriptInput.startsWith("@")) {
    const sourcePath = path.resolve(scriptInput.slice(1));
    if (!existsSync(sourcePath)) {
      throw new Error(`Script file not found: ${sourcePath}`);
    }
    scriptFile = sourcePath;
  } else {
    scriptFile = path.join(outDir, "script.dev");
    writeFileSync(scriptFile, scriptInput.trim() + "\n", "utf8");
  }

  const godotBin = resolveGodotBinary();
  const scratchPath = path.join(
    REPO_ROOT,
    "artifacts",
    "local",
    "dev-console",
    makeRunId(`${prefix}-home`),
    "home",
  );
  const { home, env } = scratchEnv(scratchPath);

  let sandbox = null;
  try {
    if (flags.ref) {
      sandbox = materializeSandbox({
        ref: flags.ref,
        repoRoot: REPO_ROOT,
        slot: flags.slot,
        godotBin,
        importHomeDir: path.join(scratchPath, "import-home"),
      });
    }

    const userArgs = buildUserArgs({
      table: flags.table,
      seed: flags.seed,
      devOut: outDir,
      devFile: scriptFile,
    });
    const spec = buildGodotLaunchSpec({
      godotBin,
      sketchDir: sandbox ? sandbox.sketchDir : SKETCH_DIR,
      mode,
      size: flags.size,
      userArgs,
    });

    const ran = await runProcess(spec.command, spec.args, {
      env,
      cwd: sandbox ? sandbox.worktreeDir : REPO_ROOT,
      timeoutMs,
    });
    const receiptPath = path.join(outDir, "receipt.json");
    const receipt = readJsonSafe(receiptPath);
    const analysis = analyzeOutput({
      exitCode: ran.exitCode,
      stdout: ran.stdout,
      stderr: ran.stderr,
      receipt,
    });

    const payload = {
      ok: analysis.ok,
      mode,
      out: outDir,
      home,
      ...(sandbox
        ? {
            ref: sandbox.ref,
            sha: sandbox.sha,
            slot: sandbox.slot,
            sandbox_dir: sandbox.worktreeDir,
            overlay_applied: sandbox.overlay.applied || sandbox.overlay.cached,
          }
        : {}),
      receipt_path: existsSync(receiptPath) ? receiptPath : null,
      exit_code: ran.exitCode,
      timed_out: ran.timedOut,
      ms: ran.ms,
      issues: analysis.issues,
      receipt,
    };

    if (flags.json) {
      console.log(JSON.stringify(payload, null, 2));
    } else {
      const refTag = sandbox ? ` @ ${sandbox.sha12}[${sandbox.slot}]` : "";
      console.log(
        `dev-console ${payload.ok ? "PASS" : "FAIL"} (${mode}, ${ran.ms}ms${refTag}) -> ${outDir}`,
      );
      if (receipt?.steps) {
        const passed = receipt.steps.filter((s) => s.ok !== false).length;
        console.log(`  steps: ${passed}/${receipt.steps.length}`);
        for (const step of receipt.steps) {
          if (step?.data && typeof step.data === "object") {
            if (step.data.spread && step.data.limiter) {
              console.log(`  ${formatPerfSummaryLine(step.data)}`);
            } else if (step.data.flat_materials && step.data.skeletons) {
              console.log(`  ${formatCensusSummaryLine(step.data)}`);
            }
          }
        }
      }
      for (const issue of analysis.issues) console.error(`  ! ${issue}`);
    }
    return payload.ok ? 0 : 1;
  } finally {
    if (sandbox) sandbox.release();
  }
}

async function cmdServe({ flags, silent = false }) {
  const mode = flags.mode ?? "headless";
  const timeoutMs = flags.timeout ?? 30_000;
  const paths = sessionPaths(flags.session);
  const check = cleanStaleReady(paths.inbox);
  if (check.alive) {
    const payload = {
      ok: true,
      already_running: true,
      session: paths.name,
      pid: check.ready.pid,
      inbox: paths.inbox,
      out: paths.artifactsDir,
      ready: check.ready,
    };
    if (!silent) {
      if (flags.json) console.log(JSON.stringify(payload, null, 2));
      else console.log(`session '${paths.name}' already running (pid ${check.ready.pid})`);
    }
    return 0;
  }

  mkdirSync(paths.inDir, { recursive: true });
  mkdirSync(paths.outDir, { recursive: true });
  mkdirSync(paths.artifactsDir, { recursive: true });
  for (const dir of [paths.inDir, paths.outDir]) {
    for (const entry of readdirSync(dir)) {
      rmSync(path.join(dir, entry), { force: true });
    }
  }

  const godotBin = resolveGodotBinary();
  const { env } = scratchEnv(paths.home);
  let sandbox = null;
  if (flags.ref) {
    sandbox = materializeSandbox({
      ref: flags.ref,
      repoRoot: REPO_ROOT,
      slot: flags.slot,
      godotBin,
      importHomeDir: path.join(paths.home, "import-home"),
    });
  }

  const userArgs = buildUserArgs({
    table: flags.table ?? "park",
    seed: flags.seed,
    devInbox: paths.inbox,
    devOut: paths.artifactsDir,
    devIdle: flags.idle,
  });
  const spec = buildGodotLaunchSpec({
    godotBin,
    sketchDir: sandbox ? sandbox.sketchDir : SKETCH_DIR,
    mode,
    size: flags.size,
    userArgs,
  });

  const logFd = openSync(paths.logFile, "w");
  const started = Date.now();
  let child;
  try {
    child = spawn(spec.command, spec.args, {
      env,
      cwd: sandbox ? sandbox.worktreeDir : REPO_ROOT,
      detached: true,
      stdio: ["ignore", logFd, logFd],
    });
    child.unref();
  } catch (error) {
    if (sandbox) sandbox.release();
    throw error;
  } finally {
    closeSync(logFd);
  }

  let ready;
  try {
    ready = await waitForReady(paths.inbox, { timeoutMs, pid: child.pid });
  } catch (error) {
    if (sandbox) sandbox.release();
    const logTail = existsSync(paths.logFile)
      ? readFileSync(paths.logFile, "utf8").split(/\r?\n/).slice(-15).join("\n")
      : "";
    throw new Error(`${error.message}${logTail ? `\n--- godot.log ---\n${logTail}` : ""}`);
  }

  const resolvedPid = Number(ready.pid ?? child.pid);
  if (sandbox) {
    sandbox.transferLockTo(resolvedPid, { session: paths.name });
  }

  const meta = {
    session: paths.name,
    pid: resolvedPid,
    launcher_pid: child.pid,
    mode,
    table: flags.table ?? "park",
    seed: flags.seed,
    size: flags.size,
    idle: flags.idle,
    inbox: paths.inbox,
    out: paths.artifactsDir,
    log: paths.logFile,
    ...(sandbox
      ? {
          ref: sandbox.ref,
          sha: sandbox.sha,
          slot: sandbox.slot,
          sandbox_dir: sandbox.worktreeDir,
        }
      : {}),
    boot_ms: Date.now() - started,
    started_at: new Date().toISOString(),
  };
  writeFileSync(paths.metaFile, JSON.stringify(meta, null, 2) + "\n", "utf8");

  const payload = { ok: true, ...meta, ready };
  if (!silent) {
    if (flags.json) console.log(JSON.stringify(payload, null, 2));
    else console.log(`session '${paths.name}' ready (pid ${meta.pid}, ${mode}, ${meta.boot_ms}ms)`);
  }
  return 0;
}

async function cmdSend({ cmdText, flags }) {
  if (!cmdText) {
    throw new Error("send requires <commands>");
  }
  const paths = sessionPaths(flags.session);
  const timeoutMs = flags.timeout ?? 30_000;
  const response = await sendMailboxRequest(paths.inbox, cmdText, { timeoutMs });
  if (flags.json) {
    console.log(JSON.stringify(response, null, 2));
  } else {
    console.log(response.text ?? (response.ok ? "ok" : "!failed"));
  }
  return response.ok === true ? 0 : 1;
}

function cmdStatus({ flags }) {
  const paths = sessionPaths(flags.session);
  const ready = readJsonSafe(paths.readyFile);
  const meta = readJsonSafe(paths.metaFile);
  const pid = Number(ready?.pid ?? meta?.pid);
  const alive = isPidAlive(pid);
  const stale = Boolean((ready || meta) && !alive);
  const payload = {
    session: paths.name,
    running: Boolean(ready && ready.ready === true && alive),
    alive,
    stale,
    pid: Number.isFinite(pid) && pid > 0 ? pid : null,
    inbox: paths.inbox,
    out: paths.artifactsDir,
    ready,
    meta,
  };
  if (flags.json) console.log(JSON.stringify(payload, null, 2));
  else if (payload.running) {
    console.log(`session '${paths.name}' running (pid ${payload.pid}, ${meta?.mode ?? "unknown"})`);
  } else {
    console.log(`session '${paths.name}' stopped${stale ? ` (stale pid ${payload.pid})` : ""}`);
  }
  return payload.running ? 0 : 1;
}

async function cmdStop({ flags, silent = false }) {
  const paths = sessionPaths(flags.session);
  const ready = readJsonSafe(paths.readyFile);
  const meta = readJsonSafe(paths.metaFile);
  const pid = Number(ready?.pid ?? meta?.pid);
  const wasAlive = isPidAlive(pid);

  if (!wasAlive) {
    cleanStaleReady(paths.inbox);
    if (meta?.sandbox_dir) releaseSlotLock(meta.sandbox_dir, { expectedPid: pid });
    const payload = { ok: true, session: paths.name, already_stopped: true, pid: null };
    if (!silent) {
      if (flags.json) console.log(JSON.stringify(payload, null, 2));
      else console.log(`session '${paths.name}' is not running`);
    }
    return 0;
  }

  let quitMethod = "mailbox";
  try {
    await sendMailboxRequest(paths.inbox, "quit", { timeoutMs: 5000 });
  } catch {
    quitMethod = "sigterm";
  }

  const deadline = Date.now() + 5000;
  while (Date.now() < deadline && isPidAlive(pid)) {
    await sleep(50);
  }

  if (isPidAlive(pid)) {
    quitMethod = "sigterm";
    try {
      process.kill(pid, "SIGTERM");
    } catch {}
    const killDeadline = Date.now() + 1500;
    while (Date.now() < killDeadline && isPidAlive(pid)) {
      await sleep(50);
    }
    if (isPidAlive(pid)) {
      quitMethod = "sigkill";
      try {
        process.kill(pid, "SIGKILL");
      } catch {}
      await sleep(100);
    }
  }

  cleanStaleReady(paths.inbox);
  if (meta?.sandbox_dir) releaseSlotLock(meta.sandbox_dir, { expectedPid: pid });
  const stillAlive = isPidAlive(pid);
  const payload = {
    ok: !stillAlive,
    session: paths.name,
    pid,
    method: quitMethod,
    stopped: !stillAlive,
  };
  if (!silent) {
    if (flags.json) console.log(JSON.stringify(payload, null, 2));
    else {
      console.log(
        stillAlive
          ? `!session '${paths.name}' pid ${pid} did not exit`
          : `session '${paths.name}' stopped (${quitMethod})`,
      );
    }
  }
  return stillAlive ? 1 : 0;
}

async function cmdRecipe({ name, flags }) {
  if (!name || !Object.hasOwn(RECIPES, name)) {
    const names = Object.keys(RECIPES).join(", ");
    throw new Error(`Unknown recipe "${name ?? ""}". Available recipes: ${names}`);
  }
  const recipe = RECIPES[name];
  const mergedFlags = {
    ...flags,
    mode: flags.mode ?? recipe.mode,
    table: flags.table ?? "park",
    size: !flags.sizeExplicit && recipe.defaultSize ? recipe.defaultSize : flags.size,
  };
  return cmdRun({
    scriptInput: recipe.script,
    flags: mergedFlags,
    prefix: `recipe-${name}`,
  });
}

async function cmdVisualQaPack({ inputPath, flags }) {
  if (flags.capture || !inputPath) {
    if (!flags.capture && !inputPath) {
      throw new Error(
        "visual-qa-pack requires <input.png> (to convert an existing PNG) or --capture (to shoot a live 1080p frame)",
      );
    }
    return cmdRecipe({ name: "visual-qa-pack", flags });
  }
  if (!existsSync(inputPath)) {
    throw new Error(`Input PNG not found: ${inputPath}`);
  }
  const outDir = flags.out ? path.resolve(flags.out) : resolveOutDir(null, "visual-qa-pack");
  const result = buildVisualQaPack(inputPath, { outDir });
  if (flags.json) {
    console.log(JSON.stringify({ ok: true, ...result }, null, 2));
  } else {
    console.log(
      `visual-qa-pack PASS (${result.source_width}x${result.source_height}) -> ${result.out}`,
    );
    for (const [k, v] of Object.entries(result.oracles)) {
      console.log(`  ${k}: ${v.width}x${v.height} mean_luma=${v.mean_luma} -> ${v.path}`);
    }
  }
  return 0;
}

function cmdLedgerAudit({ flags }) {
  const report = runLedgerAudit({ repoRoot: REPO_ROOT });
  if (flags.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log(formatLedgerAudit(report));
  }
  if (flags.strict && !report.ok) return 1;
  return 0;
}

function cmdDiff({ pathA, pathB, flags }) {
  if (!pathA || !pathB) {
    throw new Error("diff requires <pngA> <pngB>");
  }
  const result = diffPngBuffers(readFileSync(pathA), readFileSync(pathB));
  if (flags.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(
      `diff ${result.width}x${result.height}: ${result.changed_pixels}/${result.total_pixels} px (${result.changed_pct}%), mean_abs_delta=${result.mean_abs_delta}, max_delta=${result.max_delta}, identical=${result.identical}`,
    );
  }
  return 0;
}

function median(values) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

async function cmdBench({ flags }) {
  const turns = flags.turns;
  const outDir = resolveOutDir(flags.out, "bench");
  mkdirSync(outDir, { recursive: true });
  const mode = flags.mode ?? "headless";
  const godotBin = resolveGodotBinary();

  let sandbox = null;
  if (flags.ref) {
    sandbox = materializeSandbox({
      ref: flags.ref,
      repoRoot: REPO_ROOT,
      slot: flags.slot,
      godotBin,
      importHomeDir: path.join(outDir, "import-home"),
    });
  }

  try {
    const targetSketchDir = sandbox ? sandbox.sketchDir : SKETCH_DIR;
    const targetCwd = sandbox ? sandbox.worktreeDir : REPO_ROOT;

    const boot = "calm on; run 1; wait 60; pick 1; tick 5";
    const benchSteps = [
      { warm: `${boot}; assert state stage`, cold: `${boot}; assert state stage` },
      { warm: "inspect player", cold: `${boot}; inspect player` },
      { warm: "spawn chaser 2; tick 5", cold: `${boot}; spawn chaser 2; tick 5` },
      { warm: "inspect enemies", cold: `${boot}; spawn chaser 2; tick 5; inspect enemies` },
      { warm: "assert enemies 2", cold: `${boot}; spawn chaser 2; tick 5; assert enemies 2` },
      { warm: "inspect perf", cold: `${boot}; inspect perf` },
      { warm: "clear hard; tick 5", cold: `${boot}; spawn chaser 2; tick 5; clear hard; tick 5` },
      { warm: "assert enemies 0", cold: `${boot}; assert enemies 0` },
      { warm: "inspect anomalies", cold: `${boot}; inspect anomalies` },
      { warm: "assert finite", cold: `${boot}; assert finite` },
    ];
    const stepFor = (index) => {
      const entry = benchSteps[index % benchSteps.length];
      if (index > 0 && index % benchSteps.length === 0) {
        return { ...entry, warm: "inspect state; assert state stage" };
      }
      return entry;
    };

    const coldMs = [];
    const coldStart = Date.now();
    for (let i = 0; i < turns; i++) {
      const turnDir = path.join(outDir, `cold-${i + 1}`);
      mkdirSync(turnDir, { recursive: true });
      const scriptFile = path.join(turnDir, "script.dev");
      const cmd = `${stepFor(i).cold}; quit`;
      writeFileSync(scriptFile, cmd + "\n", "utf8");
      const { env } = scratchEnv(path.join(turnDir, "home"));
      const userArgs = buildUserArgs({
        table: flags.table ?? "park",
        seed: flags.seed ?? 7,
        devOut: turnDir,
        devFile: scriptFile,
      });
      const spec = buildGodotLaunchSpec({
        godotBin,
        sketchDir: targetSketchDir,
        mode,
        size: flags.size,
        userArgs,
      });
      const ran = await runProcess(spec.command, spec.args, {
        env,
        cwd: targetCwd,
        timeoutMs: flags.timeout ?? 120_000,
      });
      if (ran.exitCode !== 0) {
        throw new Error(`Cold bench turn ${i + 1} failed with exit ${ran.exitCode}`);
      }
      coldMs.push(ran.ms);
    }
    const coldTotalMs = Date.now() - coldStart;

    const sessionName = `bench-${randomBytes(3).toString("hex")}`;
    const serveFlags = {
      ...flags,
      mode,
      session: sessionName,
      table: flags.table ?? "park",
      seed: flags.seed ?? 7,
      json: false,
      ref: null,
    };
    if (sandbox) {
      sandbox.release();
      sandbox = null;
      serveFlags.ref = flags.ref;
    }
    const warmStart = Date.now();
    const paths = sessionPaths(sessionName);
    let warmBootMs = 0;
    const warmTurnMs = [];
    try {
      const bootStart = Date.now();
      await cmdServe({ flags: serveFlags, silent: true });
      warmBootMs = Date.now() - bootStart;
      for (let i = 0; i < turns; i++) {
        const res = await sendMailboxRequest(paths.inbox, stepFor(i).warm, {
          timeoutMs: flags.timeout ?? 30_000,
        });
        if (!res.ok) {
          throw new Error(`Warm bench turn ${i + 1} failed: ${res.text ?? "unknown"}`);
        }
        warmTurnMs.push(res.rtt_ms);
      }
    } finally {
      await cmdStop({ flags: serveFlags, silent: true });
    }
    const warmTotalMs = Date.now() - warmStart;

    const summary = {
      turns,
      mode,
      platform: process.platform,
      cold: {
        total_ms: coldTotalMs,
        median_ms: Number(median(coldMs).toFixed(1)),
        per_turn_ms: coldMs,
      },
      warm: {
        boot_ms: warmBootMs,
        total_ms: warmTotalMs,
        median_turn_ms: Number(median(warmTurnMs).toFixed(1)),
        per_turn_ms: warmTurnMs,
      },
      speedup: Number((coldTotalMs / Math.max(warmTotalMs, 1)).toFixed(2)),
      out: outDir,
    };
    writeFileSync(path.join(outDir, "bench.json"), JSON.stringify(summary, null, 2) + "\n", "utf8");

    if (flags.json) {
      console.log(JSON.stringify(summary, null, 2));
    } else {
      console.log(`| Mode | Turns | Boot (ms) | Median Turn (ms) | Total (ms) |`);
      console.log(`| --- | ---: | ---: | ---: | ---: |`);
      console.log(
        `| Cold batch | ${turns} | — | ${summary.cold.median_ms} | ${summary.cold.total_ms} |`,
      );
      console.log(
        `| Warm File-Mailbox | ${turns} | ${summary.warm.boot_ms} | ${summary.warm.median_turn_ms} | ${summary.warm.total_ms} |`,
      );
      console.log(`\nSpeedup: ${summary.speedup}x (saved to ${path.join(outDir, "bench.json")})`);
    }
    return 0;
  } finally {
    if (sandbox) sandbox.release();
  }
}

function printHelp() {
  const recipeList = Object.values(RECIPES)
    .map((r) => `  ${r.name.padEnd(18)} [${r.mode.padEnd(8)}] ${r.description}`)
    .join("\n");
  console.log(`Usage: node scripts/dev-console.mjs <command> [options]

Commands:
  run <cmds|@file>   Run commands in a fresh isolated Godot process (default: --headless)
  serve              Start a detached silent File-Mailbox session (--session <name>)
  send <cmds>        Send one turn to a live session
  status             Check session PID liveness and ready.json
  stop               Gracefully quit a session (SIGTERM fallback + clean stale ready.json)
  recipe <name>      Run a built-in zero-boilerplate recipe (or pass recipe name directly)
  visual-qa-pack     Convert <png> (or --capture) into 4-oracle QA pack (1080p, 720p, Rec.709, Machado CVD)
  ledger-audit       Fast (<2s) check of KNOWN-FAILING.tsv red/overdue rows, placeholder-gate, and TLA+ sync drift
  diff <a.png> <b.png> Pure-Node pixel diff of two 8-bit PNG images
  bench              Benchmark N cold batch runs vs 1 warm File-Mailbox session

Options:
  --ref <git-ref>    Run against any git ref in an isolated detached worktree under artifacts/local/dev-ref/
  --slot <name>      Pin a sandbox worktree slot (default: auto-allocated zero-collision slot)
  --headless         Headless + Dummy audio (default for run/serve/bench/logic recipes)
  --drawn            Silent offscreen rendering (macOS Metal --embedded; Linux gamescope/xvfb-run)
  --windowed         Explicitly allow a visible desktop window (never default)
  --capture          Capture live 1080p frame for visual-qa-pack
  --strict           Exit non-zero from ledger-audit when red/overdue/drift/placeholder findings exist
  --out <dir>        Output directory for receipts and shots
  --table <name>     Stage table: park | alpha | slice | default
  --seed <n>         Deterministic route seed
  --size <WxH>       Viewport resolution for drawn/windowed mode (default: 1280x720)
  --timeout <ms>     Command timeout in milliseconds
  --session <name>   Mailbox session name (default: default)
  --idle <seconds>   Auto-exit idle timeout for serve (default: 180)
  --turns <n>        Turn count for bench (default: 10)
  --json             Machine-readable JSON output

Recipes:
${recipeList}`);
}

export async function main(argv = process.argv.slice(2)) {
  const parsed = parseArgs(argv);
  if (parsed.command === "help") {
    printHelp();
    return 0;
  }
  if (parsed.command === "run") {
    return cmdRun({ scriptInput: parsed.positionals.join(" "), flags: parsed.flags });
  }
  if (parsed.command === "serve") {
    return cmdServe({ flags: parsed.flags });
  }
  if (parsed.command === "send") {
    return cmdSend({ cmdText: parsed.positionals.join(" "), flags: parsed.flags });
  }
  if (parsed.command === "status") {
    return cmdStatus({ flags: parsed.flags });
  }
  if (parsed.command === "stop") {
    return cmdStop({ flags: parsed.flags });
  }
  if (parsed.command === "recipe") {
    return cmdRecipe({ name: parsed.positionals[0], flags: parsed.flags });
  }
  if (parsed.command === "visual-qa-pack") {
    return cmdVisualQaPack({ inputPath: parsed.positionals[0], flags: parsed.flags });
  }
  if (parsed.command === "ledger-audit") {
    return cmdLedgerAudit({ flags: parsed.flags });
  }
  if (parsed.command === "diff") {
    return cmdDiff({
      pathA: parsed.positionals[0],
      pathB: parsed.positionals[1],
      flags: parsed.flags,
    });
  }
  if (parsed.command === "bench") {
    return cmdBench({ flags: parsed.flags });
  }
  return 2;
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
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`dev-console: ${error?.message ?? error}`);
      process.exitCode = Number.isInteger(error?.exitCode) ? error.exitCode : 1;
    });
}
