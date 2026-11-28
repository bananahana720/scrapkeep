import assert from "node:assert/strict";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";
import { deflateSync } from "node:zlib";

import {
  analyzeOutput,
  buildGodotLaunchSpec,
  buildUserArgs,
  cleanStaleReady,
  decodePngBuffer,
  DEV_FLAGS,
  diffPngBuffers,
  formatCensusSummaryLine,
  formatPerfSummaryLine,
  parseArgs,
  RECIPES,
  REPO_ROOT,
  resolveGodotBinary,
  scratchEnv,
  sendMailboxRequest,
  summarizeOwnerHotspots,
} from "./dev-console.mjs";
import {
  buildVisualQaPack,
  decodePng,
  encodeRgbPng,
  toMachadoDeuteranopiaRgb,
  toRec709GreyscaleRgb,
} from "./visual-qa-pack.mjs";

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function encodeSyntheticPng(width, height, rawPixels, { colorType = 6, filterType = 0 } = {}) {
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : 1;
  const stride = width * bpp;
  const scanlines = Buffer.alloc(height * (stride + 1));

  for (let y = 0; y < height; y++) {
    const outRow = y * (stride + 1);
    const inRow = y * stride;
    const prevRow = (y - 1) * stride;
    scanlines[outRow] = filterType;
    for (let x = 0; x < stride; x++) {
      const val = rawPixels[inRow + x];
      const left = x >= bpp ? rawPixels[inRow + x - bpp] : 0;
      const up = y > 0 ? rawPixels[prevRow + x] : 0;
      const upLeft = y > 0 && x >= bpp ? rawPixels[prevRow + x - bpp] : 0;
      let filtered = val;
      if (filterType === 1) filtered = (val - left) & 0xff;
      else if (filterType === 2) filtered = (val - up) & 0xff;
      else if (filterType === 3) filtered = (val - ((left + up) >> 1)) & 0xff;
      else if (filterType === 4) filtered = (val - paeth(left, up, upLeft)) & 0xff;
      scanlines[outRow + 1 + x] = filtered;
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = colorType;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", deflateSync(scanlines)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

describe("buildGodotLaunchSpec", () => {
  it("defaults to headless + Dummy audio and never passes --windowed", () => {
    for (const platform of ["darwin", "linux"]) {
      const spec = buildGodotLaunchSpec({
        godotBin: "/fake/godot",
        platform,
        userArgs: ["--dev", "--no-intro"],
      });
      assert.equal(spec.command, "/fake/godot");
      assert.equal(spec.mode, "headless");
      assert.ok(spec.args.includes("--headless"));
      assert.ok(spec.args.includes("--audio-driver"));
      assert.equal(spec.args[spec.args.indexOf("--audio-driver") + 1], "Dummy");
      assert.ok(!spec.args.includes("--windowed"));
    }
  });

  it("uses silent offscreen Metal debug flags on darwin in --drawn mode", () => {
    const spec = buildGodotLaunchSpec({
      godotBin: "/fake/Godot",
      mode: "drawn",
      platform: "darwin",
      size: "1280x720",
      userArgs: ["--dev", "--no-intro"],
    });
    assert.equal(spec.command, "/fake/Godot");
    assert.equal(spec.wrapper, "none");
    for (const flag of [
      "--embedded",
      "--rendering-driver",
      "metal",
      "--debug",
      "--skip-breakpoints",
      "--ignore-error-breaks",
      "--audio-driver",
      "Dummy",
      "--resolution",
      "1280x720",
    ]) {
      assert.ok(spec.args.includes(flag), `expected darwin drawn args to include ${flag}`);
    }
    assert.ok(!spec.args.includes("--windowed"));
    assert.ok(!spec.args.includes("--headless"));
  });

  it("wraps linux --drawn with gamescope headless when present", () => {
    const spec = buildGodotLaunchSpec({
      godotBin: "/opt/godot",
      mode: "drawn",
      platform: "linux",
      size: "1600x900",
      userArgs: ["--dev"],
      findTool: (name) => (name === "gamescope" ? "/usr/bin/gamescope" : null),
    });
    assert.equal(spec.command, "/usr/bin/gamescope");
    assert.equal(spec.wrapper, "gamescope");
    assert.deepEqual(spec.args.slice(0, 7), [
      "--backend",
      "headless",
      "-W",
      "1600",
      "-H",
      "900",
      "--",
    ]);
    assert.ok(spec.args.includes("/opt/godot"));
    assert.equal(spec.args[spec.args.indexOf("--audio-driver") + 1], "Dummy");
    assert.ok(!spec.args.includes("--windowed"));
  });

  it("falls back to xvfb-run on linux --drawn when gamescope is absent", () => {
    const spec = buildGodotLaunchSpec({
      godotBin: "/opt/godot",
      mode: "drawn",
      platform: "linux",
      size: "1280x720",
      userArgs: ["--dev"],
      findTool: (name) => (name === "xvfb-run" ? "/usr/bin/xvfb-run" : null),
    });
    assert.equal(spec.command, "/usr/bin/xvfb-run");
    assert.equal(spec.wrapper, "xvfb-run");
    assert.deepEqual(spec.args.slice(0, 3), ["-a", "-s", "-screen 0 1280x720x24"]);
    assert.ok(spec.args.includes("/opt/godot"));
    assert.equal(spec.args[spec.args.indexOf("--audio-driver") + 1], "Dummy");
  });

  it("refuses bare desktop launch on linux --drawn when neither compositor exists", () => {
    assert.throws(
      () =>
        buildGodotLaunchSpec({
          godotBin: "/opt/godot",
          mode: "drawn",
          platform: "linux",
          findTool: () => null,
        }),
      (err) => {
        assert.equal(err.exitCode, 2);
        assert.match(err.message, /gamescope.*xvfb-run/i);
        return true;
      },
    );
  });

  it("allows --windowed only when explicitly requested", () => {
    const spec = buildGodotLaunchSpec({
      godotBin: "/opt/godot",
      mode: "windowed",
      platform: "linux",
      findTool: () => null,
    });
    assert.equal(spec.command, "/opt/godot");
    assert.ok(spec.args.includes("--windowed"));
    assert.equal(spec.args[spec.args.indexOf("--audio-driver") + 1], "Dummy");
  });
});

describe("resolveGodotBinary", () => {
  it("resolves GODOT_BIN before checking filesystem or PATH", () => {
    const resolved = resolveGodotBinary({
      env: { GODOT_BIN: "/custom/godot" },
      platform: "darwin",
      homeDir: "/Users/someone",
      exists: () => false,
      which: () => null,
    });
    assert.equal(resolved, "/custom/godot");
  });

  it("checks macOS Applications path with real homeDir before scratch HOME override", () => {
    const expected = path.join(
      "/Users/realuser",
      "Applications",
      "Godot_4.7.2.app",
      "Contents",
      "MacOS",
      "Godot",
    );
    const resolved = resolveGodotBinary({
      env: {},
      platform: "darwin",
      homeDir: "/Users/realuser",
      exists: (p) => p === expected,
      which: () => null,
    });
    assert.equal(resolved, expected);
  });

  it("throws when no Godot binary can be found", () => {
    assert.throws(
      () =>
        resolveGodotBinary({
          env: {},
          platform: "linux",
          exists: () => false,
          which: () => null,
        }),
      /GODOT_BIN/,
    );
  });
});

describe("scratchEnv", () => {
  it("refuses any path outside artifacts/local/", () => {
    for (const badPath of [
      "/tmp/escape-home",
      path.join(REPO_ROOT, "artifacts"),
      path.join(REPO_ROOT, "artifacts", "local"),
      path.join(REPO_ROOT, "artifacts", "local", "..", "other"),
      "../outside",
    ]) {
      assert.throws(
        () => scratchEnv(badPath, { repoRoot: REPO_ROOT, create: false }),
        /artifacts\/local/,
      );
    }
  });

  it("creates isolated HOME and XDG directories under artifacts/local/", () => {
    const tempBase = path.join(REPO_ROOT, "artifacts", "local", "dev-console-test");
    mkdirSync(tempBase, { recursive: true });
    const runDir = mkdtempSync(path.join(tempBase, "scratch-"));
    try {
      const targetHome = path.join(runDir, "home");
      const { home, env } = scratchEnv(targetHome, {
        repoRoot: REPO_ROOT,
        baseEnv: { PATH: "/usr/bin" },
        platform: "linux",
      });
      assert.equal(home, targetHome);
      assert.equal(env.HOME, targetHome);
      assert.equal(env.XDG_DATA_HOME, path.join(targetHome, "data"));
      assert.equal(env.XDG_CONFIG_HOME, path.join(targetHome, "config"));
      assert.equal(env.XDG_CACHE_HOME, path.join(targetHome, "cache"));
      assert.equal(env.SDL_AUDIODRIVER, "dummy");
      assert.ok(existsSync(env.XDG_DATA_HOME));
      assert.ok(existsSync(env.XDG_CONFIG_HOME));
      assert.ok(existsSync(env.XDG_CACHE_HOME));
    } finally {
      rmSync(runDir, { recursive: true, force: true });
    }
  });
});

describe("analyzeOutput", () => {
  it("passes clean exit + ok receipt even with macOS RendererDummy teardown noise", () => {
    const res = analyzeOutput({
      exitCode: 0,
      stdout: "DEV_RECEIPT /tmp/receipt.json\n",
      stderr: "ERROR: 3 RID allocations of type 'RendererDummy' were leaked at exit.\n",
      receipt: { ok: true, assertions: { passed: 2, failed: 0, rows: [] }, shots: [] },
      platform: "darwin",
    });
    assert.equal(res.ok, true);
    assert.deepEqual(res.issues, []);
  });

  it("catches SCRIPT ERROR, Parse Error, !v.is_finite(), failed assertions, and dead_frame", () => {
    const res = analyzeOutput({
      exitCode: 0,
      stdout: "SCRIPT ERROR: bad call\nParse Error: unexpected token\n",
      stderr: 'ERROR: Condition "!v.is_finite()" is true.\n',
      receipt: {
        ok: false,
        assertions: { passed: 1, failed: 1, rows: [{ cmd: "assert enemies 0", ok: false }] },
        shots: [{ name: "shot_1", path: "shot_1.png", dead_frame: true }],
      },
    });
    assert.equal(res.ok, false);
    assert.equal(res.scriptErrors.length, 1);
    assert.equal(res.parseErrors.length, 1);
    assert.equal(res.nonFiniteErrors.length, 1);
    assert.equal(res.deadFrames.length, 1);
    assert.equal(res.failedAssertions.length, 1);
    assert.ok(res.issues.length >= 6);
  });
});

describe("diffPngBuffers", () => {
  it("decodes and compares identical PNGs across all 5 PNG filter types (RGB and RGBA)", () => {
    const width = 4;
    const height = 3;
    const rgba = new Uint8Array(width * height * 4);
    for (let i = 0; i < width * height; i++) {
      rgba[i * 4] = (i * 23) & 0xff;
      rgba[i * 4 + 1] = (i * 41 + 17) & 0xff;
      rgba[i * 4 + 2] = (i * 59 + 93) & 0xff;
      rgba[i * 4 + 3] = 255;
    }
    const basePng = encodeSyntheticPng(width, height, rgba, { colorType: 6, filterType: 0 });
    for (const filterType of [0, 1, 2, 3, 4]) {
      const filteredPng = encodeSyntheticPng(width, height, rgba, { colorType: 6, filterType });
      const diff = diffPngBuffers(basePng, filteredPng);
      assert.equal(diff.identical, true, `filterType ${filterType} should decode identically`);
      assert.equal(diff.changed_pixels, 0);
      assert.equal(diff.changed_pct, 0);
      assert.equal(diff.mean_abs_delta, 0);
      assert.equal(diff.max_delta, 0);
    }

    const rgb = new Uint8Array(width * height * 3);
    for (let i = 0; i < width * height; i++) {
      rgb[i * 3] = rgba[i * 4];
      rgb[i * 3 + 1] = rgba[i * 4 + 1];
      rgb[i * 3 + 2] = rgba[i * 4 + 2];
    }
    const rgbPng = encodeSyntheticPng(width, height, rgb, { colorType: 2, filterType: 4 });
    const decoded = decodePngBuffer(rgbPng);
    assert.equal(decoded.width, width);
    assert.equal(decoded.height, height);
    assert.equal(diffPngBuffers(basePng, rgbPng).identical, true);
  });

  it("reports accurate changed_pixels, changed_pct, mean_abs_delta, and max_delta", () => {
    const width = 2;
    const height = 2;
    const a = new Uint8Array(width * height * 4).fill(100);
    const b = new Uint8Array(a);
    // Modify 1 pixel: R +40, G -20 (total abs delta = 60 across 4*4 = 16 channels -> mean = 3.75)
    b[0] = 140;
    b[1] = 80;
    const pngA = encodeSyntheticPng(width, height, a, { colorType: 6, filterType: 1 });
    const pngB = encodeSyntheticPng(width, height, b, { colorType: 6, filterType: 4 });
    const diff = diffPngBuffers(pngA, pngB);
    assert.equal(diff.width, 2);
    assert.equal(diff.height, 2);
    assert.equal(diff.total_pixels, 4);
    assert.equal(diff.changed_pixels, 1);
    assert.equal(diff.changed_pct, 25);
    assert.equal(diff.mean_abs_delta, 3.75);
    assert.equal(diff.max_delta, 40);
    assert.equal(diff.identical, false);
  });

  it("throws on dimension mismatch", () => {
    const pngA = encodeSyntheticPng(2, 2, new Uint8Array(16), { colorType: 6 });
    const pngB = encodeSyntheticPng(3, 2, new Uint8Array(24), { colorType: 6 });
    assert.throws(() => diffPngBuffers(pngA, pngB), /dimension mismatch/i);
  });
});

describe("mailbox round-trip and stale ready cleanup", () => {
  it("completes an atomic request/response round-trip with a mock responder", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-mailbox-test-"));
    let poller = null;
    try {
      const inDir = path.join(tmp, "in");
      const outDir = path.join(tmp, "out");
      mkdirSync(inDir, { recursive: true });
      mkdirSync(outDir, { recursive: true });
      writeFileSync(
        path.join(tmp, "ready.json"),
        JSON.stringify({ pid: process.pid, ready: true }),
        "utf8",
      );

      poller = setInterval(() => {
        for (const name of readdirSync(inDir)) {
          if (!name.endsWith(".req.json")) continue;
          const reqPath = path.join(inDir, name);
          const req = JSON.parse(readFileSync(reqPath, "utf8"));
          unlinkSync(reqPath);
          const tmpRes = path.join(outDir, `.${req.id}.tmp`);
          const resPath = path.join(outDir, `${req.id}.res.json`);
          writeFileSync(
            tmpRes,
            JSON.stringify({
              id: req.id,
              ok: true,
              results: [{ cmd: req.cmd, ok: true, text: "pong", data: { alive: true } }],
              text: "pong",
              ms: 2,
              quitting: false,
            }),
            "utf8",
          );
          renameSync(tmpRes, resPath);
        }
      }, 10);

      const reply = await sendMailboxRequest(tmp, "inspect state", { timeoutMs: 5000 });
      assert.equal(reply.ok, true);
      assert.equal(reply.text, "pong");
      assert.equal(reply.quitting, false);
      assert.equal(reply.results[0].cmd, "inspect state");
      assert.equal(readdirSync(outDir).length, 0);
    } finally {
      if (poller) clearInterval(poller);
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("cleans stale ready.json when PID is dead and keeps it when alive", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-stale-test-"));
    try {
      const readyPath = path.join(tmp, "ready.json");
      writeFileSync(readyPath, JSON.stringify({ pid: 999999, ready: true }), "utf8");

      const aliveCheck = cleanStaleReady(tmp, { isAlive: () => true });
      assert.equal(aliveCheck.alive, true);
      assert.equal(aliveCheck.cleaned, false);
      assert.ok(existsSync(readyPath));

      const deadCheck = cleanStaleReady(tmp, { isAlive: () => false });
      assert.equal(deadCheck.alive, false);
      assert.equal(deadCheck.cleaned, true);
      assert.equal(deadCheck.stalePid, 999999);
      assert.ok(!existsSync(readyPath));
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("RECIPES, DEV_FLAGS, buildUserArgs, and parseArgs", () => {
  it("defines all 11 built-in recipes with proper headless/drawn defaults and pick 1", () => {
    const expected = {
      smoke: "headless",
      "combat-probe": "headless",
      "boss-retry-probe": "headless",
      "look-sheet": "drawn",
      "cam-sheet": "drawn",
      "quality-pair": "drawn",
      "overlay-check": "drawn",
      "perf-budget": "drawn",
      "world1-prim-census": "headless",
      "full-alpha-prim-census": "headless",
      "visual-qa-pack": "drawn",
    };
    assert.deepEqual(Object.keys(RECIPES).sort(), Object.keys(expected).sort());
    for (const [name, expectedMode] of Object.entries(expected)) {
      const recipe = RECIPES[name];
      assert.equal(recipe.mode, expectedMode, `recipe ${name} mode`);
      assert.match(recipe.script, /\brun 1\b/, `recipe ${name} starts run`);
      assert.match(recipe.script, /\bpick 1\b/, `recipe ${name} picks start card`);
      assert.match(recipe.script, /\bquit\b/, `recipe ${name} quits cleanly`);
    }
    assert.match(RECIPES["world1-prim-census"].script, /inspect prims greybox/);
    assert.match(RECIPES["world1-prim-census"].script, /stage flume/);
    assert.match(RECIPES["world1-prim-census"].script, /\bboss\b/);
    for (const token of [
      "stage flume",
      "stage pit",
      "stage sinkhole",
      "stage islands",
      "stage crown",
    ]) {
      assert.ok(
        RECIPES["full-alpha-prim-census"].script.includes(token),
        `full-alpha-prim-census missing ${token}`,
      );
    }
    assert.equal(
      (RECIPES["full-alpha-prim-census"].script.match(/inspect prims greybox/g) ?? []).length,
      9,
    );
    assert.match(RECIPES["perf-budget"].script, /inspect perf 30/);
    assert.match(RECIPES["visual-qa-pack"].script, /qa_pack/);
  });

  it("exports DEV_FLAGS for sketch-lint L3 and builds valid user args", () => {
    for (const flag of [
      "dev-run",
      "dev-file",
      "dev-out",
      "dev-inbox",
      "dev-idle",
      "route-seed",
      "table",
      "no-intro",
    ]) {
      assert.ok(DEV_FLAGS.includes(flag), `DEV_FLAGS missing ${flag}`);
    }
    const args = buildUserArgs({
      table: "park",
      seed: 42,
      devOut: "/tmp/out",
      devFile: "/tmp/script.dev",
    });
    assert.deepEqual(args, [
      "--dev",
      "--no-intro",
      "--table=park",
      "--route-seed=42",
      "--dev-out=/tmp/out",
      "--dev-file=/tmp/script.dev",
    ]);
    assert.throws(() => buildUserArgs({ table: "bogus" }), /Invalid --table/);
  });

  it("parses subcommands, leading --ref flags, recipe shorthand, and rejects conflicting mode flags", () => {
    const parsed = parseArgs([
      "run",
      "calm on; quit",
      "--table",
      "park",
      "--seed",
      "7",
      "--size",
      "1280x720",
      "--timeout",
      "15000",
      "--json",
    ]);
    assert.equal(parsed.command, "run");
    assert.deepEqual(parsed.positionals, ["calm on; quit"]);
    assert.equal(parsed.flags.mode, null);
    assert.equal(parsed.flags.table, "park");
    assert.equal(parsed.flags.seed, 7);
    assert.equal(parsed.flags.size, "1280x720");
    assert.equal(parsed.flags.timeout, 15000);
    assert.equal(parsed.flags.json, true);

    const shorthand = parseArgs(["--ref", "60f1c1474", "--slot", "qa1", "smoke", "--json"]);
    assert.equal(shorthand.command, "recipe");
    assert.deepEqual(shorthand.positionals, ["smoke"]);
    assert.equal(shorthand.flags.ref, "60f1c1474");
    assert.equal(shorthand.flags.slot, "qa1");
    assert.equal(shorthand.flags.json, true);

    const qaPack = parseArgs(["visual-qa-pack", "/tmp/a.png", "--out", "/tmp/out", "--json"]);
    assert.equal(qaPack.command, "visual-qa-pack");
    assert.deepEqual(qaPack.positionals, ["/tmp/a.png"]);
    assert.equal(qaPack.flags.out, "/tmp/out");

    const audit = parseArgs(["ledger-audit", "--strict", "--json"]);
    assert.equal(audit.command, "ledger-audit");
    assert.equal(audit.flags.strict, true);
    assert.equal(audit.flags.json, true);

    assert.throws(() => parseArgs(["run", "quit", "--headless", "--drawn"]), /Conflicting mode/);
    assert.throws(() => parseArgs(["bogus"]), /Unknown command/);
    assert.throws(() => parseArgs(["serve", "--session", "../escape"]), /Invalid session name/);
    assert.throws(() => parseArgs(["run", "quit", "--size", "wide"]), /Invalid --size/);
    assert.throws(() => parseArgs(["--ref"]), /--ref requires/);
  });
});

describe("visual-qa-pack 4-oracle deterministic transforms", () => {
  it("computes Rec.709 luminance greyscale and Machado deuteranopia preserving neutral greys", () => {
    const rgb = new Uint8Array([255, 0, 0, 0, 255, 0, 0, 0, 255, 128, 128, 128]);
    const grey = toRec709GreyscaleRgb(rgb);
    assert.equal(grey[0], grey[1]);
    assert.equal(grey[1], grey[2]);
    assert.ok(grey[3] > grey[0], "green must have higher Rec.709 luminance than red");
    assert.ok(grey[0] > grey[6], "red must have higher Rec.709 luminance than blue");
    assert.ok(Math.abs(grey[9] - 128) <= 1, "neutral grey must stay neutral");

    const cvd = toMachadoDeuteranopiaRgb(rgb);
    assert.ok(
      Math.abs(cvd[9] - 128) <= 1 && Math.abs(cvd[10] - 128) <= 1 && Math.abs(cvd[11] - 128) <= 1,
    );
    assert.ok(
      cvd[3] > 200 && cvd[4] > 180,
      "pure green shifts toward warm ochre under deuteranopia",
    );
  });

  it("emits all 4 oracle PNGs and manifest from a PNG file without Python/PIL", () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "scrapkeep-qa-pack-test-"));
    try {
      const srcW = 16;
      const srcH = 9;
      const pixels = new Uint8Array(srcW * srcH * 3);
      for (let i = 0; i < srcW * srcH; i++) {
        pixels[i * 3] = (i * 19) & 0xff;
        pixels[i * 3 + 1] = (i * 37 + 40) & 0xff;
        pixels[i * 3 + 2] = (i * 53 + 80) & 0xff;
      }
      const inPath = path.join(tmp, "sample.png");
      writeFileSync(inPath, encodeRgbPng(srcW, srcH, pixels));
      const outDir = path.join(tmp, "pack");
      const res = buildVisualQaPack(inPath, { outDir });

      assert.equal(res.source_width, 16);
      assert.equal(res.source_height, 9);
      assert.ok(existsSync(res.manifest_path));
      for (const [key, expectedSize] of [
        ["rgb_1080p", [1920, 1080]],
        ["downscale_720p", [1280, 720]],
        ["greyscale_rec709", [1280, 720]],
        ["cvd_deuteranopia_machado", [1280, 720]],
      ]) {
        const oracle = res.oracles[key];
        assert.ok(oracle && existsSync(oracle.path), `missing oracle ${key}`);
        const decoded = decodePng(readFileSync(oracle.path));
        assert.equal(decoded.width, expectedSize[0], `${key} width`);
        assert.equal(decoded.height, expectedSize[1], `${key} height`);
      }
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("formatPerfSummaryLine", () => {
  it("formats n, min, median, p95, quality preset, rendering driver, and top limiter", () => {
    const line = formatPerfSummaryLine({
      n: 30,
      quality_preset: "high",
      rendering_driver: "metal",
      fps: 60.0,
      frame_ms: 16.6,
      spread: {
        fps: { min: 57.5, median: 60.0, p95: 60.0 },
        frame_ms: { min: 16.4, median: 16.6, p95: 17.4 },
      },
      limiter: { note: "draw_calls (p95=420 / budget=500, 84.0%)" },
    });
    assert.match(line, /n=30/);
    assert.match(line, /preset=high/);
    assert.match(line, /driver=metal/);
    assert.match(line, /min=57\.5/);
    assert.match(line, /med=60/);
    assert.match(line, /p95=17\.4/);
    assert.match(line, /limiter=draw_calls/);
  });
});

describe("formatCensusSummaryLine and summarizeOwnerHotspots", () => {
  it("ranks PrimitiveMesh and flat StandardMaterial3D hotspots by owner", () => {
    const hotspots = summarizeOwnerHotspots([
      { owner_script: "res://src/world/a.gd", count: 3, total_footprint_m2: 10 },
      { owner_script: "res://src/world/a.gd", count: 4, total_footprint_m2: 20 },
      { owner_scene: "res://assets/b.glb", owner_script: "", count: 5, total_footprint_m2: 12 },
    ]);
    assert.equal(hotspots[0].owner, "src/world/a.gd");
    assert.equal(hotspots[0].count, 7);
    assert.equal(hotspots[1].owner, "assets/b.glb");

    const line = formatCensusSummaryLine({
      map: "park_pit",
      count: 12,
      ranked: [
        { owner_script: "res://src/world/a.gd", count: 7, total_footprint_m2: 30 },
        { owner_script: "res://src/world/b.gd", count: 5, total_footprint_m2: 15 },
      ],
      flat_materials: {
        count: 9,
        ranked: [{ owner_script: "res://src/world/a.gd", count: 9, total_footprint_m2: 40 }],
      },
      skeletons: { count: 1 },
    });
    assert.match(line, /census\[park_pit\]: prims=12 flat_mats=9 skeletons=1/);
    assert.match(line, /top_prim=\[src\/world\/a\.gd\(7\), src\/world\/b\.gd\(5\)\]/);
    assert.match(line, /top_flat=\[src\/world\/a\.gd\(9\)\]/);
  });
});
