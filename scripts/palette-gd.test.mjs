import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

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
  writeFileSync(
    planted,
    readFileSync(path.join(sketch, "tools/blender/common.py"), "utf8").replace(
      '"bone": "d2c5a5"',
      '"bone": "d2c5a6"',
    ),
  );
  const result = run("tools/palette_gd.py", "--check", planted);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /bone: common.py d2c5a6, palette.gd d2c5a5/);
});

test("palette: the icon generator, reading palette.gd, still draws the committed icons", () => {
  const result = run("tools/icons/generate_icons.py", "--check");
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test("palette: park prop kit derives BANNED, WARN, BRASS_HEX and shared C entries from palette_gd", () => {
  const script = `
import ast, sys
sys.path.insert(0, "tools")
import palette_gd
tree = ast.parse(open("tools/blender/park/props/kit.py", encoding="utf-8").read())
ns = {"palette_gd": palette_gd}
for node in tree.body:
    if isinstance(node, ast.Assign):
        names = [t.id for t in node.targets if isinstance(t, ast.Name)]
        if any(n in ("C", "BANNED", "WARN", "BRASS_HEX") for n in names):
            exec(compile(ast.Module(body=[node], type_ignores=[]), "kit.py", "exec"), ns)
assert ns["BANNED"] == {palette_gd.HEX["HAZARD"], palette_gd.HEX["ANCIENT"], palette_gd.HEX["ARC"]}, ns["BANNED"]
assert ns["WARN"] == {palette_gd.HEX["AMBER"], palette_gd.HEX["COPPER"], palette_gd.HEX["BRASS"]}, ns["WARN"]
assert ns["BRASS_HEX"] == palette_gd.HEX["BRASS"], ns["BRASS_HEX"]
for key, const in (("sandstone", "SANDSTONE"), ("cable", "CABLE"), ("charcoal", "CHARCOAL"), ("bone", "SAND")):
    assert ns["C"][key] == palette_gd.HEX[const], (key, ns["C"][key], palette_gd.HEX[const])
print("kit.py palette: PASS")
`;
  const result = run("-c", script);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
