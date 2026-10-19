import assert from "node:assert/strict";
import test from "node:test";
import { isSplash, parsePixel, summarize } from "./splash-probe.mjs";

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
