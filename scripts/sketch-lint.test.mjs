import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import "./lib/cli.test.mjs";
import { cwdDecidesRepository } from "./lib/git.mjs";
import "./lib/game-defs.test.mjs";
import "./lib/git.test.mjs";
import "./lib/walk.test.mjs";
import {
  BASELINE_RULES,
  FAULT_SWITCHES,
  L13_ALLOWED,
  applyBaseline,
  baselineFrom,
  baselineGrowth,
  buildScriptGraph,
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
  lintL11,
  lintL12,
  lintL13,
  lintL14,
  lintL15,
  lintL16,
  lintL17,
  lintL18,
  lintPreloadedTestSupport,
  lintSketch,
  lintTrackedUids,
  parseBatchDriverRefs,
  parseBatchDriverVars,
  parseLintArgs,
  parseTuning,
  preloadedTestSupportFiles,
  readBaselineAt,
  stronglyConnectedComponents,
} from "./sketch-lint.mjs";
import {
  SOURCES,
  lintFile,
  lintS8,
  lintS8Text,
  lintString,
  lintWords,
  parseBoundKeys,
  parseNames,
  readRows,
  readUi,
} from "./sketch-lint-words.mjs";

test("L7 flags a game file that loads from tools/, and passes src paths and comments", () => {
  assert.equal(
    lintL7(
      "a.gd",
      'const P := preload("res://tools/park_graph.gd")\nvar s = load("res://tools/x.gd")\n',
    ).length,
    2,
  );
  assert.deepEqual(
    lintL7(
      "a.gd",
      'const P := preload("res://src/world/park/park_placement.gd")\n# was res://tools/park_graph.gd\n',
    ),
    [],
  );
});

test("L7 allows only the guarded --self-play load in src/game.gd", () => {
  const line = 'const SELF_PLAY := "res://tools/self_play.gd"\n';
  const guard = "if not ResourceLoader.exists(script_path):\n";
  assert.deepEqual(lintL7("sketches/core-loop/src/game.gd", line + guard), []);
  assert.equal(lintL7("sketches/core-loop/src/game.gd", line).length, 1);
  assert.equal(lintL7("sketches/core-loop/src/other.gd", line + guard).length, 1);
  assert.equal(
    lintL7(
      "sketches/core-loop/src/game.gd",
      line + guard + 'var x = load("res://tools/bot_driver.gd")\n',
    ).length,
    1,
  );
  assert.equal(
    lintL7("sketches/core-loop/src/game.gd", 'const SELF_PLAY := "res://tools/other.gd"\n' + guard)
      .length,
    1,
  );
});

test("L8 flags a tick-rate ball read in drawing code and passes the drawn read, the sim and comments", () => {
  const bad = lintL8(
    "x/vfx.gd",
    "src/presentation/vfx.gd",
    "func _process(_d):\n\t_roll.global_position = player.ball_position()\n\tvar at = ctx.player.shown_position()\n",
    {},
  );
  assert.deepEqual(
    bad.map((item) => `${item.rule} ${item.line}`),
    ["L8 2"],
  );
  assert.equal(
    lintL8("x/hud.gd", "src/ui/hud.gd", "var d = game.player.ball_position().distance_to(at)\n", {})
      .length,
    1,
  );
  assert.deepEqual(
    lintL8(
      "x/vfx.gd",
      "src/presentation/vfx.gd",
      "var at = player.shown_position()\n# ball_position() is the tick's\n",
      {},
    ),
    [],
  );
  assert.deepEqual(
    lintL8("x/combat.gd", "src/combat/combat.gd", "var at = player.ball_position()\n", {}),
    [],
  );
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
  for (const text of spelled)
    assert.equal(lintL8("x/vfx.gd", "src/presentation/vfx.gd", text, {}).length, 1, text);
  const twice = lintL8(
    "x/vfx.gd",
    "src/presentation/vfx.gd",
    "var d = a.ball_position().distance_to(b.ball_position())\n",
    {},
  );
  assert.deepEqual(
    twice.map((item) => item.line),
    [1, 1],
  );
  assert.deepEqual(
    lintL8(
      "x/vfx.gd",
      "src/presentation/vfx.gd",
      'if target.has_method("ball_position"):\n\tpass\n',
      {},
    ),
    [],
  );
  for (const text of [
    "var at = ctx.player.body().global_position\n",
    "fx(game.player.active_body().global_position)\n",
    "var t = player.body().global_transform\n",
  ]) {
    assert.equal(lintL8("x/hud.gd", "src/ui/hud.gd", text, {}).length, 1, text);
  }
  assert.deepEqual(
    lintL8(
      "x/vfx.gd",
      "src/presentation/vfx.gd",
      "var v = ctx.player.body().linear_velocity\nvar at = enemy.global_position\n",
      {},
    ),
    [],
  );
});

test("L9 flags the player node's own place and passes the ball's, a guarded fallback and other nodes", () => {
  const asked = [
    "if player.global_position.distance_to(at) <= REACH:\n",
    "var feet := ctx.player.global_position\n",
    "var at = game.ctx.player.global_transform.origin\n",
    "var d = _player.position.distance_to(at)\n",
    "var at = game.player . global_position\n",
  ];
  for (const text of asked)
    assert.deepEqual(
      lintL9("x/cache.gd", text).map((item) => `${item.rule} ${item.line}`),
      ["L9 1"],
      text,
    );
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
  for (const text of moved)
    assert.deepEqual(
      lintL10("x/flow.gd", "src/core/flow.gd", text, {}).map((item) => `${item.rule} ${item.line}`),
      ["L10 1"],
      text,
    );
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
  for (const text of passes)
    assert.deepEqual(lintL10("x/flow.gd", "src/core/flow.gd", text, {}), [], text);
  const listed = { "src/combat/kit.gd": { sites: 1, why: "a flight leg" } };
  const one = "ctx.player.body().global_position = at\n";
  assert.deepEqual(lintL10("x/kit.gd", "src/combat/kit.gd", one, listed), []);
  assert.deepEqual(
    lintL10("x/kit.gd", "src/combat/kit.gd", one + one, listed).map((item) => item.line),
    [1, 2],
  );
  assert.match(
    lintL10("x/kit.gd", "src/combat/kit.gd", "var at = 1\n", listed)[0].message,
    /remove the entry/,
  );
});

test("L11 flags raw map/pilot ID comparisons outside owning tables and holds legacy counts", () => {
  const planted = [
    'if map_id == "park_dam":\n\tpass\n',
    'if "park_pit" != cur_map:\n\tpass\n',
    'if pilot == "tarn":\n\tpass\n',
    'if class_id in ["pylon_engineer", "tally"]:\n\tpass\n',
  ];
  for (const text of planted) {
    assert.deepEqual(
      lintL11("x/foo.gd", "src/combat/foo.gd", text, {}).map((item) => `${item.rule} ${item.line}`),
      ["L11 1"],
      text,
    );
  }
  const allowedPasses = [
    'if map_id == "park_dam":\n\tpass\n',
    'var row := {"map": "park_dam", "pilot": "tarn"}\n',
    '# if pilot == "tarn":\n',
  ];
  assert.deepEqual(lintL11("x/park_defs.gd", "src/core/park_defs.gd", allowedPasses[0], {}), []);
  assert.deepEqual(lintL11("x/dev_stage.gd", "src/dev/dev_stage.gd", allowedPasses[0], {}), []);
  assert.deepEqual(lintL11("x/foo.gd", "src/combat/foo.gd", allowedPasses[1], {}), []);
  assert.deepEqual(lintL11("x/foo.gd", "src/combat/foo.gd", allowedPasses[2], {}), []);

  const legacy = { "src/combat/foo.gd": { sites: 1, why: "legacy" } };
  const one = 'if pilot == "tarn":\n\tpass\n';
  assert.deepEqual(lintL11("x/foo.gd", "src/combat/foo.gd", one, legacy), []);
  assert.deepEqual(
    lintL11("x/foo.gd", "src/combat/foo.gd", one + one, legacy).map((item) => item.line),
    [1, 3],
  );
  assert.match(
    lintL11("x/foo.gd", "src/combat/foo.gd", "var ok := true\n", legacy)[0].message,
    /remove the entry/,
  );
});

test("L11 flags StringName compares, match arms and ID prefix tests, and leaves table rows alone", () => {
  const planted = [
    ['if pilot == &"tarn":\n\tpass\n', [1]],
    ['if map_id != &"park_dam":\n\tpass\n', [1]],
    ['if &"tally" == pilot:\n\tpass\n', [1]],
    ['if pilot == StringName("tarn"):\n\tpass\n', [1]],
    ['if pilot in [&"rivet", &"tarn"]:\n\tpass\n', [1]],
    ['if pilot == "tarn":\n\tpass\n', [1]],
    ['match pilot_id:\n\t"tarn":\n\t\treturn 1\n\t_:\n\t\treturn 0\n', [2]],
    ['match pilot_id:\n\t&"tarn":\n\t\treturn 1\n', [2]],
    ['match pilot_id:\n\t"rivet", "tarn":\n\t\treturn 1\n', [2]],
    ['match pilot_id:\n\t"tarn": return 1\n\t"tally": return 2\n', [2, 3]],
    [
      'func f():\n\tmatch map_id:\n\t\t"park_dam":\n\t\t\tmatch pilot:\n\t\t\t\t"tally":\n\t\t\t\t\tpass\n',
      [3, 5],
    ],
    ['if map_id.begins_with("park_"):\n\tpass\n', [1]],
    ['if pilot.begins_with(&"tarn"):\n\tpass\n', [1]],
  ];
  for (const [text, lines] of planted) {
    assert.deepEqual(
      lintL11("x/foo.gd", "src/combat/foo.gd", text, {}).map((item) => item.line),
      lines,
      text,
    );
  }
  const passes = [
    'const ROWS := {\n\t"tarn": {"hull": 3},\n\t"tally": 2,\n}\n',
    'match kind:\n\t"chaser":\n\t\tvar row := {\n\t\t\t"tarn": 1,\n\t\t}\n',
    'match kind:\n\t"chaser":\n\t\treturn "tarn"\n',
    'match kind:\n\t"chaser":\n\t\tpass\nvar rows := {\n\t"tarn": 1,\n}\n',
    'var pilot := &"tarn"\n',
    'if part.begins_with("part_"):\n\tpass\n',
    '# match pilot:\n#\t"tarn":\n',
  ];
  for (const text of passes) {
    assert.deepEqual(lintL11("x/foo.gd", "src/combat/foo.gd", text, {}), [], text);
  }
  const arm = 'match pilot_id:\n\t"tarn":\n\t\treturn 1\n';
  assert.deepEqual(lintL11("x/class_def.gd", "src/core/class_def.gd", arm, {}), []);
  const legacy = { "src/combat/foo.gd": { sites: 1, why: "legacy" } };
  assert.deepEqual(lintL11("x/foo.gd", "src/combat/foo.gd", arm, legacy), []);
  assert.deepEqual(
    lintL11("x/foo.gd", "src/combat/foo.gd", arm + 'var b := pilot == &"tarn"\n', legacy).map(
      (item) => item.line,
    ),
    [2, 4],
  );
});

test("L11's baseline table matches the game source, and a planted branch in a listed file fails", () => {
  const baseline = JSON.parse(
    readFileSync(new URL("./sketch-lint.baseline.json", import.meta.url), "utf8"),
  );
  assert.ok(Object.keys(baseline.L11).length > 0);
  for (const [file, sites] of Object.entries(baseline.L11)) {
    const rel = file.replace(/^sketches\/core-loop\//, "");
    const text = readFileSync(path.join(sketchDir, rel), "utf8");
    const raw = lintL11(file, rel, text);
    assert.equal(raw.length, sites, file);
    assert.deepEqual(
      applyBaseline(raw, { L11: { [file]: sites } }, () => true),
      [],
      file,
    );
    for (const plant of [
      '\nfunc _planted(p):\n\tmatch p:\n\t\t"tarn":\n\t\t\tpass\n',
      '\nfunc _planted(p):\n\treturn p == &"tarn"\n',
      '\nfunc _planted(p):\n\treturn p == "tarn"\n',
    ]) {
      const regressed = lintL11(file, rel, text + plant);
      assert.equal(
        applyBaseline(regressed, { L11: { [file]: sites } }, () => true).length,
        sites + 1,
        `${rel} ${plant}`,
      );
    }
  }
});

test("L12 flags a write to a fault switch from game code, and passes reads, the declaration and the home's reset", () => {
  const switches = {
    lead_plant: { home: "src/combat/pack_pressure.gd", why: "a planted lead" },
    _test_pending: { home: "src/core/cosmetics.gd", why: "planted pending art" },
  };
  const fails = [
    'PackPressure.lead_plant = "full"\n',
    'lead_plant = "none"\n',
    'lead_plant += "x"\n',
    'PackPressure.set("lead_plant", "full")\n',
    "pressure.set_deferred(&'lead_plant', \"full\")\n",
    'Cosmetics._test_pending = ["outfit_rivet_hood"]\n',
    'Cosmetics._test_pending.append("outfit_rivet_hood")\n',
    "_test_pending . clear()\n",
    'Cosmetics._test_pending[0] = "outfit_rivet_hood"\n',
    "_test_pending [i] += 1\n",
    'Cosmetics._test_pending[ids[0]] = "x"\n',
    '_test_pending[0].push_back("outfit_rivet_hood")\n',
    'lead_plant["mode"] = "full"\n',
  ];
  for (const text of fails) {
    assert.deepEqual(
      lintL12("x/world.gd", "src/world/world.gd", `func _go():\n\t${text}`, switches).map(
        (item) => `${item.rule} ${item.line}`,
      ),
      ["L12 2"],
      text,
    );
  }
  const passes = [
    'if PackPressure.lead_plant == "full":\n',
    'if lead_plant != "none" and lead_plant <= "z":\n',
    "var held := Cosmetics._test_pending.has(id)\n",
    "for id in PENDING_ART + _test_pending:\n",
    'if Cosmetics._test_pending[0] == "outfit_rivet_hood":\n',
    "var first = _test_pending[0]\n",
    'if lead_plant["mode"] != "none" and _test_pending[i] <= "z":\n',
    'var row := {"lead_plant": "full"}\n',
    'var unlead_plant = "full"\n',
    '# PackPressure.lead_plant = "full"\n',
  ];
  for (const text of passes) {
    assert.deepEqual(
      lintL12("x/world.gd", "src/world/world.gd", `func _go():\n\t${text}`, switches),
      [],
      text,
    );
  }
  const home =
    'static var lead_plant := ""\n\n\nstatic func reset_for_tests() -> void:\n\tlead_plant = ""\n\n\nstatic func lead() -> String:\n\treturn lead_plant\n';
  assert.deepEqual(
    lintL12("x/pack_pressure.gd", "src/combat/pack_pressure.gd", home, switches),
    [],
  );
  const armed = `${home}\n\nstatic func arm() -> void:\n\tlead_plant = "full"\n`;
  assert.deepEqual(
    lintL12("x/pack_pressure.gd", "src/combat/pack_pressure.gd", armed, switches).map(
      (item) => item.line,
    ),
    [13],
  );
  const borrowed = 'func reset_for_tests() -> void:\n\tPackPressure.lead_plant = ""\n';
  assert.equal(lintL12("x/world.gd", "src/world/world.gd", borrowed, switches).length, 1);
  assert.match(
    lintL12("x/pack_pressure.gd", "src/combat/pack_pressure.gd", "var other := 1\n", switches)[0]
      .message,
    /no longer declares: remove the entry/,
  );
});

test("L12's switch table matches the game source, and a planted write from src/ fails", () => {
  const homes = new Set(Object.values(FAULT_SWITCHES).map((row) => row.home));
  for (const rel of homes) {
    const text = readFileSync(path.join(sketchDir, rel), "utf8");
    assert.deepEqual(lintL12(rel, rel, text), [], rel);
  }
  const other = "src/world/world.gd";
  const world = readFileSync(path.join(sketchDir, other), "utf8");
  assert.deepEqual(lintL12(other, other, world), []);
  for (const [name, row] of Object.entries(FAULT_SWITCHES)) {
    const home = readFileSync(path.join(sketchDir, row.home), "utf8");
    assert.match(home, new RegExp(`^(?:static\\s+)?var\\s+${name}\\b`, "m"), name);
    const plant = `\nfunc _planted(holder) -> void:\n\tholder.${name} = null\n`;
    assert.equal(lintL12(row.home, row.home, home + plant).length, 1, `${row.home} ${name}`);
    assert.equal(lintL12(other, other, world + plant).length, 1, `${other} ${name}`);
    assert.match(lintL12(other, other, world + plant)[0].message, new RegExp(name));
    for (const write of [
      `holder.${name}[0] = null`,
      `holder.${name}.append(null)`,
      `holder.${name}.push_back(null)`,
    ]) {
      const indexed = `\nfunc _planted(holder) -> void:\n\t${write}\n`;
      assert.equal(lintL12(other, other, world + indexed).length, 1, `${other} ${write}`);
    }
  }
});

test("L13 flags raw DisplayServer.get_name() in src/ outside app_shell.gd and names AppShell.headless()", () => {
  const pastMistake = [
    "static func _is_headless_audio() -> bool:",
    "\tvar disp := DisplayServer.get_name().to_lower()",
    '\treturn disp == "headless"',
  ].join("\n");
  const bad = lintL13(
    "sketches/core-loop/src/experimental/live_run_bridge.gd",
    "src/experimental/live_run_bridge.gd",
    pastMistake,
  );
  assert.equal(bad.length, 1);
  assert.equal(bad[0].rule, "L13");
  assert.equal(bad[0].line, 2);
  assert.match(bad[0].message, /AppShell\.headless\(\)/);
  assert.deepEqual(
    lintL13("sketches/core-loop/src/core/app_shell.gd", "src/core/app_shell.gd", pastMistake),
    [],
  );
  assert.deepEqual(
    lintL13(
      "sketches/core-loop/src/experimental/live_run_bridge.gd",
      "src/experimental/live_run_bridge.gd",
      "static func _is_headless_audio() -> bool:\n\treturn AppShell.headless()\n",
    ),
    [],
  );
});

test("L13 flags raw DisplayServer.get_name() in tools/ and tests/, honors L13_ALLOWED counts, and flags stale entries", () => {
  const raw = 'if DisplayServer.get_name() == "headless":\n\tquit(2)\n';
  for (const rel of ["tools/new_capture.gd", "tests/new_test.gd"]) {
    const bad = lintL13(`sketches/core-loop/${rel}`, rel, raw);
    assert.equal(bad.length, 1, rel);
    assert.equal(bad[0].rule, "L13");
    assert.equal(bad[0].line, 1);
    assert.match(bad[0].message, /AppShell\.headless\(\)/);
  }
  const allowed = { "tools/offscreen_window.gd": { sites: 1, why: "embedded check" } };
  assert.deepEqual(
    lintL13(
      "sketches/core-loop/tools/offscreen_window.gd",
      "tools/offscreen_window.gd",
      "var d := DisplayServer.get_name().to_lower()\n",
      allowed,
    ),
    [],
  );
  assert.equal(
    lintL13(
      "sketches/core-loop/tools/offscreen_window.gd",
      "tools/offscreen_window.gd",
      'var d := DisplayServer.get_name().to_lower()\nif DisplayServer.get_name() == "headless":\n\tpass\n',
      allowed,
    ).length,
    2,
  );
  assert.match(
    lintL13(
      "sketches/core-loop/tools/offscreen_window.gd",
      "tools/offscreen_window.gd",
      "var ok := true\n",
      allowed,
    )[0].message,
    /tighten or remove/,
  );
  for (const [rel, entry] of Object.entries(L13_ALLOWED)) {
    const text = readFileSync(path.join(sketchDir, rel), "utf8");
    assert.deepEqual(lintL13(rel, rel, text), [], rel);
    assert.equal(lintL13(rel, rel, text, {}).length, entry.sites, rel);
    assert.equal(lintL13(rel, rel, `${text}\n${raw}`).length, entry.sites + 1, rel);
  }
});

test("L8 passes a listed sim read, and flags a drifted count and a stale entry", () => {
  const allowed = { "src/presentation/hero_assets.gd": { sites: 1, why: "sight target" } };
  const lens = "var dir = target.ball_position() - origin\n";
  assert.deepEqual(
    lintL8("x/hero_assets.gd", "src/presentation/hero_assets.gd", lens, allowed),
    [],
  );
  const drift = lintL8(
    "x/hero_assets.gd",
    "src/presentation/hero_assets.gd",
    lens + "var at = player.ball_position()\n",
    allowed,
  );
  assert.deepEqual(
    drift.map((item) => item.line),
    [1, 2],
  );
  assert.equal(drift[0].message.includes("SIM_READS lists 1"), true);
  const stale = lintL8(
    "x/hero_assets.gd",
    "src/presentation/hero_assets.gd",
    "var at = player.shown_position()\n",
    allowed,
  );
  assert.deepEqual(
    stale.map((item) => `${item.rule} ${item.line}`),
    ["L8 1"],
  );
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
  const bad = lintL1(
    "t.gd",
    "func x():\n\tvar a := Time.get_ticks_msec()\n\tawait create_timer(1.0).timeout\n",
  );
  assert.deepEqual(
    bad.map((item) => item.line),
    [2, 3],
  );
  assert.equal(formatFinding(bad[0]).startsWith("L1 t.gd:2 "), true);
  assert.deepEqual(
    lintL1("t.gd", "func x():\n\tawait process_frame\n\t# Time.get_ticks_msec is banned\n"),
    [],
  );
});

test("L2 flags a raw write and passes a read", () => {
  assert.equal(
    lintL2("a.gd", 'var f := FileAccess.open(p, FileAccess.WRITE)\nf.store_string("x")\n').length,
    2,
  );
  assert.equal(
    lintL2("a.gd", "var f := FileAccess.open(p, FileAccess.READ)\nvar s := f.get_as_text()\n")
      .length,
    0,
  );
});

test("L3 flags a dangling flag and a dangling tuning key, and passes real ones", () => {
  const bad = lintL3(
    [{ path: "t.gd", text: 'args = ["--wrong=1"]\nt.set_option("nope", "x")\n' }],
    tuning,
  );
  assert.equal(bad.length, 2);
  const good = lintL3(
    [
      {
        path: "t.gd",
        text: 'args = ["--scrap=armor", "--harpoon-pull=on"]\nt.set_option("scrap_mode", "x")\n',
      },
    ],
    tuning,
  );
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
  const files = [
    {
      path: "render.py",
      text: "tag = next(v for v in sys.argv if v.startswith('--render-tag='))\n",
    },
  ];
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

test("L5 passes a retired header-only file", () => {
  assert.deepEqual(lintL5(header + "\n", new Set(["a_test", "b_test"])), []);
});

test("L5 fails on any entry when retired (max 0), a missing test, a duplicate, a bad header and a short row", () => {
  const names = ["a", "b"].map((name) => `${name}_test`);
  const exists = new Set(names);
  assert.match(
    lintL5([header, row("a_test")].join("\n"), exists)[0].message,
    /1 entries; QUARANTINE\.tsv is retired \(max 0\), use KNOWN-FAILING\.tsv/,
  );
  const missing = lintL5([header, row("gone_test")].join("\n"), exists);
  assert.ok(missing.some((f) => /not an existing top-level test/.test(f.message)));
  const dup = lintL5([header, row("a_test"), row("a_test")].join("\n"), exists);
  assert.ok(dup.some((f) => /listed twice/.test(f.message)));
  assert.match(lintL5("test\towner\n", exists)[0].message, /header/);
  const shortRow = lintL5([header, "a_test\tO1"].join("\n"), exists);
  assert.ok(shortRow.some((f) => /needs test, owner/.test(f.message)));
});

test("the baseline silences listed offenders and shrinks only", () => {
  const findings = [
    { rule: "L1", path: "a.gd", line: 3, message: "m" },
    { rule: "L1", path: "new.gd", line: 1, message: "m" },
  ];
  const baseline = { L1: ["a.gd", "fixed.gd", "gone.gd"], L2: [], L3: [], L4: [] };
  const out = applyBaseline(findings, baseline, (file) => file !== "gone.gd");
  assert.deepEqual(
    out.map((item) => `${item.rule} ${item.path}`),
    ["L1 new.gd", "BASELINE fixed.gd", "BASELINE gone.gd"],
  );
  assert.match(out[1].message, /remove from baseline/);
  assert.match(out[2].message, /file is gone/);
  assert.deepEqual(
    applyBaseline([{ rule: "L5", path: "q", line: 1, message: "m" }], { L5: ["q"] }, () => true)
      .length,
    1,
  );
  assert.deepEqual(baselineFrom(findings), {
    L1: ["a.gd", "new.gd"],
    L2: [],
    L3: [],
    L4: [],
    L11: {},
    L14: [],
    L15: {},
    L16: [],
    W1: {},
    W2: {},
    W4: {},
    W6: {},
    W7: {},
    S8: {},
    L18: [],
  });
});

test("unified baseline registry round-trips baselineFrom -> applyBaseline and catches stale entries for L11, L14, and L15", () => {
  assert.equal(BASELINE_RULES.L11.shape, "count");
  assert.equal(BASELINE_RULES.L14.shape, "keys");
  assert.equal(BASELINE_RULES.L15.shape, "count");

  const raw = [
    { rule: "L11", path: "sketches/core-loop/src/a.gd", line: 4, message: "id branch" },
    { rule: "L11", path: "sketches/core-loop/src/a.gd", line: 9, message: "id branch" },
    {
      rule: "L14",
      path: "sketches/core-loop/src/b.gd",
      line: 3,
      message: "static var _x",
      key: "sketches/core-loop/src/b.gd:_x",
    },
    { rule: "L15", path: "sketches/core-loop/tests/c_test.gd", line: 7, message: "60 hz" },
    { rule: "L15", path: "sketches/core-loop/tests/c_test.gd", line: 12, message: "60 hz" },
  ];

  const base = baselineFrom(raw);
  assert.deepEqual(base.L11, { "sketches/core-loop/src/a.gd": 2 });
  assert.deepEqual(base.L14, ["sketches/core-loop/src/b.gd:_x"]);
  assert.deepEqual(base.L15, { "sketches/core-loop/tests/c_test.gd": 2 });
  assert.deepEqual(
    applyBaseline(raw, base, () => true),
    [],
  );

  const reduced = [raw[0], raw[3]];
  const stale = applyBaseline(reduced, base, (file) => file !== "sketches/core-loop/src/b.gd");
  assert.deepEqual(stale.map((item) => `${item.rule} ${item.path}`).sort(), [
    "BASELINE sketches/core-loop/src/a.gd",
    "BASELINE sketches/core-loop/src/b.gd",
    "BASELINE sketches/core-loop/tests/c_test.gd",
  ]);
  assert.match(
    stale.find((item) => item.path === "sketches/core-loop/src/a.gd").message,
    /L11 fell to 1 from 2: lower the baseline to 1/,
  );
  assert.match(
    stale.find((item) => item.path === "sketches/core-loop/src/b.gd").message,
    /L14 \(sketches\/core-loop\/src\/b\.gd:_x\) no longer offends \(file is gone\): remove from baseline/,
  );
  assert.match(
    stale.find((item) => item.path === "sketches/core-loop/tests/c_test.gd").message,
    /L15 fell to 1 from 2: lower the baseline to 1/,
  );
});

const wardenDress = (light) => `func _dress_warden(warden) -> void:
\tvar base := _warden_scene(WARDEN_BASE)
\twarden.add_child(base)
${light ? "\tvar cool := OmniLight3D.new()\n\tbase.add_child(cool)\n" : "\t# OmniLight3D.new() would be freed with the Warden\n"}`;
const owners = {
  "src/presentation/hero_assets.gd": { sites: 1, owner: "MossBay barge, session-lived" },
};

test("L6 flags a Light3D created under a stage-freed node in an unlisted file", () => {
  const bad = lintL6(
    "sketches/s/src/combat/warden_dress.gd",
    "src/combat/warden_dress.gd",
    wardenDress(true),
    owners,
  );
  assert.deepEqual(
    bad.map((item) => `${item.rule} ${item.line}`),
    ["L6 4"],
  );
  assert.match(bad[0].message, /does not list/);
});

test("L6 flags a new light in a listed file whose site count drifts", () => {
  const text = "var lamp := OmniLight3D.new()\nbarge.add_child(lamp)\n" + wardenDress(true);
  const bad = lintL6("x/hero_assets.gd", "src/presentation/hero_assets.gd", text, owners);
  assert.equal(bad.length, 2);
  assert.match(bad[0].message, /2 runtime Light3D sites, LIGHT_OWNERS lists 1/);
});

test("L6 passes a listed owner, a lightless dress and a commented light", () => {
  const listed = lintL6(
    "x/hero_assets.gd",
    "src/presentation/hero_assets.gd",
    "var lamp := OmniLight3D.new()\nbarge.add_child(lamp)\n" + wardenDress(false),
    owners,
  );
  assert.deepEqual(listed, []);
  assert.deepEqual(lintL6("x/w.gd", "src/combat/warden_dress.gd", wardenDress(false), owners), []);
  assert.deepEqual(
    lintL6(
      "x/s.gd",
      "src/a.gd",
      "var s := DirectionalLight3D\nvar m := MeshInstance3D.new()\n",
      owners,
    ),
    [],
  );
});

test("L6 flags a stale owner entry", () => {
  assert.deepEqual(lintL6Owners(new Set(["src/presentation/hero_assets.gd"]), "s", owners), []);
  const stale = lintL6Owners(new Set(), "s", owners);
  assert.equal(stale.length, 1);
  assert.match(stale[0].message, /remove the entry/);
});

const sketchDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "sketches",
  "core-loop",
);
const realNames = readFileSync(path.join(sketchDir, "design-v3", "NAMES.md"), "utf8");
const wordCtx = {
  bans: parseNames(realNames),
  keys: parseBoundKeys(readFileSync(path.join(sketchDir, "src", "core", "bindings.gd"), "utf8")),
};
const codesOf = (value, voice = false) =>
  [...lintString("x.gd", 1, value, { ...wordCtx, voice }), ...lintS8Text("x.gd", 1, value)].map(
    (item) => item.rule,
  );

test("words: a planted bad string for every rule is reported with its code", () => {
  const planted = [
    ["W1", "An epic blast that hits hard"],
    ["W1", "Unleash the shot"],
    ["W2", "Get ready"],
    ["W2", "Are you sure?"],
    ["W2", "Scrap is up. Good luck out there, pilot."],
    ["W4", "Pick a class"],
    ["W4", "Hold E to mount the pylon"],
    ["W4", "F fires your active."],
    ["W4", "Radio: [.] next station"],
    ["W4", "U empties. Esc leaves."],
    ["W6", "Roll fast — hit hard"],
    ["W6", "Roll fast – hit hard"],
    ["W6", "Jam field · Locks picks 2 and 3."],
    ["W6", "Wait for it..."],
    ["W6", "Wait for it…"],
    ["W6", "Go now!"],
    ["W6", "Press “go”"],
    ["W6", "Cast time: a knock drops it"],
    ["W6", "KEPT IN YOUR TOTALS"],
    ["S8", "Esc to close"],
  ];
  for (const [code, value] of planted) {
    assert.ok(
      codesOf(value).includes(code),
      `${code} not reported for "${value}": ${codesOf(value).join(",")}`,
    );
  }
  const bans = wordCtx.bans.map((entry) => entry.ban);
  assert.ok(bans.length >= 15, `NAMES.md Lint column parsed to ${bans.length} bans`);
  for (const ban of bans)
    assert.ok(codesOf(`Now ${ban} works here`).includes("W7"), `W7 not reported for "${ban}"`);
  assert.ok(
    !bans.includes("detonation"),
    "detonation is Kest's ability name and is not a safe plain ban",
  );
});

test("words: S8 flags a Back button on another key or under another name, and passes Back on Esc", () => {
  const rules = (line) => lintS8("x.gd", line).map((item) => item.rule);
  assert.deepEqual(rules('\tback = ChoiceButton.new("back", "key_h", "Back")\n'), ["S8"]);
  assert.deepEqual(rules('\tclose = ChoiceButton.new("close", "key_esc", "Close build")\n'), [
    "S8",
  ]);
  assert.deepEqual(rules('\tvar b := ChoiceButton.new("back", "key_esc", "Return")\n'), ["S8"]);
  assert.deepEqual(rules('\tback = ChoiceButton.new("back", "key_esc", "Back")\n'), []);
  assert.deepEqual(
    rules('\t_buttons.add_child(ChoiceButton.new("launch", "key_space", "Launch"))\n'),
    [],
  );
});

test("words: the held-out clean set of accepted lines draws no finding", () => {
  const plain = [
    "Gates offer better parts",
    "Hull not returned.",
    "New run",
    "Back",
    "Settings",
    "Continue",
    "Choose pilot",
    "Replay stage %d",
    "Loose cannons, all of them. Pick one.",
    "No SPIL-9 pieces yet. They turn up in runs.",
    "The saved run would not load. %s",
    "Scrap per machine",
    "Clocked out",
    "Find the Warden",
    "Keep playing.",
    "MOSS'S JUKEBOX",
    "Third bounce in 4s strikes double",
    "Every 8s, next hit +60%",
    "Kills in cloak extend it 0.4s",
    "%d:%02d",
    "3:42",
    "Ultimate becomes Ball Lightning.",
    "ULTIMATE",
    "Detonation line recharges 25% faster",
    "Reactor Warden pulse",
    "A small efficiency fee. You're welcome.",
    "Rare pressing. Found in a cartridge slot.",
    "Recorded at full speed. No refunds.",
    "Moss's copy. The label is a ration sticker.",
    "Esc",
    "P / Esc",
  ];
  const voice = [
    "Tragic, right?",
    "This is the sad part.",
    "%s hull. Moss packed a spare.",
    "Meanwhile, at %s.",
    "SHIFT COMPLETE",
    "THE WAKING STILLED",
    "ADMIRAL BRINDLE",
    "06:00",
    "Eyesight",
    "theoretical",
    "Shift log, after hours: found the pump crew's break room behind the bench wash. Kettle still warm.",
    "Mind: Welcome home, Kest. I kept your sky. Commit to staying.",
    "Toe apron stencil: STAND CLEAR OF THE FACE.",
  ];
  assert.ok(plain.length + voice.length >= 25);
  for (const value of plain) assert.deepEqual(codesOf(value), [], `flagged accepted "${value}"`);
  for (const value of voice)
    assert.deepEqual(codesOf(value, true), [], `flagged accepted voice "${value}"`);
});

test("words: extraction reads player text and skips keys, node paths, signals, ids and debug prints", () => {
  const fixture = [
    'const Palette := preload("res://src/core/palette.gd")',
    'const TIPS := {"grip_tip": "Fast balls cling to walls."}',
    'signal opened("page_opened")',
    "func _ready() -> void:",
    '\tvar node := get_node("Panel/VBox/Title")',
    '\t%Title.text = "Roll up scrap"',
    '\tprint("debug: Title text set")',
    '\temit_signal("page_opened")',
    '\tvar row: Dictionary = ROWS.get("find_warden", {})',
    '\tlabel.text = String(row.get("words", ""))',
    '\t# label.text = "A commented line"',
    '\tbutton = ChoiceButton.new("back", "key_esc", "Back")',
    '\tgame.hud.toast("Gate open")',
    'const NOTE_KEY := "hud:note"',
    'const NOTE_WORDS := "Note: read it"',
  ].join("\n");
  assert.deepEqual(
    readUi(fixture).map((item) => item.value),
    ["Fast balls cling to walls.", "Roll up scrap", "Back", "Gate open", "Note: read it"],
  );
  const rows =
    '{"id": "s_bulwark", "name": "Bulwark", "effect": "Mounted, crowd control slides off you", "key": "movement",\n\t"icon": "ab_sable_mount"}';
  assert.deepEqual(readRows(rows, { fields: ["name", "effect"] }), [
    { line: 1, value: "Bulwark" },
    { line: 1, value: "Mounted, crowd control slides off you" },
  ]);
});

test("words: the coverage floor fails an empty source list and a source that matches no file", () => {
  const empty = lintWords({
    sketchDir,
    prefix: "sketches/core-loop",
    names: realNames,
    bindings: readFileSync(path.join(sketchDir, "src", "core", "bindings.gd"), "utf8"),
    sources: [],
  });
  assert.equal(empty.total, 0);
  assert.deepEqual(
    empty.findings.map((item) => item.rule),
    ["COVERAGE"],
  );
  assert.match(empty.findings[0].message, /under the floor of 2650/);
  const missing = lintWords({
    sketchDir,
    prefix: "p",
    names: realNames,
    bindings: readFileSync(path.join(sketchDir, "src", "core", "bindings.gd"), "utf8"),
    sources: [{ path: "src/ui/no_such_page.gd", read: "ui" }],
    floor: 0,
  });
  assert.deepEqual(
    missing.findings.map((item) => `${item.rule} ${item.path}`),
    ["COVERAGE p/src/ui/no_such_page.gd"],
  );
});

test("words: a bad line planted in a real UI file is found by the same reader and rules", () => {
  const rel = "src/ui/camp_menu.gd";
  const text = readFileSync(path.join(sketchDir, rel), "utf8");
  const source = SOURCES.find((entry) => entry.read === "ui");
  const before = lintFile(rel, text, source, wordCtx);
  const lines = text.split("\n");
  const at = lines.findIndex((line) => line.startsWith("func "));
  lines.splice(at + 1, 0, '\tgame.hud.toast("Get ready — epic loot!")');
  const after = lintFile(rel, lines.join("\n"), source, wordCtx);
  const added = after.findings
    .filter((item) => item.line === at + 2)
    .map((item) => item.rule)
    .sort();
  assert.deepEqual(added, ["W1", "W2", "W6", "W6"]);
  assert.equal(after.read, before.read + 1);
});

test("words: the count baseline holds a file at its count, fails it above, and asks to lower or drop it below", () => {
  const hit = (path) => ({ rule: "W6", path, line: 1, message: "m" });
  const baseline = { W6: { "a.gd": 2, "b.gd": 2, "c.gd": 1 } };
  const out = applyBaseline(
    [hit("a.gd"), hit("a.gd"), hit("b.gd"), hit("b.gd"), hit("b.gd"), hit("d.gd")],
    baseline,
    () => true,
  );
  assert.deepEqual(out.map((item) => `${item.rule} ${item.path}`).sort(), [
    "BASELINE c.gd",
    "W6 b.gd",
    "W6 b.gd",
    "W6 b.gd",
    "W6 d.gd",
  ]);
  assert.match(out.find((item) => item.path === "b.gd").message, /3 in this file, baseline 2/);
  const lower = applyBaseline([hit("a.gd")], { W6: { "a.gd": 2 } }, () => true);
  assert.match(lower[0].message, /W6 fell to 1 from 2: lower the baseline to 1/);
  assert.deepEqual(baselineFrom([hit("a.gd"), hit("a.gd")]).W6, { "a.gd": 2 });
});

test("L14 passes the checked-out core-loop src tree against baseline and parses test_batch_driver refs", () => {
  const driverText = readFileSync(path.join(sketchDir, "tools", "test_batch_driver.gd"), "utf8");
  const refs = parseBatchDriverRefs(driverText);
  assert.ok(refs.size >= 80, `expected >= 80 driver refs, got ${refs.size}`);
  assert.ok(refs.has("src/build/parts.gd"));
  assert.ok(refs.has("src/core/challenge_dials.gd"));
  const baseline = JSON.parse(
    readFileSync(new URL("./sketch-lint.baseline.json", import.meta.url), "utf8"),
  );
  assert.ok(baseline.L14.length > 0);
  const raw = lintSketch("core-loop").filter((item) => item.rule === "L14");
  assert.deepEqual(
    applyBaseline(raw, { L14: baseline.L14 }, () => true),
    [],
  );
});

test("L14 blocks a new unwired static var and fails when a registered file adds a second unreset static var", () => {
  const file = "sketches/core-loop/src/presentation/planted_craft_cache.gd";
  const rel = "src/presentation/planted_craft_cache.gd";
  const srcWithReset = [
    "extends RefCounted",
    "",
    "static var _leaked_cache := {}",
    "const SAFE := 1",
    "var inst := 0",
    "static func reset_for_tests() -> void:",
    "\t_leaked_cache.clear()",
    "",
  ].join("\n");
  const emptyRefs = parseBatchDriverRefs("extends RefCounted\n");
  const bad = lintL14(file, rel, srcWithReset, emptyRefs, new Set());
  assert.equal(bad.length, 1);
  assert.equal(bad[0].rule, "L14");
  assert.equal(bad[0].line, 3);
  assert.match(bad[0].message, /_leaked_cache/);
  assert.match(bad[0].message, /sketches\/core-loop\/tools\/test_batch_driver\.gd _reset\(\)/);
  assert.match(bad[0].message, /clear _leaked_cache in the script's reset method/);

  const driverWithPath =
    'const Planted := preload("res://src/presentation/planted_craft_cache.gd")\n';
  const wiredRefs = parseBatchDriverRefs(driverWithPath);
  const wiredVars = parseBatchDriverVars(driverWithPath);
  assert.deepEqual(lintL14(file, rel, srcWithReset, wiredRefs, new Set(), wiredVars), []);

  const srcSecondLeak = [
    "extends RefCounted",
    "",
    "static var _leaked_cache := {}",
    "static var _second_leak := {}",
    "static func reset_for_tests() -> void:",
    "\t_leaked_cache.clear()",
    "",
  ].join("\n");
  const secondBad = lintL14(file, rel, srcSecondLeak, wiredRefs, new Set(), wiredVars);
  assert.equal(secondBad.length, 1);
  assert.equal(secondBad[0].rule, "L14");
  assert.equal(secondBad[0].line, 4);
  assert.match(secondBad[0].message, /_second_leak/);
  assert.match(
    secondBad[0].message,
    /sketches\/core-loop\/tools\/test_batch_driver\.gd _reset\(\)/,
  );
  assert.match(secondBad[0].message, /clear _second_leak in the script's reset method/);

  const driverDirect = `${driverWithPath}func _reset() -> void:\n\tPlanted._second_leak = {}\n`;
  assert.deepEqual(
    lintL14(
      file,
      rel,
      srcSecondLeak,
      parseBatchDriverRefs(driverDirect),
      new Set(),
      parseBatchDriverVars(driverDirect),
    ),
    [],
  );

  const baselined = new Set([`${rel}:_leaked_cache`]);
  assert.deepEqual(lintL14(file, rel, srcWithReset, emptyRefs, baselined), []);
  assert.deepEqual(
    lintL14(file, rel, "# static var _commented := {}\nvar ok := 1\n", emptyRefs, new Set()),
    [],
  );
});

test("L14 covers tools/ and tests/support/ libraries preloaded by tests (clean, failing, and live tree)", () => {
  const testFiles = [
    {
      path: "sketches/core-loop/tests/sample_test.gd",
      text: [
        'extends "res://tools/runner.gd"',
        'const Helper := preload("res://tests/support/helper.gd")',
        '# const Ignored := preload("res://tools/commented.gd")',
        "",
      ].join("\n"),
    },
    {
      path: "sketches/core-loop/tests/support/helper.gd",
      text: [
        "extends RefCounted",
        "static var _cached := {}",
        "static func reset_for_tests() -> void:",
        "\t_cached.clear()",
        "",
      ].join("\n"),
    },
  ];
  const toolFiles = [
    {
      path: "sketches/core-loop/tools/runner.gd",
      text: 'const Shared := preload("res://tools/shared_state.gd")\n',
    },
    {
      path: "sketches/core-loop/tools/shared_state.gd",
      text: [
        "extends RefCounted",
        "static var flag := false",
        "static func reset_for_tests() -> void:",
        "\tflag = false",
        "",
      ].join("\n"),
    },
    {
      path: "sketches/core-loop/tools/unused_tool.gd",
      text: "extends RefCounted\nstatic var unreached := 0\n",
    },
    {
      path: "sketches/core-loop/tools/commented.gd",
      text: "extends RefCounted\nstatic var commented_only := 0\n",
    },
  ];
  const reached = preloadedTestSupportFiles(testFiles, toolFiles, "sketches/core-loop");
  assert.deepEqual(
    reached.map((file) => file.rel),
    ["tests/support/helper.gd", "tools/runner.gd", "tools/shared_state.gd"],
  );

  const emptyRefs = parseBatchDriverRefs("extends RefCounted\n");
  const failing = lintPreloadedTestSupport(
    testFiles,
    toolFiles,
    "sketches/core-loop",
    emptyRefs,
    new Set(),
  );
  assert.deepEqual(
    failing.map((item) => item.key),
    [
      "sketches/core-loop/tests/support/helper.gd:_cached",
      "sketches/core-loop/tools/shared_state.gd:flag",
    ],
  );

  const driver = [
    'const Helper := preload("res://tests/support/helper.gd")',
    'const Shared := preload("res://tools/shared_state.gd")',
    "",
  ].join("\n");
  const wiredRefs = parseBatchDriverRefs(driver);
  const wiredVars = parseBatchDriverVars(driver);
  assert.deepEqual(
    lintPreloadedTestSupport(testFiles, toolFiles, "sketches/core-loop", wiredRefs, wiredVars),
    [],
  );

  const noTools = lintPreloadedTestSupport(
    testFiles,
    [],
    "sketches/core-loop",
    wiredRefs,
    wiredVars,
  );
  assert.deepEqual(
    noTools.map((item) => `${item.rule} ${item.path}`),
    ["L14 sketches/core-loop/tools"],
  );
  assert.match(noTools[0].message, /sketches\/core-loop\/tools/);

  const noSupport = lintPreloadedTestSupport(
    [testFiles[0]],
    toolFiles,
    "sketches/core-loop",
    wiredRefs,
    wiredVars,
  );
  assert.deepEqual(
    noSupport.map((item) => `${item.rule} ${item.path}`),
    ["L14 sketches/core-loop/tests/support"],
  );
  assert.match(noSupport[0].message, /sketches\/core-loop\/tests\/support/);

  const neither = lintPreloadedTestSupport(
    [{ path: "sketches/core-loop/tests/plain_test.gd", text: "extends SceneTree\n" }],
    toolFiles,
    "sketches/core-loop",
    wiredRefs,
    wiredVars,
  );
  assert.deepEqual(
    neither.map((item) => `${item.rule} ${item.path}`),
    ["L14 sketches/core-loop/tools", "L14 sketches/core-loop/tests/support"],
  );

  const liveDriver = readFileSync(path.join(sketchDir, "tools", "test_batch_driver.gd"), "utf8");
  const liveRefs = parseBatchDriverRefs(liveDriver);
  for (const rel of [
    "tools/bot_profile.gd",
    "tools/skill_band.gd",
    "tools/traversal_line.gd",
    "tools/bot_fairness.gd",
    "tests/support/content_registry.gd",
    "tests/support/cosmetic_art.gd",
    "tests/support/teardown_noise.gd",
  ]) {
    assert.ok(liveRefs.has(rel), `expected ${rel} in driver refs`);
  }
  const raw = lintSketch("core-loop").filter((item) => item.rule === "L14");
  const toolOrSupport = raw
    .map((item) => item.key)
    .filter(
      (key) =>
        key.startsWith("sketches/core-loop/tools/") ||
        key.startsWith("sketches/core-loop/tests/support/"),
    )
    .sort();
  assert.deepEqual(toolOrSupport, []);
});

test("L15 passes the checked-out core-loop tests tree against baseline and blocks a second 60 Hz literal in find_in_fight_test.gd", () => {
  const baseline = JSON.parse(
    readFileSync(new URL("./sketch-lint.baseline.json", import.meta.url), "utf8"),
  );
  assert.ok(Object.keys(baseline.L15).length > 0);
  assert.equal(baseline.L15["sketches/core-loop/tests/find_in_fight_test.gd"], 1);
  const raw = lintSketch("core-loop").filter((item) => item.rule === "L15");
  assert.deepEqual(
    applyBaseline(raw, { L15: baseline.L15 }, () => true),
    [],
  );
  const findRel = "tests/find_in_fight_test.gd";
  const findPath = `sketches/core-loop/${findRel}`;
  const findText = readFileSync(path.join(sketchDir, findRel), "utf8");
  const regressed = `${findText}\nconst REGRESSED_FRAMES := int(ScreenBusy.FIND_HOLD * 60.0)\n`;
  const bad = applyBaseline(
    lintL15(findPath, findRel, regressed),
    { L15: { [findPath]: 1 } },
    () => true,
  );
  assert.equal(bad.length, 2);
  assert.match(bad[0].message, /Engine\.physics_ticks_per_second/);
  assert.match(bad[0].message, /2 in this file, baseline 1/);
});

test("L15 blocks hardcoded 60 Hz physics frame math and passes Engine.physics_ticks_per_second", () => {
  const file = "sketches/core-loop/tests/planted_find_in_fight_test.gd";
  const rel = "tests/planted_find_in_fight_test.gd";
  const badSrc = [
    "extends SceneTree",
    "const FIND_FRAMES := int(ScreenBusy.FIND_HOLD * 60.0)",
    "const DT := 1.0 / 60.0",
    "const STEP := 1.0 / 60",
    "func _wait() -> void:",
    "\tawait physics_frame",
    "",
  ].join("\n");
  const bad = lintL15(file, rel, badSrc, {});
  assert.deepEqual(
    bad.map((item) => `${item.rule} ${item.line}`),
    ["L15 2", "L15 3", "L15 4"],
  );
  assert.match(bad[0].message, /Engine\.physics_ticks_per_second/);

  const goodSrc = [
    "extends SceneTree",
    "func _frames_for(seconds: float) -> int:",
    "\treturn int(ceil(seconds * Engine.physics_ticks_per_second))",
    "func _wait() -> void:",
    "\tvar dt := 1.0 / float(Engine.physics_ticks_per_second)",
    "\tawait physics_frame",
    "",
  ].join("\n");
  assert.deepEqual(lintL15(file, rel, goodSrc, {}), []);

  const nonPhysics = "extends SceneTree\nconst DT := 1.0 / 60.0\nfunc _run():\n\tpass\n";
  assert.deepEqual(lintL15(file, rel, nonPhysics, {}), []);

  assert.deepEqual(lintL15(file, rel, badSrc, { [rel]: 3 }), []);
  assert.deepEqual(lintL15(file, rel, badSrc, { [rel]: 4 }), []);
  const ratcheted = lintL15(file, rel, badSrc, { [rel]: 2 });
  assert.equal(ratcheted.length, 3);
  assert.match(ratcheted[0].message, /Engine\.physics_ticks_per_second/);
  assert.match(ratcheted[0].message, /L15 baseline allows 2/);
});

test("L16 extracts edges from preload, load, extends, path constants, data rows and class_name, and skips self, prefixes, strings and comments", () => {
  const files = [
    {
      path: "sketches/core-loop/src/a/entry.gd",
      text: [
        'extends "res://src/a/base.gd"',
        'const PRE := preload("res://src/a/preloaded.gd")',
        'const PATH := "res://src/a/const_ref.gd"',
        'const ROWS := [{"script": "res://src/a/row_ref.gd"}]',
        'const SELF := "res://src/a/entry.gd"',
        'const UID := "res://src/a/b.gd.uid"',
        'const OTHER := "res://src/a/bb.gd"',
        'const LABEL := "NamedClass inside string"',
        'const DOC := """',
        "NamedClass inside triple-quoted string",
        '"""',
        "# NamedClass in full comment",
        "func _run() -> void:",
        '\tvar dyn = load("res://src/a/loaded.gd")',
        "\tvar ok := NamedClass.make() # OtherClass in inline comment",
        "\tvar near := NamedClassExtra.make()",
        "",
      ].join("\n"),
    },
    { path: "sketches/core-loop/src/a/base.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/preloaded.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/loaded.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/const_ref.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/row_ref.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/b.gd", text: "extends RefCounted\n" },
    { path: "sketches/core-loop/src/a/bb.gd", text: "extends RefCounted\n" },
    {
      path: "sketches/core-loop/src/a/named.gd",
      text: "class_name NamedClass\nextends RefCounted\nstatic func make():\n\treturn NamedClass.new()\n",
    },
    {
      path: "sketches/core-loop/src/a/other.gd",
      text: "class_name OtherClass\nextends RefCounted\n",
    },
    {
      path: "sketches/core-loop/src/a/only_string.gd",
      text: "const TEXT := \"NamedClass\"\nconst SINGLE := 'NamedClass'\n",
    },
  ];
  const graph = buildScriptGraph(files);
  assert.deepEqual(graph.get("sketches/core-loop/src/a/entry.gd"), [
    "sketches/core-loop/src/a/base.gd",
    "sketches/core-loop/src/a/bb.gd",
    "sketches/core-loop/src/a/const_ref.gd",
    "sketches/core-loop/src/a/loaded.gd",
    "sketches/core-loop/src/a/named.gd",
    "sketches/core-loop/src/a/preloaded.gd",
    "sketches/core-loop/src/a/row_ref.gd",
  ]);
  assert.deepEqual(graph.get("sketches/core-loop/src/a/named.gd"), []);
  assert.deepEqual(graph.get("sketches/core-loop/src/a/only_string.gd"), []);
});

test("L16 stronglyConnectedComponents finds 2-loop, 3-loop, acyclic tree, two separate loops and deep chains iteratively", () => {
  const cyclesOf = (graph) =>
    stronglyConnectedComponents(graph).filter((component) => component.length >= 2);

  const twoLoop = new Map([
    ["a", ["b"]],
    ["b", ["a"]],
  ]);
  assert.deepEqual(cyclesOf(twoLoop), [["a", "b"]]);

  const threeLoop = new Map([
    ["a", ["b"]],
    ["b", ["c"]],
    ["c", ["a"]],
  ]);
  assert.deepEqual(cyclesOf(threeLoop), [["a", "b", "c"]]);

  const tree = new Map([
    ["root", ["left", "right"]],
    ["left", ["leaf1", "leaf2"]],
    ["right", ["leaf3"]],
    ["leaf1", []],
    ["leaf2", []],
    ["leaf3", []],
  ]);
  assert.deepEqual(cyclesOf(tree), []);
  assert.equal(stronglyConnectedComponents(tree).length, 6);

  const twoLoops = new Map([
    ["a", ["b"]],
    ["b", ["a", "c"]],
    ["c", ["d"]],
    ["d", ["e"]],
    ["e", ["c"]],
  ]);
  assert.deepEqual(cyclesOf(twoLoops), [
    ["c", "d", "e"],
    ["a", "b"],
  ]);

  const deepChain = new Map();
  for (let i = 0; i < 4000; i++) {
    deepChain.set(`n${i}`, i + 1 < 4000 ? [`n${i + 1}`] : []);
  }
  assert.deepEqual(cyclesOf(deepChain), []);
  assert.equal(stronglyConnectedComponents(deepChain).length, 4000);
});

test("L16 reports one finding per file in a cycle with size and in-loop neighbours, and ratchets through the baseline", () => {
  const files = [
    {
      path: "sketches/core-loop/src/a.gd",
      text: 'const B := preload("res://src/b.gd")\nconst C := preload("res://src/c.gd")\nconst D := preload("res://src/d.gd")\nconst E := preload("res://src/e.gd")\nconst LEAF := preload("res://src/leaf.gd")\n',
    },
    { path: "sketches/core-loop/src/b.gd", text: 'const A := preload("res://src/a.gd")\n' },
    { path: "sketches/core-loop/src/c.gd", text: 'const A := preload("res://src/a.gd")\n' },
    { path: "sketches/core-loop/src/d.gd", text: 'const A := preload("res://src/a.gd")\n' },
    { path: "sketches/core-loop/src/e.gd", text: 'const A := preload("res://src/a.gd")\n' },
    { path: "sketches/core-loop/src/leaf.gd", text: "extends RefCounted\n" },
  ];
  const findings = lintL16(files);
  assert.deepEqual(
    findings.map((item) => item.path),
    [
      "sketches/core-loop/src/a.gd",
      "sketches/core-loop/src/b.gd",
      "sketches/core-loop/src/c.gd",
      "sketches/core-loop/src/d.gd",
      "sketches/core-loop/src/e.gd",
    ],
  );
  assert.match(
    findings[0].message,
    /5-file script dependency cycle \(depends on src\/b\.gd, src\/c\.gd, src\/d\.gd \(\+1 more\)\)/,
  );
  assert.ok(!findings[0].message.includes("src/leaf.gd"));

  const baseline = {
    L16: [
      "sketches/core-loop/src/a.gd",
      "sketches/core-loop/src/b.gd",
      "sketches/core-loop/src/c.gd",
      "sketches/core-loop/src/d.gd",
      "sketches/core-loop/src/leaf.gd",
    ],
  };
  const after = applyBaseline(findings, baseline, () => true);
  assert.deepEqual(
    after.map((item) => `${item.rule} ${item.path}`),
    ["L16 sketches/core-loop/src/e.gd", "BASELINE sketches/core-loop/src/leaf.gd"],
  );
  assert.match(after[1].message, /L16 no longer offends: remove from baseline/);
});

test("L17 flags hardcoded /home/andrew paths in scripts and passes HOME-based paths", () => {
  const clean = [
    "from pathlib import Path",
    'P = Path.home() / "scratch/w18"',
    'GODOT="${GODOT:-$HOME/.local/share/godot/godot}"',
    "# $HOME/scratch/log",
  ].join("\n");
  assert.deepEqual(lintL17("sketches/core-loop/tools/ok.py", clean), []);

  const bad = [
    'P = "/home/andrew/scratch/w18"',
    "G=/home/andrew/.local/share/godot/godot",
    "# /home/andrew/scratch/log",
  ].join("\n");
  const hits = lintL17("sketches/core-loop/tools/bad.py", bad);
  assert.deepEqual(
    hits.map((item) => `${item.rule} ${item.path}:${item.line}`),
    [
      "L17 sketches/core-loop/tools/bad.py:1",
      "L17 sketches/core-loop/tools/bad.py:2",
      "L17 sketches/core-loop/tools/bad.py:3",
    ],
  );
  assert.match(hits[0].message, /hardcoded \/home\/andrew path/);

  const realL17 = lintSketch("core-loop").filter((item) => item.rule === "L17");
  assert.deepEqual(realL17, []);
});

test("baselineGrowth fails a rule whose list gained an entry and names the rule, both counts, the new entry and the fix", () => {
  const base = { L1: ["a.gd", "b.gd"], L14: ["s.gd:_x"], L15: { "c.gd": 2 } };
  const [grew, ...rest] = baselineGrowth(base, { ...base, L1: ["a.gd", "b.gd", "d.gd"] });
  assert.deepEqual(rest, []);
  assert.equal(grew.rule, "BASELINE");
  assert.equal(grew.path, "scripts/sketch-lint.baseline.json");
  assert.equal(
    grew.message,
    "L1 list grew from 2 to 3 entries (new: d.gd): fix the offence instead of listing it",
  );
  assert.match(
    formatFinding(baselineGrowth(base, { ...base, L14: ["s.gd:_x", "t.gd:_y"] })[0]),
    /L14 list grew from 1 to 2 entries \(new: t\.gd:_y\): register a reset in sketches\/core-loop\/tools\/test_batch_driver\.gd/,
  );
  assert.equal(
    baselineGrowth(base, { ...base, L1: ["a.gd", "b.gd", "b.gd"] })[0].message,
    "L1 list grew from 2 to 3 entries (new: b.gd): fix the offence instead of listing it",
  );
  assert.equal(
    baselineGrowth(base, { ...base, L15: { "c.gd": 3 } })[0].message,
    "L15 list grew from 2 to 3 entries (new: c.gd (2 to 3)): fix the offence instead of listing it",
  );
});

test("baselineGrowth passes a moved or removed entry, fails a rule with an empty list that gains one, and allows a new rule's first list", () => {
  const base = { L1: ["a.gd", "b.gd"], L2: [], L15: { "c.gd": 2 }, W1: {} };
  assert.deepEqual(baselineGrowth(base, { ...base, L1: ["a.gd", "moved/b.gd"] }), []);
  assert.deepEqual(baselineGrowth(base, { ...base, L15: { "moved/c.gd": 2 } }), []);
  assert.deepEqual(baselineGrowth(base, { ...base, L1: ["a.gd"], L15: {} }), []);
  assert.deepEqual(baselineGrowth(base, { ...base, L99: ["new.gd"] }), []);
  assert.deepEqual(
    baselineGrowth(base, { ...base, L2: ["x.gd"], W1: { "y.gd": 1 } }).map((item) => item.message),
    [
      "L2 list grew from 0 to 1 entries (new: x.gd): fix the offence instead of listing it",
      "W1 list grew from 0 to 1 entries (new: y.gd (0 to 1)): fix the offence instead of listing it",
    ],
  );
});

test("readBaselineAt reads the committed baseline at a commit and refuses a ref that is not one", () => {
  assert.ok(Array.isArray(readBaselineAt("HEAD").L1));
  assert.throws(() => readBaselineAt("no-such-ref-g1"), /rev-parse/);
});

test("L18 flags a script with no uid file and a uid file with no script, naming the file and the fix", () => {
  const out = lintL18([
    "sketches/core-loop/src/a.gd",
    "sketches/core-loop/src/a.gd.uid",
    "sketches/core-loop/src/b.gd",
    "sketches/core-loop/tests/gone_test.gd.uid",
    "sketches/core-loop/src/notes.md",
  ]);
  assert.deepEqual(
    out.map((item) => formatFinding(item)),
    [
      "L18 sketches/core-loop/src/b.gd:1 script has no tracked NAME.gd.uid beside it; run a Godot import and commit the .uid file",
      "L18 sketches/core-loop/tests/gone_test.gd.uid:1 uid file has no NAME.gd beside it; delete the orphan",
    ],
  );
  assert.equal(BASELINE_RULES.L18.shape, "keys");

  const emptyFolders = [
    "sketches/core-loop/addons",
    "sketches/core-loop/src",
    "sketches/core-loop/tests",
    "sketches/core-loop/tools",
  ];
  for (const input of [[], ["sketches/core-loop/src/notes.md"]]) {
    const emptyFindings = lintL18(input, emptyFolders);
    assert.equal(emptyFindings.length, 1);
    assert.equal(emptyFindings[0].rule, "L18");
    for (const folder of emptyFolders) {
      assert.ok(emptyFindings[0].message.includes(folder), folder);
    }
  }

  const repoRoot = path.resolve(sketchDir, "..", "..");
  const gitDirRun = spawnSync("git", ["rev-parse", "--git-dir"], {
    cwd: repoRoot,
    encoding: "utf8",
  });
  assert.equal(gitDirRun.status, 0, gitDirRun.stderr);
  const gitDir = gitDirRun.stdout.trim();
  assert.ok(gitDir.length > 0);

  const tmp = mkdtempSync(path.join(os.tmpdir(), "sketch-lint-l18-"));
  const prevGitDir = process.env.GIT_DIR;
  try {
    const run = (cwd, ...args) => {
      const ran = spawnSync("git", args, { cwd, encoding: "utf8", env: cwdDecidesRepository() });
      assert.equal(ran.status, 0, ran.stderr);
    };
    const scratchSrc = path.join(tmp, "sketches", "core-loop", "src");
    mkdirSync(scratchSrc, { recursive: true });
    writeFileSync(path.join(scratchSrc, "missing_uid.gd"), "extends RefCounted\n");
    run(tmp, "init", "-q");
    run(tmp, "add", "sketches/core-loop/src/missing_uid.gd");
    run(tmp, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "missing uid");

    process.env.GIT_DIR = path.resolve(repoRoot, gitDir);
    const hooked = lintTrackedUids("sketches/core-loop", tmp);
    assert.deepEqual(
      hooked.map((item) => `${item.rule} ${item.path}`),
      ["L18 sketches/core-loop/src/missing_uid.gd"],
    );
  } finally {
    if (prevGitDir === undefined) delete process.env.GIT_DIR;
    else process.env.GIT_DIR = prevGitDir;
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("readBaselineAt throws when a blob-less clone cannot fetch the base copy, and returns {} when the commit has no baseline file", () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "sketch-lint-partial-"));
  try {
    const run = (cwd, ...args) => {
      const ran = spawnSync("git", args, { cwd, encoding: "utf8" });
      assert.equal(ran.status, 0, ran.stderr);
      return ran.stdout.trim();
    };
    const source = path.join(tmp, "source");
    mkdirSync(path.join(source, "scripts"), { recursive: true });
    run(source, "init", "-q");
    run(source, "config", "uploadpack.allowFilter", "true");
    const commit = (message) => {
      run(source, "add", "-A");
      run(source, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", message);
      return run(source, "rev-parse", "HEAD");
    };
    writeFileSync(path.join(source, "README"), "x\n");
    const bare = commit("no baseline");
    const file = path.join(source, "scripts", "sketch-lint.baseline.json");
    writeFileSync(file, JSON.stringify({ L1: ["a.gd"] }));
    const base = commit("one entry");
    writeFileSync(file, JSON.stringify({ L1: ["a.gd", "b.gd"] }));
    const head = commit("two entries");
    const clone = path.join(tmp, "clone");
    run(tmp, "clone", "-q", "--filter=blob:none", "--no-checkout", `file://${source}`, clone);
    run(clone, "checkout", "-q", head);
    renameSync(source, path.join(tmp, "gone"));
    assert.deepEqual(readBaselineAt(head, { cwd: clone }), { L1: ["a.gd", "b.gd"] });
    assert.deepEqual(readBaselineAt(bare, { cwd: clone }), {});
    assert.throws(
      () => readBaselineAt(base, { cwd: clone }),
      new RegExp(`base copy of scripts/sketch-lint\\.baseline\\.json at ${base} could not be read`),
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("parseLintArgs refuses a --base with no ref and a flag it does not know", () => {
  assert.deepEqual(parseLintArgs(["--sketch", "core-loop", "--base", "origin/main"]), {
    sketch: "core-loop",
    writeBaseline: false,
    base: "origin/main",
  });
  assert.throws(() => parseLintArgs(["--sketch", "core-loop", "--base"]), /--base requires a ref/);
  assert.throws(() => parseLintArgs(["--base", ""]), /--base requires a ref/);
  assert.throws(() => parseLintArgs(["--base", "--sketch", "core-loop"]), /--base requires a ref/);
  assert.throws(
    () => parseLintArgs(["--base=origin/main"]),
    /unknown argument --base=origin\/main/,
  );
});
