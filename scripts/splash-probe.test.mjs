import assert from "node:assert/strict";
import test from "node:test";
import { isSplash, parseArgs, parsePixel, summarize } from "./splash-probe.mjs";

test("parsePixel reads ImageMagick pixel text", () => {
  assert.deepEqual(parsePixel("srgb(36,42,40)\n"), [36, 42, 40]);
  assert.deepEqual(parsePixel("gray(0)"), [0, 0, 0]);
  assert.equal(parsePixel("nonsense"), null);
});

test("isSplash matches only the boot splash colour", () => {
  assert.equal(isSplash([36, 42, 40]), true);
  assert.equal(isSplash([245, 228, 210]), false);
  assert.equal(isSplash(null), false);
});

test("summarize reports the first splash frame", () => {
  const rows = [{ at: 0.1, rgb: [0, 0, 0] }, { at: 0.3, rgb: [36, 42, 40] }];
  assert.deepEqual(summarize(rows), { seen: true, firstAt: 0.3 });
  assert.deepEqual(summarize(rows.slice(0, 1)), { seen: false, firstAt: null });
});

test("parseArgs reads a valid set", () => {
  assert.deepEqual(parseArgs(["--display=:97", "--godot=/bin/godot", "--times=0,0.5,2", "--out=x"]), {
    display: ":97", godot: "/bin/godot", times: [0, 0.5, 2], out: "x",
  });
  assert.deepEqual(parseArgs(["--display=:1", "--godot=g"]).times, [0.1, 0.3, 0.6, 1]);
});

test("parseArgs rejects unknown flags and missing required ones", () => {
  assert.throws(() => parseArgs(["--display=:1", "--godot=g", "--bogus"]), /unknown argument/);
  assert.throws(() => parseArgs(["--display=:1"]), /--godot/);
  assert.throws(() => parseArgs(["--godot=g"]), /--display/);
});

test("parseArgs rejects bad --times entries", () => {
  const base = ["--display=:1", "--godot=g"];
  assert.throws(() => parseArgs([...base, "--times=abc"]), /--times/);
  assert.throws(() => parseArgs([...base, "--times=-1"]), /--times/);
  assert.throws(() => parseArgs([...base, "--times=0.1,,1"]), /--times/);
  assert.throws(() => parseArgs([...base, "--times=Infinity"]), /--times/);
});
