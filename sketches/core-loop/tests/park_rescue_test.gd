extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# The park table rescues Rivet and Kest (KD7 makes it the launch default): park_dam and park_pit
# pass the schema with their rescue_rows, stage 1 (park_dam) stands Rivet's cage and stage 3
# (park_pit) Kest's, each at its row's site with its pilot seated, and freeing each fires its quest
# and unlocks its pilot. Every wait is counted in physics frames; none reads the wall clock.

# The park cages sit on slopes (a dome top, a bowl floor), so the approach steps in until the
# dropped ball is inside E's reach; farther out, Sable's E mounts the slope's face instead.
const STANDOFFS := [6.0, 4.0, 3.0, 2.0]
const HOLD_FRAMES := 60
const CAGES := [
	{"stage": 1, "map": "park_dam", "id": "rivet_cage", "quest": "rivet", "pilot": "runner_gunner"},
	{"stage": 3, "map": "park_pit", "id": "kest_cage", "quest": "dig", "pilot": "demolitions_caster"},
]

var _t := preload("res://tests/support/t.gd").new("park_rescue_test")
var _game
var _source := Intent.Scripted.new()
var _rescued: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _break_frames() -> int:
	return int(ceil(RescueSites.BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10


func _approach(cage) -> void:
	var f: Vector3 = -_game.camera.yaw_basis().z
	var forward := Vector3(f.x, 0.0, f.z).normalized()
	var ball := Vector3.INF
	for standoff in STANDOFFS:
		var at: Vector3 = cage.global_position - forward * standoff
		ball = _game.ctx.terrain.drop_point(at.x, at.z, 1.05)
		if cage.near(ball):
			break
	_game.player.reset_to(ball, Vector3.ZERO)
	_game.player.body().global_position = ball
	_source.hold = {}
	_source.press = {}
	await _frames(2)


func _run() -> void:
	for row in CAGES:
		var park := ParkMap.new("res://src/world/park/%s.json" % row["map"])
		_t.check("%s passes the park schema" % row["map"], park.ok, str(park.errors))
		_t.eq("%s lists one rescue" % row["map"], park.rescue_sites.map(func(s): return s["id"]), [row["id"]])

	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = _source
	_game.events.rescue_completed.connect(func(quest: String): _rescued.append(quest))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	var profile = _game.ctx.profile

	for row in CAGES:
		_game.flow.enter_stage(row["stage"], Vector3.ZERO, false)
		await _frames(60)
		var map = _game.ctx.terrain.map()
		var label: String = row["map"]
		_t.eq("stage %d is %s" % [row["stage"], label], map.title, label)
		_t.eq("%s stands one cage" % label, _game.world.rescue.cages.size(), 1)
		var cage = _game.world.rescue.cage(row["quest"])
		if cage == null:
			_t.check("%s has the %s cage" % [label, row["quest"]], false)
			continue
		var site: Vector2 = map.rescue_sites[0]["at"]
		_t.check("%s's cage stands at its row's site" % label, Vector2(cage.global_position.x, cage.global_position.z).distance_to(site) < 0.5,
			"cage %s site %s" % [cage.global_position, site])
		_t.check("%s's cage is a registered ally device" % label, _game.world.interact.devices.has(cage) and cage.family == "ally")
		var pilot = ClassDef.by_id(row["pilot"])
		_t.check("%s starts locked" % row["pilot"], not profile.has_pilot(row["pilot"]) and not _game.pilot_unlocked(pilot))

		await _approach(cage)
		var ball: Vector3 = _game.ctx.player.ball_position()
		_t.check("%s's cage is in E reach of the approach" % label, cage.near(ball), "ball %s reach %s" % [ball, cage.reach_point()])
		_source.press["mount_pressed"] = true
		_source.hold["mount_held"] = true
		await _frames(HOLD_FRAMES)
		_source.hold = {}
		await _frames(_break_frames())
		_t.check("%s's rescue fires %s" % [label, row["quest"]], _rescued.has(row["quest"]), str(_rescued))
		_t.check("%s is unlocked by the park rescue" % row["pilot"], profile.has_pilot(row["pilot"]) and _game.pilot_unlocked(pilot))

	_t.eq("each rescue fired once", _rescued, ["rivet", "dig"])
	_game.free()
	quit(_t.verdict())
