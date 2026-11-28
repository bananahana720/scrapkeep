import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const sketch = fileURLToPath(new URL("../sketches/core-loop/", import.meta.url));

test("palette: park prop kit derives BANNED, WARN, BRASS_HEX and palette-matching C entries from palette_gd without literals", () => {
  const script = `
import ast, sys
sys.path.insert(0, "tools")
import palette_gd

tree = ast.parse(open("tools/blender/park/props/kit.py", encoding="utf-8").read())
assigns = {}
for node in tree.body:
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id in ("C", "BANNED", "WARN", "BRASS_HEX"):
                assigns[target.id] = node

def is_palette_lookup(expr):
    return (
        isinstance(expr, ast.Subscript)
        and isinstance(expr.value, ast.Attribute)
        and isinstance(expr.value.value, ast.Name)
        and expr.value.value.id == "palette_gd"
        and expr.value.attr == "HEX"
    )

palette_values = set(palette_gd.HEX.values())

for set_name in ("BANNED", "WARN"):
    val = assigns[set_name].value
    assert isinstance(val, ast.Set), f"{set_name} must be a set literal"
    for elt in val.elts:
        assert is_palette_lookup(elt), f"{set_name} entry must read palette_gd.HEX, got {ast.dump(elt)}"

assert is_palette_lookup(assigns["BRASS_HEX"].value), f"BRASS_HEX must read palette_gd.HEX, got {ast.dump(assigns['BRASS_HEX'].value)}"

c_val = assigns["C"].value
assert isinstance(c_val, ast.Dict), "C must be a dict literal"
for k_node, v_node in zip(c_val.keys, c_val.values):
    key = ast.literal_eval(k_node)
    if isinstance(v_node, ast.Constant) and isinstance(v_node.value, str):
        assert v_node.value.lower() not in palette_values, (
            f"C[{key!r}] uses literal {v_node.value!r} matching palette.gd; read from palette_gd.HEX"
        )
    else:
        assert is_palette_lookup(v_node), f"C[{key!r}] must be a literal or palette_gd.HEX lookup"

ns = {"palette_gd": palette_gd}
for name in ("C", "BANNED", "WARN", "BRASS_HEX"):
    exec(compile(ast.Module(body=[assigns[name]], type_ignores=[]), "kit.py", "exec"), ns)

assert ns["BANNED"] == {palette_gd.HEX["HAZARD"], palette_gd.HEX["ANCIENT"], palette_gd.HEX["ARC"]}, ns["BANNED"]
assert ns["WARN"] == {palette_gd.HEX["AMBER"], palette_gd.HEX["COPPER"], palette_gd.HEX["BRASS"]}, ns["WARN"]
assert ns["BRASS_HEX"] == palette_gd.HEX["BRASS"], ns["BRASS_HEX"]
for key, const in (("sandstone", "SANDSTONE"), ("cable", "CABLE"), ("charcoal", "CHARCOAL"), ("bone", "SAND")):
    assert ns["C"][key] == palette_gd.HEX[const], (key, ns["C"][key], palette_gd.HEX[const])
print("kit.py palette: PASS")
`;
  const result = spawnSync("python3", ["-c", script], { cwd: sketch, encoding: "utf8" });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
