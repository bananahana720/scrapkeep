extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Items := preload("res://src/build/items.gd")
const Parts := preload("res://src/build/parts.gd")
const WorldPrompt := preload("res://src/ui/world_prompt.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The cog wallet on screen (CG2): scrap is mass, cogs are money, and every place that
# showed scrap as a wallet now shows cogs.
#   - the shop counter's wallet readout shows run.cogs, not run.scrap;
#   - with scrap high and cogs low the reroll, top-shelf and cell tiles read "poor"; with
#     cogs high and scrap zero they read "ok";
#   - the HUD's wallet reads run.cogs while playing;
#   - the run summary carries cogs;
#   - a fabricator hoop's label names cogs and WorldPrompt.parse still reads it as a fabricator;
#   - the hoop is the authored recipe (no torus), standing across its line around the trigger band,
#     and its steel wears the state tint: dark copper short of cogs, amber when you can buy;
#   - an activity's payout adds cogs beside its mass;
#   - an item whose effect is scrap reads as mass, not money.
# Every wait is a counted physics frame; none reads the wall clock.

const SETTLE := 20

var _game
var _ws
var _failures := 0
var _phase := "boot"
var _wait := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _states() -> Array:
	var counter = _ws.counter
	var tiles: Array = []
	for k in ["reroll", "top"]:
		tiles.append(counter.tile_for(k))
	tiles.append(counter.tile_for("cell"))
	return tiles.map(func(t): return t.state() if t != null else "missing")


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			_ws = _game.get_node("Workshop")
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_phase = "shop"
			_wait = 0
		"shop":
			if _wait == SETTLE:
				_ws.armed = true
				_game.build.shop.enter()
				_game.run.add_scrap(5000, Vector3.ZERO)
				_game.run.cogs = 3
				_ws.open_counter()
				_ws.counter.refresh()
				var words: PackedStringArray = _ws.counter._scrap.drawn_words()
				_check("shop wallet", words == PackedStringArray(["3"]),
					"scrap 5000, cogs 3: readout %s" % [words])
				var poor := _states()
				_check("tiles poor on cogs", poor == ["poor", "poor", "poor"],
					"scrap 5000, cogs 3: reroll/top/cell %s" % [poor])
				_game.run.cogs = 5000
				_ws.counter.refresh()
				var rich := _states()
				_check("tiles ok on cogs", rich == ["ok", "ok", "ok"],
					"scrap still high, cogs 5000: reroll/top/cell %s" % [rich])
				_ws.counter.close()
				_phase = "hud"
				_wait = 0
		"hud":
			if _wait == SETTLE:
				_game.run.scrap = 0
				_game.run.cogs = 37
			if _wait == SETTLE + 3:
				_check("HUD wallet", _game.hud.wallet_cogs() == 37,
					"cogs 37: HUD reads %d" % _game.hud.wallet_cogs())
				var s: Dictionary = _game.run.summary()
				_check("summary cogs", s.has("cogs") and s["cogs"] == 37 and s.has("scrap"), "summary %s" % [s.keys()])
				_hoop()
				_text()
				_phase = "activity"
				_wait = 0
		"activity":
			_game.free()
			_game = Game.new()
			_game.test_mode = true
			_game.table = "slice"
			root.add_child(_game)
			_phase = "activity_boot"
			_wait = 0
		"activity_boot":
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "activity_pay"
			_wait = 0
		"activity_pay":
			if _wait == SETTLE:
				_activity()
				print("cog_ui_test: PASS" if _failures == 0 else "cog_ui_test: FAIL (%d)" % _failures)
				quit(0 if _failures == 0 else 1)
	return false


func _hoop() -> void:
	var fabs = _game.build.fabricators
	fabs.clear()
	var at: Vector3 = _game.ctx.terrain.drop_point(-62.0, -70.0, 0.0)
	var fab: Dictionary = fabs.add_at(at, Vector3(0.0, 0.0, 1.0), "long_spool")
	fabs.step(Vector3(0.0, 500.0, 0.0), 0.016, 0, [])
	var poor: String = fab["text"]
	var poor_tint: Array = _tints(fab)
	var price: int = fabs.price("long_spool", 0)
	fabs.step(Vector3(0.0, 500.0, 0.0), 0.016, price + 100, [])
	var ready: String = fab["text"]
	var ready_tint: Array = _tints(fab)
	_hoop_recipe(fab, poor_tint, ready_tint)
	var parsed: Dictionary = WorldPrompt.parse(ready)
	_check("hoop label", poor.contains("need %d cogs (have 0)" % price) and ready.contains("ROLL THROUGH: %d cogs" % price)
			and not ready.contains("scrap") and parsed["icon"] == "obj_fabricator",
		"short \"%s\"; ready \"%s\"; parsed icon %s" % [poor.replace("\n", " / "), ready.replace("\n", " / "), parsed["icon"]])
	fabs.clear()


# The state tint on each steel view of the hoop's base (the views that wear the hoop's state).
func _tints(fab: Dictionary) -> Array:
	var base: Array[GeometryInstance3D] = []
	base.assign((fab["node"] as Node3D).find_children("fabricator_hoop_*", "MeshInstance3D", false, false))
	return RecipeProps.steel_views(base).map(func(v): return v.get_instance_shader_parameter("state_tint"))


# SWAP-WAVE 12-F (2026-10-09): the greybox torus became the recipe hoop; these checks pin the swap.
func _hoop_recipe(fab: Dictionary, poor_tint: Array, ready_tint: Array) -> void:
	var node: Node3D = fab["node"]
	var tori := node.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh is TorusMesh)
	var base := node.find_children("fabricator_hoop_*", "MeshInstance3D", false, false)
	var shells := node.find_children("*", "MeshInstance3D", false, false).filter(func(m): return m.has_meta(RecipeProps.META_FADE))
	_check("hoop recipe views", tori.is_empty() and base.size() == 2 and shells.size() == RecipeProps.shell_rows("fabricator_hoop").size(),
		"torus %d, base views %d (want 2), shells %d" % [tori.size(), base.size(), shells.size()])
	_check("hoop state tint", poor_tint == [Fabricators.state_tint(false)] and ready_tint == [Fabricators.state_tint(true)]
			and Fabricators.state_tint(true) != Fabricators.state_tint(false),
		"one steel view each time; short of cogs %s, ready %s" % [poor_tint, ready_tint])
	var box := AABB()
	for i in base.size():
		var m: MeshInstance3D = base[i]
		var b: AABB = node.global_transform * m.transform * m.mesh.get_aabb()
		box = b if i == 0 else box.merge(b)
	var facing: Vector3 = fab["facing"]
	var along := box.size.dot(facing.abs())
	var across := box.size.dot(facing.cross(Vector3.UP).abs())
	var ground: float = (fab["at"] as Vector3).y
	# The visible ring stands on the ground across its line and covers the trigger band (step: rel.y < RING * 2 - SINK,
	# side within WIDTH / 2 + 0.5); the band is several class I balls tall.
	_check("hoop bounds", absf(box.position.y - ground) < 0.05 and box.end.y - ground >= Fabricators.RING * 2.0 - Fabricators.SINK
			and across >= Fabricators.WIDTH + 1.0 and along < 3.0 and box.size.y > Tuning.RADIUS * 8.0,
		"ground %.2f, box %s, along facing %.2f, across %.2f, ball radius %.2f" % [ground, box, along, across, Tuning.RADIUS])


func _text() -> void:
	var drum: String = Items.TABLE["ballast_drum"]["text"]
	var cache: String = Items.TABLE["cache_key"]["text"]
	var drone: String = Items.TABLE["salvage_drone"]["text"]
	var gravity: String = Parts.def("scrap_gravity").text
	# NAMES.md (wave 36): what the ball rolls up is scrap, how much it carries is heft, and "mass" is retired.
	var ok := drum.contains("heft")
	for t in [cache, drone, gravity]:
		ok = ok and t.contains("scrap")
	for t in [drum, cache, drone, gravity]:
		ok = ok and not t.to_lower().contains("mass")
	_check("scrap effects say scrap or heft, never mass", ok, "\"%s\" | \"%s\" | \"%s\" | \"%s\"" % [drum, cache, drone, gravity])


func _activity() -> void:
	var acts = _game.world.activities
	var site = acts.site("cracked_cache")
	var run = _game.run
	var cogs: int = run.cogs
	var scrap: int = run.scrap
	acts._pay_scrap(site, site.global_position)
	_check("activity pays cogs", site != null and run.cogs > cogs and run.cogs - cogs == run.scrap - scrap and run.scrap > scrap,
		"cogs %d -> %d, scrap %d -> %d" % [cogs, run.cogs, scrap, run.scrap])
