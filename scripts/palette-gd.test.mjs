import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

// SG-15: recipes read src/core/palette.gd (tools/palette_gd.py). The Blender kit's HEX table stays a literal mirror
// for the asset forge, so this holds it to palette.gd, and the icon generator to its committed icons.
const sketch = fileURLToPath(new URL("../sketches/core-loop/", import.meta.url));
const run = (...args) => spawnSync("python3", args, { cwd: sketch, encoding: "utf8" });

test("palette: common.py's HEX mirror matches palette.gd", () => {
  const result = run("tools/palette_gd.py", "--check");
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test("palette: a drifted mirror entry fails and is named", (t) => {
  const dir = mkdtempSync(path.join(os.tmpdir(), "palette-gd-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const planted = path.join(dir, "common.py");
  writeFileSync(planted, readFileSync(path.join(sketch, "tools/blender/common.py"), "utf8").replace('"bone": "d2c5a5"', '"bone": "d2c5a6"'));
  const result = run("tools/palette_gd.py", "--check", planted);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /bone: common.py d2c5a6, palette.gd d2c5a5/);
});

test("palette: the icon generator, reading palette.gd, still draws the committed icons", () => {
  const result = run("tools/icons/generate_icons.py", "--check");
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
