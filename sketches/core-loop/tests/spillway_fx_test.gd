# smoke: solo timeout=300s (enters the dam and the flume)
extends SceneTree

# The Spillway parks' anchored effects (spillway_fx.gd, Specs.SPILL_PLACES; unit 14): on the dam the
# powerhouse steams and the dam's spray curtain stands at its gate leaves once the landmark is built;
# on the flume the weir gatehouse steams, the weir falls spray and the penstock tower vents. Every set
# names a real place in its park, the anchors go through WorldFx's ranking, and the run's seed reaches
# them: one bot seed gives the same look twice, another seed a different one.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Grain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")

# What each Spillway park stands, by set.
const WANT := {
	1: ["spill_powerhouse", "landmark_dam"],
	2: ["spill_powerhouse", "spill_falls", "landmark_penstock_tower"],
}
const LANDMARK_FRAMES := 600

var _t := T.new("spillway_fx_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.ctx.run.run_seed_override = 31
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	var terrain = game.ctx.terrain
	var looks := {}
	for stage in WANT:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await physics_frame
		var stage_root: Node3D = terrain.geometry_root(stage)
		var fx: Node3D = stage_root.get_node_or_null("SpillwayScenery/SpillwayFx")
		_t.check("stage %d hangs the Spillway's effects" % stage, fx != null)
		if fx == null:
			continue
		for k in LANDMARK_FRAMES:
			if not fx.is_processing():
				break
			await process_frame
		var sets: Array = fx.placed.map(func(a): return String(a.set_id))
		sets.sort()
		var want: Array = WANT[stage].duplicate()
		want.sort()
		_t.eq("stage %d stands its sets" % stage, sets, want)
		_t.eq("stage %d: the run's seed reaches the effects" % stage, Grain.run_seed, int(game.ctx.run.run_seed))
		for a: Node3D in fx.placed:
			_t.check("stage %d %s is in the tree and ranked by WorldFx" % [stage, a.name], a.is_inside_tree()
				and WorldFx.current != null and a.emitters.size() == Specs.SETS[a.set_id].size())
			_t.check("stage %d %s stands inside the park" % [stage, a.name], terrain.map_for(stage).play_rect.grow(400.0).has_point(Vector2(a.global_position.x, a.global_position.z)),
				str(a.global_position))
			for p: GPUParticles3D in a.emitters:
				looks["%d/%s" % [stage, p.get_meta("world_fx")]] = p.seed
			if a.set_id == "landmark_dam":
				var lm: Node3D = a.get_parent()
				var gates: Array = ["gate_l", "gate_r"].map(func(n): return lm.get_node_or_null(n))
				if gates.all(func(n): return n != null):
					var mid: Vector3 = (gates[0].position + gates[1].position) * 0.5
					_t.check("the dam's curtain stands at its gate leaves", a.position.is_equal_approx(mid + Specs.SPILL_PLACES[2]["offset"]), "%s vs %s" % [a.position, mid])
		var steam: Array = fx.placed.filter(func(a): return a.set_id == "spill_powerhouse")
		if not steam.is_empty():
			var ground: float = terrain.height(steam[0].global_position.x, steam[0].global_position.z)
			_t.check("stage %d's steam stands on its roof, not under the ground" % stage, steam[0].global_position.y > ground,
				"steam %.1f, ground %.1f" % [steam[0].global_position.y, ground])
	_t.check("the parks' effects take their run's own particle seeds", looks.values().all(func(s): return s != 917))
	# A second run on the same bot seed looks the same; another seed looks different.
	var first := looks.duplicate()
	for seed in [32, 31]:
		game.ctx.run.run_seed_override = seed
		game.ctx.run.begin(game.ctx.run.class_def)
		game.flow.enter_stage(1, Vector3.ZERO, false)
		await physics_frame
		var fx: Node3D = terrain.geometry_root(1).get_node("SpillwayScenery/SpillwayFx")
		var same: bool = fx.placed.all(func(a): return a.emitters.all(func(p): return first.get("1/%s" % p.get_meta("world_fx")) == p.seed))
		if seed == 31:
			_t.check("the same seed gives the same look", same)
		else:
			_t.check("another seed gives another look", not same)
	game.queue_free()
	await physics_frame
	quit(_t.verdict())


func _table() -> void:
	for place in Specs.SPILL_PLACES:
		_t.check("place row %s names an anchor set" % place["set"], Specs.SETS.has(place["set"])
			and Specs.SETS[place["set"]].all(func(id): return Specs.SPECS[id]["attach"] == "anchor"))
	for name in ["park_dam", "park_flume"]:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % name))
		var ids := {}
		for row in park["park_rows"]:
			ids[row["id"]] = true
		var named := 0
		for place in Specs.SPILL_PLACES:
			for id in place.get("rows", []):
				named += int(ids.has(id))
		_t.check("%s carries at least one place row" % name, named >= 1, str(named))
