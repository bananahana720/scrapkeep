extends SceneTree

# JL-27: the Jev Lab port's read side on Spillway Drop. `seed_override` reseeds the
# stage and leaves the default stage alone; the layout helpers put the refuges above
# the full flood and the routes where the terrain has them; the state export offers the
# route and flood choices, keeps an enemy a threat until the game removes it (stage
# threat rule 2), and validates against protocol v1. No gameplay is judged here.

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")
const FloodCycle := preload("res://src/flood_cycle.gd")
const Director := preload("res://src/director.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const JevState := preload("res://src/jev/jev_state.gd")
const Geo := preload("res://src/jev/geo.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")


# Run.observe's view, fed by hand.
class FakeView:
	extends RefCounted

	var tick := 0
	var at := Vector3.ZERO
	var v := Vector3.ZERO
	var on_ground := true

	func position() -> Vector3:
		return at

	func velocity() -> Vector3:
		return v

	func grounded() -> bool:
		return on_ground

	func hp() -> float:
		return 100.0

	func alive() -> bool:
		return true

	func submersion() -> float:
		return 0.0

	func flood_phase() -> int:
		return FloodCycle.DRY

	func hatch_open() -> bool:
		return false

	func knocked_count() -> int:
		return 0

	func scrap_held() -> int:
		return 0


var _stages := {}
var _started := false
var _failures := 0


func _initialize() -> void:
	for key in ["default", "same", "zero", "seven", "eight", "probe"]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var stage = Stage.new()
		stage.test_mode = true
		match key:
			"same":
				stage.seed_override = Stage.DEFAULT_SEED
			"zero":
				stage.seed_override = 0
			"seven":
				stage.seed_override = 7
			"eight":
				stage.seed_override = 8
		viewport.add_child(stage)
		_stages[key] = stage


func _check(ok: bool, text: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _started:
		return false
	for stage in _stages.values():
		if stage.player == null:
			return false
	_started = true
	for stage in _stages.values():
		stage.director.paused = true
	_seed_checks()
	_geo_checks()
	_route_checks()
	_state_checks()
	print("jev_state_test: %s" % ("PASS" if _failures == 0 else "FAILED %d" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _seed_checks() -> void:
	var d = _stages["default"]
	var same = _stages["same"]
	var seven = _stages["seven"]
	var eight = _stages["eight"]
	_check(d.scrap.item_position(0) == same.scrap.item_position(0) and d.scrap.count() == same.scrap.count(),
		"seed_override %d reproduces the default stage's scrap layout" % Stage.DEFAULT_SEED)
	_check(seven.scrap.item_position(0) != eight.scrap.item_position(0),
		"seed_override 7 and 8 lay the scrap out differently")
	var a := Director.new(7)
	var b := Director.new(7)
	var same_orders := true
	for i in 200:
		if a.advance(0.5, 0) != b.advance(0.5, 0):
			same_orders = false
	_check(same_orders and seven.director._rng.seed == 7, "the director is seeded from seed_override")
	# Seed 0 is a seed of its own, not the default (JL-27 review, F5): the runner's
	# default --seed is 0, and only -1 means the stage as played.
	var zero = _stages["zero"]
	_check(zero.director._rng.seed == 0 and zero.scrap.item_position(0) != d.scrap.item_position(0),
		"seed_override 0 seeds the stage with 0, distinct from the default %d" % Stage.DEFAULT_SEED)


func _geo_checks() -> void:
	var surface := Geo.full_surface()
	for spot in Geo.REFUGES:
		var at: Vector3 = Terrain.at(spot, Geo.BALL_CLEARANCE)
		_check(not Geo.wet_at_full(at), "refuge %s stays dry at the full flood (%.1f m, surface %.1f)" % [spot, at.y, surface])
	var flood: Dictionary = Scenarios.make("flood-hatch")
	_check(not flood.is_empty() and Geo.wet_at_full(flood["spawn"]), "flood-hatch spawns in the flood")
	var climb: Dictionary = Scenarios.make("mid-climb")
	_check(not climb.is_empty() and Geo.shelf_at(climb["spawn"].z) == Geo.BASIN
		and Geo.shelf_at(climb["objective"]["point"].z) == Geo.MID, "mid-climb goes from the basin up to the mid shelf")
	_check(Scenarios.make("nope").is_empty(), "an unknown scenario id is refused")
	_check(Geo.corridor_at(Vector3(-18.0, 5.0, 50.0)) == "chute:2", "the west basin chute is a chute corridor")
	_check(Geo.corridor_at(Vector3(140.0, 8.0, 70.0)) == "bypass", "x 140 is the bypass")
	_check(Geo.corridor_at(Vector3(40.0, 1.0, 100.0)) == "open", "the basin floor is open ground")


func _route_checks() -> void:
	var from := Terrain.drop_point(40.0, 100.0, 1.0)
	var to := Terrain.drop_point(30.0, -10.0, 1.0)
	var ground: Array = Geo.ground_route(from, to)
	_check(ground.size() == 3 and is_equal_approx(ground[0].x, Terrain.BYPASS_X) and ground[2] == to,
		"the ground route up from the basin goes by the bypass ramp")
	_check(Geo.ground_route(to, from).size() == 1, "the ground route down is the straight line")
	var chute := Geo.chute_for(from, to)
	_check(chute == 2 or chute == 3, "a basin chute leads up toward the mid shelf (got %d)" % chute)
	var path: Array = Geo.chute_route(from, to)
	_check(path.size() == 3 and absf(path[0].x - Terrain.CHUTES[chute]["x"]) < 0.01 and path[1].z < Terrain.CHUTES[chute]["z0"],
		"the chute route runs from its foot out over its top")
	_check(Geo.chute_for(to, Terrain.drop_point(10.0, 5.0, 1.0)) == -1, "no chute on the same shelf")

	# Route attribution: the last corridor used before arriving on the upper shelf.
	var run := Scenarios.Run.new(Scenarios.make("mid-climb"))
	var view := FakeView.new()
	var path_points := [Vector3(40, 1, 100), Vector3(-18, 1, 86), Vector3(-18, 1, 70), Vector3(-18, 8, 40),
		Vector3(-18, 12, 22), Vector3(-10, 16, 12), Vector3(30, 16, -6)]
	for p in path_points:
		view.tick += 1
		view.at = p
		run.observe(view)
	_check(run.progress["route"] == "chute" and run.progress["route_tick"] == 6,
		"a climb up the west basin chute is attributed to the chute (got %s at %d)" % [run.progress["route"], run.progress["route_tick"]])
	var run2 := Scenarios.Run.new(Scenarios.make("mid-climb"))
	var view2 := FakeView.new()
	for p in [Vector3(40, 1, 100), Vector3(140, 1, 115), Vector3(140, 8, 70), Vector3(140, 16, 25), Vector3(100, 16, 10)]:
		view2.tick += 1
		view2.at = p
		run2.observe(view2)
	_check(run2.progress["route"] == "bypass", "a climb up x 140 is attributed to the bypass (got %s)" % run2.progress["route"])


func _state_checks() -> void:
	var stage = _stages["probe"]
	# Kinematic, because its teleport lands at once; a rigid one waits for the next step.
	stage.player.set_mode(PlayerBall.KINEMATIC)
	var scenario: Dictionary = Scenarios.make("mid-climb")
	Scenarios.place(stage, scenario)
	var run := Scenarios.Run.new(scenario)
	var view := JevState.new(stage, run)
	view.attach()
	view.advance()
	var jev := view.jev_block()
	var ids := _ids(jev)
	_check(ids.has("push_objective") and ids.has("hit_kicker"), "the basin offers the ground route and the chute (%s)" % [ids])
	var kicker := _option(jev, "hit_kicker")
	_check(not kicker.has("requires_speed_ms"), "the chute is not gated on a speed the steering cannot reach at decision time")
	_check(String(_option(jev, "push_objective")["why"]).contains("bypass"), "push_objective names the bypass ramp")
	_check(jev["state"]["stage"]["name"] == "spillway-drop" and jev["state"]["self"].has("hp"),
		"the state names the stage and carries hp")
	var message := {"protocol": JevIO.PROTOCOL, "seq": 0, "tick": 0, "held": null}
	message.merge(view.snapshot())
	var errors := JevIO.validate_state(message)
	_check(errors.is_empty(), "the snapshot validates against protocol v1 %s" % [errors])

	# Stage threat rule 2 (EV-0550): a chaser in reach is a threat and a target until
	# the game takes it out of play. A knocked chaser survives and keeps hitting, so it
	# stays; a dead one is removed and leaves.
	var at: Vector3 = stage.player.ball_position()
	var chaser = stage.spawn_enemy(Director.CHASER)
	chaser.global_position = at + Vector3(6.0, 0.5, 0.0)
	view.advance()
	jev = view.jev_block()
	_check(_kinds(jev).has("chaser") and _ids(jev).has("stomp_target"), "an unknocked chaser 6 m away is a threat and a stomp target")
	stage.player.enemy_struck.emit(chaser, true, 6.0)
	view.advance()
	jev = view.jev_block()
	_check(chaser.hp > 0.0 and _kinds(jev).has("chaser") and _ids(jev).has("stomp_target"),
		"a knocked chaser that survives (hp %.1f) stays a threat and a target" % chaser.hp)
	_check(view.knock_count("stomp") == 1 and view.knocked_count() == 1, "the knock is counted once, as a stomp")
	chaser.take_damage(chaser.hp + 1.0)
	view.advance()
	jev = view.jev_block()
	_check(not _kinds(jev).has("chaser") and not _ids(jev).has("stomp_target"),
		"a dead chaser, removed by the game, leaves the threats and the targets")
	var state_script: Script = JevState
	_check(state_script.get_script_constant_map().get("THREAT_RULE", "") == "stage-threat-rule 2",
		"the state names its threat rule epoch")

	# The flood: listed with its clock, aimed at the ball only where the full flood reaches.
	stage.flood.cycle.phase = FloodCycle.WARNING
	stage.flood.cycle.elapsed = 2.0
	stage.player.reset_to(Scenarios.make("flood-hatch")["spawn"])
	view.advance()
	jev = view.jev_block()
	var flood := _threat(jev, "flood")
	_check(not flood.is_empty() and is_equal_approx(flood["water_rises_in_s"], 3.0) and flood["targets_current_position"] == true,
		"in the basin the klaxon reads as a flood rising in 3 s at the ball (%s)" % [flood])
	_check(_ids(jev).has("evade_hazard"), "the flood in the basin offers evade_hazard")
	var refuge := Geo.nearest_refuge(stage.player.ball_position())
	_check(not Geo.wet_at_full(refuge), "evade's refuge is above the full flood")
	stage.player.reset_to(Terrain.drop_point(40.0, 0.0, 1.0))
	view.advance()
	jev = view.jev_block()
	flood = _threat(jev, "flood")
	_check(not flood.is_empty() and flood["targets_current_position"] == false and not _ids(jev).has("evade_hazard"),
		"on the mid shelf the flood is listed but not aimed at the ball")
	stage.flood.cycle.phase = FloodCycle.DRY
	stage.flood.cycle.elapsed = 0.0
	view.advance()
	_check(_threat(view.jev_block(), "flood").is_empty(), "a dry basin 57 s from the klaxon is no threat")
	view.detach()


func _ids(jev: Dictionary) -> Array:
	return jev["options"].map(func(option): return option["id"])


func _kinds(jev: Dictionary) -> Array:
	return jev["state"]["threats"].map(func(threat): return threat["kind"])


func _option(jev: Dictionary, id: String) -> Dictionary:
	for option in jev["options"]:
		if option["id"] == id:
			return option
	return {}


func _threat(jev: Dictionary, kind: String) -> Dictionary:
	for threat in jev["state"]["threats"]:
		if threat["kind"] == kind:
			return threat
	return {}
