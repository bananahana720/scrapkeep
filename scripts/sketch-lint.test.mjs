import assert from "node:assert/strict";
import test from "node:test";
import {
  applyBaseline,
  baselineFrom,
  formatFinding,
  lintL1,
  lintL2,
  lintL3,
  lintL4,
  lintL5,
  lintL6,
  lintL6Owners,
  lintL7,
  lintL8,
  lintL9,
  lintL10,
  parseTuning,
} from "./sketch-lint.mjs";

test("L7 flags a game file that loads from tools/, and passes src paths and comments", () => {
  assert.equal(lintL7("a.gd", 'const P := preload("res://tools/park_graph.gd")\nvar s = load("res://tools/x.gd")\n').length, 2);
  assert.deepEqual(lintL7("a.gd", 'const P := preload("res://src/world/park/park_placement.gd")\n# was res://tools/park_graph.gd\n'), []);
});

test("L7 allows only the guarded --self-play load in src/game.gd", () => {
  const line = 'const SELF_PLAY := "res://tools/self_play.gd"\n';
  const guard = "if not ResourceLoader.exists(script_path):\n";
  assert.deepEqual(lintL7("sketches/core-loop/src/game.gd", line + guard), []);
  assert.equal(lintL7("sketches/core-loop/src/game.gd", line).length, 1);
  assert.equal(lintL7("sketches/core-loop/src/other.gd", line + guard).length, 1);
  assert.equal(lintL7("sketches/core-loop/src/game.gd", line + guard + 'var x = load("res://tools/bot_driver.gd")\n').length, 1);
  assert.equal(lintL7("sketches/core-loop/src/game.gd", 'const SELF_PLAY := "res://tools/other.gd"\n' + guard).length, 1);
});

test("L8 flags a tick-rate ball read in drawing code and passes the drawn read, the sim and comments", () => {
  const bad = lintL8("x/vfx.gd", "src/presentation/vfx.gd", "func _process(_d):\n\t_roll.global_position = player.ball_position()\n\tvar at = ctx.player.shown_position()\n", {});
  assert.deepEqual(bad.map((item) => `${item.rule} ${item.line}`), ["L8 2"]);
  assert.equal(lintL8("x/hud.gd", "src/ui/hud.gd", "var d = game.player.ball_position().distance_to(at)\n", {}).length, 1);
  assert.deepEqual(lintL8("x/vfx.gd", "src/presentation/vfx.gd", "var at = player.shown_position()\n# ball_position() is the tick's\n", {}), []);
  assert.deepEqual(lintL8("x/combat.gd", "src/combat/combat.gd", "var at = player.ball_position()\n", {}), []);
});

test("L8 counts every mention as a read, however the call is spelled, and passes a has_method guard", () => {
  const spelled = [
    "var at = player.ball_position ()\n",
    "var at = player.ball_position( )\n",
    'var at = player.call("ball_position")\n',
    'var ask := Callable(player, "ball_position")\n',
    "var at = player.ball_position.call()\n",
    "var at = ball_position()\n",
    "var at = player \\\n\t.ball_position()\n",
  ];
  for (const text of spelled) assert.equal(lintL8("x/vfx.gd", "src/presentation/vfx.gd", text, {}).length, 1, text);
  const twice = lintL8("x/vfx.gd", "src/presentation/vfx.gd", "var d = a.ball_position().distance_to(b.ball_position())\n", {});
  assert.deepEqual(twice.map((item) => item.line), [1, 1]);
  assert.deepEqual(lintL8("x/vfx.gd", "src/presentation/vfx.gd", 'if target.has_method("ball_position"):\n\tpass\n', {}), []);
  for (const text of ["var at = ctx.player.body().global_position\n", "fx(game.player.active_body().global_position)\n", "var t = player.body().global_transform\n"]) {
    assert.equal(lintL8("x/hud.gd", "src/ui/hud.gd", text, {}).length, 1, text);
  }
  assert.deepEqual(lintL8("x/vfx.gd", "src/presentation/vfx.gd", "var v = ctx.player.body().linear_velocity\nvar at = enemy.global_position\n", {}), []);
});

test("L9 flags the player node's own place and passes the ball's, a guarded fallback and other nodes", () => {
  const asked = [
    "if player.global_position.distance_to(at) <= REACH:\n",
    "var feet := ctx.player.global_position\n",
    "var at = game.ctx.player.global_transform.origin\n",
    "var d = _player.position.distance_to(at)\n",
    "var at = game.player . global_position\n",
  ];
  for (const text of asked) assert.deepEqual(lintL9("x/cache.gd", text).map((item) => `${item.rule} ${item.line}`), ["L9 1"], text);
  const passes = [
    "var at = player.ball_position()\n",
    "var at = ctx.player.shown_position()\n",
    'var ball: Vector3 = player.ball_position() if player.has_method("ball_position") else player.global_position\n',
    'return _player.shown_position() if _player.has_method("shown_position") else _player.global_position\n',
    "var at = ctx.player.body().global_position\n",
    "var at = enemy.global_position\n",
    "var at = multiplayer.global_position\n",
    "# player.global_position is the origin\n",
  ];
  for (const text of passes) assert.deepEqual(lintL9("x/cache.gd", text), [], text);
});

test("L10 flags a write to the ball's body, passes reads and other bodies, and holds the listed count", () => {
  const moved = [
    "ctx.player.body().global_position = at\n",
    "player.body().global_position.y = floor + 1.0\n",
    "game.player.active_body().global_transform.origin = at\n",
    "ctx.player.body() . position += push\n",
    "player.body().transform = Transform3D(Basis.IDENTITY, at)\n",
    "_rigid.global_position = spawn_point\n",
    "_rigid.position = spawn_point\n",
    "_ball_body().global_position = at\n",
    "ctx.player.body().set_global_position(at)\n",
    "player.body().global_translate(push)\n",
    "_rigid.translate(push)\n",
  ];
  for (const text of moved) assert.deepEqual(lintL10("x/flow.gd", "src/core/flow.gd", text, {}).map((item) => `${item.rule} ${item.line}`), ["L10 1"], text);
  const passes = [
    "ctx.player.reset_to(at, velocity)\n",
    "var at = ctx.player.body().global_position\n",
    "if ctx.player.body().global_position == at:\n\tpass\n",
    "enemy.global_position = at\n",
    "return _rigid.global_position\n",
    "var at := _ball_body().global_position\n",
    "pin_body().global_position = at\n",
    "ctx.player.body().set_collision_layer_value(2, false)\n",
    "# ctx.player.body().global_position = at\n",
  ];
  for (const text of passes) assert.deepEqual(lintL10("x/flow.gd", "src/core/flow.gd", text, {}), [], text);
  const listed = { "src/combat/kit.gd": { sites: 1, why: "a flight leg" } };
  const one = "ctx.player.body().global_position = at\n";
  assert.deepEqual(lintL10("x/kit.gd", "src/combat/kit.gd", one, listed), []);
  assert.deepEqual(lintL10("x/kit.gd", "src/combat/kit.gd", one + one, listed).map((item) => item.line), [1, 2]);
  assert.match(lintL10("x/kit.gd", "src/combat/kit.gd", "var at = 1\n", listed)[0].message, /remove the entry/);
});

test("L8 passes a listed sim read, and flags a drifted count and a stale entry", () => {
  const allowed = { "src/presentation/hero_assets.gd": { sites: 1, why: "sight target" } };
  const lens = "var dir = target.ball_position() - origin\n";
  assert.deepEqual(lintL8("x/hero_assets.gd", "src/presentation/hero_assets.gd", lens, allowed), []);
  const drift = lintL8("x/hero_assets.gd", "src/presentation/hero_assets.gd", lens + "var at = player.ball_position()\n", allowed);
  assert.deepEqual(drift.map((item) => item.line), [1, 2]);
  assert.equal(drift[0].message.includes("SIM_READS lists 1"), true);
  const stale = lintL8("x/hero_assets.gd", "src/presentation/hero_assets.gd", "var at = player.shown_position()\n", allowed);
  assert.deepEqual(stale.map((item) => `${item.rule} ${item.line}`), ["L8 1"]);
});

const tuningText = `
const ROWS := [
	{"key": "scrap_mode", "label": "Scrap"},
	{"key": "harpoon", "label": "Harpoon"},
]
const FLAGS := {
	"scrap": ["scrap_mode", "option", "start"],
	"harpoon-pull": ["harpoon_pull", "option", "launch"],
}
`;
const tuning = parseTuning(tuningText);

test("L1 flags a wall-clock read and passes a frame-stepped test", () => {
  const bad = lintL1("t.gd", "func x():\n\tvar a := Time.get_ticks_msec()\n\tawait create_timer(1.0).timeout\n");
  assert.deepEqual(bad.map((item) => item.line), [2, 3]);
  assert.equal(formatFinding(bad[0]).startsWith("L1 t.gd:2 "), true);
  assert.deepEqual(lintL1("t.gd", "func x():\n\tawait process_frame\n\t# Time.get_ticks_msec is banned\n"), []);
});

test("L2 flags a raw write and passes a read", () => {
  assert.equal(lintL2("a.gd", 'var f := FileAccess.open(p, FileAccess.WRITE)\nf.store_string("x")\n').length, 2);
  assert.equal(lintL2("a.gd", 'var f := FileAccess.open(p, FileAccess.READ)\nvar s := f.get_as_text()\n').length, 0);
});

test("L3 flags a dangling flag and a dangling tuning key, and passes real ones", () => {
  const bad = lintL3([{ path: "t.gd", text: 'args = ["--wrong=1"]\nt.set_option("nope", "x")\n' }], tuning);
  assert.equal(bad.length, 2);
  const good = lintL3([{ path: "t.gd", text: 'args = ["--scrap=armor", "--harpoon-pull=on"]\nt.set_option("scrap_mode", "x")\n' }], tuning);
  assert.deepEqual(good, []);
});

test("L3 lets a flag some file parses stand, and skips comments", () => {
  const files = [
    { path: "run.gd", text: 'if arg.begins_with("--out="):\n\tpass\n' },
    { path: "t.gd", text: 'args = ["--out=x"]\n# --ghost=1\n' },
  ];
  assert.deepEqual(lintL3(files, tuning), []);
});

test("L3 lets a flag a Python tool parses for itself stand", () => {
  const files = [{ path: "render.py", text: "tag = next(v for v in sys.argv if v.startswith('--render-tag='))\n" }];
  assert.deepEqual(lintL3(files, tuning), []);
});

test("L3 fails loudly when tuning.gd parses to no flags or no keys", () => {
  assert.throws(() => parseTuning("const FLAGS := {\n}\n"), /cannot check flags/);
  assert.throws(() => parseTuning('{"key": "a"}\n'), /0 FLAGS names/);
  assert.deepEqual([...tuning.flags], ["scrap", "harpoon-pull"]);
  assert.deepEqual([...tuning.keys], ["scrap_mode", "harpoon"]);
});

test("L4 flags stray files under tests/ and a unit file that is not a case", () => {
  const bad = lintL4([
    { rel: "run.sh", dir: false },
    { rel: "mystery", dir: true },
    { rel: "unit/helper.gd", dir: false },
  ]);
  assert.equal(bad.length, 3);
  const good = lintL4([
    { rel: "a_test.gd", dir: false },
    { rel: "a_test.gd.uid", dir: false },
    { rel: "QUARANTINE.tsv", dir: false },
    { rel: "unit", dir: true },
    { rel: "unit/x_case.gd", dir: false },
    { rel: "unit/x_case.gd.uid", dir: false },
    { rel: "support/t.gd", dir: false },
  ]);
  assert.deepEqual(good, []);
});

const header = "test\towner\treason\tadded\tdeadline";
const row = (name) => `${name}\tO1\treason\t2026-10-01\twave 3`;

test("L5 passes a well-formed file", () => {
  assert.deepEqual(lintL5([header, row("a_test"), row("b_test")].join("\n") + "\n", new Set(["a_test", "b_test"])), []);
});

test("L5 fails on four entries, a missing test, a duplicate, a bad header and a short row", () => {
  const names = ["a", "b", "c", "d"].map((name) => `${name}_test`);
  const exists = new Set(names);
  assert.match(lintL5([header, ...names.map(row)].join("\n"), exists)[0].message, /4 entries/);
  assert.match(lintL5([header, row("gone_test")].join("\n"), exists)[0].message, /not an existing top-level test/);
  assert.match(lintL5([header, row("a_test"), row("a_test")].join("\n"), exists)[0].message, /listed twice/);
  assert.match(lintL5("test\towner\n", exists)[0].message, /header/);
  assert.match(lintL5([header, "a_test\tO1"].join("\n"), exists)[0].message, /needs test, owner/);
});

test("the baseline silences listed offenders and shrinks only", () => {
  const findings = [
    { rule: "L1", path: "a.gd", line: 3, message: "m" },
    { rule: "L1", path: "new.gd", line: 1, message: "m" },
  ];
  const baseline = { L1: ["a.gd", "fixed.gd", "gone.gd"], L2: [], L3: [], L4: [] };
  const out = applyBaseline(findings, baseline, (file) => file !== "gone.gd");
  assert.deepEqual(out.map((item) => `${item.rule} ${item.path}`), ["L1 new.gd", "BASELINE fixed.gd", "BASELINE gone.gd"]);
  assert.match(out[1].message, /remove from baseline/);
  assert.match(out[2].message, /file is gone/);
  assert.deepEqual(applyBaseline([{ rule: "L5", path: "q", line: 1, message: "m" }], { L5: ["q"] }, () => true).length, 1);
  assert.deepEqual(baselineFrom(findings), { L1: ["a.gd", "new.gd"], L2: [], L3: [], L4: [] });
});

const wardenDress = (light) => `func _dress_warden(warden) -> void:
\tvar base := _warden_scene(WARDEN_BASE)
\twarden.add_child(base)
${light ? "\tvar cool := OmniLight3D.new()\n\tbase.add_child(cool)\n" : "\t# OmniLight3D.new() would be freed with the Warden\n"}`;
const owners = { "src/presentation/hero_assets.gd": { sites: 1, owner: "MossBay barge, session-lived" } };

test("L6 flags a Light3D created under a stage-freed node in an unlisted file", () => {
  const bad = lintL6("sketches/s/src/combat/warden_dress.gd", "src/combat/warden_dress.gd", wardenDress(true), owners);
  assert.deepEqual(bad.map((item) => `${item.rule} ${item.line}`), ["L6 4"]);
  assert.match(bad[0].message, /does not list/);
});

test("L6 flags a new light in a listed file whose site count drifts", () => {
  const text = "var lamp := OmniLight3D.new()\nbarge.add_child(lamp)\n" + wardenDress(true);
  const bad = lintL6("x/hero_assets.gd", "src/presentation/hero_assets.gd", text, owners);
  assert.equal(bad.length, 2);
  assert.match(bad[0].message, /2 runtime Light3D sites, LIGHT_OWNERS lists 1/);
});

test("L6 passes a listed owner, a lightless dress and a commented light", () => {
  const listed = lintL6("x/hero_assets.gd", "src/presentation/hero_assets.gd", "var lamp := OmniLight3D.new()\nbarge.add_child(lamp)\n" + wardenDress(false), owners);
  assert.deepEqual(listed, []);
  assert.deepEqual(lintL6("x/w.gd", "src/combat/warden_dress.gd", wardenDress(false), owners), []);
  assert.deepEqual(lintL6("x/s.gd", "src/a.gd", "var s := DirectionalLight3D\nvar m := MeshInstance3D.new()\n", owners), []);
});

test("L6 flags a stale owner entry", () => {
  assert.deepEqual(lintL6Owners(new Set(["src/presentation/hero_assets.gd"]), "s", owners), []);
  const stale = lintL6Owners(new Set(), "s", owners);
  assert.equal(stale.length, 1);
  assert.match(stale[0].message, /remove the entry/);
});
